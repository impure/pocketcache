
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:path/path.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:sqlite3/common.dart';
import 'package:state_groups/state_groups.dart';

import 'count_records.dart';
import 'db_isolate.dart';
import 'get_records.dart';

/// PocketBase does not support getting more than 500 items at once so limit it to that amount. Maybe in the future we can increase it
const int defaultMaxItems = 500;

/// Get our results only from the server, only from the cache, or try server first and then the cache
/// Failures from the cache only or any will return an empty response, failures from server only will throw an exception
enum QuerySource {
	server,
	cache,
	any,
}

bool isTest() => kIsWeb ? false : Platform.environment.containsKey('FLUTTER_TEST');

enum AuthRefreshResult {
	success,
	network_error,
	failure,
}

class PbOfflineCache {

	factory PbOfflineCache(PocketBase pb, String? directoryToSave, {
		Logger? overrideLogger,
		Map<String, List<(String name, bool unique, List<String> columns)>>? indexInstructions,
		FutureOr<(String, List<Object?>)?> Function(String tableName, String lastUpdatedTime)? generateWhereForResync,
	}) {

		final String? path = directoryToSave == null ? null : join(directoryToSave, "offline_cache");

		return PbOfflineCache._(
			pb,
			DbIsolate(path),
			overrideLogger ?? Logger(),
			indexInstructions ?? const <String, List<(String name, bool unique, List<String>)>>{},
			path,
			generateWhereForResync,
		);
	}

	PbOfflineCache._(this.pb, this.dbIsolate, this.logger, [this.indexInstructions = const <String, List<(String name, bool unique, List<String>)>>{}, this.dbPath, this.generateWhereForResync]) {
		unawaited(reinitIndexes());

		if (!isTest()) {
			unawaited(_continuouslyCheckDbAccessible());
		}
	}

	factory PbOfflineCache.withDb(PocketBase pb, CommonDatabase db, {Logger? overrideLogger, Map<String, List<(String name, bool unique, List<String> columns)>> indexInstructions = const <String, List<(String name, bool unique, List<String>)>>{}}) {
		return PbOfflineCache._(pb, DbIsolate.test(db), overrideLogger ?? Logger(), indexInstructions);
	}

	Future<void> createAllIndexesForTable(String tableName, Map<String, List<(String, bool, List<String>)>> indexInstructions, {Logger? overrideLogger, Set<String>? tableKeys}) async {
		if (await dbIsolate.makePort == null) {
			return;
		}
		// TODO: needs more work to set up indexes for JSON, relations, and bools. Fix that.
		final List<(String name, bool unique, List<String> columns)>? indexesToCreate = indexInstructions[tableName];
		if (indexesToCreate != null) {
			for (final (String name, bool unique, List<String> columns) entry in indexesToCreate) {
				if (tableKeys != null && !tableKeys.containsAll(entry.$3)) {
					(overrideLogger ?? logger).e("Unable to create index ${entry.$1} on $tableName($tableKeys), could not find all columns: ${entry.$3}");
				} else {

					String columnNames = entry.$3.toString();
					columnNames = columnNames.substring(1, columnNames.length - 1);

					unawaited(dbIsolate.execute("CREATE${entry.$2 ? " UNIQUE" : ""} INDEX IF NOT EXISTS ${entry.$1} ON $tableName($columnNames)"));
				}
			}
		}
	}

	Future<void> reinitIndexes() async {
		if (await dbIsolate.makePort == null) {
			return;
		}
		final List<Map<String, dynamic>> tables = await dbIsolate.select("SELECT name FROM sqlite_master WHERE type = 'table'");

		for (final Map<String, dynamic> table in tables) {
			final String tableName = table['name'] as String;

			// Autogenerated by SQLite, ignore
			if (tableName == "sqlite_sequence") {
				continue;
			}

			// Don't drop these tables because they're probably empty and that causes errors
			if (tableName == "_operation_queue" || tableName == "_operation_queue_params") {
				continue;
			}

			if (tableName == "_last_sync_times") {
				continue;
			}

			try {
				unawaited(dbIsolate.execute("CREATE INDEX IF NOT EXISTS _idx_downloaded ON $tableName (_downloaded)"));
			} catch (e) {
				logger.w('Unable to create index: $e');
			}

			try {
				unawaited(createAllIndexesForTable(tableName, indexInstructions));
			} catch (e) {
				logger.w('Unable to create index: $e');
			}
		}
	}

	Future<void> dropAllTables(String directoryToSave) async {
		if (await dbIsolate.makePort == null) {
			return;
		}
		try {
			final List<Map<String, dynamic>> tables = await dbIsolate.select("SELECT name FROM sqlite_master WHERE type = 'table'");

			for (final Map<String, dynamic> table in tables) {
				final String tableName = table['name'] as String;

				// Autogenerated by SQLite, ignore
				if (tableName == "sqlite_sequence") {
					continue;
				}

				// Don't drop these tables because they're probably empty and that causes errors
				if (tableName == "_operation_queue" || tableName == "_operation_queue_params") {
					continue;
				}

				await dbIsolate.execute('DROP TABLE IF EXISTS $tableName');
				logger.i('Dropped table: $tableName');
			}

			logger.i('All tables dropped successfully');
		} catch (e) {
			logger.w('Error during dropAllTables: $e');
		} finally {

			// Have to recreate this table or it will cause issues
			await dbIsolate.execute("""
				CREATE TABLE IF NOT EXISTS _last_sync_times (
					table_name TEXT PRIMARY KEY,
					last_update TEXT
				)
			""");

			try {
				await dbIsolate.execute('VACUUM;');
				logger.i('Database vacuumed successfully');
			} catch (e) {
				logger.w('Error during vacuum: $e');
			}
		}
	}

	String? dbPath;
	final DbIsolate dbIsolate;
	bool dbAccessible = true;
	final PocketBase pb;
	final Logger logger;
	final Map<String, List<(String name, bool unique, List<String> columns)>> indexInstructions;

	/// Not required, but recommended. This is called periodically to resync the data with the db
	final FutureOr<(String, List<Object?>)?> Function(String tableName, String lastUpdatedTime)? generateWhereForResync;

	String? get id => isTest() ? "test" : pb.authStore.model?.id;
	bool get tokenValid => pb.authStore.isValid;

	Future<void> clearOldRecords(int maxOfflineDays) async {
		if (await dbIsolate.makePort != null) {
			final List<Map<String, dynamic>> data = await dbIsolate.select(
				"SELECT name FROM sqlite_master WHERE type='table'",
			);

			for (final Map<String, dynamic> row in data) {
				if (row["name"] != "_last_sync_times" && row["name"] != "sqlite_sequence" && row["name"] != "_operation_queue_params" && row["name"] != "_operation_queue") {
					try {
						unawaited(dbIsolate.execute("DELETE FROM ${row["name"]} WHERE _downloaded < ?", <Object>[DateTime.now().toUtc().subtract(Duration(days: maxOfflineDays)).toString()]));
					} catch (e) {
					}
				}
			}

		}
	}

	// Returns true on success, false on error
	Future<AuthRefreshResult> tryRefreshAuth(Function() onUnauthorizedError) async {
		if (id != null) {
			if (tokenValid) {
				try {
					await pb.collection('users').authRefresh();
					return AuthRefreshResult.success;
				} on ClientException catch (e) {
					if (e.isNetworkError()) {
						return AuthRefreshResult.network_error;
					} else if (e.toString().contains("The request requires valid record authorization token to be set")) {
						pb.authStore.clear();
						onUnauthorizedError();
						return AuthRefreshResult.failure;
					} else {
						rethrow;
					}
				}
			} else {
				onUnauthorizedError();
				return AuthRefreshResult.failure;
			}
		} else {
			return AuthRefreshResult.failure;
		}
	}

	Future<void> _continuouslyCheckDbAccessible() async {
		if (isTest()) {
			dbAccessible = false;
			return;
		}
		while (true) {
			try {
				final http.Response response = await http.get(pb.buildUrl("/api/health"));
				if (response.statusCode != 200) {
					dbAccessible = false;
				} else {
					if (!dbAccessible) {
						dbAccessible = true;
						logger.i("DB accessible again");
						broadcastToListeners("pocketcache/network-state-changed", true);
					}
					await dequeueCachedOperations();
					try {
						if (generateWhereForResync != null && await tableExists(dbIsolate, "_last_sync_times")) {
							bool gotNewItems = false;
							final List<Map<String, dynamic>> syncTimes = await dbIsolate.select("SELECT * FROM _last_sync_times");
							for (final Map<String, dynamic> row in syncTimes) {
								final (String, List<Object?>)? whereCondition = await generateWhereForResync!(row["table_name"], row["last_update"]);

								if (whereCondition == null) {
									continue;
								}

								final List<Map<String, dynamic>> items = await getRecords(row["table_name"], where: whereCondition, sort: ("updated", false), source: QuerySource.server);
								if (items.isNotEmpty) {

									for (final Map<String, dynamic> item in items) {
										broadcastToListeners("pocketcache/record-updated-resync", (row["table_name"], item));
									}

									gotNewItems = true;
									logger.i("Updating ${items.length} items in table ${row["table_name"]}");
									unawaited(dbIsolate.execute("INSERT OR REPLACE INTO _last_sync_times(table_name, last_update) VALUES(?, ?)", <dynamic>[	row["table_name"], items.last["updated"] ]));
								}
							}
							if (gotNewItems) {
								broadcastToListeners("pocketcache/local-cache-updated", null);
							}
						}
					} catch (e, stack) {
						logger.e("$e\n\n$stack");
					}
				}
			} catch (_) {
				if (dbAccessible) {
					dbAccessible = false;
					logger.i("DB do longer accessible");
					broadcastToListeners("pocketcache/network-state-changed", false);
				}
			}
			await Future<void>.delayed(const Duration(seconds: 10));
		}
	}

	Future<void> dequeueCachedOperations() async {

		if (await dbIsolate.makePort == null) {
			return;
		}

		final List<Map<String, dynamic>> data = await dbIsolate.select("SELECT * FROM _operation_queue ORDER BY created ASC");

		for (final Map<String, dynamic> operation in data) {

			final String operationId = operation["id"].toString();
			final String operationType = operation["operation_type"].toString();
			final String collectionName = operation["collection_name"].toString();
			final String pbId = operation["id_to_modify"].toString();

			final List<Map<String, dynamic>> data = await dbIsolate.select("SELECT * FROM _operation_queue_params WHERE operation_id = ?", <String>[ operationId ]);
			final Map<String, dynamic> params = <String, dynamic>{};
			for (final Map<String, dynamic> operationParam in data) {
				params[operationParam["param_key"].toString()] = operationParam["param_value"];
			}

			Future<void> cleanUp() async {
				await dbIsolate.execute("DELETE FROM _operation_queue WHERE id = ?", <String>[ operationId ]);
				await dbIsolate.execute("DELETE FROM _operation_queue_params WHERE id = ?", <String>[ operationId ]);
			}

			// If we failed to update data (probably due to a key constraint) then we need to delete the local copy of the record as well or we'll be out of sync
			Future<void> deleteLocalRecord() async {
				await dbIsolate.execute("DELETE FROM $collectionName WHERE id = ?", <String>[ pbId ]);
				await cleanUp();
			}

			switch (operationType) {
				case "UPDATE":
					try {
						await pb.collection(collectionName).update(pbId, body: params);
						await cleanUp();
					} on ClientException catch (e) {
						if (!e.isNetworkError()) {
							logger.e(e, stackTrace: StackTrace.current);
							await deleteLocalRecord();
							await cleanUp();
						}
					}
					break;
				case "DELETE":
					try {
						await pb.collection(collectionName).delete(pbId);
						await cleanUp();
					} on ClientException catch (e) {
						if (!e.isNetworkError()) {
							logger.e(e, stackTrace: StackTrace.current);
							await cleanUp();
						}
					}
					break;
				case "INSERT":
					try {
						params["id"] = pbId;
						await pb.collection(collectionName).create(body: params);
						await cleanUp();
					} on ClientException catch (e) {
						if (!e.isNetworkError()) {
							logger.e("Failed to insert $params into $collectionName ($e)", stackTrace: StackTrace.current);
							await deleteLocalRecord();
							await cleanUp();
						}
					}
					break;
				default:
					logger.e("Unknown operation type: $operationType, operation: $operation");
			}
		}
	}

	Future<void> queueOperation(
		String operationType,
		String collectionName,
		{Map<String, dynamic>? values, String idToModify = ""}
	) async {

		if (await dbIsolate.makePort == null) {
			return;
		}

		// This is not guaranteed to be unique but if two commands are executed at the same time the order doesn't really matter
		final int created = DateTime.now().toUtc().millisecondsSinceEpoch;

		final List<Map<String, dynamic>> record = await dbIsolate.select("INSERT INTO _operation_queue (operation_type, created, collection_name, id_to_modify) VALUES ('$operationType', $created, '$collectionName', ?) RETURNING id", <Object>[ idToModify ]);
		final int id = record.first.values.first! as int;

		if (values != null) {
			for (final MapEntry<String, dynamic> entry in values.entries) {

				String valueToWrite;

				if (entry.value is bool) {
					valueToWrite = entry.value.toString();
				} else if (entry.value is int) {
					valueToWrite = entry.value.toString();
				} else if (entry.value is double) {
					valueToWrite = entry.value.toString();
				} else if (entry.value is String) {
					valueToWrite = entry.value.toString();
				} else if (entry.value is List<dynamic> || entry.value is Map<dynamic, dynamic>) {
					valueToWrite = jsonEncode(entry.value);
				} else if (entry.value == null) {
					valueToWrite = "";
				} else {
					valueToWrite = "";
					logger.e("Unknown type: ${entry.value.runtimeType}");
				}

				unawaited(dbIsolate.select("INSERT INTO _operation_queue_params (operation_id, param_key, param_value) VALUES (?, ?, ?)", <Object?>[id, entry.key, valueToWrite]));
			}
		}
	}

	QueryBuilder collection(String collectionName) {
		return QueryBuilder._(this, collectionName, "", <dynamic>[], null, <String>[]);
	}
}

extension NetworkErrorCheck on ClientException{
	bool isNetworkError() {
		return toString().contains("refused the network connection")
				|| toString().contains("refused the connection")
				|| toString().contains("Failed host lookup")
				|| toString().contains("No address associated with hostname")
				|| toString().contains("statusCode: 0, response: {}");
	}
}

Future<bool> tableExists(DbIsolate db, String tableName) async {
	return (await db.select(
		"SELECT name FROM sqlite_master WHERE type='table' AND name=?",
		<String> [ tableName ],
	)).isNotEmpty;
}

Future<List<Map<String, dynamic>>> selectBuilder(DbIsolate db, String tableName, {
	String? columns,
	(String, List<Object?>)? filter,
	int? maxItems,
	(String, bool descending)? sort,
	Map<String, dynamic>? startAfter,
}) {

	final StringBuffer query = StringBuffer("SELECT ${columns ?? "*"} FROM $tableName");

	(String, List<dynamic> newValues) generateSortCondition(Map<String, dynamic>? startAfter, (String, bool descending)? sort, bool and, List<dynamic> parameters) {

		if (startAfter == null || startAfter.isEmpty) {
			return ("", parameters);
		}

		assert(sort != null, "Start after requires a sort condition");

		if (sort == null) {
			return ("", parameters);
		}

		final Map<String, dynamic> relevantStartKeys = <String, dynamic>{};

		if (startAfter.containsKey(sort.$1)) {
			relevantStartKeys[sort.$1] = startAfter[sort.$1];
		}

		assert(relevantStartKeys.isNotEmpty, "Unable to find sort key in sort!");
		if (relevantStartKeys.isEmpty) {
			return ("", <dynamic>[]);
		}

		if (!relevantStartKeys.containsKey("id")) {
			relevantStartKeys["id"] = startAfter["id"];
		}

		final List<String> keys = relevantStartKeys.keys.toList();
		final List<dynamic> values = relevantStartKeys.values.toList();

		final String keysPart = keys.join(', ');
		final String valuesPart = values.map((dynamic val) {
			return "?";
		}).join(', ');

		return ("${and ? " AND " : ""}($keysPart) ${sort.$2 ? "<" : ">"} ($valuesPart)", List<dynamic>.from(parameters)..addAll(values));
	}

	String preprocessQuery(String query, List<dynamic> params) {
		final List<String> operators = <String>['=', '!=', '>=', '>', '<=', '<'];
		final String regexPattern = operators.map((String op) => RegExp.escape(op)).join('|');
		final RegExp regex = RegExp(r'(.*?)(' + regexPattern + r')(.*)');

		final List<String> parts = query.split('&&');
		final List<String> updatedParts = <String>[];
		int paramIndex = 0;

		for (final String part in parts) {
			if (paramIndex < params.length && params[paramIndex] is bool) {
				final RegExpMatch? match = regex.firstMatch(part);
				if (match != null) {
					final String columnName = match.group(1) ?? '';
					final String operator = match.group(2) ?? '';
					final String rest = match.group(3) ?? '';

					final String updatedPart = "_offline_bool_${columnName.trimLeft()}$operator$rest";
					updatedParts.add(updatedPart);
				} else {
					updatedParts.add(part);
				}
			} else {
				updatedParts.add(part);
			}
			paramIndex++;
		}

		return updatedParts.join('AND ');
	}

	if (filter != null) {

		final (String whereClause, List<dynamic> items) orderBy = generateSortCondition(startAfter, sort, true, filter.$2);

		query.write(" WHERE ${preprocessQuery(filter.$1, filter.$2)}${orderBy.$1}");
		filter = (filter.$1, orderBy.$2);

	} else if (startAfter != null) {

		final (String whereClause, List<dynamic> items) orderBy = generateSortCondition(startAfter, sort, true, <dynamic>[]);

		query.write(" WHERE ${generateSortCondition(startAfter, sort, false, <dynamic>[])}");
		filter = ("", orderBy.$2);
	}

	if (sort != null) {
		query.write(" ORDER BY ${sort.$1} ${sort.$2 ? "DESC" : "ASC"}");
	}

	if (maxItems != null) {
		query.write(" LIMIT $maxItems");
	}

	query.write(";");

	if (filter != null) {

		for (int i = 0; i < filter.$2.length; i++) {
			if (filter.$2[i] is DateTime) {
				filter.$2[i] = (filter.$2[i] as DateTime?)?.toUtc().toString();
			} else if (filter.$2[i] is List<dynamic> || filter.$2[i] is Map<dynamic, dynamic>) {
				filter.$2[i] = filter.$2[i].toString();
			} else if (filter.$2[i] == null) {
				filter.$2[i] = "";
			}
		}

		return db.select(query.toString(), filter.$2);
	} else {
		return db.select(query.toString());
	}
}

class QueryBuilder {

	const QueryBuilder._(this.pb, this.collectionName, this.currentFilter, this.args, this.orderRule, this.expandFields);

	final PbOfflineCache pb;
	final String collectionName;
	final String currentFilter;
	final List<dynamic> args;
	final (String, bool descending)? orderRule;
	final List<String> expandFields;

	@override
	String toString() => "$collectionName $currentFilter $args $orderRule";

	QueryBuilder where(String column, {
		dynamic isEqualTo,
		dynamic isNotEqualTo,
		dynamic isGreaterThan,
		dynamic isLessThan,
		dynamic isGreaterThanOrEqualTo,
		dynamic isLessThanOrEqualTo,
		bool? isNull,
	}) {
		assert((isEqualTo != null ? 1 : 0)
				+ (isNotEqualTo != null ? 1 : 0)
				+ (isGreaterThan != null ? 1 : 0)
				+ (isLessThan != null ? 1 : 0)
				+ (isGreaterThanOrEqualTo != null ? 1 : 0)
				+ (isLessThanOrEqualTo != null ? 1 : 0)
				+ (isNull != null ? 1 : 0) == 1);

		if (isNull == true) {
			return QueryBuilder._(pb, collectionName,
					"${currentFilter != "" ? "$currentFilter && " : ""}$column = ?", List<dynamic>.from(args)..add(null), orderRule, expandFields);
		} else if (isNull == false) {
			return QueryBuilder._(pb, collectionName,
					"${currentFilter != "" ? "$currentFilter && " : ""}$column != ?", List<dynamic>.from(args)..add(null), orderRule, expandFields);
		} else if (isEqualTo != null) {
			return QueryBuilder._(pb, collectionName,
					"${currentFilter != "" ? "$currentFilter && " : ""}$column = ?", List<dynamic>.from(args)..add(isEqualTo), orderRule, expandFields);
		} else if (isNotEqualTo != null) {
			return QueryBuilder._(pb, collectionName,
					"${currentFilter != "" ? "$currentFilter && " : ""}$column != ?", List<dynamic>.from(args)..add(isNotEqualTo), orderRule, expandFields);
		} else if (isGreaterThan != null) {
			return QueryBuilder._(pb, collectionName,
					"${currentFilter != "" ? "$currentFilter && " : ""}$column > ?", List<dynamic>.from(args)..add(isGreaterThan), orderRule, expandFields);
		} else if (isLessThan != null) {
			return QueryBuilder._(pb, collectionName,
					"${currentFilter != "" ? "$currentFilter && " : ""}$column < ?", List<dynamic>.from(args)..add(isLessThan), orderRule, expandFields);
		} else if (isLessThanOrEqualTo != null) {
			return QueryBuilder._(pb, collectionName,
					"${currentFilter != "" ? "$currentFilter && " : ""}$column <= ?", List<dynamic>.from(args)..add(isLessThanOrEqualTo), orderRule, expandFields);
		} else {
			return QueryBuilder._(pb, collectionName,
					"${currentFilter != "" ? "$currentFilter && " : ""}$column >= ?", List<dynamic>.from(args)..add(isGreaterThanOrEqualTo), orderRule, expandFields);
		}
	}

	QueryBuilder expand(List<String> expandFields) {
		return QueryBuilder._(pb, collectionName, currentFilter, args, orderRule, List<String>.from(expandFields)..addAll(expandFields));
	}

	QueryBuilder orderBy(String columnName, { bool descending = true }) {
		assert(orderRule == null, "Multiple order by not supported");
		return QueryBuilder._(pb, collectionName, currentFilter, args, (columnName, descending), expandFields);
	}

	Future<List<Map<String, dynamic>>> get({ int maxItems = defaultMaxItems, QuerySource source = QuerySource.any, Map<String, dynamic>? startAfter }) {
		return pb.getRecords(collectionName, where: (currentFilter, args), maxItems: maxItems, source: source, sort: orderRule, startAfter: startAfter, expand: expandFields);
	}

	Future<int?> getCount({ QuerySource source = QuerySource.any }) {
		return pb.getRecordCount(collectionName, where: (currentFilter, args), source: source);
	}
}
