# MindPulse AI — Human Companion Engine Phase 1 Data Contract

## Product role

MindPulse is an AI-powered digital wellbeing companion. It behaves supportively but never claims to be a human, therapist, doctor or emergency service.

## Core privacy rule

Only permission-approved, privacy-minimized daily aggregates may enter the companion context.

The context must not include:

- private messages;
- typed keyboard content;
- microphone recordings;
- continuous exact location;
- contact lists;
- individual app package histories stored on the server;
- raw journal content unless journal analysis is separately enabled.

## Proposed local context structure

```json
{
  "schema_version": "1.0",
  "generated_at": "ISO-8601 timestamp",
  "local_date": "YYYY-MM-DD",
  "permissions": {
    "phone_usage": false,
    "movement": false,
    "checkin": true,
    "recovery": true,
    "ai_personalization": false,
    "supportive_reminders": false
  },
  "phone_usage": {
    "available": false,
    "total_minutes": null,
    "longest_session_minutes": null,
    "late_night_minutes": null,
    "seven_day_average_minutes": null,
    "comparison": "unknown"
  },
  "movement": {
    "available": false,
    "step_count": null,
    "walking_minutes": null,
    "active_minutes": null,
    "source": "none"
  },
  "checkin": {
    "available": false,
    "mood_score": null,
    "stress_level": null,
    "energy_level": null,
    "sleep_hours": null,
    "sleep_quality": null,
    "work_study_pressure": null
  },
  "recovery": {
    "available": false,
    "completed_activity_count": null,
    "completed_minutes": null,
    "last_activity_helpful": null
  },
  "context_flags": [],
  "suggestion": {
    "id": null,
    "category": null,
    "priority": "none",
    "message_key": null,
    "requires_user_action": false
  }
}
```

## Context flags

Initial deterministic flags may include:

- `extended_phone_session`
- `high_late_night_usage`
- `movement_below_personal_baseline`
- `high_stress_low_energy`
- `poor_sleep_pattern`
- `recovery_completed`
- `insufficient_data`

## Decision-engine rules

1. Safety and emergency logic remains independent.
2. Missing permission must produce `unavailable`, not zero.
3. Personal baseline is preferred over population comparison.
4. No diagnosis may be generated from the context.
5. No automatic call, message or external contact is allowed.
6. Suggestions must be small, optional and non-judgmental.
7. The same suggestion must not be repeated aggressively.
8. Helpful / Not helpful feedback controls future frequency.

## Storage decision

Phase 1 context is generated on-device. Only explicit feedback or an approved privacy-safe summary may be sent to the backend.

## Release restriction

The companion engine remains a wellness-support feature. It must not be marketed as continuous human monitoring, clinical assessment or autonomous care.
