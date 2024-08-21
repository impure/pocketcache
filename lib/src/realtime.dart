
import 'dart:async';

import 'package:pocketbase/pocketbase.dart';
import 'package:synchronized/synchronized.dart';

import 'get_single_record.dart';
import 'pocketbase_offline_cache_base.dart';

Map<(String table, String id), List<PbSubscriptionDetails>> pbListeners = <(String table, String id), List<PbSubscriptionDetails>>{};

// The reason why we need this and not to cancel the subscription directly is because subscribeToId() is async meaning if we unsubscribed directly
// it's possible to request a subscription, unsubscribe, and then get a subscription resulting in a leak.
class PbSubscriptionDetails {

	PbSubscriptionDetails({
		required this.pb,
		required this.collectionName,
		required this.id,
		required void Function(Map<String, dynamic>) updateData,
		required this.connectToServer,
		required this.lastKnownUpdateTime,
	}) {

		callback = (Map<String, dynamic> data) {

			final DateTime? updateTime = DateTime.tryParse(data["updated"]);
			if (updateTime != null && (updateTime == lastKnownUpdateTime || updateTime.isAfter(lastKnownUpdateTime))) {
				updateData(data);
				lastKnownUpdateTime = updateTime;
			}
		};

		final List<PbSubscriptionDetails>? detailsList = pbListeners[(collectionName, id)];
		if (detailsList == null) {
			pbListeners[(collectionName, id)] = <PbSubscriptionDetails>[this];
		} else {
			detailsList.add(this);
		}
	}

	final PbOfflineCache pb;
	final String collectionName;
	final String id;
	void Function(Map<String, dynamic>)? callback;
	bool allowSubscribe = true;
	final Lock lock = Lock();
	final bool connectToServer;
	DateTime lastKnownUpdateTime;

	/// Manually gets new data from the server. Useful for checking for updates that happened before we started listening or when the screen is off.
	Future<void> manualUpdate() async {
		final Map<String, dynamic>? data;
		try {
			data = await pb.getSingleRecord(collectionName, id, source: QuerySource.server);
		} on ClientException catch (e) {
			if (!e.isNetworkError()) {
				rethrow;
			} else {
				return;
			}
		}

		if (data != null && callback != null) {
			callback!(data);
		}
	}

	Future<void> subscribe() async {
		await lock.synchronized(() async {
			if (allowSubscribe && connectToServer) {
				await pb.pb.collection(collectionName).subscribe(id, (RecordSubscriptionEvent event) {
					if (event.record != null) {
						final Map<String, dynamic> data = event.record!.data;

						data["updated"] = event.record!.updated;

						if (callback != null) {
							callback!(event.record!.data);
						}
					}
				});
			}
		});
	}

	Future<void> unsubscribe() async {

		allowSubscribe = false;

		final List<PbSubscriptionDetails>? details = pbListeners[(collectionName, id)];

		if (details == null) {
			pb.logger.e("Subscription not found");
		} else if (details.length == 1) {
			pbListeners.remove((collectionName, id));
		} else {
			details.remove(this);
		}

		callback = null;

		// Prevents the connection from being closed too abruptly.
		await Future<void>.delayed(const Duration(milliseconds: 100));

		try {
			await lock.synchronized(() async {
				await pb.pb.collection(collectionName).unsubscribe(id);
			});
		} on ClientException catch (e) {
			if (!e.isNetworkError()) {
				rethrow;
			}
		}
	}
}

extension Realtime on PbOfflineCache {

	PbSubscriptionDetails subscribeToId(String collection, String id, DateTime updateTime, void Function(Map<String, dynamic>) callback, {
		Duration debouncingDuration = const Duration(milliseconds: 100),

		// Due to stability concerns we may not want to actually want to create a socket connection and instead just listen to updates locally
		bool connectToServer = true,

		// Item could have been modified between getting the record and subscribing so catch changes by refreshing immediately
		bool refreshImmediately = true,
	}) {

		final PbSubscriptionDetails details = PbSubscriptionDetails(pb: this, collectionName: collection, id: id, updateData: callback, connectToServer: connectToServer, lastKnownUpdateTime: updateTime);

		unawaited(_subscribeToId(details, collection, id, updateTime, callback, debouncingDuration, connectToServer, refreshImmediately));

		return details;
	}

	Future<void> _subscribeToId(PbSubscriptionDetails details, String collection, String id, DateTime updateTime, Function(Map<String, dynamic>) callback, Duration debouncingDuration, bool connectToServer, bool refreshImmediately) async {

		// Prevents too many temporary listeners from being registered all at once
		await Future<void>.delayed(debouncingDuration);

		if (!details.allowSubscribe) {
			return;
		}

		if (refreshImmediately) {
			await details.manualUpdate();
		}

		try {
			await details.subscribe();
		} on ClientException catch (e) {
			if (!e.isNetworkError()) {
				rethrow;
			}
		}
	}
}
