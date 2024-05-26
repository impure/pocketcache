
import 'package:pocketbase/pocketbase.dart';
import 'pocketbase_offline_cache_base.dart';

extension DeleteWrapper on PbOfflineCache {
  Future<void> deleteRecord(String collectionName, String id, {
    QuerySource source = QuerySource.any,
  }) async {

    if (source != QuerySource.server && (!dbAccessible || source == QuerySource.client)) {

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
      if (source == QuerySource.any) {
        return deleteRecord(collectionName, id, source: QuerySource.client);
      }
    }
  }

}
