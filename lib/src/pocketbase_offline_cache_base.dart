
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:sqlite3/sqlite3.dart';

late Database db;
late PocketBase pb;
late Logger logger;

bool dbAccessible = true;

Future<void> initPbOffline(PocketBase pbInstance, {Logger? overrideLogger}) async {
	logger = overrideLogger ?? Logger();
	pb = pbInstance;
	db = sqlite3.open(join((await getApplicationDocumentsDirectory()).path, "offline_cache"));
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
