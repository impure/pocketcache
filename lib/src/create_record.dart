

import 'dart:math';

import 'package:pocketbase/pocketbase.dart';

import 'get_records.dart';
import 'pocketbase_offline_cache_base.dart';

extension CreateWrapper on PbOfflineCache {
  Future<Map<String, dynamic>?> createRecord(String collectionName, Map<String, dynamic> body, {
    bool forceOffline = false,
  }) async {

    if (!dbAccessible || forceOffline) {

      // If table does not exist yet we are unsure of the required schema so can't add anything
      if (tableExists(db, collectionName)) {
        final String id = makePbId();
        final String now = DateTime.now().toString();

        queueOperation("INSERT", collectionName, idToModify: id, values: body);
        insertRecordsIntoLocalDb(db, collectionName, <RecordModel>[ RecordModel(
          id: id,
          created: now,
          updated: now,
          data: body,
        ) ], logger);

        body["id"] = id;
        body["created"] = now;
        body["updated"] = now;

        return body;
      }

      return null;
    }

    try {
      final RecordModel model = await pb.collection(collectionName).create(body: body);
      insertRecordsIntoLocalDb(db, collectionName, <RecordModel>[ model ], logger);
      final Map<String, dynamic> data = model.data;

      body["id"] = model.id;
      body["created"] = model.created;
      body["updated"] = model.updated;

      return data;
    } on ClientException catch (e) {
      if (!e.toString().contains("refused the network connection")) {
        rethrow;
      }
      return createRecord(collectionName, body, forceOffline: true);
    }
  }

}

final Random random = Random();

String makePbId() {
  const String chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

  return List<String>.generate(15, (int index) => chars[random.nextInt(chars.length)]).join();
}
