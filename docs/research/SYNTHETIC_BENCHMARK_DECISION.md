# MindPulse AI — Synthetic Benchmark Decision

Generated: 2026-07-16T17:44:46.989986+00:00

## Final decision

**Existing machine-learning models remain experimental and production_ready=false.**

They may be used only for software integration, demonstration and pipeline testing.

They must not drive diagnosis, emergency decisions, clinical claims or unsupervised high-impact actions.

## Benchmark summary

| Task | Selected model | Raw macro-F1 | Raw balanced accuracy | Raw ECE | Calibrated macro-F1 | Calibrated ECE |
|---|---|---:|---:|---:|---:|---:|
| Wellness strain prototype | hist_gradient_boosting | 0.485203 | 0.453709 | 0.090305 | 0.371943 | 0.051805 |
| Stress prototype | random_forest | 0.623142 | 0.59865 | 0.085078 | 0.621522 | 0.042763 |
| Mood prototype | logistic_regression | 0.740233 | 0.776613 | 0.035414 | 0.754008 | 0.107082 |

## Product rules

- User-facing terminology uses **Wellness Strain**, not a medical burnout diagnosis.
- Internal `burnout_score` API and database field names remain unchanged for compatibility.
- Synthetic prediction outputs must display an experimental and non-diagnostic warning.
- Rule-based crisis protection remains independent of the experimental models.
- Model confidence must not be interpreted as clinical certainty.
- No automatic call, message or emergency action may be triggered by these models.

## Production release remains blocked until

- representative real-world data are available;
- provenance, licence and consent are documented;
- external validation is complete;
- subgroup and fairness evaluation is complete;
- calibration and error analysis are acceptable;
- qualified expert review is completed;
- human oversight and monitoring are operational.
