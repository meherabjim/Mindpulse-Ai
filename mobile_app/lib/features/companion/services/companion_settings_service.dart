// HUMAN_COMPANION_SETTINGS_V1

import 'package:shared_preferences/shared_preferences.dart';

class CompanionPermissions {
  const CompanionPermissions({
    this.phoneUsage = false,
    this.movement = false,
    this.checkin = true,
    this.recovery = true,
    this.aiPersonalization = false,
    this.supportiveReminders = false,
  });

  final bool phoneUsage;
  final bool movement;
  final bool checkin;
  final bool recovery;
  final bool aiPersonalization;
  final bool supportiveReminders;

  CompanionPermissions copyWith({
    bool? phoneUsage,
    bool? movement,
    bool? checkin,
    bool? recovery,
    bool? aiPersonalization,
    bool? supportiveReminders,
  }) {
    return CompanionPermissions(
      phoneUsage: phoneUsage ?? this.phoneUsage,

      movement: movement ?? this.movement,

      checkin: checkin ?? this.checkin,

      recovery: recovery ?? this.recovery,

      aiPersonalization: aiPersonalization ?? this.aiPersonalization,

      supportiveReminders: supportiveReminders ?? this.supportiveReminders,
    );
  }
}

class CompanionSettingsService {
  static const String _phoneUsageKey = 'companion_allow_phone_usage';

  static const String _movementKey = 'companion_allow_movement';

  static const String _checkinKey = 'companion_allow_checkin';

  static const String _recoveryKey = 'companion_allow_recovery';

  static const String _aiKey = 'companion_allow_ai_personalization';

  static const String _remindersKey = 'companion_allow_supportive_reminders';

  Future<CompanionPermissions> load() async {
    final preferences = await SharedPreferences.getInstance();

    return CompanionPermissions(
      phoneUsage: preferences.getBool(_phoneUsageKey) ?? false,

      movement: preferences.getBool(_movementKey) ?? false,

      checkin: preferences.getBool(_checkinKey) ?? true,

      recovery: preferences.getBool(_recoveryKey) ?? true,

      aiPersonalization: preferences.getBool(_aiKey) ?? false,

      supportiveReminders: preferences.getBool(_remindersKey) ?? false,
    );
  }

  Future<void> save(CompanionPermissions value) async {
    final preferences = await SharedPreferences.getInstance();

    await Future.wait<bool>(<Future<bool>>[
      preferences.setBool(_phoneUsageKey, value.phoneUsage),
      preferences.setBool(_movementKey, value.movement),
      preferences.setBool(_checkinKey, value.checkin),
      preferences.setBool(_recoveryKey, value.recovery),
      preferences.setBool(_aiKey, value.aiPersonalization),
      preferences.setBool(_remindersKey, value.supportiveReminders),
    ]);
  }
}
