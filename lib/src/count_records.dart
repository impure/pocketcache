
import 'package:pocketbase/pocketbase.dart';
import 'package:sqlite3/sqlite3.dart';

import 'get_records.dart';
import 'pocketbase_offline_cache_base.dart';

extension CountWrapper on PbOfflineCache {
	Future<int?> countRecords(String collectionName, {
		(String, List<Object?>)? filter,
		QuerySource source = QuerySource.any,
	}) async {

		if ((source != QuerySource.server) && !dbAccessible || source == QuerySource.client) {

			if (tableExists(db, collectionName)) {
				final ResultSet results = selectBuilder(db, collectionName, columns: "COUNT(*)", filter: filter);
				return results.first.values.first! as int;
			}

			return 0;
		}

		try {
			return (await pb.collection(collectionName).getList(
				page: 1,
				perPage: 1,
				skipTotal: false,
				filter: makePbFilter(filter),
			)).totalItems;
		} on ClientException catch (e) {
			if (!e.toString().contains("refused the network connection")) {
				rethrow;
			}
			if (source == QuerySource.any) {
				return countRecords(collectionName, source: QuerySource.client);
			}
			return null;
		}
	}
}
