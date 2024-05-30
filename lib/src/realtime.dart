
import 'package:pocketbase/pocketbase.dart';

import 'get_single_record.dart';
import 'pocketbase_offline_cache_base.dart';

extension Realtime on PbOfflineCache {
	Future<void> subscribeToId(String collection, String id, DateTime updateTime, Function(Map<String, dynamic>) callback) async {

		final Map<String, dynamic>? data = await getSingleRecord(collection, id, source: QuerySource.server);

		if (data != null) {
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
			if (!e.toString().contains("refused network connection") && !e.toString().contains("The remote computer refused the network connection")) {
				rethrow;
			}
		}
	}

	Future<void> unsubscribeFromId(String collection, String id) {
		return pb.collection(collection).unsubscribe(id);
	}
}
