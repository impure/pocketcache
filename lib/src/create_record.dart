

import 'dart:math';

import 'package:pocketbase/pocketbase.dart';

import 'get_records.dart';
import 'pocketbase_offline_cache_base.dart';

extension CreateWrapper on PbOfflineCache {
  Future<Map<String, dynamic>?> createRecord(String collectionName, Map<String, dynamic> values, {
    QuerySource source = QuerySource.any,
  }) async {

    convertToPbTypes(values);

    if (source != QuerySource.server && (!dbAccessible || source == QuerySource.cache)) {

      // If table does not exist yet we are unsure of the required schema so can't add anything
      if (tableExists(db, collectionName)) {
        final String id = makePbId();
        final String now = DateTime.now().toUtc().toString();

        queueOperation("INSERT", collectionName, idToModify: id, values: values);
        insertRecordsIntoLocalDb(db, collectionName, <RecordModel>[ RecordModel(
          id: id,
          created: now,
          updated: now,
          data: values,
        ) ], logger, indexInstructions: indexInstructions);

        values["id"] = id;
        values["created"] = now;
        values["updated"] = now;

        return values;
      }

      return null;
    }

    try {
      final RecordModel model = await pb.collection(collectionName).create(body: values);
      insertRecordsIntoLocalDb(db, collectionName, <RecordModel>[ model ], logger, indexInstructions: indexInstructions);
      final Map<String, dynamic> data = model.data;

      data["id"] = model.id;
      data["created"] = model.created;
      data["updated"] = model.updated;

      return data;
    } on ClientException catch (e) {
      if (e.toString().contains("Failed to find all relation records")) {
        logger.e("Failed to insert $values into $collectionName");
        rethrow;
      }
      if (!e.isNetworkError()) {
        rethrow;
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
