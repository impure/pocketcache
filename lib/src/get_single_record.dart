
import 'dart:convert';
import 'dart:core';

import 'package:pocketbase/pocketbase.dart';
import 'package:sqlite3/sqlite3.dart';

import 'get_records.dart';
import 'pocketbase_offline_cache_base.dart';

extension GetOneWrapper on PbOfflineCache {
	Future<Map<String, dynamic>?> getSingleRecord(String collectionName, String id, {
		QuerySource source = QuerySource.any,
	}) async {
		if (source != QuerySource.server && (!dbAccessible || source == QuerySource.cache)) {
			if (tableExists(db, collectionName)) {
				final ResultSet results = selectBuilder(db, collectionName, maxItems: 1, filter: ("id = ?", <Object>[ id ]));
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

				return data.firstOrNull;
			}

			return null;
		}

		try {
			final RecordModel record = await pb.collection(collectionName).getOne(id);

			insertRecordsIntoLocalDb(db, collectionName, <RecordModel>[ record ], logger, indexInstructions: indexInstructions);

			final Map<String, dynamic> data = record.data;

			data["id"] = record.id;
			data["created"] = record.created;
			data["updated"] = record.updated;

			return data;
		} on ClientException catch (e) {
			if (!e.isNetworkError()) {
				rethrow;
			}
			if (source == QuerySource.any) {
				return getSingleRecord(collectionName, id, source: QuerySource.cache);
			} else {
				return null;
			}
		}
	}
}
