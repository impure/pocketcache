
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:sqlite3/sqlite3.dart';

late Database db;
late PocketBase pb;
late Logger logger;

const int defaultMaxItems = 100000;

bool dbAccessible = true;

Future<void> initPbOffline(PocketBase pbInstance, {Logger? overrideLogger}) async {
	logger = overrideLogger ?? Logger();
	pb = pbInstance;
	db = sqlite3.open(join((await getApplicationDocumentsDirectory()).path, "offline_cache"));
	unawaited(continuouslyCheckDbAccessible());
}

Future<void> continuouslyCheckDbAccessible() async {
	while (true) {
		try {
			final http.Response response = await http.get(pb.buildUrl("/api/health"));
			if (response.statusCode != 200) {
				dbAccessible = false;
			} else {
				dbAccessible = true;
			}
		} on SocketException catch (e) {
			if (!e.message.contains("refused")) {
				rethrow;
			}
			dbAccessible = false;
		}
		await Future<void>.delayed(const Duration(seconds: 10));
	}
}

Future<void> resetAuth() async {
	try {
		await pb.collection('users').authRefresh();
	} on ClientException catch (e) {
		if (!e.toString().contains("refused the network connection")) {
			rethrow;
		}
	}
}

ResultSet selectBuilder(String tableName, {String? columns, (String, List<Object?>)? filter, int? maxItems}) {
	
	final StringBuffer query = StringBuffer("SELECT ${columns ?? "*"} FROM $tableName");
	
	if (filter != null) {
		query.write(" WHERE ${filter.$1}");
	}

	if (maxItems != null) {
		query.write(" LIMIT $maxItems");
	}

	query.write(";");

	if (filter != null) {
		return db.select(query.toString(), filter.$2);
	} else {
		return db.select(query.toString());
	}
}
