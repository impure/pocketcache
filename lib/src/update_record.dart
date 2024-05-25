
import 'package:pocketbase/pocketbase.dart';
import 'package:sqlite3/sqlite3.dart';

import 'pocketbase_offline_cache_base.dart';

extension UpdateWrapper on PbOfflineCache {
	Future<void> updateRecord(String collectionName, String id, Map<String, dynamic> values, { bool forceOffline = false }) async {
		if (!dbAccessible || forceOffline) {
			if (tableExists(collectionName)) {
				queueOperation("UPDATE", collectionName, values, idToModify: id);
				updateCache(db, collectionName, id, values);
			}

			return;
		}

		try {
			await pb.collection(collectionName).update(id, body: values);
		} on ClientException catch (_) {
			return updateRecord(collectionName, id, values, forceOffline: true);
		}

		if (tableExists(collectionName)) {
			updateCache(db, collectionName, id, values);
		}
	}
}

void updateCache(Database db, String collectionName, String id, Map<String, dynamic> values) {
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
		} else {
			command.write(" ${entry.key} = ?");
		}
	}

	parameters.add(id);
	command.write(" WHERE id = ?;");

	db.execute(command.toString(), parameters);
}
