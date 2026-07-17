// HUMAN_COMPANION_POLICY_ENGINE_V1

import '../models/daily_companion_context.dart';

class CompanionPolicyEngine {
  const CompanionPolicyEngine();

  CompanionSuggestion evaluate(
    DailyCompanionContext context, {
    Set<String> suppressedSuggestionIds = const <String>{},
  }) {
    final candidates = <CompanionSuggestion>[
      if (context.hasFlag('poor_sleep_pattern') &&
          context.hasFlag('high_late_night_usage'))
        const CompanionSuggestion(
          id: 'sleep_wind_down',
          category: 'sleep',
          priority: CompanionSuggestionPriority.timely,
          messageKey: 'sleep_wind_down',
          message:
              'Your recent pattern suggests late-night '
              'phone use alongside limited sleep. A '
              'gentle next step could be putting the '
              'phone aside for 10 minutes and letting '
              'your body slow down.',
          rationale:
              'Late-night usage and limited sleep '
              'were both present in approved context.',
          requiresUserAction: false,
        ),
      if (context.hasFlag('high_stress_low_energy'))
        const CompanionSuggestion(
          id: 'one_minute_reset',
          category: 'recovery',
          priority: CompanionSuggestionPriority.timely,
          messageKey: 'one_minute_reset',
          message:
              'Today looks heavy, and your energy '
              'seems limited. You do not need to solve '
              'everything now. Try one slow breath, a '
              'sip of water, or a one-minute pause.',
          rationale:
              'High stress and low energy were present '
              'in the approved daily check-in.',
          requiresUserAction: false,
        ),
      if (context.hasFlag('extended_phone_session') &&
          context.hasFlag('movement_below_personal_baseline'))
        const CompanionSuggestion(
          id: 'screen_and_movement_break',
          category: 'movement',
          priority: CompanionSuggestionPriority.timely,
          messageKey: 'screen_and_movement_break',
          message:
              'You have had a long stretch of phone '
              'use, while movement appears lower than '
              'your own usual pattern. A one- or '
              'two-minute walk could be enough.',
          rationale:
              'Extended phone use and movement below '
              'the personal baseline were both present.',
          requiresUserAction: false,
        ),
      if (context.hasFlag('extended_phone_session'))
        const CompanionSuggestion(
          id: 'screen_pause',
          category: 'screen_time',
          priority: CompanionSuggestionPriority.gentle,
          messageKey: 'screen_pause',
          message:
              'You have had a long stretch of phone '
              'use. A short eye and posture break may '
              'help: stand up, look away from the '
              'screen, and move for a minute.',
          rationale:
              'A long phone-use session was present '
              'in the local daily aggregate.',
          requiresUserAction: false,
        ),
      if (context.hasFlag('movement_below_personal_baseline'))
        const CompanionSuggestion(
          id: 'gentle_movement',
          category: 'movement',
          priority: CompanionSuggestionPriority.gentle,
          messageKey: 'gentle_movement',
          message:
              'Movement appears below your own usual '
              'pattern. A small walk is enough; there '
              'is no need to chase a perfect goal.',
          rationale:
              'Movement was below the available '
              'personal baseline.',
          requiresUserAction: false,
        ),
      if (context.hasFlag('recovery_completed'))
        const CompanionSuggestion(
          id: 'recovery_acknowledgement',
          category: 'encouragement',
          priority: CompanionSuggestionPriority.gentle,
          messageKey: 'recovery_acknowledgement',
          message:
              'You completed a recovery activity '
              'today. That counts. Notice what helped, '
              'even if the change felt small.',
          rationale:
              'A completed recovery activity was '
              'present in approved context.',
          requiresUserAction: false,
        ),
      if (context.hasFlag('insufficient_data'))
        const CompanionSuggestion(
          id: 'context_invitation',
          category: 'checkin',
          priority: CompanionSuggestionPriority.gentle,
          messageKey: 'context_invitation',
          message:
              'MindPulse does not have enough approved '
              'context yet. A quick check-in can help '
              'it support you without guessing.',
          rationale: 'No approved daily signal was available.',
          requiresUserAction: false,
        ),
      const CompanionSuggestion(
        id: 'balanced_context',
        category: 'general',
        priority: CompanionSuggestionPriority.gentle,
        messageKey: 'balanced_context',
        message:
            'Your available signals do not show a '
            'strong need for interruption right now. '
            'Keep checking in with yourself, and take '
            'a small break when it feels useful.',
        rationale:
            'No higher-priority deterministic '
            'companion rule was activated.',
        requiresUserAction: false,
      ),
    ];

    for (final candidate in candidates) {
      if (!suppressedSuggestionIds.contains(candidate.id)) {
        return candidate;
      }
    }

    return CompanionSuggestion.none();
  }
}
