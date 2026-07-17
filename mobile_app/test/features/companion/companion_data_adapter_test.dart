// HUMAN_COMPANION_DATA_ADAPTER_TEST_V1

import 'package:flutter_test/flutter_test.dart';
import 'package:mindpulse_ai/features/companion/services/companion_data_adapter_service.dart';

void main() {
  test('nested phone-use data is flattened safely', () {
    final result = CompanionDataAdapterService.flattenPhoneUsage(
      <String, dynamic>{
        'has_usage_access': true,
        'today': <String, dynamic>{
          'total_minutes': 340,
          'longest_session_minutes': 110,
          'late_night_minutes': 50,
          'private_message': 'must not pass',
        },
        'seven_day_average_minutes': 240,
        'difference_from_average_minutes': 100,
        'history': <dynamic>[
          <String, dynamic>{'package_name': 'private.package'},
        ],
      },
    );

    expect(result['available'], isTrue);

    expect(result['total_minutes'], 340);

    expect(result['comparison'], 'above_personal_baseline');

    expect(result.containsKey('private_message'), isFalse);

    expect(result.containsKey('history'), isFalse);
  });

  test('today check-in excludes note and raw fields', () {
    final result = CompanionDataAdapterService.extractTodayCheckin(
      <String, dynamic>{
        'data': <String, dynamic>{
          'has_checkin': true,
          'checkin': <String, dynamic>{
            'mood_score': 3,
            'stress_level': 4,
            'energy_level': 2,
            'sleep_hours': 5.5,
            'sleep_quality': 2,
            'work_study_pressure': 4,
            'note': 'Private check-in note',
            'user_id': 99,
          },
        },
      },
    );

    expect(result['available'], isTrue);

    expect(result['stress_level'], 4);

    expect(result.containsKey('note'), isFalse);

    expect(result.containsKey('user_id'), isFalse);
  });

  test('missing daily check-in remains unavailable', () {
    final result = CompanionDataAdapterService.extractTodayCheckin(
      <String, dynamic>{
        'data': <String, dynamic>{'has_checkin': false, 'checkin': null},
      },
    );

    expect(result['available'], isFalse);

    expect(result['reason'], 'no_checkin_today');

    expect(result.containsKey('mood_score'), isFalse);
  });

  test('recovery summary includes only completed logs today', () {
    final result = CompanionDataAdapterService.summarizeRecoveryLogs(
      <Map<String, dynamic>>[
        <String, dynamic>{
          'status': 'completed',
          'completed_at': '2026-07-17T09:00:00',
          'duration_seconds': 300,
          'note': 'private note',
          'activity_title': 'Breathing',
        },
        <String, dynamic>{
          'status': 'completed',
          'completed_at': '2026-07-16T09:00:00',
          'duration_seconds': 900,
        },
        <String, dynamic>{
          'status': 'started',
          'started_at': '2026-07-17T10:00:00',
          'duration_seconds': 120,
        },
      ],
      now: DateTime(2026, 7, 17, 12),
    );

    expect(result['available'], isTrue);

    expect(result['completed_activity_count'], 1);

    expect(result['completed_minutes'], 5);

    expect(result.containsKey('note'), isFalse);

    expect(result.containsKey('activity_title'), isFalse);
  });
}
