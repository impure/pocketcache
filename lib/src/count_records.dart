
import 'package:pocketbase/pocketbase.dart';
import 'package:sqlite3/sqlite3.dart';

import 'get_records.dart';
import 'pocketbase_offline_cache_base.dart';

extension CountWrapper on PbOfflineCache {
	Future<int?> getRecordCount(String collectionName, {
		(String, List<Object?>)? where,
		QuerySource source = QuerySource.any,
	}) async {

		if ((source != QuerySource.server) && !dbAccessible || source == QuerySource.cache) {

			if (tableExists(db, collectionName)) {
				final ResultSet results = selectBuilder(db, collectionName, columns: "COUNT(*)", filter: where);
				return results.first.values.first! as int;
			}

			return 0;
		}

		try {
			return (await pb.collection(collectionName).getList(
				page: 1,
				perPage: 1,
				skipTotal: false,
				filter: makePbFilter(where),
			)).totalItems;
		} on ClientException catch (e) {
			if (!e.isNetworkError()) {
				rethrow;
			}
			if (source == QuerySource.any) {
				return getRecordCount(collectionName, where: where, source: QuerySource.cache);
			}
			return null;
		}
	}
}
