
import 'package:logger/logger.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketbase_offline_cache/pocketbase_offline_cache.dart';
import 'package:pocketbase_offline_cache/src/get_records.dart';
import 'package:sqlite3/common.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

import 'pocketbase_offline_cache_test.dart';

class TestLogger implements Logger {
  @override
  Future<void> close() {
    throw UnimplementedError();
  }

  @override
  void d(dynamic message, {DateTime? time, Object? error, StackTrace? stackTrace}) {
		operations.add("d: $message");
  }

  @override
  void e(dynamic message, {DateTime? time, Object? error, StackTrace? stackTrace}) {
		operations.add("e: $message");
  }

  @override
  void f(dynamic message, {DateTime? time, Object? error, StackTrace? stackTrace}) {
		operations.add("f: $message");
  }

  @override
  void i(dynamic message, {DateTime? time, Object? error, StackTrace? stackTrace}) {
		operations.add("i: $message");
  }

  @override
  Future<void> get init => throw UnimplementedError();

  @override
  bool isClosed() {
    throw UnimplementedError();
  }

  @override
  void log(Level level, dynamic message, {DateTime? time, Object? error, StackTrace? stackTrace}) {
		operations.add("$level: $message");
  }

  @override
  void t(dynamic message, {DateTime? time, Object? error, StackTrace? stackTrace}) {
		operations.add("t: $message");
  }

  @override
  void v(dynamic message, {DateTime? time, Object? error, StackTrace? stackTrace}) {
		operations.add("v: $message");
  }

  @override
  void w(dynamic message, {DateTime? time, Object? error, StackTrace? stackTrace}) {
		operations.add("w: $message");
  }

  @override
  void wtf(dynamic message, {DateTime? time, Object? error, StackTrace? stackTrace}) {
		operations.add("wtf: $message");
  }

}

void main() {

	setUp(() {
		operations.clear();
	});
	tearDown(() {
		operations.clear();
	});

	final PbOfflineCache pb = PbOfflineCache.withDb(PbWrapper(), DatabaseMock());
	pb.remoteAccessible = true;
	final Logger testLogger = TestLogger();

	group("listRecords", () {
		test("basic getRecords", () async {
			await pb.getRecords("abc");
			expect(operations.toString(), "[getList 1 500 true null, [SELECT last_update FROM _last_sync_times WHERE table_name=?, [abc]]]");
		});

		test("limit items getRecords", () async {
			await pb.getRecords("abc", maxItems: 50);
			expect(operations.toString(), "[getList 1 50 true null, [SELECT last_update FROM _last_sync_times WHERE table_name=?, [abc]]]");
		});

		test("multi condition 1 getRecords", () async {
			await pb.getRecords("abc", maxItems: 50, where: ("abc = ? && xyz = ?", <int>[1, 2]));
			expect(operations.toString(), "[getList 1 50 true abc = 1 && xyz = 2, [SELECT last_update FROM _last_sync_times WHERE table_name=?, [abc]]]");
		});

		test("multi condition 2 getRecords", () async {
			await pb.getRecords("abc", where: ("status = ? && created >= ?", <Object>[true, "2022-08-01"]));
			expect(operations.toString(), "[getList 1 500 true status = true && created >= '2022-08-01', [SELECT last_update FROM _last_sync_times WHERE table_name=?, [abc]]]");
		});

		test("single condition getRecords", () async {
			await pb.getRecords("abc", maxItems: 50, where: ("created >= ?", <Object>[DateTime.utc(2024)]));
			expect(operations.toString(), "[getList 1 50 true created >= '2024-01-01 00:00:00.000Z', [SELECT last_update FROM _last_sync_times WHERE table_name=?, [abc]]]");
		});

		test("single start after multi condition getRecords descending", () async {
			await pb.getRecords("abc", where: ("status = ? && created >= ?", <Object>[true, "2022-08-01"]), startAfter: <String, dynamic>{"status": true}, sort: ("status", true));
			expect(operations.toString(), "[getList 1 500 true status = true && created >= '2022-08-01' && status < true, [SELECT last_update FROM _last_sync_times WHERE table_name=?, [abc]]]");
		});

		test("multi start after no conditions getRecords", () async {
			await pb.getRecords("abc", startAfter: <String, dynamic>{"status": DateTime.utc(2024), "1" : 2}, sort: ("status", false));
			expect(operations.toString(), "[getList 1 500 true status > '2024-01-01 00:00:00.000Z', [SELECT last_update FROM _last_sync_times WHERE table_name=?, [abc]]]");
		});
	});

	group("insertRecordsIntoLocalDb", () {

		test("insert empty", () async {
			await pb.insertRecordsIntoLocalDb("test", <RecordModel>[ RecordModel(
				<String, dynamic> {
					"id" : "abc",
					"created" : DateTime(2024, 1).toString(),
					"updated" : DateTime(2024, 2).toString(),
				}
			) ], testLogger, overrideDownloadTime: DateTime(2024, 3).toString());
			expect(operations.toString(),
					"[[SELECT name FROM sqlite_master WHERE type='table' AND name=?, [test]], "
					"[CREATE TABLE test (id TEXT PRIMARY KEY, created TEXT, updated TEXT, _downloaded TEXT), []], "
					"[CREATE INDEX IF NOT EXISTS _idx_downloaded ON test (_downloaded), []], "
					"[INSERT OR REPLACE INTO test(id, created, updated, _downloaded) VALUES(?, ?, ?, ?);, [abc, 2024-01-01 00:00:00.000, 2024-02-01 00:00:00.000, 2024-03-01 00:00:00.000]]]"
			);
		});

		test("insert one item", () async {
			await pb.insertRecordsIntoLocalDb("test", <RecordModel>[ RecordModel(
					<String, dynamic> {
						"id" : "abc",
						"created" : DateTime(2024, 1).toString(),
						"updated" : DateTime(2024, 2).toString(),
						"1" : 2,
					}
			) ], testLogger, overrideDownloadTime: DateTime(2024, 3).toString());
			expect(operations.toString(),
				"[[SELECT name FROM sqlite_master WHERE type='table' AND name=?, [test]], "
				"[CREATE TABLE test (id TEXT PRIMARY KEY, created TEXT, updated TEXT, _downloaded TEXT,1 REAL DEFAULT 0.0), []], "
				"[CREATE INDEX IF NOT EXISTS _idx_downloaded ON test (_downloaded), []], "
				"[INSERT OR REPLACE INTO test(id, created, updated, _downloaded, 1) VALUES(?, ?, ?, ?, ?);, [abc, 2024-01-01 00:00:00.000, 2024-02-01 00:00:00.000, 2024-03-01 00:00:00.000, 2]]]"
			);
		});

		test("insert two items", () async {
			await pb.insertRecordsIntoLocalDb("test", <RecordModel>[ RecordModel(
				<String, dynamic> {
					"id" : "abc",
					"created" : DateTime(2024, 1).toString(),
					"updated" : DateTime(2024, 2).toString(),
					"1" : true,
					"2" : DateTime(2022).toString(),
				},
			) ], testLogger, overrideDownloadTime: DateTime(2024, 3).toString());
			expect(operations.toString(),
				"[[SELECT name FROM sqlite_master WHERE type='table' AND name=?, [test]], "
				"[CREATE TABLE test (id TEXT PRIMARY KEY, created TEXT, updated TEXT, _downloaded TEXT,_offline_bool_1 INTEGER DEFAULT 0,2 TEXT DEFAULT ''), []], "
				"[CREATE INDEX IF NOT EXISTS _idx_downloaded ON test (_downloaded), []], "
				"[INSERT OR REPLACE INTO test(id, created, updated, _downloaded, _offline_bool_1, 2) VALUES(?, ?, ?, ?, ?, ?);, [abc, 2024-01-01 00:00:00.000, 2024-02-01 00:00:00.000, 2024-03-01 00:00:00.000, true, 2022-01-01 00:00:00.000]]]"
			);
		});

		test("single index failed", () async {
			await pb.insertRecordsIntoLocalDb("test", <RecordModel>[ RecordModel(
				<String, dynamic> {
					"1" : 1,
					"2" : DateTime(2022).toString(),
					"id" : "abc",
					"created" : DateTime(2024, 1).toString(),
					"updated" : DateTime(2024, 2).toString(),
				},
			) ], testLogger, indexInstructions: <String, List<(String, bool, List<String>)>>{"test" : <(String, bool, List<String>)>[ ("index1", false, <String>["3"]) ]}, overrideDownloadTime: DateTime(2024, 3).toString());
			expect(operations.toString(),
				"[[SELECT name FROM sqlite_master WHERE type='table' AND name=?, [test]], "
				"[CREATE TABLE test (id TEXT PRIMARY KEY, created TEXT, updated TEXT, _downloaded TEXT,1 REAL DEFAULT 0.0,2 TEXT DEFAULT ''), []], "
				"[CREATE INDEX IF NOT EXISTS _idx_downloaded ON test (_downloaded), []], "
				"e: Unable to create index index1 on test({id, created, updated, _downloaded, 1, 2}), could not find all columns: [3], "
				"[INSERT OR REPLACE INTO test(id, created, updated, _downloaded, 1, 2) VALUES(?, ?, ?, ?, ?, ?);, [abc, 2024-01-01 00:00:00.000, 2024-02-01 00:00:00.000, 2024-03-01 00:00:00.000, 1, 2022-01-01 00:00:00.000]]]"
			);
		});

		test("irrelevant index", () async {
			await pb.insertRecordsIntoLocalDb("test", <RecordModel>[ RecordModel(
				<String, dynamic> {
					"1" : <String>["1", "2"],
					"2" : DateTime(2022).toString(),
					"id" : "abc",
					"created" : DateTime(2024, 1).toString(),
					"updated" : DateTime(2024, 2).toString(),
				},
			) ], testLogger, indexInstructions: <String, List<(String, bool, List<String>)>>{"3" : <(String, bool, List<String>)>[ ("index1", false, <String>["4", "5"]) ]}, overrideDownloadTime: DateTime(2024, 3).toString());
			expect(operations.toString(),
				"[[SELECT name FROM sqlite_master WHERE type='table' AND name=?, [test]], "
				"[CREATE TABLE test (id TEXT PRIMARY KEY, created TEXT, updated TEXT, _downloaded TEXT,_offline_json_1 TEXT DEFAULT '[]',2 TEXT DEFAULT ''), []], "
				"[CREATE INDEX IF NOT EXISTS _idx_downloaded ON test (_downloaded), []], "
				"[INSERT OR REPLACE INTO test(id, created, updated, _downloaded, _offline_json_1, 2) VALUES(?, ?, ?, ?, ?, ?);, [abc, 2024-01-01 00:00:00.000, 2024-02-01 00:00:00.000, 2024-03-01 00:00:00.000, [\"1\",\"2\"], 2022-01-01 00:00:00.000]]]"
			);
		});

		test("double index success", () async {
			await pb.insertRecordsIntoLocalDb("test", <RecordModel>[ RecordModel(
				<String, dynamic> {
					"1" : 1,
					"2" : DateTime(2022).toString(),
					"id" : "abc",
					"created" : DateTime(2024, 1).toString(),
					"updated" : DateTime(2024, 2).toString(),
				},
			) ], testLogger, indexInstructions: <String, List<(String, bool, List<String>)>>{"test" : <(String, bool, List<String>)>[
				("index1", false, <String>["1", "2"]),
			]}, overrideDownloadTime: DateTime(2024, 3).toString());
			expect(operations.toString(),
				"[[SELECT name FROM sqlite_master WHERE type='table' AND name=?, [test]], "
				"[CREATE TABLE test (id TEXT PRIMARY KEY, created TEXT, updated TEXT, _downloaded TEXT,1 REAL DEFAULT 0.0,2 TEXT DEFAULT ''), []], "
				"[CREATE INDEX IF NOT EXISTS _idx_downloaded ON test (_downloaded), []], "
				"[CREATE INDEX IF NOT EXISTS index1 ON test(1, 2), []], "
				"[INSERT OR REPLACE INTO test(id, created, updated, _downloaded, 1, 2) VALUES(?, ?, ?, ?, ?, ?);, [abc, 2024-01-01 00:00:00.000, 2024-02-01 00:00:00.000, 2024-03-01 00:00:00.000, 1, 2022-01-01 00:00:00.000]]]"
			);
		});

		test("multiple indexes at the same time (and one unique)", () async {
			await pb.insertRecordsIntoLocalDb("test", <RecordModel>[ RecordModel(
				<String, dynamic> {
					"1" : 1,
					"2" : DateTime(2022).toString(),
					"id" : "abc",
					"created" : DateTime(2024, 1).toString(),
					"updated" : DateTime(2024, 2).toString(),
				},
			) ], testLogger, indexInstructions: <String, List<(String, bool, List<String>)>>{"test" : <(String, bool, List<String>)>[
				("index1", true, <String>["1", "2"]),
				("index2", false, <String>["2"]),
			]}, overrideDownloadTime: DateTime(2024, 3).toString());
			expect(operations.toString(),
				"[[SELECT name FROM sqlite_master WHERE type='table' AND name=?, [test]], "
				"[CREATE TABLE test (id TEXT PRIMARY KEY, created TEXT, updated TEXT, _downloaded TEXT,1 REAL DEFAULT 0.0,2 TEXT DEFAULT ''), []], "
				"[CREATE INDEX IF NOT EXISTS _idx_downloaded ON test (_downloaded), []], "
				"[CREATE UNIQUE INDEX IF NOT EXISTS index1 ON test(1, 2), []], "
				"[CREATE INDEX IF NOT EXISTS index2 ON test(2), []], "
				"[INSERT OR REPLACE INTO test(id, created, updated, _downloaded, 1, 2) VALUES(?, ?, ?, ?, ?, ?);, [abc, 2024-01-01 00:00:00.000, 2024-02-01 00:00:00.000, 2024-03-01 00:00:00.000, 1, 2022-01-01 00:00:00.000]]]"
			);
		});

		test("multiple indexes at the same time 2 (and one unique)", () async {

			// On Windows in terminal requires SQLite files in the path, in Android Studio SQLite should be in the root of the project
			final PbOfflineCache testPb = PbOfflineCache.withDb(PocketBase(""), sqlite3.openInMemory());

			await testPb.insertRecordsIntoLocalDb("test", <RecordModel>[ RecordModel(
				<String, dynamic> {
					"one" : 1,
					"two" : DateTime(2022).toString(),
					"id" : "abc",
					"created" : DateTime(2024, 1).toString(),
					"updated" : DateTime(2024, 2).toString(),
				},
			) ], testLogger, indexInstructions: <String, List<(String, bool, List<String>)>>{"test" : <(String, bool, List<String>)>[
				("index1", true, <String>["one", "two"]),
				("index2", false, <String>["two"]),
			]}, overrideDownloadTime: DateTime(2024, 3).toString());
			final Set<String> names = getRowNames(await testPb.dbIsolate.select("PRAGMA index_list('test');"));
			expect(names.contains("_idx_downloaded"), true);
			expect(names.contains("index1"), true);
			expect(names.contains("index2"), true);
		});

		test("reinit indexes", () async {

			// On Windows in terminal requires SQLite files in the path, in Android Studio SQLite should be in the root of the project
			final CommonDatabase db = sqlite3.openInMemory();
			PbOfflineCache testPb = PbOfflineCache.withDb(PocketBase(""), db);

			await testPb.insertRecordsIntoLocalDb("test", <RecordModel>[ RecordModel(
				<String, dynamic> {
					"one" : 1,
					"two" : DateTime(2022).toString(),
					"id" : "abc",
					"created" : DateTime(2024, 1).toString(),
					"updated" : DateTime(2024, 2).toString(),
				},
			) ], testLogger, indexInstructions: <String, List<(String, bool, List<String>)>>{"test" : <(String, bool, List<String>)>[
				("index1", true, <String>["one", "two"]),
			]}, overrideDownloadTime: DateTime(2024, 3).toString());

			Set<String> names = getRowNames(await testPb.dbIsolate.select("PRAGMA index_list('test');"));
			expect(names.contains("_idx_downloaded"), true);
			expect(names.contains("index1"), true);
			expect(names.contains("index2"), false);

			// On Windows in terminal requires SQLite files in the path, in Android Studio SQLite should be in the root of the project
			testPb = PbOfflineCache.withDb(PocketBase(""), db, indexInstructions: <String, List<(String, bool, List<String>)>>{"test" : <(String, bool, List<String>)>[
				("index1", true, <String>["one", "two"]),
				("index2", false, <String>["two"]),
			]});

			await testPb.insertRecordsIntoLocalDb("test", <RecordModel>[ RecordModel(
				<String, dynamic> {
					"one" : 1,
					"two" : DateTime(2022).toString(),
					"id" : "abc",
					"created" : DateTime(2024, 1).toString(),
					"updated" : DateTime(2024, 2).toString(),
				},
			) ], testLogger, indexInstructions: <String, List<(String, bool, List<String>)>>{"test" : <(String, bool, List<String>)>[
				("index1", true, <String>["one", "two"]),
				("index2", false, <String>["two"]),
			]}, overrideDownloadTime: DateTime(2024, 3).toString());
			await testPb.reinitIndexes();

			names = getRowNames(await testPb.dbIsolate.select("PRAGMA index_list('test');"));
			expect(names.contains("_idx_downloaded"), true);
			expect(names.contains("index1"), true);
			expect(names.contains("index2"), true);
		});
	});
}

Set<String> getRowNames(List<Map<String, dynamic>> result) {
	final Set<String> names = <String>{};

	for (final Map<String, dynamic> row in result) {
		names.add(row["name"]);
	}

	return names;
}
