
import 'package:pocketbase/pocketbase.dart';
import 'package:sqlite3/sqlite3.dart';

import 'pocketbase_offline_cache_base.dart';

extension CountWrapper on PbOfflineCache {
	Future<int> countRecords(String collectionName, {
		bool forceOffline = false,
		(String, List<Object?>)? filter,
	}) async {

		if (!dbAccessible || forceOffline) {

			if (tableExists(collectionName)) {
				final ResultSet results = selectBuilder(db, collectionName, columns: "COUNT(*)", filter: filter);
				return results.first.values.first as int;
			}

			return 0;
		}

		try {
			return (await pb.collection(collectionName).getList(
				page: 1,
				perPage: 1,
				skipTotal: false,
			)).totalItems;
		} on ClientException catch (_) {
			return countRecords(collectionName, forceOffline: true);
		}
	}
}
