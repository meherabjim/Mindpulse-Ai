// HUMAN_COMPANION_CONTEXT_MODEL_V1

enum CompanionSuggestionPriority { none, gentle, timely }

class CompanionSuggestion {
  const CompanionSuggestion({
    required this.id,
    required this.category,
    required this.priority,
    required this.messageKey,
    required this.message,
    required this.rationale,
    required this.requiresUserAction,
  });

  factory CompanionSuggestion.none() {
    return const CompanionSuggestion(
      id: 'none',
      category: 'none',
      priority: CompanionSuggestionPriority.none,
      messageKey: 'none',
      message: '',
      rationale: '',
      requiresUserAction: false,
    );
  }

  final String id;
  final String category;
  final CompanionSuggestionPriority priority;
  final String messageKey;
  final String message;
  final String rationale;
  final bool requiresUserAction;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'category': category,
      'priority': priority.name,
      'message_key': messageKey,
      'message': message,
      'rationale': rationale,
      'requires_user_action': requiresUserAction,
    };
  }
}

class DailyCompanionContext {
  const DailyCompanionContext({
    required this.schemaVersion,
    required this.generatedAt,
    required this.localDate,
    required this.permissions,
    required this.phoneUsage,
    required this.movement,
    required this.checkin,
    required this.recovery,
    required this.contextFlags,
    this.suggestion,
  });

  final String schemaVersion;
  final DateTime generatedAt;
  final String localDate;

  final Map<String, bool> permissions;

  final Map<String, dynamic> phoneUsage;
  final Map<String, dynamic> movement;
  final Map<String, dynamic> checkin;
  final Map<String, dynamic> recovery;

  final List<String> contextFlags;

  final CompanionSuggestion? suggestion;

  bool hasFlag(String flag) {
    return contextFlags.contains(flag);
  }

  DailyCompanionContext copyWith({CompanionSuggestion? suggestion}) {
    return DailyCompanionContext(
      schemaVersion: schemaVersion,
      generatedAt: generatedAt,
      localDate: localDate,
      permissions: permissions,
      phoneUsage: phoneUsage,
      movement: movement,
      checkin: checkin,
      recovery: recovery,
      contextFlags: contextFlags,
      suggestion: suggestion ?? this.suggestion,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schema_version': schemaVersion,
      'generated_at': generatedAt.toUtc().toIso8601String(),
      'local_date': localDate,
      'permissions': Map<String, bool>.from(permissions),
      'phone_usage': Map<String, dynamic>.from(phoneUsage),
      'movement': Map<String, dynamic>.from(movement),
      'checkin': Map<String, dynamic>.from(checkin),
      'recovery': Map<String, dynamic>.from(recovery),
      'context_flags': List<String>.from(contextFlags),
      'suggestion': suggestion?.toMap(),
    };
  }
}
