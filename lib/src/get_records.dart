
import 'dart:convert';
import 'dart:core';

import 'package:logger/logger.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:sqlite3/common.dart';
import 'package:state_groups/state_groups.dart';

import 'pocketbase_offline_cache_base.dart';

extension ListWrapper on PbOfflineCache {
	Future<List<Map<String, dynamic>>> getRecords(String collectionName, {
		int maxItems = defaultMaxItems,
		(String, List<Object?>)? where,
		QuerySource source = QuerySource.any,
		(String column, bool descending)? sort,
		Map<String, dynamic>? startAfter,
		List<String> expand = const <String>[],
	}) async {
		if (source != QuerySource.server && (!dbAccessible || source == QuerySource.cache)) {
			if (db != null && tableExists(db!, collectionName)) {
				final ResultSet results = selectBuilder(db!, collectionName, maxItems: maxItems, filter: where, startAfter: startAfter, sort: sort);
				final List<Map<String, dynamic>> data = <Map<String, dynamic>>[];
				for (final Row row in results) {
					final Map<String, dynamic> entryToInsert = <String, dynamic>{};
					for (final MapEntry<String, dynamic> data in row.entries) {
						if (data.key.startsWith("_offline_bool_")) {
							entryToInsert[data.key.substring(14)] = data.value == 1 ? true : false;
						} else if (data.key.startsWith("_offline_json_")) {
							entryToInsert[data.key.substring(14)] = jsonDecode(data.value);
						} else {
							entryToInsert[data.key] = data.value;
						}
					}
					data.add(entryToInsert);
				}
				return data;
			}

			return <Map<String, dynamic>>[];
		}

		try {

			final List<RecordModel> records = (await pb.collection(collectionName).getList(
				page: 1,
				perPage: maxItems,
				skipTotal: true,
				filter: makePbFilter(where, sort: sort, startAfter: startAfter),
				sort: makeSortFilter(sort),
				expand: expand.join(",")
			)).items;

			if (db != null) {
				final Row? lastSyncTime = db!.select(
					"SELECT last_update FROM _last_sync_times WHERE table_name=?",
					<String> [ collectionName ],
				).firstOrNull;

				if (lastSyncTime == null) {
					DateTime? newLastSyncTime;

					for (final RecordModel model in records) {
						final DateTime? time = DateTime.tryParse(model.updated)?.toUtc();
						if (time == null) {
							logger.e("Unable to parse time ${model.updated}");
						}
						if (time != null && (newLastSyncTime == null || time.isAfter(newLastSyncTime))) {
							newLastSyncTime = time;
						}
					}

					if (newLastSyncTime != null) {
						db!.execute("INSERT OR REPLACE INTO _last_sync_times(table_name, last_update) VALUES(?, ?)", <dynamic>[	collectionName,	newLastSyncTime.toString() ]);
					}
				}
			}

			if (records.isNotEmpty) {
				insertRecordsIntoLocalDb(db, collectionName, records, logger, indexInstructions: indexInstructions);
			}

			final List<Map<String, dynamic>> data = <Map<String, dynamic>>[];

			for (final RecordModel record in records) {
				final Map<String, dynamic> entry = record.data;
				addMetadataToMap(entry, record);

				if (record.expand.isNotEmpty) {
					final Map<String, Map<String, dynamic>> expansions = <String, Map<String, dynamic>>{};

					for (final MapEntry<String, List<RecordModel>> item in record.expand.entries) {

						if (item.value.length != 1) {
							logger.w("Only 1 expansion record per table is supported");
						}
						final RecordModel? expansionRecord = item.value.firstOrNull;

						if (expansionRecord != null) {
							insertRecordsIntoLocalDb(db, expansionRecord.collectionName, item.value, logger);
							expansions[item.key] = expansionRecord.data;
							addMetadataToMap(expansionRecord.data, expansionRecord);
						}
					}
					entry["expand"] = expansions;
				}
				data.add(entry);
			}

			return data;
		} on ClientException catch (e) {
			if (!e.isNetworkError()) {
				logger.e("$e: filter: ${makePbFilter(where, sort: sort, startAfter: startAfter)}, sort: ${makeSortFilter(sort)}");
				rethrow;
			}
			if (source == QuerySource.any) {
				return getRecords(collectionName, where: where, sort: sort, maxItems: maxItems, startAfter: startAfter, source: QuerySource.cache);
			} else {
				rethrow;
			}
		}
	}
}

void addMetadataToMap(Map<String, dynamic> map, RecordModel record) {
	map["id"] = record.id;
	map["created"] = record.created;
	map["updated"] = record.updated;
}

void insertRecordsIntoLocalDb(CommonDatabase? db, String collectionName, List<RecordModel> records, Logger logger, {Map<String, List<(String name, bool unique, List<String> columns)>> indexInstructions = const <String, List<(String, bool, List<String>)>>{}, String? overrideDownloadTime}) {

	if (db == null || records.isEmpty) {
		return;
	}

	if (!isTest()) {
		assert(collectionName == records.first.collectionName, "Collection name mismatch");
	}

	if (!tableExists(db, collectionName)) {
		final StringBuffer schema = StringBuffer("id TEXT PRIMARY KEY, created TEXT, updated TEXT, _downloaded TEXT");
		final Set<String> tableKeys = <String>{"id", "created", "updated", "_downloaded"};

		for (final MapEntry<String, dynamic> data in records.first.data.entries) {
			if (data.value is String) {
				tableKeys.add(data.key);
				schema.write(",${data.key} TEXT DEFAULT ''");
			} else if (data.value is bool) {
				tableKeys.add("_offline_bool_${data.key}");
				schema.write(",_offline_bool_${data.key} INTEGER DEFAULT 0");
			} else if (data.value is double || data.value is int) {
				tableKeys.add(data.key);
				schema.write(",${data.key} REAL DEFAULT 0.0");
			} else if (data.value is List<dynamic> || data.value is Map<dynamic, dynamic>) {
				tableKeys.add("_offline_json_${data.key}");
				schema.write(",_offline_json_${data.key} TEXT DEFAULT '[]'");
			} else {
				logger.e("Unknown type ${data.value.runtimeType}", stackTrace: StackTrace.current);
			}
		}

		db.execute("CREATE TABLE $collectionName ($schema)");
		db.execute("CREATE INDEX ON $collectionName (_downloaded)");

		// TODO: needs more work to set up indexes for JSON, relations, and bools. Fix that.
		final List<(String name, bool unique, List<String> columns)>? indexesToCreate = indexInstructions[collectionName];
		if (indexesToCreate != null) {
			for (final (String name, bool unique, List<String> columns) entry in indexesToCreate) {
				if (!tableKeys.containsAll(entry.$3)) {
					logger.e("Unable to create index ${entry.$1} on $collectionName($tableKeys), could not find all columns: ${entry.$3}");
				} else {

					String columnNames = entry.$3.toString();
					columnNames = columnNames.substring(1, columnNames.length - 1);

					db.execute("CREATE${entry.$2 ? " UNIQUE" : ""} INDEX ${entry.$1} ON $collectionName($columnNames)");
				}
			}
		}

	}

	for (final RecordModel record in records) {
		broadcastToListeners("pocketcache/pre-local-update", (collectionName, record));
	}

	final StringBuffer command = StringBuffer("INSERT OR REPLACE INTO $collectionName(id, created, updated, _downloaded");

	final List<String> keys = <String>[];

	for (final String key in records.first.data.keys) {
		keys.add(key);
		if (records.first.data[key] is bool) {
			command.write(", _offline_bool_$key");
		} else if (records.first.data[key] is List<dynamic> || records.first.data[key] is Map<dynamic, dynamic>) {
			command.write(", _offline_json_$key");
		} else {
			command.write(", $key");
		}
	}

	command.write(") VALUES");

	bool first = true;
	final List<dynamic> parameters = <dynamic>[];
	final String now = overrideDownloadTime ?? DateTime.now().toUtc().toString();

	for (final RecordModel record in records) {
		if (!first) {
			command.write(",");
		} else {
			first = false;
		}

		command.write("(?, ?, ?, ?");

		parameters.add(record.id);
		parameters.add(record.created);
		parameters.add(record.updated);
		parameters.add(now);

		for (final String key in keys) {
			command.write(", ?");
			if (record.data[key] == null) {
				if (key.startsWith("_offline_bool_")) {
					parameters.add("false");
				} else {
					parameters.add("");
				}
			} else if (record.data[key] is List<dynamic> || record.data[key] is Map<dynamic, dynamic>) {
				parameters.add(jsonEncode(record.data[key]));
			} else{
				parameters.add(record.data[key]);
			}
		}

		command.write(")");
	}

	command.write(";");

	try {
		db.execute(command.toString(), parameters);
	} on SqliteException catch (e) {
		if (!isTest() && e.message.contains("has no column")) {
			logger.i("Dropping table $collectionName");
			db.execute("DROP TABLE $collectionName");
		} else {
			rethrow;
		}
	}
}

String? makePbFilter((String, List<Object?>)? params, { (String column, bool descending)? sort, Map<String, dynamic>? startAfter }) {

	assert(startAfter == null || (startAfter != null && sort != null), "If start after is not null sort must also be not null");

	if (startAfter != null && sort != null && startAfter.containsKey(sort.$1)) {
		if (params != null) {
			if (sort.$2) {
				final List<Object?> objects = List<Object?>.from(params.$2);
				objects.add(startAfter[sort.$1]);
				params = ("${params.$1} && ${sort.$1} < ?", objects);
			} else {
				final List<Object?> objects = List<Object?>.from(params.$2);
				objects.add(startAfter[sort.$1]);
				params = ("${params.$1} && ${sort.$1} > ?", objects);
			}
		} else {
			if (sort.$2) {
				params = ("${sort.$1} < ?", <Object?> [ startAfter[sort.$1] ]);
			} else {
				params = ("${sort.$1} > ?", <Object?> [ startAfter[sort.$1] ]);
			}
		}
	}

	if (params == null) {
		return null;
	}

	int i = 0;
	final String filter = params.$1.replaceAllMapped(RegExp(r'\?'), (Match match) {

		final dynamic param = params!.$2[i];
		i++;

		if (param is String) {
			return "'${param.replaceAll("'", r"\'")}'";
		} else if (param is DateTime) {
			return "'${param.toUtc()}'";
		} else if (param == null) {
			return "''";
		} else {
			return param.toString();
		}
	});

	assert(i == params.$2.length, "Incorrect number of parameters ($i, ${params.$2.length})");

	return filter;

}

String? makeSortFilter((String column, bool descending)? data) {
	if (data == null) {
		return null;
	} else {
		return "${data.$2 ? "-" : "+"}${data.$1}";
	}
}
