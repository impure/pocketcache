
import 'dart:ffi';

import 'package:http/src/client.dart';
import 'package:http/src/multipart_file.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketbase_offline_cache/pocketbase_offline_cache.dart';
import 'package:pocketbase_offline_cache/src/pocketbase_offline_cache_base.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

(List<String>, List<List<Object?>>)? testResults;

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
	void execute(String sql, [List<Object?> parameters = const <Object?>[]]) {
		operations.add(<dynamic>[ sql, parameters]);
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
	ResultSet select(String sql, [List<Object?> parameters = const <Object?>[]]) {
		operations.add(<dynamic>[ sql, parameters]);
		return ResultSet(testResults?.$1 ?? <String>[], <String>[], testResults?.$2 ?? <List<Object?>>[]);
	}

	@override
	int get updatedRows => throw UnimplementedError();

	@override
	Stream<SqliteUpdate> get updates => throw UnimplementedError();

}

PocketBase basePb = PocketBase("");

class PbWrapper implements PocketBase {

	@override
	AdminService admins = basePb.admins;

	@override
	AuthStore authStore = basePb.authStore;

	@override
	BackupService backups = basePb.backups;

	@override
	String baseUrl = basePb.baseUrl;

	@override
	CollectionService collections = basePb.collections;

	@override
	FileService files = basePb.files;

	@override
	HealthService health = basePb.health;

	@override
	Client Function() httpClientFactory = basePb.httpClientFactory;

	@override
	String lang = "";

	@override
	LogService logs = basePb.logs;

	@override
	RealtimeService realtime = basePb.realtime;

	@override
	SettingsService settings = basePb.settings;

	@override
	Uri buildUrl(String path, [Map<String, dynamic> queryParameters = const <String, dynamic>{}]) {
		throw UnimplementedError();
	}

	@override
	RecordService collection(String collectionIdOrName) {
		return RecordServiceMock(collectionIdOrName);
	}

	@override
	String filter(String expr, [Map<String, dynamic> query = const <String, dynamic>{}]) {
		throw UnimplementedError();
	}

	@override
	Uri getFileUrl(RecordModel record, String filename, {String? thumb, String? token, Map<String, dynamic> query = const <String, dynamic>{}}) {
		throw UnimplementedError();
	}

	@override
	Future<void> send(String path, {String method = "GET", Map<String, String> headers = const <String, String>{}, Map<String, dynamic> query = const <String, dynamic>{}, Map<String, dynamic> body = const <String, dynamic>{}, List<MultipartFile> files = const <MultipartFile>[]}) {
		throw UnimplementedError();
	}
}

class RecordServiceMock implements RecordService {

	RecordServiceMock(this.collection);

	final String collection;

	@override
	Future<RecordAuth> authRefresh({String? expand, String? fields, Map<String, dynamic> body = const <String, dynamic>{}, Map<String, dynamic> query = const <String, dynamic>{}, Map<String, String> headers = const <String, String>{}}) {
		throw UnimplementedError();
	}

	@override
	Future<RecordAuth> authWithOAuth2(String providerName, OAuth2UrlCallbackFunc urlCallback, {List<String> scopes = const <String>[], Map<String, dynamic> createData = const <String, dynamic>{}, String? expand, String? fields}) {
		throw UnimplementedError();
	}

	@override
	Future<RecordAuth> authWithOAuth2Code(String provider, String code, String codeVerifier, String redirectUrl, {Map<String, dynamic> createData = const <String, dynamic>{}, Map<String, dynamic> body = const <String, dynamic>{}, Map<String, dynamic> query = const <String, dynamic>{}, Map<String, String> headers = const <String, String>{}, String? expand, String? fields}) {
		throw UnimplementedError();
	}

	@override
	Future<RecordAuth> authWithPassword(String usernameOrEmail, String password, {String? expand, String? fields, Map<String, dynamic> body = const <String, dynamic>{}, Map<String, dynamic> query = const <String, dynamic>{}, Map<String, String> headers = const <String, String>{}}) {
		throw UnimplementedError();
	}

	@override
	String get baseCollectionPath => throw UnimplementedError();

	@override
	String get baseCrudPath => throw UnimplementedError();

	@override
	PocketBase get client => throw UnimplementedError();

	@override
	Future<void> confirmEmailChange(String emailChangeToken, String userPassword, {Map<String, dynamic> body = const <String, dynamic>{}, Map<String, dynamic> query = const <String, dynamic>{}, Map<String, String> headers = const <String, String>{}}) {
		throw UnimplementedError();
	}

	@override
	Future<void> confirmPasswordReset(String passwordResetToken, String password, String passwordConfirm, {Map<String, dynamic> body = const <String, dynamic>{}, Map<String, dynamic> query = const <String, dynamic>{}, Map<String, String> headers = const <String, String>{}}) {
		throw UnimplementedError();
	}

	@override
	Future<void> confirmVerification(String verificationToken, {Map<String, dynamic> body = const <String, dynamic>{}, Map<String, dynamic> query = const <String, dynamic>{}, Map<String, String> headers = const <String, String>{}}) {
		throw UnimplementedError();
	}

	@override
	Future<RecordModel> create({Map<String, dynamic> body = const <String, dynamic>{}, Map<String, dynamic> query = const <String, dynamic>{}, List<MultipartFile> files = const <MultipartFile>[], Map<String, String> headers = const <String, String>{}, String? expand, String? fields}) {
		throw UnimplementedError();
	}

	@override
	Future<void> delete(String id, {Map<String, dynamic> body = const <String, dynamic>{}, Map<String, dynamic> query = const <String, dynamic>{}, Map<String, String> headers = const <String, String>{}}) {
		throw UnimplementedError();
	}

	@override
	Future<RecordModel> getFirstListItem(String filter, {String? expand, String? fields, Map<String, dynamic> query = const <String, dynamic>{}, Map<String, String> headers = const <String, String>{}}) {
		throw UnimplementedError();
	}

	@override
	Future<List<RecordModel>> getFullList({int batch = 500, String? expand, String? filter, String? sort, String? fields, Map<String, dynamic> query = const <String, dynamic>{}, Map<String, String> headers = const <String, String>{}}) {
		throw UnimplementedError();
	}

	@override
	Future<ResultList<RecordModel>> getList({int page = 1, int perPage = 30, bool skipTotal = false, String? expand, String? filter, String? sort, String? fields, Map<String, dynamic> query = const <String, dynamic>{}, Map<String, String> headers = const <String, String>{}}) async {
		operations.add("getList $page $perPage $skipTotal $filter");
		return ResultList<RecordModel>();
	}

	@override
	Future<RecordModel> getOne(String id, {String? expand, String? fields, Map<String, dynamic> query = const <String, dynamic>{}, Map<String, String> headers = const <String, String>{}}) {
		throw UnimplementedError();
	}

	@override
	RecordModel itemFactoryFunc(Map<String, dynamic> json) {
		throw UnimplementedError();
	}

	@override
	Future<AuthMethodsList> listAuthMethods({Map<String, dynamic> query = const <String, dynamic>{}, Map<String, String> headers = const <String, String>{}}) {
		throw UnimplementedError();
	}

	@override
	Future<List<ExternalAuthModel>> listExternalAuths(String recordId, {Map<String, dynamic> query = const <String, dynamic>{}, Map<String, String> headers = const <String, String>{}}) {
		throw UnimplementedError();
	}

	@override
	Future<void> requestEmailChange(String newEmail, {Map<String, dynamic> body = const <String, dynamic>{}, Map<String, dynamic> query = const <String, dynamic>{}, Map<String, String> headers = const <String, String>{}}) {
		throw UnimplementedError();
	}

	@override
	Future<void> requestPasswordReset(String email, {Map<String, dynamic> body = const <String, dynamic>{}, Map<String, dynamic> query = const <String, dynamic>{}, Map<String, String> headers = const <String, String>{}}) {
		throw UnimplementedError();
	}

	@override
	Future<void> requestVerification(String email, {Map<String, dynamic> body = const <String, dynamic>{}, Map<String, dynamic> query = const <String, dynamic>{}, Map<String, String> headers = const <String, String>{}}) {
		throw UnimplementedError();
	}

	@override
	Future<UnsubscribeFunc> subscribe(String topic, RecordSubscriptionFunc callback, {String? expand, String? filter, String? fields, Map<String, dynamic> query = const <String, dynamic>{}, Map<String, String> headers = const <String, String>{}}) {
		throw UnimplementedError();
	}

	@override
	Future<void> unlinkExternalAuth(String recordId, String provider, {Map<String, dynamic> body = const <String, dynamic>{}, Map<String, dynamic> query = const <String, dynamic>{}, Map<String, String> headers = const <String, String>{}}) {
		throw UnimplementedError();
	}

	@override
	Future<void> unsubscribe([String topic = ""]) {
		throw UnimplementedError();
	}

	@override
	Future<RecordModel> update(String id, {Map<String, dynamic> body = const <String, dynamic>{}, Map<String, dynamic> query = const <String, dynamic>{}, List<MultipartFile> files = const <MultipartFile>[], Map<String, String> headers = const <String, String>{}, String? expand, String? fields}) {
		throw UnimplementedError();
	}
}

List<dynamic> operations = <dynamic>[];

// Note: run this from `flutter test` not from the IDE
void main() {

	setUp(() {
		operations.clear();
	});

	tearDown(() {
		operations.clear();
		testResults = null;
	});

	final PbOfflineCache pb = PbOfflineCache.withDb(PbWrapper(), DatabaseMock());
	pb.dbAccessible = true;

	group("selectBuilder", () {
		test("basic selectBuilder", () {
			selectBuilder(pb.db, "collection");
			expect(operations.toString(), "[[SELECT * FROM collection;, []]]");
		});

		test("count selectBuilder", () {
			selectBuilder(pb.db, "collection", columns: "COUNT(*)");
			expect(operations.toString(), "[[SELECT COUNT(*) FROM collection;, []]]");
		});

		test("single conditions selectBuilder", () {
			selectBuilder(pb.db, "collection", filter: ("abc >= ?", <dynamic>[ DateTime.utc(2024) ]));
			expect(operations.toString(), "[[SELECT * FROM collection WHERE abc >= ?;, [2024-01-01 00:00:00.000Z]]]");
		});

		test("multiple conditions selectBuilder", () {
			selectBuilder(pb.db, "collection", columns: "COUNT(*)", filter: ("abc = ? && xyz = ?", <dynamic>[ 1, "2" ]));
			expect(operations.toString(), "[[SELECT COUNT(*) FROM collection WHERE abc = ? AND  xyz = ?;, [1, 2]]]");
		});

		test("single condition bool selectBuilder", () {
			testResults = (<String>["_offline_bool_abc"], <List<Object?>>[<Object?>[true]]);
			expect(selectBuilder(pb.db, "collection", filter: ("abc = ?", <dynamic>[ true ])).toString(), "[{_offline_bool_abc: true}]");
			expect(operations.toString(), "[[SELECT * FROM collection WHERE _offline_bool_abc = ?;, [true]]]");
		});

	});

	group("QueryBuilder", () {
		test("Empty", () async {
			expect((await pb.collection("test").get()).toString(), "[]");
			expect(operations.toString(), "[getList 1 500 true ]");
		});
		
		test("Single condition", () async {
			expect((await pb.collection("test").where("abc", isEqualTo: "xyz").get()).toString(), "[]");
			expect(operations.toString(), "[getList 1 500 true abc = 'xyz']");
		});

		test("Multiple conditions", () async {
			expect((await pb.collection("test")
				.where("abc", isNotEqualTo: "xyz")
				.where("1", isGreaterThan: 3)
				.where("2", isLessThan: 6)
				.where("abc", isGreaterThanOrEqualTo: 44).get()).toString(), "[]");
			expect(operations.toString(), "[getList 1 500 true abc != 'xyz' && 1 > 3 && 2 < 6 && abc >= 44]");
		});
	});
}
