// HUMAN_COMPANION_CONTEXT_SERVICE_V1

import '../models/daily_companion_context.dart';
import 'companion_context_builder.dart';
import 'companion_policy_engine.dart';
import 'companion_settings_service.dart';

class CompanionContextService {
  const CompanionContextService({
    CompanionContextBuilder builder = const CompanionContextBuilder(),
    CompanionPolicyEngine policyEngine = const CompanionPolicyEngine(),
  }) : this._(builder, policyEngine);

  const CompanionContextService._(this._builder, this._policyEngine);

  final CompanionContextBuilder _builder;
  final CompanionPolicyEngine _policyEngine;

  DailyCompanionContext create({
    required CompanionPermissions permissions,
    Map<String, dynamic>? phoneUsage,
    Map<String, dynamic>? movement,
    Map<String, dynamic>? checkin,
    Map<String, dynamic>? recovery,
    Set<String> suppressedSuggestionIds = const <String>{},
    DateTime? now,
  }) {
    final context = _builder.build(
      permissions: permissions,
      phoneUsage: phoneUsage,
      movement: movement,
      checkin: checkin,
      recovery: recovery,
      now: now,
    );

    final suggestion = _policyEngine.evaluate(
      context,
      suppressedSuggestionIds: suppressedSuggestionIds,
    );

    return context.copyWith(suggestion: suggestion);
  }
}
