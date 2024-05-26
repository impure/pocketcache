
import 'dart:core';

import 'package:logger/logger.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:sqlite3/sqlite3.dart';

import 'pocketbase_offline_cache_base.dart';

extension ListWrapper on PbOfflineCache {
	Future<List<Map<String, dynamic>>> getRecords(String collectionName, {
		int maxItems = defaultMaxItems,
		(String, List<Object?>)? filter,
		QuerySource source = QuerySource.any,
	}) async {
		if (source != QuerySource.server && (!dbAccessible || source == QuerySource.client)) {
			if (tableExists(db, collectionName)) {
				final ResultSet results = selectBuilder(db, collectionName, maxItems: maxItems, filter: filter);
				final List<Map<String, dynamic>> data = <Map<String, dynamic>>[];
				for (final Row row in results) {
					final Map<String, dynamic> entryToInsert = <String, dynamic>{};
					for (final MapEntry<String, dynamic> data in row.entries) {
						if (data.key.startsWith("_offline_bool_")) {
							entryToInsert[data.key.substring(14)] =
							data.value == 1 ? true : false;
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
				filter: makePbFilter(filter),
			)).items;

			if (records.isNotEmpty) {
				insertRecordsIntoLocalDb(db, collectionName, records, logger);
			}

			final List<Map<String, dynamic>> data = <Map<String, dynamic>>[];

			for (final RecordModel record in records) {
				final Map<String, dynamic> entry = record.data;
				entry["id"] = record.id;
				entry["created"] = record.created;
				entry["updated"] = record.updated;
				data.add(entry);
			}

			return data;
		} on ClientException catch (e) {
			if (!e.toString().contains("refused the network connection")) {
				rethrow;
			}
			if (source == QuerySource.any) {
				return getRecords(collectionName, maxItems: maxItems, source: QuerySource.client);
			} else {
				return <Map<String, dynamic>>[];
			}
		}
	}
}

void insertRecordsIntoLocalDb(Database db, String collectionName, List<RecordModel> records, Logger logger) {

	if (!tableExists(db, collectionName)) {
		final StringBuffer schema = StringBuffer("id TEXT PRIMARY KEY, created TEXT, updated TEXT, _downloaded TEXT");

		for (final MapEntry<String, dynamic> data in records.first.data.entries) {
			if (data.value is String) {
				schema.write(",${data.key} TEXT DEFAULT ''");
			} else if (data.value is bool) {
				schema.write(",_offline_bool_${data.key} INTEGER DEFAULT 0");
			} else if (data.value is double || data.value is int) {
				schema.write(",${data.key} REAL DEFAULT 0.0");
			} else {
				logger.e("Unknown type ${data.value.runtimeType}", stackTrace: StackTrace.current);
			}
		}

		db.execute("CREATE TABLE $collectionName ($schema)");
	}

	final StringBuffer command = StringBuffer("INSERT OR REPLACE INTO $collectionName(id, created, updated, _downloaded");

	final List<String> keys = <String>[];

	for (final String key in records.first.data.keys) {
		keys.add(key);
		if (records.first.data[key] is bool) {
			command.write(", _offline_bool_$key");
		} else {
			command.write(", $key");
		}
	}

	command.write(") VALUES");

	bool first = true;
	final List<dynamic> parameters = <dynamic>[];
	final String now = DateTime.now().toString();

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
			parameters.add(record.data[key]);
		}

		command.write(")");
	}

	command.write(";");

	try {
		db.execute(command.toString(), parameters);
	} on SqliteException catch (e) {
		if (e.message.contains("has no column")) {
			logger.i("Dropping table $collectionName");
			db.execute("DROP TABLE $collectionName");
		} else {
			rethrow;
		}
	}
}

String? makePbFilter((String, List<Object?>)? params) {

	if (params == null) {
		return null;
	}

	String filter = params.$1;

	for (final Object? param in params.$2) {
		if (param is String) {
			filter = filter.replaceFirst("?", "'$param'");
		} else {
			filter = filter.replaceFirst("?", param.toString());
		}
	}
	return filter;
}
