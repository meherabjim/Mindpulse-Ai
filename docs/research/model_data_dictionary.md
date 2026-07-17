# MindPulse AI Model Data Dictionary

Generated: 2026-07-16T17:27:07.580109+00:00

**Dataset status:** Synthetic demonstration data; not real-world or clinical evidence.

| Column | Role | Type | Missing | Unique | Observed min | Observed max | Expected range |
|---|---|---:|---:|---:|---:|---:|---|
| mood_score | Feature | int64 | 0 | 5 | 1.0 | 5.0 | 1 to 5 |
| stress_level | Feature | int64 | 0 | 5 | 1.0 | 5.0 | 1 to 5 |
| energy_level | Feature | int64 | 0 | 5 | 1.0 | 5.0 | 1 to 5 |
| sleep_hours | Feature | float64 | 0 | 86 | 2.5 | 11.0 | 0 to 24 |
| sleep_quality | Feature | int64 | 0 | 5 | 1.0 | 5.0 | 1 to 5 |
| focus_level | Feature | int64 | 0 | 5 | 1.0 | 5.0 | 1 to 5 |
| motivation_level | Feature | int64 | 0 | 5 | 1.0 | 5.0 | 1 to 5 |
| restlessness_level | Feature | int64 | 0 | 5 | 1.0 | 5.0 | 1 to 5 |
| work_study_pressure | Feature | int64 | 0 | 5 | 1.0 | 5.0 | 1 to 5 |
| physical_activity_minutes | Feature | int64 | 0 | 121 | 0.0 | 120.0 | 0 to 1440 |
| hydration_cups | Feature | int64 | 0 | 13 | 0.0 | 12.0 | 0 to 30 |
| social_withdrawal | Feature | int64 | 0 | 5 | 1.0 | 5.0 | 1 to 5 |
| burnout_score | Other/Review | float64 | 0 | 3191 | 0.11 | 92.98 |  |
| burnout_risk | Target | str | 0 | 4 |  |  |  |
| stress_score | Other/Review | float64 | 0 | 3580 | 0.0 | 100.0 |  |
| stress_class | Target | str | 0 | 4 |  |  |  |
| mood_wellbeing_score | Other/Review | float64 | 0 | 3423 | 0.0 | 100.0 |  |
| mood_class | Target | str | 0 | 3 |  |  |  |

## Restrictions

- Do not interpret synthetic labels as diagnoses.
- Do not report synthetic metrics as clinical accuracy.
- Do not use this dataset for production release.
- Do not add personal identifiers to model features.
- Preserve rule-based crisis-safety protection.
