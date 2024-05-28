
import 'package:pocketbase/pocketbase.dart';
import 'package:sqlite3/sqlite3.dart';

import 'create_record.dart';
import 'get_single_record.dart';
import 'pocketbase_offline_cache_base.dart';

extension UpdateWrapper on PbOfflineCache {
	Future<Map<String, dynamic>?> updateRecord(String collectionName, String id, Map<String, dynamic> values, { QuerySource source = QuerySource.any }) async {

		convertToPbTypes(values);

		if (source != QuerySource.server && (!dbAccessible || source == QuerySource.client)) {
			if (tableExists(db, collectionName)) {
				queueOperation("UPDATE", collectionName, values: values, idToModify: id);
				applyLocalUpdateOperation(db, collectionName, id, values);
				return getSingleRecord(collectionName, id, source: QuerySource.client);
			}

			return null;
		}

		try {
			final RecordModel record = await pb.collection(collectionName).update(id, body: values);

			if (tableExists(db, collectionName)) {
				applyLocalUpdateOperation(db, collectionName, id, values);
			}

			final Map<String, dynamic> newValues = record.data;

			values["id"] = id;
			values["created"] = record.created;
			values["updated"] = record.updated;

			return newValues;

		} on ClientException catch (e) {
			if (!e.toString().contains("refused the network connection")) {
				rethrow;
			}
			if (source == QuerySource.any) {
				return updateRecord(collectionName, id, values, source: QuerySource.client);
			} else {
				return null;
			}
		}
	}
}

void applyLocalUpdateOperation(Database db, String collectionName, String id, Map<String, dynamic> values) {
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

	db.execute(command.toString(), parameters);
}
