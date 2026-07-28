import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindpulse_ai/core/settings/app_preferences_controller.dart';
import 'package:mindpulse_ai/features/religion/services/manual_faith_reminder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('language and theme preferences persist locally', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final controller = AppPreferencesController.instance;
    await controller.load();
    await controller.apply(languageCode: 'bn', themeMode: 'dark');

    expect(controller.languageCode, 'bn');
    expect(controller.isBangla, isTrue);
    expect(controller.themeModeCode, 'dark');
    expect(controller.themeMode, ThemeMode.dark);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('mindpulse_language_code'), 'bn');
    expect(preferences.getString('mindpulse_theme_mode'), 'dark');
  });

  test('manual faith reminder keeps title, time, days and alarm state', () {
    const reminder = ManualFaithReminder(
      id: 'onboarding_manual_v1',
      title: 'Evening prayer',
      hour: 19,
      minute: 15,
      weekdays: <int>[1, 3, 5],
      enabled: true,
    );

    final restored = ManualFaithReminder.fromJson(reminder.toJson());

    expect(restored.id, reminder.id);
    expect(restored.title, reminder.title);
    expect(restored.hour, 19);
    expect(restored.minute, 15);
    expect(restored.weekdays, <int>[1, 3, 5]);
    expect(restored.enabled, isTrue);
  });
  test('Bangla and theme choices update independently', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final controller = AppPreferencesController.instance;
    await controller.load();

    await controller.apply(languageCode: 'bn', themeMode: 'light');
    expect(controller.isBangla, isTrue);
    expect(controller.themeMode, ThemeMode.light);

    await controller.apply(themeMode: 'dark');
    expect(controller.isBangla, isTrue);
    expect(controller.themeMode, ThemeMode.dark);

    await controller.apply(languageCode: 'en');
    expect(controller.isBangla, isFalse);
    expect(controller.themeMode, ThemeMode.dark);
  });
}
