
import 'package:pocketbase_offline_cache/src/get_records.dart';
import 'package:test/test.dart';

void main() {
	test("makePbFilter", () {
		expect(makePbFilter(("feed_url = ? && id_from_feed = ?", <Object>[ "https://www.reddit.com/r/rss/.rss?rdt=123", "t3_1cue8dv" ])), "feed_url = 'https://www.reddit.com/r/rss/.rss?rdt=123' && id_from_feed = 't3_1cue8dv'");
		expect(makePbFilter(("id = 123", <Object>[ ])), "id = 123");
		expect(makePbFilter(("id = ?", <Object>[ " 1 2 3 " ])), "id = ' 1 2 3 '");
	});
}
