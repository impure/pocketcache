
import 'dart:async';

import 'package:pocketbase/pocketbase.dart';
import 'package:synchronized/synchronized.dart';

import 'get_single_record.dart';
import 'pocketbase_offline_cache_base.dart';

// The reason why we need this and not to cancel the subscription directly is because subscribeToId() is async meaning if we unsubscribed directly
// it's possible to request a subscription, unsubscribe, and then get a subscription resulting in a leak.
class PbSubscriptionDetails {

	PbSubscriptionDetails({required this.pb, required this.collectionName, required this.id});

	final PocketBase pb;
	final String collectionName;
	final String id;
	bool allowSubscribe = true;
	final Lock lock = Lock();

	Future<void> unsubscribe() async {
		try {
			await lock.synchronized(() async {
				allowSubscribe = false;
				await pb.collection(collectionName).unsubscribe(id);
			});
		} on ClientException catch (e) {
			if (!e.isNetworkError()) {
				rethrow;
			}
		}
	}
}

extension Realtime on PbOfflineCache {

	PbSubscriptionDetails subscribeToId(String collection, String id, DateTime updateTime, Function(Map<String, dynamic>) callback) {

		final PbSubscriptionDetails details = PbSubscriptionDetails(pb: pb, collectionName: collection, id: id);

		unawaited(_subscribeToId(details, collection, id, updateTime, callback));

		return details;
	}

	Future<void> _subscribeToId(PbSubscriptionDetails details, String collection, String id, DateTime updateTime, Function(Map<String, dynamic>) callback) async {

		final Map<String, dynamic>? data;
		try {
			data = await getSingleRecord(collection, id, source: QuerySource.server);
		} on ClientException catch (e) {
			if (!e.isNetworkError()) {
				rethrow;
			} else {
				return;
			}
		}

		// We need the update time check or if we re-init the widget too often it may result in getting old data here
		// I'm not exactly sure why this is, maybe it's a caching issue
		if (data != null && (DateTime.tryParse(data["updated"] ?? "") ?? DateTime(2024)).isAfter(updateTime)) {
			callback(data);
		}

		try {
			await details.lock.synchronized(() async {
				if (details.allowSubscribe) {
					await pb.collection(collection).subscribe(id, (RecordSubscriptionEvent event) {
						if (event.record != null) {
							final Map<String, dynamic> data = event.record!.data;

							data["updated"] = event.record!.updated;

							callback(event.record!.data);
						}
					});
				}
			});
		} on ClientException catch (e) {
			if (!e.isNetworkError()) {
				rethrow;
			}
		}
	}
}
