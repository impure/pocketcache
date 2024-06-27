
import 'dart:core';

import 'get_records.dart';
import 'pocketbase_offline_cache_base.dart';

extension GetOneWrapper on PbOfflineCache {
	Future<Map<String, dynamic>?> getSingleRecord(String collectionName, String id, {
		QuerySource source = QuerySource.any,
	}) async {
		return (await getRecords(collectionName, where: ("id = ?", <String>[ id ]), source: source)).firstOrNull;
	}
}
