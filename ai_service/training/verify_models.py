import json
from pathlib import Path

import joblib
import pandas as pd


ROOT_DIR = Path(__file__).resolve().parents[1]
MODEL_DIR = ROOT_DIR / "models"

SAMPLE = {
    "mood_score": 2,
    "stress_level": 4,
    "energy_level": 2,
    "sleep_hours": 5.5,
    "sleep_quality": 2,
    "focus_level": 2,
    "motivation_level": 2,
    "restlessness_level": 4,
    "work_study_pressure": 5,
    "physical_activity_minutes": 10,
    "hydration_cups": 4,
    "social_withdrawal": 3,
}


def main() -> None:
    metadata_path = (
        MODEL_DIR
        / "model_metadata.json"
    )

    if not metadata_path.exists():
        raise FileNotFoundError(
            "Model metadata was not found."
        )

    with metadata_path.open(
        "r",
        encoding="utf-8",
    ) as file:
        metadata = json.load(file)

    print(
        "Training data type:",
        metadata["training_data_type"],
    )

    print(
        "Production ready:",
        metadata["production_ready"],
    )

    for task_name in [
        "burnout",
        "stress",
        "mood",
    ]:
        model_path = (
            MODEL_DIR
            / f"{task_name}_model.joblib"
        )

        payload = joblib.load(
            model_path
        )

        model = payload["model"]
        features = payload["features"]

        sample_frame = pd.DataFrame(
            [
                {
                    feature: SAMPLE[feature]
                    for feature in features
                }
            ]
        )

        prediction = model.predict(
            sample_frame
        )[0]

        probabilities = model.predict_proba(
            sample_frame
        )[0]

        probability_map = {
            str(label): round(
                float(probability),
                4,
            )
            for label, probability in zip(
                model.classes_,
                probabilities,
            )
        }

        print(
            f"\n{task_name.upper()}"
        )

        print(
            "Prediction:",
            prediction,
        )

        print(
            "Probabilities:",
            probability_map,
        )


if __name__ == "__main__":
    main()
