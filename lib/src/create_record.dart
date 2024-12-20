

import 'dart:async';
import 'dart:math';

import 'package:pocketbase/pocketbase.dart';

import 'get_records.dart';
import 'pocketbase_offline_cache_base.dart';

extension CreateWrapper on PbOfflineCache {
	Future<Map<String, dynamic>?> createRecord(String collectionName, Map<String, dynamic> values, {
		QuerySource source = QuerySource.any,
	}) async {

		convertToPbTypes(values);

		if (source != QuerySource.server && (!remoteAccessible || source == QuerySource.cache)) {

			// If table does not exist yet we are unsure of the required schema so can't add anything
			if (await tableExists(dbIsolate, collectionName)) {
				final String id = makePbId();
				final String now = DateTime.now().toUtc().toString();

				unawaited(queueOperation("INSERT", collectionName, idToModify: id, values: values));

				values["id"] = id;
				values["created"] = now;
				values["updated"] = now;

				unawaited(insertRecordsIntoLocalDb(collectionName, <RecordModel>[ RecordModel(values) ],
						logger, indexInstructions: indexInstructions));

				return values;
			}

			return null;
		}

		try {
			final RecordModel model = await pb.collection(collectionName).create(body: values);
			unawaited(insertRecordsIntoLocalDb(collectionName, <RecordModel>[ model ], logger, indexInstructions: indexInstructions));
			return model.data;
		} catch (e) {

			if (e is! ClientException){
				logger.w("Unknown non-client exception when inserting record: $e", stackTrace: StackTrace.current);
			} else if (e.toString().contains("Failed to find all relation records")) {
				logger.e("Failed to insert $values into $collectionName ($e)", stackTrace: StackTrace.current);
				rethrow;
			} else if (!e.isNetworkError()) {
				logger.w("Unknown exception when inserting record: $e", stackTrace: StackTrace.current);
			}

			if (source == QuerySource.any) {
				return createRecord(collectionName, values, source: QuerySource.cache);
			} else {
				rethrow;
			}
		}
	}

}

final Random random = Random();

String makePbId() {
	const String chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

	return List<String>.generate(15, (int index) => chars[random.nextInt(chars.length)]).join();
}

void convertToPbTypes(Map<String, dynamic> map) {
	for (final String key in map.keys) {
		if (map[key] is DateTime) {
			map[key] = map[key].toUtc().toString();
		} else if (map[key] is Uri) {
			map[key] = map[key].toString();
		}
	}
}
