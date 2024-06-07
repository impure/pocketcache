
import 'package:pocketbase/pocketbase.dart';

import 'get_single_record.dart';
import 'pocketbase_offline_cache_base.dart';

extension Realtime on PbOfflineCache {
	Future<void> subscribeToId(String collection, String id, DateTime updateTime, Function(Map<String, dynamic>) callback) async {

		final Map<String, dynamic>? data = await getSingleRecord(collection, id, source: QuerySource.server);

		// We need the update time check or if we re-init the widget too often it may result in getting old data here
		// I'm not exactly sure why this is, maybe it's a caching issue
		if (data != null && updateTime.isAfter(DateTime.tryParse(data["updated"] ?? "") ?? DateTime(2024))) {
			callback(data);
		}

		try {
			await pb.collection(collection).subscribe(id, (RecordSubscriptionEvent event) {
				if (event.record != null) {
					final Map<String, dynamic> data = event.record!.data;

					data["updated"] = event.record!.updated;

					callback(event.record!.data);
				}
			});
		} on ClientException catch (e) {
			if (!e.isNetworkError()) {
				rethrow;
			}
		}
	}

	Future<void> unsubscribeFromId(String collection, String id) async {
		try {
			return pb.collection(collection).unsubscribe(id);
		} on ClientException catch (e) {
			if (!e.isNetworkError()) {
				rethrow;
			}
		}
	}
}
