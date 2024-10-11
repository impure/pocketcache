
import 'dart:async';

import 'package:pocketbase/pocketbase.dart';

import 'create_record.dart';
import 'db_isolate.dart';
import 'get_single_record.dart';
import 'pocketbase_offline_cache_base.dart';
import 'realtime.dart';

extension UpdateWrapper on PbOfflineCache {
	Future<Map<String, dynamic>?> updateRecord(String collectionName, String id, Map<String, dynamic> values, {
		QuerySource source = QuerySource.any,
	}) async {

		convertToPbTypes(values);

		if (await dbIsolate.enabled() && source != QuerySource.server && (!dbAccessible || source == QuerySource.cache)) {
			if (await tableExists(dbIsolate, collectionName)) {
				unawaited(queueOperation("UPDATE", collectionName, values: values, idToModify: id));
				applyLocalUpdateOperation(dbIsolate, collectionName, id, values);

				final Map<String, dynamic>? record = await getSingleRecord(collectionName, id, source: QuerySource.cache);

				if (record != null) {
					final List<PbSubscriptionDetails>? details = pbListeners[(collectionName, id)];
					if (details != null) {
						for (final PbSubscriptionDetails item in details) {
							if (item.callback != null) {
								item.callback!(record);
							}
						}
					}
				}

				return record;
			}

			return null;
		}

		try {
			final RecordModel record = await pb.collection(collectionName).update(id, body: values);

			if (await tableExists(dbIsolate, collectionName)) {
				applyLocalUpdateOperation(dbIsolate, collectionName, id, values);
			}

			final Map<String, dynamic> newValues = record.data;

			newValues["id"] = id;
			newValues["created"] = record.created;
			newValues["updated"] = record.updated;

			final List<PbSubscriptionDetails>? details = pbListeners[(collectionName, id)];
			if (details != null) {
				for (final PbSubscriptionDetails item in details) {
					if (!item.connectToServer && item.callback != null) {
						item.callback!(newValues);
					}
				}
			}

			return newValues;

		} catch (e) {
			if (e is! ClientException){
				logger.w("Unknown non-client exception when updating record: $e values: $values");
			} else if (!e.isNetworkError()) {
				logger.w("Unknown exception when updating record: $e values: $values");
			}
			if (source == QuerySource.any) {
				return updateRecord(collectionName, id, values, source: QuerySource.cache);
			} else {
				rethrow;
			}
		}
	}
}

void applyLocalUpdateOperation(DbIsolate db, String collectionName, String id, Map<String, dynamic> values) {
	final StringBuffer command = StringBuffer("UPDATE $collectionName SET");

	bool first = true;
	final List<dynamic> parameters = <dynamic>[];

	for (final MapEntry<String, dynamic> entry in values.entries) {
		if (!first) {
			command.write(",");
		} else {
			first = false;
		}

		parameters.add(entry.value);

		if (entry.value is bool) {
			command.write(" _offline_bool_${entry.key} = ?");
		} else if (entry.value is List<dynamic> || entry.value is Map<dynamic, dynamic>) {
			command.write(" _offline_json_${entry.key} = ?");
		} else {
			command.write(" ${entry.key} = ?");
		}
	}

	parameters.add(id);
	command.write(" WHERE id = ?;");

	unawaited(db.execute(command.toString(), parameters));
}
