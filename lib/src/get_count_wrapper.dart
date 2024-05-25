
import 'package:pocketbase/pocketbase.dart';
import 'package:sqlite3/sqlite3.dart';

import 'pocketbase_offline_cache_base.dart';

Future<int> getCountWrapper(String collectionName, {
	bool forceOffline = false,
	int? maxItems,
}) async {

	if (!dbAccessible || forceOffline) {

		final ResultSet result = db.select(
			"SELECT name FROM sqlite_master WHERE type='table' AND name=?",
			<String> [ collectionName ],
		);

		if (result.isNotEmpty) {
			final ResultSet results = maxItems != null ? db.select("SELECT COUNT(*) FROM $collectionName LIMIT $maxItems") : db.select("SELECT COUNT(*) FROM $collectionName");
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
		return getCountWrapper(collectionName, forceOffline: true);
	}
}
