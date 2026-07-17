// HUMAN_COMPANION_CONTEXT_BUILDER_V1

import '../models/daily_companion_context.dart';
import 'companion_settings_service.dart';

class CompanionContextBuilder {
  const CompanionContextBuilder();

  DailyCompanionContext build({
    required CompanionPermissions permissions,
    Map<String, dynamic>? phoneUsage,
    Map<String, dynamic>? movement,
    Map<String, dynamic>? checkin,
    Map<String, dynamic>? recovery,
    DateTime? now,
  }) {
    final generatedAt = now ?? DateTime.now();

    final normalizedPhone = permissions.phoneUsage
        ? _phoneUsage(phoneUsage)
        : _unavailable(reason: 'disabled_by_user');

    final normalizedMovement = permissions.movement
        ? _movement(movement)
        : _unavailable(reason: 'disabled_by_user');

    final normalizedCheckin = permissions.checkin
        ? _checkin(checkin)
        : _unavailable(reason: 'disabled_by_user');

    final normalizedRecovery = permissions.recovery
        ? _recovery(recovery)
        : _unavailable(reason: 'disabled_by_user');

    final flags = _contextFlags(
      phoneUsage: normalizedPhone,
      movement: normalizedMovement,
      checkin: normalizedCheckin,
      recovery: normalizedRecovery,
    );

    return DailyCompanionContext(
      schemaVersion: '1.0',
      generatedAt: generatedAt,
      localDate: _localDate(generatedAt),
      permissions: <String, bool>{
        'phone_usage': permissions.phoneUsage,
        'movement': permissions.movement,
        'checkin': permissions.checkin,
        'recovery': permissions.recovery,
        'ai_personalization': permissions.aiPersonalization,
        'supportive_reminders': permissions.supportiveReminders,
      },
      phoneUsage: normalizedPhone,
      movement: normalizedMovement,
      checkin: normalizedCheckin,
      recovery: normalizedRecovery,
      contextFlags: List<String>.unmodifiable(flags),
    );
  }

  Map<String, dynamic> _phoneUsage(Map<String, dynamic>? source) {
    final available = _isAvailable(
      source,
      meaningfulKeys: const <String>[
        'total_minutes',
        'longest_session_minutes',
        'late_night_minutes',
      ],
    );

    if (!available) {
      return _unavailable(reason: 'no_phone_usage_data');
    }

    return <String, dynamic>{
      'available': true,
      'total_minutes': _number(source, const <String>['total_minutes']),
      'longest_session_minutes': _number(source, const <String>[
        'longest_session_minutes',
      ]),
      'late_night_minutes': _number(source, const <String>[
        'late_night_minutes',
      ]),
      'seven_day_average_minutes': _number(source, const <String>[
        'seven_day_average_minutes',
        'seven_day_average',
      ]),
      'comparison':
          _text(source, const <String>[
            'comparison',
            'compared_with_average',
          ]) ??
          'unknown',
      'privacy_mode': 'local_aggregate_only',
    };
  }

  Map<String, dynamic> _movement(Map<String, dynamic>? source) {
    final available = _isAvailable(
      source,
      meaningfulKeys: const <String>[
        'step_count',
        'walking_minutes',
        'active_minutes',
      ],
    );

    if (!available) {
      return _unavailable(reason: 'no_movement_data');
    }

    return <String, dynamic>{
      'available': true,
      'step_count': _integer(source, const <String>['step_count']),
      'walking_minutes': _number(source, const <String>['walking_minutes']),
      'active_minutes': _number(source, const <String>['active_minutes']),
      'personal_baseline_steps': _number(source, const <String>[
        'personal_baseline_steps',
        'baseline_step_count',
      ]),
      'comparison':
          _text(source, const <String>[
            'comparison',
            'compared_with_average',
          ]) ??
          'unknown',
      'source': _text(source, const <String>['source']) ?? 'unknown',
      'coverage': _text(source, const <String>['coverage']) ?? 'unknown',
      'privacy_mode': 'local_aggregate_only',
    };
  }

  Map<String, dynamic> _checkin(Map<String, dynamic>? source) {
    final available = _isAvailable(
      source,
      meaningfulKeys: const <String>[
        'mood_score',
        'stress_level',
        'energy_level',
        'sleep_hours',
        'sleep_quality',
        'work_study_pressure',
      ],
    );

    if (!available) {
      return _unavailable(reason: 'no_checkin_data');
    }

    return <String, dynamic>{
      'available': true,
      'mood_score': _number(source, const <String>['mood_score', 'mood']),
      'stress_level': _number(source, const <String>['stress_level', 'stress']),
      'energy_level': _number(source, const <String>['energy_level', 'energy']),
      'sleep_hours': _number(source, const <String>['sleep_hours']),
      'sleep_quality': _number(source, const <String>['sleep_quality']),
      'focus_level': _number(source, const <String>['focus_level']),
      'motivation_level': _number(source, const <String>['motivation_level']),
      'work_study_pressure': _number(source, const <String>[
        'work_study_pressure',
      ]),
      'physical_activity_minutes': _number(source, const <String>[
        'physical_activity_minutes',
      ]),
      'privacy_mode': 'approved_summary_only',
    };
  }

  Map<String, dynamic> _recovery(Map<String, dynamic>? source) {
    final available = _isAvailable(
      source,
      meaningfulKeys: const <String>[
        'completed_activity_count',
        'completed_minutes',
        'duration_minutes',
        'completed',
        'helpful',
      ],
    );

    if (!available) {
      return _unavailable(reason: 'no_recovery_data');
    }

    final completed = _boolean(source, const <String>['completed']);

    final activityCount =
        _integer(source, const <String>['completed_activity_count']) ??
        (completed == true ? 1 : 0);

    return <String, dynamic>{
      'available': true,
      'completed_activity_count': activityCount,
      'completed_minutes': _number(source, const <String>[
        'completed_minutes',
        'duration_minutes',
      ]),
      'last_activity_helpful': _boolean(source, const <String>[
        'last_activity_helpful',
        'helpful',
      ]),
      'recovery_score': _number(source, const <String>['recovery_score']),
      'privacy_mode': 'approved_summary_only',
    };
  }

  List<String> _contextFlags({
    required Map<String, dynamic> phoneUsage,
    required Map<String, dynamic> movement,
    required Map<String, dynamic> checkin,
    required Map<String, dynamic> recovery,
  }) {
    final flags = <String>[];

    final availableCount = <Map<String, dynamic>>[
      phoneUsage,
      movement,
      checkin,
      recovery,
    ].where((value) => value['available'] == true).length;

    if (availableCount == 0) {
      flags.add('insufficient_data');
    }

    final totalMinutes = _mapNumber(phoneUsage, 'total_minutes');

    final longestSession = _mapNumber(phoneUsage, 'longest_session_minutes');

    final lateNightMinutes = _mapNumber(phoneUsage, 'late_night_minutes');

    if ((longestSession != null && longestSession >= 90) ||
        (totalMinutes != null && totalMinutes >= 300)) {
      flags.add('extended_phone_session');
    }

    if (lateNightMinutes != null && lateNightMinutes >= 45) {
      flags.add('high_late_night_usage');
    }

    final movementComparison = movement['comparison']?.toString().toLowerCase();

    final stepCount = _mapNumber(movement, 'step_count');

    final baselineSteps = _mapNumber(movement, 'personal_baseline_steps');

    final belowByText =
        movementComparison != null &&
        (movementComparison.contains('below') ||
            movementComparison.contains('lower'));

    final belowByBaseline =
        stepCount != null &&
        baselineSteps != null &&
        baselineSteps > 0 &&
        stepCount < baselineSteps * 0.6;

    if (movement['available'] == true && (belowByText || belowByBaseline)) {
      flags.add('movement_below_personal_baseline');
    }

    final stress = _mapNumber(checkin, 'stress_level');

    final energy = _mapNumber(checkin, 'energy_level');

    if (stress != null && energy != null && _isHigh(stress) && _isLow(energy)) {
      flags.add('high_stress_low_energy');
    }

    final sleepHours = _mapNumber(checkin, 'sleep_hours');

    final sleepQuality = _mapNumber(checkin, 'sleep_quality');

    if ((sleepHours != null && sleepHours < 6) ||
        (sleepQuality != null && _isLow(sleepQuality))) {
      flags.add('poor_sleep_pattern');
    }

    final completedCount = _mapNumber(recovery, 'completed_activity_count');

    if (recovery['available'] == true &&
        completedCount != null &&
        completedCount > 0) {
      flags.add('recovery_completed');
    }

    return flags;
  }

  Map<String, dynamic> _unavailable({required String reason}) {
    return <String, dynamic>{'available': false, 'reason': reason};
  }

  bool _isAvailable(
    Map<String, dynamic>? source, {
    required List<String> meaningfulKeys,
  }) {
    if (source == null || source.isEmpty) {
      return false;
    }

    final explicit = _boolean(source, const <String>['available']);

    if (explicit != null) {
      return explicit;
    }

    return meaningfulKeys.any(
      (key) => source.containsKey(key) && source[key] != null,
    );
  }

  num? _number(Map<String, dynamic>? source, List<String> keys) {
    if (source == null) {
      return null;
    }

    for (final key in keys) {
      final value = source[key];

      if (value is num) {
        return value;
      }

      if (value is String) {
        final parsed = num.tryParse(value.trim());

        if (parsed != null) {
          return parsed;
        }
      }
    }

    return null;
  }

  int? _integer(Map<String, dynamic>? source, List<String> keys) {
    final value = _number(source, keys);

    return value?.round();
  }

  bool? _boolean(Map<String, dynamic>? source, List<String> keys) {
    if (source == null) {
      return null;
    }

    for (final key in keys) {
      final value = source[key];

      if (value is bool) {
        return value;
      }

      if (value is num) {
        return value != 0;
      }

      if (value is String) {
        final normalized = value.trim().toLowerCase();

        if (normalized == 'true' || normalized == 'yes' || normalized == '1') {
          return true;
        }

        if (normalized == 'false' || normalized == 'no' || normalized == '0') {
          return false;
        }
      }
    }

    return null;
  }

  String? _text(Map<String, dynamic>? source, List<String> keys) {
    if (source == null) {
      return null;
    }

    for (final key in keys) {
      final value = source[key];

      if (value == null) {
        continue;
      }

      final text = value.toString().trim();

      if (text.isNotEmpty) {
        return text;
      }
    }

    return null;
  }

  num? _mapNumber(Map<String, dynamic> source, String key) {
    final value = source[key];

    if (value is num) {
      return value;
    }

    if (value is String) {
      return num.tryParse(value.trim());
    }

    return null;
  }

  bool _isHigh(num value) {
    if (value <= 10) {
      return value >= 7;
    }

    return value >= 70;
  }

  bool _isLow(num value) {
    if (value <= 10) {
      return value <= 4;
    }

    return value <= 40;
  }

  String _localDate(DateTime value) {
    final local = value.toLocal();

    final month = local.month.toString().padLeft(2, '0');

    final day = local.day.toString().padLeft(2, '0');

    return '${local.year}-$month-$day';
  }
}
