
import 'package:pocketbase/pocketbase.dart';
import 'pocketbase_offline_cache_base.dart';

extension DeleteWrapper on PbOfflineCache {
  Future<void> deleteRecord(String collectionName, String id, {
    bool forceOffline = false,
  }) async {

    if (!dbAccessible || forceOffline) {

      if (tableExists(db, collectionName)) {
        queueOperation("DELETE", collectionName, idToModify: id);
        db.execute("DELETE FROM $collectionName WHERE id = ?", <Object?>[ id ]);
      }

      return;
    }

    try {
      await pb.collection(collectionName).delete(id);
      db.execute("DELETE FROM $collectionName WHERE id = ?", <Object?>[ id ]);
    } on ClientException catch (e) {
      if (!e.toString().contains("refused the network connection")) {
        rethrow;
      }
      return deleteRecord(collectionName, id, forceOffline: true);
    }
  }

}
