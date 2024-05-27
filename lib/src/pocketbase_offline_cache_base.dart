
import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:path/path.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:sqlite3/sqlite3.dart';

// PocketBase does not support getting more than 500 items at once
const int defaultMaxItems = 500;

enum QuerySource {
	server,
	client,
	any,
}

bool isTest() => Platform.environment.containsKey('FLUTTER_TEST');

bool dbAccessible = true;

class PbOfflineCache {

	factory PbOfflineCache(PocketBase pb, String directoryToSave, {
		Logger? overrideLogger,
		Map<String, List<(bool unique, List<String> columns)>>? indexInstructions,
	}) {
		return PbOfflineCache._(pb, sqlite3.open(join(directoryToSave, "offline_cache")), overrideLogger ?? Logger(), indexInstructions ?? const <String, List<(bool unique, List<String>)>>{});
	}

	PbOfflineCache._(this.pb, this.db, this.logger, [this.indexInstructions = const <String, List<(bool unique, List<String>)>>{}]) {
		db.execute("""
	CREATE TABLE IF NOT EXISTS _operation_queue (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		operation_type TEXT,
		created INTEGER,
		collection_name TEXT,
		id_to_modify TEXT
	)""");
		db.execute("""
	CREATE TABLE IF NOT EXISTS _operation_queue_params (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		operation_id INTEGER,
		param_key TEXT,
		param_value TEXT,
		type TEXT,
		FOREIGN KEY(operation_id) REFERENCES operations(id)
	)""");

		if (!isTest()) {
			unawaited(_continuouslyCheckDbAccessible());
		}
	}

	factory PbOfflineCache.withDb(PocketBase pb, Database db, {Logger? overrideLogger}) {
		return PbOfflineCache._(pb, db, overrideLogger ?? Logger());
	}

	final PocketBase pb;
	final Database db;
	final Logger logger;
	final Map<String, List<(bool unique, List<String> columns)>> indexInstructions;

	String? get id => pb.authStore.model?.id;
	bool get tokenValid => pb.authStore.isValid;

	Future<void> _continuouslyCheckDbAccessible() async {
		while (true) {
			try {
				final http.Response response = await http.get(pb.buildUrl("/api/health"));
				if (response.statusCode != 200) {
					dbAccessible = false;
				} else {
					dbAccessible = true;
					await dequeueCachedOperations();
				}
			} on SocketException catch (e) {
				if (!e.message.contains("refused")) {
					rethrow;
				}
				dbAccessible = false;
			}
			await Future<void>.delayed(const Duration(seconds: 10));
		}
	}

	Future<void> dequeueCachedOperations() async {
		final ResultSet data = db.select("SELECT * FROM _operation_queue ORDER BY created ASC");

		for (final Row row in data) {
			final String operationId = row.values[0].toString();
			final String operationType = row.values[1].toString();
			final String collectionName = row.values[3].toString();
			final String pbId = row.values[4].toString();

			final ResultSet data = db.select("SELECT * FROM _operation_queue_params WHERE operation_id = ?", <String>[ operationId ]);
			final Map<String, dynamic> params = <String, dynamic>{};
			for (final Row row in data) {

				dynamic value;

				if (row.values[4] == "bool") {
					value = row.values[3] == "1" ? true : false;
				} else if (row.values[4] == "int") {
					value = int.tryParse(row.values[3].toString());
				} else if (row.values[4] == "double") {
					value = double.tryParse(row.values[3].toString());
				} else if (row.values[4] == "String") {
					value = row.values[3];
				} else {
					logger.e("Unknown type when loading: ${row.values[4]}");
				}

				params[row.values[2].toString()] = value;
			}

			void cleanUp() {
				db.execute("DELETE FROM _operation_queue WHERE id = ?", <String>[ operationId ]);
				db.execute("DELETE FROM _operation_queue_params WHERE id = ?", <String>[ operationId ]);
			}

			// If we failed to update data (probably due to a key constraint) then we need to delete the local copy of the record as well or we'll be out of sync
			void deleteLocalRecord() {
				db.execute("DELETE FROM $collectionName WHERE id = ?", <String>[ pbId ]);
				cleanUp();
			}

			switch (operationType) {
				case "UPDATE":
					try {
						await pb.collection(collectionName).update(pbId, body: params);
						cleanUp();
					} on ClientException catch (e) {
						if (!e.toString().contains("refused the network connection")) {
							logger.e(e, stackTrace: StackTrace.current);
							deleteLocalRecord();
						}
					}
					break;
				case "DELETE":
					try {
						await pb.collection(collectionName).delete(pbId);
						cleanUp();
					} on ClientException catch (e) {
						if (!e.toString().contains("refused the network connection")) {
							logger.e(e, stackTrace: StackTrace.current);
							cleanUp();
						}
					}
					break;
				case "INSERT":
					try {
						params["id"] = pbId;
						await pb.collection(collectionName).create(body: params);
						cleanUp();
					} on ClientException catch (e) {
						if (!e.toString().contains("refused the network connection")) {
							logger.e(e, stackTrace: StackTrace.current);
							deleteLocalRecord();
						}
					}
					break;
				default:
					logger.e("Unknown operation type: $operationType, row: $row");
			}
		}
	}

	Future<void> resetAuth() async {
		try {
			await pb.collection('users').authRefresh();
		} on ClientException catch (e) {
			if (!e.toString().contains("refused the network connection")) {
				rethrow;
			}
		}
	}

	void queueOperation(
			String operationType,
			String collectionName,
			{Map<String, dynamic>? values, String idToModify = ""}
			) {

		// This is not guaranteed to be unique but if two commands are executed at the same time the order doesn't really matter
		final int created = DateTime.now().millisecondsSinceEpoch;

		final ResultSet record = db.select("INSERT INTO _operation_queue (operation_type, created, collection_name, id_to_modify) VALUES ('$operationType', $created, '$collectionName', ?) RETURNING id", <Object>[ idToModify ]);
		final int id = record.first.values.first! as int;

		if (values != null) {
			for (final MapEntry<String, dynamic> entry in values.entries) {

				String? type;

				if (entry.value is bool) {
					type = "bool";
				} else if (entry.value is int) {
					type = "int";
				} else if (entry.value is double) {
					type = "double";
				} else if (entry.value is String) {
					type = "String";
				} else {
					logger.e("Unknown type: ${entry.value.runtimeType}");
				}

				db.select("INSERT INTO _operation_queue_params (operation_id, param_key, param_value, type) VALUES (?, ?, ?, ?)", <Object?>[id, entry.key, entry.value, type]);
			}
		}
	}
}

bool tableExists(Database db, String tableName) {
	return db.select(
		"SELECT name FROM sqlite_master WHERE type='table' AND name=?",
		<String> [ tableName ],
	).isNotEmpty;
}

ResultSet selectBuilder(Database db, String tableName, {String? columns, (String, List<Object?>)? filter, int? maxItems}) {

	final StringBuffer query = StringBuffer("SELECT ${columns ?? "*"} FROM $tableName");

	if (filter != null) {
		query.write(" WHERE ${filter.$1.replaceAll("&&", "AND").replaceAll("||", "OR")}");
	}

	if (maxItems != null) {
		query.write(" LIMIT $maxItems");
	}

	query.write(";");

	if (filter != null) {
		return db.select(query.toString(), filter.$2);
	} else {
		return db.select(query.toString());
	}
}
