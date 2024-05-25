

import 'dart:math';

import 'package:pocketbase/pocketbase.dart';

import 'get_records.dart';
import 'pocketbase_offline_cache_base.dart';

extension CreateWrapper on PbOfflineCache {
  Future<void> createRecord(String collectionName, Map<String, dynamic> body, {
    bool forceOffline = false,
  }) async {

    if (!dbAccessible || forceOffline) {

      // If table does not exist yet we are unsure of the required schema so can't add anything
      if (tableExists(db, collectionName)) {
        final String id = makePbId();
        queueOperation("INSERT", collectionName, idToModify: id, values: body);
        insertRecordsIntoLocalDb(db, collectionName, <RecordModel>[ RecordModel(
          id: id,
          created: DateTime.now().toString(),
          updated: DateTime.now().toString(),
          data: body,
        ) ], logger);
      }

      return;
    }

    try {
      final RecordModel model = await pb.collection(collectionName).create(body: body);
      insertRecordsIntoLocalDb(db, collectionName, <RecordModel>[ model ], logger);
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

  return List.generate(15, (int index) => chars[random.nextInt(chars.length)]).join();
}
