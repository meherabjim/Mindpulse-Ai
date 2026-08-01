import 'package:flutter_test/flutter_test.dart';
import 'package:mindpulse_ai/features/prayer/services/prayer_service.dart';

void main() {
  group('prayer reminder rules', () {
    test('keeps the requested Dhuhr and Friday reminder defaults', () {
      expect(PrayerService.defaultReminderTimes['dhuhr'], '13:05');
      expect(PrayerService.defaultReminderTimes['jummah'], '12:35');
    });

    test('uses ten minutes for automatic reminder preparation', () {
      expect(PrayerService.automaticLeadMinutes, 10);
    });

    test('rejects invalid clock values before scheduling', () {
      expect(() => PrayerTimeParser.parse('24:00'), throwsFormatException);
      expect(() => PrayerTimeParser.parse('12:60'), throwsFormatException);
    });

    test('uses only the approved Bengali prayer message', () {
      expect(
        PrayerService.banglaReminderMessage,
        'নামাজের সময় হয়ে যাচ্ছে। আপনারা নামাজের প্রস্তুতি নিন।',
      );
      expect(
        PrayerService.banglaReminderMessage,
        isNot(contains('নামাজেই আসল সুখ')),
      );
      expect(
        PrayerService.banglaReminderMessage.toLowerCase(),
        isNot(contains('jamaat')),
      );
    });
  });
}
