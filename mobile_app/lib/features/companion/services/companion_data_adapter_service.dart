// HUMAN_COMPANION_DATA_ADAPTER_V1

import '../../checkin/services/daily_checkin_service.dart';
import '../../digital_wellbeing/services/screen_time_insight_service.dart';
import '../../recovery/services/recovery_service.dart';
import '../models/daily_companion_context.dart';
import 'companion_context_service.dart';
import 'companion_feedback_service.dart';
import 'companion_settings_service.dart';
import 'movement_insight_service.dart';

class CompanionDataAdapterService {
  CompanionDataAdapterService({
    CompanionSettingsService? settingsService,
    ScreenTimeInsightService? screenTimeService,
    MovementInsightService? movementService,
    DailyCheckinService? checkinService,
    RecoveryService? recoveryService,
    CompanionFeedbackService? feedbackService,
    this._contextService = const CompanionContextService(),
  }) : _settingsService = settingsService ?? CompanionSettingsService(),
       _screenTimeService = screenTimeService ?? ScreenTimeInsightService(),
       _movementService = movementService ?? MovementInsightService(),
       _checkinService = checkinService ?? DailyCheckinService(),
       _recoveryService = recoveryService ?? RecoveryService(),
       _feedbackService = feedbackService ?? CompanionFeedbackService();

  final CompanionSettingsService _settingsService;
  final ScreenTimeInsightService _screenTimeService;
  final MovementInsightService _movementService;
  final DailyCheckinService _checkinService;
  final RecoveryService _recoveryService;
  final CompanionFeedbackService _feedbackService;
  final CompanionContextService _contextService;

  Future<DailyCompanionContext> loadContext({DateTime? now}) async {
    final generatedAt = now ?? DateTime.now();

    final permissions = await _settingsService.load();

    Map<String, dynamic>? phoneUsage;
    Map<String, dynamic>? movement;
    Map<String, dynamic>? checkin;
    Map<String, dynamic>? recovery;

    if (permissions.phoneUsage) {
      phoneUsage = await _loadPhoneUsage();
    }

    if (permissions.movement) {
      movement = await _loadMovement();
    }

    if (permissions.checkin) {
      checkin = await _loadCheckin();
    }

    if (permissions.recovery) {
      recovery = await _loadRecovery(now: generatedAt);
    }

    final suppressed = await _feedbackService.suppressedSuggestionIds(
      date: generatedAt,
    );

    return _contextService.create(
      permissions: permissions,
      phoneUsage: phoneUsage,
      movement: movement,
      checkin: checkin,
      recovery: recovery,
      suppressedSuggestionIds: suppressed,
      now: generatedAt,
    );
  }

  Future<Map<String, dynamic>> _loadPhoneUsage() async {
    try {
      final hasAccess = await _screenTimeService.hasUsageAccess();

      if (!hasAccess) {
        return const <String, dynamic>{
          'available': false,
          'reason': 'android_usage_access_not_granted',
        };
      }

      final source = await _screenTimeService.getInsights();

      return flattenPhoneUsage(source);
    } catch (_) {
      return const <String, dynamic>{
        'available': false,
        'reason': 'phone_usage_unavailable',
      };
    }
  }

  Future<Map<String, dynamic>> _loadMovement() async {
    try {
      final hasPermission = await _movementService.hasPermission();

      if (!hasPermission) {
        return const <String, dynamic>{
          'available': false,
          'reason': 'physical_activity_permission_not_granted',
        };
      }

      final source = await _movementService.getInsights();

      return safeMap(source);
    } catch (_) {
      return const <String, dynamic>{
        'available': false,
        'reason': 'movement_unavailable',
      };
    }
  }

  Future<Map<String, dynamic>> _loadCheckin() async {
    try {
      final payload = await _checkinService.getTodayCheckin();

      return extractTodayCheckin(payload);
    } catch (_) {
      return const <String, dynamic>{
        'available': false,
        'reason': 'checkin_unavailable',
      };
    }
  }

  Future<Map<String, dynamic>> _loadRecovery({required DateTime now}) async {
    try {
      final logs = await _recoveryService.listActivityLogs(page: 1, limit: 50);

      return summarizeRecoveryLogs(logs, now: now);
    } catch (_) {
      return const <String, dynamic>{
        'available': false,
        'reason': 'recovery_unavailable',
      };
    }
  }

  static Map<String, dynamic> flattenPhoneUsage(Map<String, dynamic> source) {
    final today = safeMap(source['today']);

    final hasAccess = source['has_usage_access'] == true || today.isNotEmpty;

    if (!hasAccess) {
      return const <String, dynamic>{
        'available': false,
        'reason': 'android_usage_access_not_granted',
      };
    }

    final difference = numberValue(source['difference_from_average_minutes']);

    String comparison = 'unknown';

    if (difference != null) {
      if (difference > 0) {
        comparison = 'above_personal_baseline';
      } else if (difference < 0) {
        comparison = 'below_personal_baseline';
      } else {
        comparison = 'about_personal_baseline';
      }
    }

    return <String, dynamic>{
      'available': true,
      'total_minutes': numberValue(today['total_minutes']),
      'longest_session_minutes': numberValue(today['longest_session_minutes']),
      'late_night_minutes': numberValue(today['late_night_minutes']),
      'seven_day_average_minutes': numberValue(
        source['seven_day_average_minutes'],
      ),
      'comparison': comparison,
      'privacy_mode': 'local_aggregate_only',
    };
  }

  static Map<String, dynamic> extractTodayCheckin(
    Map<String, dynamic> payload,
  ) {
    final data = safeMap(payload['data']);

    if (data['has_checkin'] != true) {
      return const <String, dynamic>{
        'available': false,
        'reason': 'no_checkin_today',
      };
    }

    final checkin = safeMap(data['checkin']);

    if (checkin.isEmpty) {
      return const <String, dynamic>{
        'available': false,
        'reason': 'no_checkin_today',
      };
    }

    return <String, dynamic>{
      'available': true,
      'mood_score': numberValue(checkin['mood_score']),
      'stress_level': numberValue(checkin['stress_level']),
      'energy_level': numberValue(checkin['energy_level']),
      'sleep_hours': numberValue(checkin['sleep_hours']),
      'sleep_quality': numberValue(checkin['sleep_quality']),
      'focus_level': numberValue(checkin['focus_level']),
      'motivation_level': numberValue(checkin['motivation_level']),
      'work_study_pressure': numberValue(checkin['work_study_pressure']),
      'physical_activity_minutes': numberValue(
        checkin['physical_activity_minutes'],
      ),
      'privacy_mode': 'approved_summary_only',
    };
  }

  static Map<String, dynamic> summarizeRecoveryLogs(
    List<Map<String, dynamic>> logs, {
    DateTime? now,
  }) {
    final date = (now ?? DateTime.now()).toLocal();

    final completedToday = logs.where((log) {
      if (log['status']?.toString().toLowerCase() != 'completed') {
        return false;
      }

      final rawDate =
          log['completed_at'] ?? log['started_at'] ?? log['created_at'];

      final parsed = DateTime.tryParse(rawDate?.toString() ?? '');

      if (parsed == null) {
        return false;
      }

      final local = parsed.toLocal();

      return (local.year == date.year &&
          local.month == date.month &&
          local.day == date.day);
    }).toList();

    var durationSeconds = 0;

    for (final log in completedToday) {
      final value = numberValue(log['duration_seconds']);

      if (value != null && value > 0) {
        durationSeconds += value.round();
      }
    }

    return <String, dynamic>{
      'available': true,
      'completed_activity_count': completedToday.length,
      'completed_minutes': durationSeconds / 60,
      'last_activity_helpful': null,
      'privacy_mode': 'approved_summary_only',
    };
  }

  static Map<String, dynamic> safeMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }

  static num? numberValue(dynamic value) {
    if (value is num) {
      return value;
    }

    if (value is String) {
      return num.tryParse(value.trim());
    }

    return null;
  }
}
