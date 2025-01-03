
import 'dart:async';

import 'package:pocketbase/pocketbase.dart';
import 'pocketbase_offline_cache_base.dart';

extension DeleteWrapper on PbOfflineCache {
	Future<void> deleteRecord(String collectionName, String id, {
		QuerySource source = QuerySource.any,
	}) async {

		if (source != QuerySource.server && (!remoteAccessible || source == QuerySource.cache)) {

			if (await tableExists(dbIsolate, collectionName)) {
				unawaited(queueOperation("DELETE", collectionName, idToModify: id));
				unawaited(dbIsolate.execute("DELETE FROM $collectionName WHERE id = ?", <Object?>[ id ]));
			}

			return;
		}

		try {
			await pb.collection(collectionName).delete(id);
			unawaited(dbIsolate.execute("DELETE FROM $collectionName WHERE id = ?", <Object?>[ id ]));
		} catch (e) {
			if (e is! ClientException){
				logger.w("Unknown non-client exception when deleting record: $e");
			} else if (!e.isNetworkError()) {
				logger.w("Unknown exception when deleting record: $e");
			}
			if (source == QuerySource.any) {
				return deleteRecord(collectionName, id, source: QuerySource.cache);
			} else {
				rethrow;
			}
		}
	}

}
