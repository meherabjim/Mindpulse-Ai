// HUMAN_COMPANION_CONTEXT_TEST_V1

import 'package:flutter_test/flutter_test.dart';

import 'package:mindpulse_ai/features/companion/services/companion_context_builder.dart';
import 'package:mindpulse_ai/features/companion/services/companion_context_service.dart';
import 'package:mindpulse_ai/features/companion/services/companion_settings_service.dart';

void main() {
  const builder = CompanionContextBuilder();

  const service = CompanionContextService();

  test('extended phone session creates screen pause', () {
    const permissions = CompanionPermissions(
      phoneUsage: true,
      movement: false,
      checkin: false,
      recovery: false,
    );

    final context = service.create(
      permissions: permissions,
      phoneUsage: <String, dynamic>{
        'available': true,
        'total_minutes': 360,
        'longest_session_minutes': 120,
        'late_night_minutes': 0,
      },
      now: DateTime(2026, 7, 17, 14),
    );

    expect(context.hasFlag('extended_phone_session'), isTrue);

    expect(context.suggestion?.id, 'screen_pause');
  });

  test('high stress and low energy creates reset suggestion', () {
    const permissions = CompanionPermissions(
      phoneUsage: false,
      movement: false,
      checkin: true,
      recovery: false,
    );

    final context = service.create(
      permissions: permissions,
      checkin: <String, dynamic>{
        'available': true,
        'stress_level': 8,
        'energy_level': 3,
        'sleep_hours': 7,
        'sleep_quality': 7,
      },
    );

    expect(context.hasFlag('high_stress_low_energy'), isTrue);

    expect(context.suggestion?.id, 'one_minute_reset');
  });

  test('disabled signal is unavailable instead of zero', () {
    const permissions = CompanionPermissions(
      phoneUsage: false,
      movement: false,
      checkin: false,
      recovery: false,
    );

    final context = builder.build(
      permissions: permissions,
      phoneUsage: <String, dynamic>{'available': true, 'total_minutes': 800},
    );

    expect(context.phoneUsage['available'], isFalse);

    expect(context.phoneUsage['reason'], 'disabled_by_user');

    expect(context.phoneUsage.containsKey('total_minutes'), isFalse);
  });

  test('late-night usage and poor sleep prioritize wind down', () {
    const permissions = CompanionPermissions(
      phoneUsage: true,
      movement: false,
      checkin: true,
      recovery: false,
    );

    final context = service.create(
      permissions: permissions,
      phoneUsage: <String, dynamic>{
        'available': true,
        'total_minutes': 250,
        'longest_session_minutes': 60,
        'late_night_minutes': 70,
      },
      checkin: <String, dynamic>{
        'available': true,
        'stress_level': 5,
        'energy_level': 5,
        'sleep_hours': 5.5,
        'sleep_quality': 4,
      },
    );

    expect(context.hasFlag('high_late_night_usage'), isTrue);

    expect(context.hasFlag('poor_sleep_pattern'), isTrue);

    expect(context.suggestion?.id, 'sleep_wind_down');
  });
}
