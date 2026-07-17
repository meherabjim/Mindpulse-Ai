import json
from datetime import datetime, timezone
from pathlib import Path

import joblib
import pandas as pd

from sklearn.ensemble import (
    RandomForestClassifier,
)

from sklearn.metrics import (
    accuracy_score,
    confusion_matrix,
    precision_recall_fscore_support,
)

from sklearn.model_selection import (
    StratifiedKFold,
    cross_val_score,
    train_test_split,
)


ROOT_DIR = Path(__file__).resolve().parents[1]

DATA_PATH = (
    ROOT_DIR
    / "data"
    / "processed"
    / "demo_training_data.csv"
)

MODEL_DIR = ROOT_DIR / "models"

RANDOM_SEED = 42


TASKS = {
    "burnout": {
        "target": "burnout_risk",
        "features": [
            "mood_score",
            "stress_level",
            "energy_level",
            "sleep_hours",
            "sleep_quality",
            "focus_level",
            "motivation_level",
            "restlessness_level",
            "work_study_pressure",
            "physical_activity_minutes",
            "hydration_cups",
            "social_withdrawal",
        ],
    },
    "stress": {
        "target": "stress_class",
        "features": [
            "mood_score",
            "energy_level",
            "sleep_hours",
            "sleep_quality",
            "focus_level",
            "motivation_level",
            "restlessness_level",
            "work_study_pressure",
            "physical_activity_minutes",
            "hydration_cups",
            "social_withdrawal",
        ],
    },
    "mood": {
        "target": "mood_class",
        "features": [
            "stress_level",
            "energy_level",
            "sleep_hours",
            "sleep_quality",
            "focus_level",
            "motivation_level",
            "restlessness_level",
            "work_study_pressure",
            "physical_activity_minutes",
            "hydration_cups",
            "social_withdrawal",
        ],
    },
}


def create_model() -> RandomForestClassifier:
    return RandomForestClassifier(
        n_estimators=300,
        max_depth=14,
        min_samples_leaf=3,
        class_weight="balanced",
        random_state=RANDOM_SEED,
        n_jobs=-1,
    )


def train_task(
    dataframe: pd.DataFrame,
    task_name: str,
    task_config: dict[str, object],
) -> dict[str, object]:
    features = list(
        task_config["features"]
    )

    target = str(
        task_config["target"]
    )

    x_data = dataframe[features]
    y_data = dataframe[target]

    (
        x_train,
        x_test,
        y_train,
        y_test,
    ) = train_test_split(
        x_data,
        y_data,
        test_size=0.20,
        random_state=RANDOM_SEED,
        stratify=y_data,
    )

    model = create_model()

    model.fit(
        x_train,
        y_train,
    )

    predictions = model.predict(
        x_test
    )

    (
        precision,
        recall,
        f1_score,
        _,
    ) = precision_recall_fscore_support(
        y_test,
        predictions,
        average="macro",
        zero_division=0,
    )

    labels = sorted(
        y_data.unique().tolist()
    )

    cross_validation = StratifiedKFold(
        n_splits=5,
        shuffle=True,
        random_state=RANDOM_SEED,
    )

    cv_scores = cross_val_score(
        create_model(),
        x_data,
        y_data,
        cv=cross_validation,
        scoring="f1_macro",
        n_jobs=-1,
    )

    model_path = (
        MODEL_DIR
        / f"{task_name}_model.joblib"
    )

    model_payload = {
        "model": model,
        "features": features,
        "labels": labels,
        "task": task_name,
        "model_version": "demo-1.0.0",
        "training_data_type": (
            "synthetic_demo"
        ),
        "production_ready": False,
    }

    joblib.dump(
        model_payload,
        model_path,
    )

    return {
        "task": task_name,
        "model_file": model_path.name,
        "model_type": (
            "RandomForestClassifier"
        ),
        "model_version": "demo-1.0.0",
        "training_rows": int(
            len(dataframe)
        ),
        "train_rows": int(
            len(x_train)
        ),
        "test_rows": int(
            len(x_test)
        ),
        "features": features,
        "labels": labels,
        "metrics": {
            "accuracy": round(
                float(
                    accuracy_score(
                        y_test,
                        predictions,
                    )
                ),
                4,
            ),
            "precision_macro": round(
                float(precision),
                4,
            ),
            "recall_macro": round(
                float(recall),
                4,
            ),
            "f1_macro": round(
                float(f1_score),
                4,
            ),
            "cross_validation_f1_mean": (
                round(
                    float(
                        cv_scores.mean()
                    ),
                    4,
                )
            ),
            "cross_validation_f1_std": (
                round(
                    float(
                        cv_scores.std()
                    ),
                    4,
                )
            ),
            "confusion_matrix": (
                confusion_matrix(
                    y_test,
                    predictions,
                    labels=labels,
                ).tolist()
            ),
        },
    }


def main() -> None:
    if not DATA_PATH.exists():
        raise FileNotFoundError(
            "Demo dataset was not found. "
            "Run generate_demo_dataset.py first."
        )

    MODEL_DIR.mkdir(
        parents=True,
        exist_ok=True,
    )

    dataframe = pd.read_csv(
        DATA_PATH
    )

    results: dict[str, object] = {}

    for task_name, task_config in (
        TASKS.items()
    ):
        print(
            f"\nTraining {task_name} model..."
        )

        result = train_task(
            dataframe,
            task_name,
            task_config,
        )

        results[task_name] = result

        metrics = result["metrics"]

        print(
            "Accuracy:",
            metrics["accuracy"],
        )

        print(
            "Macro F1:",
            metrics["f1_macro"],
        )

        print(
            "Cross-validation F1:",
            metrics[
                "cross_validation_f1_mean"
            ],
        )

    manifest = {
        "generated_at": (
            datetime.now(
                timezone.utc
            ).isoformat()
        ),
        "training_data_type": (
            "synthetic_demo"
        ),
        "production_ready": False,
        "important_warning": (
            "These metrics describe performance "
            "on synthetic demonstration data only. "
            "They are not clinical accuracy and "
            "must not be presented as real-world "
            "medical performance."
        ),
        "models": results,
    }

    manifest_path = (
        MODEL_DIR
        / "model_metadata.json"
    )

    with manifest_path.open(
        "w",
        encoding="utf-8",
    ) as file:
        json.dump(
            manifest,
            file,
            indent=2,
            ensure_ascii=False,
        )

    print(
        f"\nModel metadata saved: "
        f"{manifest_path}"
    )


if __name__ == "__main__":
    main()
