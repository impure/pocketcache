
import 'package:sqlite3/common.dart';
import 'package:sqlite3/sqlite3.dart';

CommonDatabase? makeDb(String? path) => path == null ? null : sqlite3.open(path);
