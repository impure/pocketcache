
import 'dart:convert';
import 'dart:core';

import 'package:pocketbase/pocketbase.dart';
import 'package:sqlite3/common.dart';

import 'get_records.dart';
import 'pocketbase_offline_cache_base.dart';

extension GetOneWrapper on PbOfflineCache {
	Future<Map<String, dynamic>?> getSingleRecord(String collectionName, String id, {
		QuerySource source = QuerySource.any,
	}) async {
		return (await getRecords(collectionName, where: ("id = ?", <String>[ id ]), source: source)).firstOrNull;
	}
}
