# MindPulse AI Data Dictionary

Dataset: ai_service/data/processed/demo_training_data.csv

All fields contain synthetic demonstration values.

Observed ranges describe this file only and are not clinical thresholds.

| Column | Type | Observed values or range | Description |
|---|---|---|---|
| mood_score | Numeric | 1 to 5; mean 2.99 | Synthetic mood indicator used as an experimental input. |
| stress_level | Numeric | 1 to 5; mean 2.98 | Synthetic self-reported stress intensity. |
| energy_level | Numeric | 1 to 5; mean 2.98 | Synthetic perceived daily energy level. |
| sleep_hours | Numeric | 2.5 to 11; mean 6.75 | Synthetic number of hours slept. |
| sleep_quality | Numeric | 1 to 5; mean 3.03 | Synthetic ordinal sleep-quality estimate. |
| focus_level | Numeric | 1 to 5; mean 3.01 | Synthetic perceived concentration level. |
| motivation_level | Numeric | 1 to 5; mean 2.99 | Synthetic perceived motivation level. |
| restlessness_level | Numeric | 1 to 5; mean 3.05 | Synthetic restlessness intensity. |
| work_study_pressure | Numeric | 1 to 5; mean 2.97 | Synthetic work or study pressure indicator. |
| physical_activity_minutes | Numeric | 0 to 120; mean 60.19 | Synthetic physical-activity duration in minutes. |
| hydration_cups | Numeric | 0 to 12; mean 6.02 | Synthetic estimated hydration amount in cups. |
| social_withdrawal | Numeric | 1 to 5; mean 3 | Synthetic social-withdrawal tendency indicator. |
| burnout_score | Numeric | 0.11 to 92.98; mean 47.22 | Synthetic internal wellness-strain score; not a diagnosis. |
| stress_score | Numeric | 0 to 100; mean 48.32 | Synthetic aggregate stress score. |
| mood_wellbeing_score | Numeric | 0 to 100; mean 49.91 | Synthetic aggregate mood-wellbeing score. |
| burnout_risk | Categorical | elevated, low, mild, moderate | Synthetic categorical wellness-strain target. |
| stress_class | Categorical | high, low, mild, moderate | Synthetic categorical stress target. |
| mood_class | Categorical | good, low, neutral | Synthetic categorical mood-wellbeing target. |

## Interpretation Boundary

Stress, mood, and burnout fields are internal experimental labels.

They do not represent medical diagnoses or validated clinical scales.

User-facing MindPulse wording should prefer wellness strain and wellbeing patterns.
