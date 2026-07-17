from pathlib import Path

import numpy as np
import pandas as pd


ROOT_DIR = Path(__file__).resolve().parents[1]
OUTPUT_PATH = (
    ROOT_DIR
    / "data"
    / "processed"
    / "demo_training_data.csv"
)

RANDOM_SEED = 42
TOTAL_ROWS = 5000


def direct_risk(series: pd.Series) -> pd.Series:
    return ((series - 1) / 4) * 100


def inverse_risk(series: pd.Series) -> pd.Series:
    return ((5 - series) / 4) * 100


def classify_burnout(score: float) -> str:
    if score < 25:
        return "low"

    if score < 45:
        return "mild"

    if score < 70:
        return "moderate"

    return "elevated"


def classify_stress(score: float) -> str:
    if score < 30:
        return "low"

    if score < 50:
        return "mild"

    if score < 70:
        return "moderate"

    return "high"


def classify_mood(score: float) -> str:
    if score < 40:
        return "low"

    if score < 65:
        return "neutral"

    return "good"


def build_dataset() -> pd.DataFrame:
    rng = np.random.default_rng(
        RANDOM_SEED
    )

    dataframe = pd.DataFrame(
        {
            "mood_score": rng.integers(
                1,
                6,
                TOTAL_ROWS,
            ),
            "stress_level": rng.integers(
                1,
                6,
                TOTAL_ROWS,
            ),
            "energy_level": rng.integers(
                1,
                6,
                TOTAL_ROWS,
            ),
            "sleep_hours": np.round(
                np.clip(
                    rng.normal(
                        6.8,
                        1.8,
                        TOTAL_ROWS,
                    ),
                    2.5,
                    11,
                ),
                1,
            ),
            "sleep_quality": rng.integers(
                1,
                6,
                TOTAL_ROWS,
            ),
            "focus_level": rng.integers(
                1,
                6,
                TOTAL_ROWS,
            ),
            "motivation_level": rng.integers(
                1,
                6,
                TOTAL_ROWS,
            ),
            "restlessness_level": rng.integers(
                1,
                6,
                TOTAL_ROWS,
            ),
            "work_study_pressure": rng.integers(
                1,
                6,
                TOTAL_ROWS,
            ),
            "physical_activity_minutes": rng.integers(
                0,
                121,
                TOTAL_ROWS,
            ),
            "hydration_cups": rng.integers(
                0,
                13,
                TOTAL_ROWS,
            ),
            "social_withdrawal": rng.integers(
                1,
                6,
                TOTAL_ROWS,
            ),
        }
    )

    sleep_distance = np.abs(
        dataframe["sleep_hours"] - 7.5
    )

    sleep_risk = np.clip(
        sleep_distance / 4.5,
        0,
        1,
    ) * 100

    activity_risk = np.where(
        dataframe[
            "physical_activity_minutes"
        ] >= 30,
        0,
        np.where(
            dataframe[
                "physical_activity_minutes"
            ] >= 10,
            35,
            70,
        ),
    )

    hydration_risk = np.where(
        dataframe["hydration_cups"] >= 7,
        0,
        np.where(
            dataframe["hydration_cups"] >= 4,
            35,
            70,
        ),
    )

    burnout_noise = rng.normal(
        0,
        8,
        TOTAL_ROWS,
    )

    burnout_score = (
        inverse_risk(
            dataframe["mood_score"]
        )
        * 0.12
        + direct_risk(
            dataframe["stress_level"]
        )
        * 0.18
        + inverse_risk(
            dataframe["energy_level"]
        )
        * 0.10
        + sleep_risk
        * 0.10
        + inverse_risk(
            dataframe["sleep_quality"]
        )
        * 0.08
        + inverse_risk(
            dataframe["focus_level"]
        )
        * 0.08
        + inverse_risk(
            dataframe["motivation_level"]
        )
        * 0.08
        + direct_risk(
            dataframe["restlessness_level"]
        )
        * 0.07
        + direct_risk(
            dataframe["work_study_pressure"]
        )
        * 0.10
        + direct_risk(
            dataframe["social_withdrawal"]
        )
        * 0.05
        + activity_risk
        * 0.02
        + hydration_risk
        * 0.02
        + burnout_noise
    )

    dataframe["burnout_score"] = np.round(
        np.clip(
            burnout_score,
            0,
            100,
        ),
        2,
    )

    dataframe["burnout_risk"] = dataframe[
        "burnout_score"
    ].map(classify_burnout)

    stress_noise = rng.normal(
        0,
        9,
        TOTAL_ROWS,
    )

    stress_score = (
        direct_risk(
            dataframe["work_study_pressure"]
        )
        * 0.32
        + direct_risk(
            dataframe["restlessness_level"]
        )
        * 0.22
        + inverse_risk(
            dataframe["sleep_quality"]
        )
        * 0.16
        + inverse_risk(
            dataframe["focus_level"]
        )
        * 0.12
        + direct_risk(
            dataframe["social_withdrawal"]
        )
        * 0.10
        + sleep_risk
        * 0.08
        + stress_noise
    )

    dataframe["stress_score"] = np.round(
        np.clip(
            stress_score,
            0,
            100,
        ),
        2,
    )

    dataframe["stress_class"] = dataframe[
        "stress_score"
    ].map(classify_stress)

    mood_noise = rng.normal(
        0,
        8,
        TOTAL_ROWS,
    )

    mood_wellbeing_score = (
        direct_risk(
            dataframe["energy_level"]
        )
        * 0.25
        + direct_risk(
            dataframe["motivation_level"]
        )
        * 0.22
        + direct_risk(
            dataframe["focus_level"]
        )
        * 0.15
        + direct_risk(
            dataframe["sleep_quality"]
        )
        * 0.16
        + (
            100
            - direct_risk(
                dataframe[
                    "work_study_pressure"
                ]
            )
        )
        * 0.10
        + (
            100
            - direct_risk(
                dataframe[
                    "restlessness_level"
                ]
            )
        )
        * 0.07
        + (
            100
            - direct_risk(
                dataframe[
                    "social_withdrawal"
                ]
            )
        )
        * 0.05
        + mood_noise
    )

    dataframe["mood_wellbeing_score"] = (
        np.round(
            np.clip(
                mood_wellbeing_score,
                0,
                100,
            ),
            2,
        )
    )

    dataframe["mood_class"] = dataframe[
        "mood_wellbeing_score"
    ].map(classify_mood)

    return dataframe


def main() -> None:
    OUTPUT_PATH.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    dataframe = build_dataset()

    dataframe.to_csv(
        OUTPUT_PATH,
        index=False,
    )

    print(
        f"Demo dataset saved: {OUTPUT_PATH}"
    )

    print(
        f"Total rows: {len(dataframe)}"
    )

    print("\nBurnout classes:")
    print(
        dataframe[
            "burnout_risk"
        ].value_counts()
    )

    print("\nStress classes:")
    print(
        dataframe[
            "stress_class"
        ].value_counts()
    )

    print("\nMood classes:")
    print(
        dataframe[
            "mood_class"
        ].value_counts()
    )


if __name__ == "__main__":
    main()
