
import 'package:pocketbase_offline_cache/src/create_record.dart';
import 'package:test/test.dart';

void main() {
	test("convertDates", () {
		Map<String, dynamic> testMap = <String, dynamic>{ "date" : DateTime(2020) };
		expect(testMap["date"].runtimeType, DateTime);
		convertToPbTypes(testMap);
		expect(testMap["date"].runtimeType, String);
		expect(testMap.toString(), "{date: 2020-01-01 00:00:00.000}");
		convertToPbTypes(testMap);
		expect(testMap["date"].runtimeType, String);
		expect(testMap.toString(), "{date: 2020-01-01 00:00:00.000}");

		testMap = <String, dynamic>{ "1" : DateTime(2020), "2" : 3, "3" : "abc" };
		convertToPbTypes(testMap);
		expect(testMap["1"].runtimeType, String);
		expect(testMap.toString(), "{1: 2020-01-01 00:00:00.000, 2: 3, 3: abc}");
	});
}
