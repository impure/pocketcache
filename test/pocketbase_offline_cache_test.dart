
import 'dart:ffi';

import 'package:http/src/client.dart';
import 'package:http/src/multipart_file.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketbase_offline_cache/pocketbase_offline_cache.dart';
import 'package:pocketbase_offline_cache/src/pocketbase_offline_cache_base.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

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
		return ResultSet(<String>[], <String>[], <List<Object?>>[]);
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

	tearDown(() {
		operations.clear();
	});

	final PbOfflineCache pb = PbOfflineCache.withDb(PbWrapper(), DatabaseMock());

	test("selectBuilder", () {
		selectBuilder(pb.db, "collection");
		expect(operations[0].toString(), "[SELECT * FROM collection;, []]");
		selectBuilder(pb.db, "collection", columns: "COUNT(*)");
		expect(operations[1].toString(), "[SELECT COUNT(*) FROM collection;, []]");
		selectBuilder(pb.db, "collection", columns: "COUNT(*)", filter: ("abc = ? && xyz = ?", <dynamic>[ 1, "2" ]));
		expect(operations[2].toString(), "[SELECT COUNT(*) FROM collection WHERE abc = ? AND xyz = ?;, [1, 2]]");
	});

	test("listRecords", () async {
		await pb.getRecords("abc");
		expect(operations.toString(), "[getList 1 500 true null]");
		operations.clear();
		await pb.getRecords("abc", maxItems: 50);
		expect(operations.toString(), "[getList 1 50 true null]");
		operations.clear();
		await pb.getRecords("abc", maxItems: 50, where: ("abc = ? && xyz = ?", <int>[1, 2]));
		expect(operations.toString(), "[getList 1 50 true abc = 1 && xyz = 2]");
		operations.clear();
		await pb.getRecords("abc", maxItems: 50, where: ("status = ? && created >= ?", <Object>[true, "2022-08-01"]));
		expect(operations.toString(), "[getList 1 50 true status = true && created >= '2022-08-01']");
		operations.clear();
		await pb.getRecords("abc", maxItems: 50, where: ("status = ? && created >= ?", <Object>[true, DateTime(2024)]));
		expect(operations.toString(), "[getList 1 50 true status = true && created >= '2024-01-01 00:00:00.000']");
	});
}
