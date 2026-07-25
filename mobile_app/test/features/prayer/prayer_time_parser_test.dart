import 'package:flutter_test/flutter_test.dart';
import 'package:mindpulse_ai/features/prayer/services/prayer_service.dart';

void main() {
  test('prayer parser ignores API timezone suffix', () {
    final parsed = PrayerTimeParser.parse('04:17 (+06)');
    expect(parsed.hour, 4);
    expect(parsed.minute, 17);
  });

  test('prayer parser accepts two digit hour', () {
    final parsed = PrayerTimeParser.parse('18:42');
    expect(parsed.hour, 18);
    expect(parsed.minute, 42);
  });
}
