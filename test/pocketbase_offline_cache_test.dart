
import 'dart:ffi';

import 'package:http/src/client.dart';
import 'package:http/src/multipart_file.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketbase_offline_cache/src/pocketbase_offline_cache_base.dart';
import 'package:test/test.dart';
import 'package:sqlite3/sqlite3.dart';

class DatabaseMock implements Database {
  @override
  int userVersion = 0;

  @override
  bool get autocommit => throw UnimplementedError();

  @override
  Stream<double> backup(Database toDatabase, {int nPage = 5}) {
    throw UnimplementedError();
  }

  @override
  DatabaseConfig get config => throw UnimplementedError();

  @override
  void createAggregateFunction<V>({required String functionName, required AggregateFunction<V> function, AllowedArgumentCount argumentCount = const AllowedArgumentCount.any(), bool deterministic = false, bool directOnly = true}) {
  }

  @override
  void createCollation({required String name, required CollatingFunction function}) {
  }

  @override
  void createFunction({required String functionName, required ScalarFunction function, AllowedArgumentCount argumentCount = const AllowedArgumentCount.any(), bool deterministic = false, bool directOnly = true}) {
  }

  @override
  void dispose() {
  }

  @override
  void execute(String sql, [List<Object?> parameters = const []]) {
  }

  @override
  int getUpdatedRows() {
    throw UnimplementedError();
  }

  @override
  Pointer<void> get handle => throw UnimplementedError();

  @override
  int get lastInsertRowId => throw UnimplementedError();

  @override
  PreparedStatement prepare(String sql, {bool persistent = false, bool vtab = true, bool checkNoTail = false}) {
    throw UnimplementedError();
  }

  @override
  List<PreparedStatement> prepareMultiple(String sql, {bool persistent = false, bool vtab = true}) {
    throw UnimplementedError();
  }

  @override
  ResultSet select(String sql, [List<Object?> parameters = const []]) {
    operations.add(<dynamic>[ sql, parameters]);
    return ResultSet(<String>[], <String>[], <List<Object?>>[]);
  }

  @override
  int get updatedRows => throw UnimplementedError();

  @override
  Stream<SqliteUpdate> get updates => throw UnimplementedError();

}

List<dynamic> operations = <dynamic>[];

// Note: run this from `flutter test` not from the IDE
void main() {

  final PbOfflineCache pb = PbOfflineCache.withDb(PocketBase(""), DatabaseMock());

  test("selectBuilder", () {
    pb.selectBuilder("collection");
    expect(operations[0].toString(), "[SELECT * FROM collection;, []]");
    pb.selectBuilder("collection", columns: "COUNT(*)");
    expect(operations[1].toString(), "[SELECT COUNT(*) FROM collection;, []]");
    pb.selectBuilder("collection", columns: "COUNT(*)", filter: ("abc = ? && xyz = ?", <dynamic>[ 1, "2" ]));
    expect(operations[2].toString(), "[SELECT COUNT(*) FROM collection WHERE abc = ? AND xyz = ?;, [1, 2]]");
  });
}
