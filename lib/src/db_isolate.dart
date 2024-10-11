
import 'dart:async';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:sqlite3/common.dart';
import 'package:sqlite3/common.dart' as sql;

import 'make_db.dart' if (dart.library.io) 'make_db_io.dart' if (dart.library.html) 'make_db_web.dart';

class DbIsolate {

	factory DbIsolate(String? path) {
		// ignore: discarded_futures
		return DbIsolate._(_generateIsolate(path));
	}

	factory DbIsolate.test(CommonDatabase? db) {
		return DbIsolate._(Future<SendPort?>.value(null), db);
	}

	DbIsolate._(this.makePort, [this.testDb]);

	CommonDatabase? testDb;
	Future<SendPort?> makePort;

	// Mostly only for tests
	Future<bool> enabled() async {
		if (testDb != null) {
			return true;
		} else {
			return await makePort != null;
		}
	}

	Future<void> execute(String command, [List<dynamic> parameters = const <dynamic>[], StackTrace? debugStack]) async {

		if (testDb != null) {
			testDb!.execute(command, parameters);
			return;
		}

		final SendPort? port = await makePort;

    final ReceivePort responsePort = ReceivePort();

		// A null port indicates we could not open the database for whatever reason
		if (port != null) {
			port.send((command, parameters, responsePort.sendPort, true));
		} else {
			debugPrint("Failed to send to db");
			return;
		}

		final Completer<void> completer = Completer<void>();

    responsePort.listen((dynamic result) {

			if (result == null) {
			} else if (result is String) {
				debugPrint("DB Isolate: $result");
			} else if (result is Exception) {
				if (debugStack != null) {
					debugPrint(debugStack.toString());
				}
				completer.completeError(result);
			} else {
				debugPrint("Unknown result: $result");
			}

      completer.complete();
      responsePort.close();
    });

    return completer.future;
	}

	Future<List<Map<String, dynamic>>> select(String command, [List<dynamic> parameters = const <dynamic>[]]) async {

		if (testDb != null) {
			return testDb!.select(command, parameters);
		}

		final SendPort? port = await makePort;
    final ReceivePort responsePort = ReceivePort();

		// A null port indicates we could not open the database for whatever reason
		if (port != null) {
			port.send((command, parameters, responsePort.sendPort, false));
		} else {
			debugPrint("Failed to send to db");
			return <Map<String, dynamic>>[];
		}

		final Completer<List<Map<String, dynamic>>> completer = Completer<List<Map<String, dynamic>>>();

    responsePort.listen((dynamic result) {

			if (result == null || result is List<Map<String, dynamic>>) {
			} else if (result is String) {
				debugPrint("DB Isolate: $result");
			} else if (result is Exception) {
				completer.complete(<Map<String, dynamic>>[]);
				throw result;
			} else {
				debugPrint("Unknown result: $result");
			}

      completer.complete(result);
      responsePort.close();
    });

    return completer.future;
	}

}

Future<SendPort?> _generateIsolate(String? path) async {
  final ReceivePort receivePort = ReceivePort();
  await Isolate.spawn(_isolateEntry, (receivePort.sendPort, path));
  return await receivePort.first as SendPort?;
}

Future<void> _isolateEntry((SendPort, String? path) data) async {
  final ReceivePort receivePort = ReceivePort();

  final CommonDatabase? db = makeDb(data.$2);

	if (db == null) {
		data.$1.send("no db");
		return;
	} else {
	  data.$1.send(receivePort.sendPort);
	}

	db.execute("""
	CREATE TABLE IF NOT EXISTS _operation_queue (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		operation_type TEXT,
		created INTEGER,
		collection_name TEXT,
		id_to_modify TEXT
	)""");
	db.execute("""
	CREATE TABLE IF NOT EXISTS _operation_queue_params (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		operation_id INTEGER,
		param_key TEXT,
		param_value TEXT,
		FOREIGN KEY(operation_id) REFERENCES operations(id)
	)""");
	db.execute("""
	CREATE TABLE IF NOT EXISTS _last_sync_times (
		table_name TEXT PRIMARY KEY,
		last_update TEXT
	)""");

  await for (final dynamic message in receivePort) {
		if (message.$4) {
			try {
				db.execute(message.$1, message.$2);
				message.$3.send(null);
			} catch (e) {
				message.$3.send(e);
			}
		} else {
			try {
				final ResultSet set = db.select(message.$1, message.$2);
				final List<Map<String, dynamic>> data = <Map<String, dynamic>>[];
				for (final sql.Row row in set) {
					final Map<String, dynamic> rowData = <String, dynamic>{};

					for (final MapEntry<String, dynamic> cell in row.entries) {
						rowData[cell.key] = cell.value;
					}

					data.add(rowData);
				}
				message.$3.send(data);
			} catch (e) {
				message.$3.send(e);
			}
		}
  }
}
