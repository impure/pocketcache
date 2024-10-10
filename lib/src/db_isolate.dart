
import 'dart:async';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:sqlite3/common.dart';

import 'make_db.dart' if (dart.library.io) 'make_db_io.dart' if (dart.library.html) 'make_db_web.dart';

class DbIsolate {

	factory DbIsolate(String? path) {
		// ignore: discarded_futures
		return DbIsolate._(_generateIsolate(path));
	}

	factory DbIsolate.test() {
		return DbIsolate._(Future<SendPort?>.value(null));
	}

	DbIsolate._(this.makePort);

	Future<SendPort?> makePort;

	Future<void> execute(String command, List<dynamic> parameters) async {

		final SendPort? port = await makePort;

		final Completer<void> completer = Completer<void>();
    final ReceivePort responsePort = ReceivePort();

		// A null port indicates we could not open the database for whatever reason
		if (port != null) {
			port.send((command, parameters, responsePort.sendPort));
		} else {
			debugPrint("Failed to send to db");
		}

    responsePort.listen((dynamic result) {

			if (result == null) {
			} else if (result is String) {
				debugPrint("DB Isolate: $result");
			} else if (result is Exception) {
				throw result;
			} else {
				debugPrint("Unknown result: $result");
			}

      completer.complete();
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

  await for (final dynamic message in receivePort) {
    try {
      db.execute(message.$1, message.$2);
      message.$3.send(null);
    } catch (e) {
      message.$3.send(e);
    }
  }
}
