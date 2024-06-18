
import 'package:pocketbase_offline_cache/src/create_record.dart';
import 'package:test/test.dart';

void main() {
	test("convertDates", () {
		Map<String, dynamic> testMap = <String, dynamic>{ "date" : DateTime.utc(2020) };
		expect(testMap["date"].runtimeType, DateTime);
		convertToPbTypes(testMap);
		expect(testMap["date"].runtimeType, String);
		expect(testMap.toString(), "{date: 2020-01-01 00:00:00.000Z}");
		convertToPbTypes(testMap);
		expect(testMap["date"].runtimeType, String);
		expect(testMap.toString(), "{date: 2020-01-01 00:00:00.000Z}");

		testMap = <String, dynamic>{ "1" : DateTime.utc(2020), "2" : 3, "3" : "abc" };
		convertToPbTypes(testMap);
		expect(testMap["1"].runtimeType, String);
		expect(testMap.toString(), "{1: 2020-01-01 00:00:00.000Z, 2: 3, 3: abc}");
	});
}
