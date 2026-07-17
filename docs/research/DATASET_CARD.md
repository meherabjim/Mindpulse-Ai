# MindPulse AI Synthetic Demo Dataset Card

## Dataset Summary

| Property | Value |
|---|---|
| Dataset | demo_training_data.csv |
| Repository path | ai_service/data/processed/demo_training_data.csv |
| Format | CSV |
| Records | 5000 |
| Columns | 18 |
| File size | 329028 bytes |
| Dataset type | Synthetic demonstration data |
| Production ready | No |
| Clinical dataset | No |
| Missing cells | 0 |

## Purpose

This dataset supports software demonstrations, experimental model training, pipeline testing, and reproducible engineering examples for MindPulse AI.

It must not be interpreted as evidence that MindPulse can diagnose, predict, prevent, or treat a medical or psychological condition.

## Data Origin and Provenance

- Maintained as project-generated synthetic demo data.
- Not collected through the production MindPulse application.
- Not presented as representative of any real population.
- Generation assumptions require further research documentation.

## Privacy Audit

| Check | Detected |
|---|---:|
| Email-like values | 0 |
| Bangladesh phone-like values | 0 |
| Windows user-directory paths | 0 |

This pattern scan reduces obvious publication risk but is not a formal privacy certification.

## Target Distributions

### Internal wellness-strain target: burnout_risk

| Value | Count | Percentage |
|---|---:|---:|
| elevated | 235 | 4.70% |
| low | 256 | 5.12% |
| mild | 1927 | 38.54% |
| moderate | 2582 | 51.64% |

### Stress target: stress_class

| Value | Count | Percentage |
|---|---:|---:|
| high | 622 | 12.44% |
| low | 803 | 16.06% |
| mild | 1911 | 38.22% |
| moderate | 1664 | 33.28% |

### Mood-wellbeing target: mood_class

| Value | Count | Percentage |
|---|---:|---:|
| good | 923 | 18.46% |
| low | 1396 | 27.92% |
| neutral | 2681 | 53.62% |

## Appropriate Uses

- Data-loading and preprocessing demonstrations
- Experimental model-training tests
- Non-clinical algorithm comparisons
- Portfolio and engineering demonstrations
- Calibration, fairness, and evaluation-tool testing

## Inappropriate Uses

- Clinical decision-making
- Medical or psychological diagnosis
- Real-world personal risk scoring
- Emergency-response decisions
- Employment, insurance, or eligibility decisions
- Claims about population health or clinical effectiveness

## Known Limitations

- Synthetic relationships may be unrealistic.
- Target-class imbalance may affect minority performance.
- No external validation has been completed.
- No participant-level fairness evidence exists.
- No clinical calibration evidence exists.
- No real-world deployment evidence exists.
- Synthetic benchmarks are not clinical evidence.

## Licensing and Reuse

No separate open-data license is granted. The repository copyright notice applies.

## Version

- Documentation version: 1.0
- Dataset SHA-256: 2B997261F3B01211C706B55AD0E5FA4CB53D690D47B1C262240B52B809DC9E26
- Records documented: 5000
- Columns documented: 18
