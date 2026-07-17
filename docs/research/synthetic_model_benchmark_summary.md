# MindPulse AI Synthetic Model Benchmark

**Status:** Experimental benchmark on synthetic demonstration data.

| Task | Selected model | Raw macro-F1 | Calibrated macro-F1 | Raw ECE | Calibrated ECE |
|---|---|---:|---:|---:|---:|
| burnout | hist_gradient_boosting | 0.485203 | 0.371943 | 0.090305 | 0.051805 |
| stress | random_forest | 0.623142 | 0.621522 | 0.085078 | 0.042763 |
| mood | logistic_regression | 0.740233 | 0.754008 | 0.035414 | 0.107082 |

## Interpretation

- Candidate selection used validation macro-F1.
- The final held-out test set was not used for model selection.
- Probability calibration was evaluated.
- Results are synthetic demonstration metrics, not clinical performance.
- Fairness was not established because subgroup data is unavailable.
- Existing model artifacts were not replaced.

## Release status

**BLOCKED — production_ready remains false.**
