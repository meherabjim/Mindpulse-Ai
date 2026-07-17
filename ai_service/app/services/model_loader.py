from __future__ import annotations

import json
import threading
from pathlib import Path
from typing import Any

import joblib
import pandas as pd


class ModelLoadError(RuntimeError):
    """Raised when trained model artifacts cannot be loaded."""


class ModelRegistry:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._loaded = False
        self._models: dict[str, dict[str, Any]] = {}
        self._metadata: dict[str, Any] = {}

        self._model_dir = (
            Path(__file__).resolve().parents[2]
            / "models"
        )

    def load(self) -> None:
        if self._loaded:
            return

        with self._lock:
            if self._loaded:
                return

            metadata_path = (
                self._model_dir
                / "model_metadata.json"
            )

            if not metadata_path.exists():
                raise ModelLoadError(
                    "Model metadata file was not found."
                )

            try:
                with metadata_path.open(
                    "r",
                    encoding="utf-8",
                ) as file:
                    metadata = json.load(file)
            except Exception as error:
                raise ModelLoadError(
                    "Model metadata could not be read."
                ) from error

            loaded_models: dict[
                str,
                dict[str, Any],
            ] = {}

            for task in (
                "burnout",
                "stress",
                "mood",
            ):
                model_path = (
                    self._model_dir
                    / f"{task}_model.joblib"
                )

                if not model_path.exists():
                    raise ModelLoadError(
                        f"{task} model file was not found."
                    )

                try:
                    payload = joblib.load(
                        model_path
                    )
                except Exception as error:
                    raise ModelLoadError(
                        f"{task} model could not be loaded."
                    ) from error

                if not isinstance(payload, dict):
                    raise ModelLoadError(
                        f"{task} model payload is invalid."
                    )

                if (
                    "model" not in payload
                    or "features" not in payload
                ):
                    raise ModelLoadError(
                        f"{task} model metadata is incomplete."
                    )

                loaded_models[task] = payload

            self._metadata = metadata
            self._models = loaded_models
            self._loaded = True

    def status(self) -> dict[str, Any]:
        try:
            self.load()
        except ModelLoadError as error:
            return {
                "available": False,
                "production_ready": False,
                "training_data_type": None,
                "warning": str(error),
                "models": [],
            }

        model_information = []

        for task, payload in self._models.items():
            model_information.append(
                {
                    "task": task,
                    "model_version": payload.get(
                        "model_version",
                        "unknown",
                    ),
                    "training_data_type": payload.get(
                        "training_data_type",
                        "unknown",
                    ),
                    "production_ready": bool(
                        payload.get(
                            "production_ready",
                            False,
                        )
                    ),
                    "feature_count": len(
                        payload.get(
                            "features",
                            [],
                        )
                    ),
                    "labels": [
                        str(label)
                        for label in payload.get(
                            "labels",
                            [],
                        )
                    ],
                }
            )

        return {
            "available": True,
            "production_ready": bool(
                self._metadata.get(
                    "production_ready",
                    False,
                )
            ),
            "training_data_type": (
                self._metadata.get(
                    "training_data_type",
                    "unknown",
                )
            ),
            "warning": self._metadata.get(
                "important_warning",
                (
                    "This model is an experimental "
                    "wellness-support model."
                ),
            ),
            "generated_at": self._metadata.get(
                "generated_at"
            ),
            "models": model_information,
        }

    def predict(
        self,
        task: str,
        feature_values: dict[str, Any],
    ) -> dict[str, Any]:
        self.load()

        if task not in self._models:
            raise ModelLoadError(
                f"Unknown prediction task: {task}"
            )

        payload = self._models[task]

        feature_names = list(
            payload["features"]
        )

        missing_features = [
            feature
            for feature in feature_names
            if feature not in feature_values
        ]

        if missing_features:
            raise ModelLoadError(
                "Required model features are missing: "
                + ", ".join(missing_features)
            )

        ordered_values = {
            feature: feature_values[feature]
            for feature in feature_names
        }

        dataframe = pd.DataFrame(
            [ordered_values],
            columns=feature_names,
        )

        model = payload["model"]

        prediction = str(
            model.predict(dataframe)[0]
        )

        probabilities: dict[str, float] = {}

        if hasattr(model, "predict_proba"):
            probability_values = (
                model.predict_proba(
                    dataframe
                )[0]
            )

            probabilities = {
                str(label): round(
                    float(probability),
                    4,
                )
                for label, probability in zip(
                    model.classes_,
                    probability_values,
                )
            }

        confidence = (
            max(probabilities.values())
            if probabilities
            else 1.0
        )

        return {
            "label": prediction,
            "confidence": round(
                float(confidence),
                4,
            ),
            "probabilities": probabilities,
            "model_version": payload.get(
                "model_version",
                "unknown",
            ),
            "training_data_type": payload.get(
                "training_data_type",
                "unknown",
            ),
            "production_ready": bool(
                payload.get(
                    "production_ready",
                    False,
                )
            ),
        }


model_registry = ModelRegistry()
