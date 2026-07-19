from __future__ import annotations

import json
import math
import threading
from pathlib import Path
from typing import Any


class ModelLoadError(RuntimeError):
    """Raised when runtime model artifacts cannot be loaded."""


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

    @staticmethod
    def _finite_number(
        value: Any,
        description: str,
    ) -> float:
        if isinstance(value, bool):
            raise ModelLoadError(
                f"{description} must be numeric."
            )

        try:
            number = float(value)
        except (TypeError, ValueError) as error:
            raise ModelLoadError(
                f"{description} must be numeric."
            ) from error

        if not math.isfinite(number):
            raise ModelLoadError(
                f"{description} must be finite."
            )

        return number

    def _validate_payload(
        self,
        task: str,
        payload: Any,
    ) -> dict[str, Any]:
        if not isinstance(payload, dict):
            raise ModelLoadError(
                f"{task} model payload is invalid."
            )

        if (
            payload.get("schema_version")
            != "mindpulse-portable-logistic-1"
        ):
            raise ModelLoadError(
                f"{task} model schema is unsupported."
            )

        if payload.get("task") != task:
            raise ModelLoadError(
                f"{task} model task metadata is invalid."
            )

        features = payload.get("features")
        labels = payload.get("labels")
        preprocessing = payload.get(
            "preprocessing"
        )
        classifier = payload.get(
            "classifier"
        )

        if (
            not isinstance(features, list)
            or not features
            or len(features) != len(set(features))
            or not all(
                isinstance(item, str)
                and item
                for item in features
            )
        ):
            raise ModelLoadError(
                f"{task} feature schema is invalid."
            )

        if (
            not isinstance(labels, list)
            or len(labels) < 2
            or len(labels) != len(set(labels))
            or not all(
                isinstance(item, str)
                and item
                for item in labels
            )
        ):
            raise ModelLoadError(
                f"{task} label schema is invalid."
            )

        if not isinstance(
            preprocessing,
            dict,
        ):
            raise ModelLoadError(
                f"{task} preprocessing is invalid."
            )

        if not isinstance(
            classifier,
            dict,
        ):
            raise ModelLoadError(
                f"{task} classifier is invalid."
            )

        means = preprocessing.get("mean")
        scales = preprocessing.get("scale")

        coefficients = classifier.get(
            "coefficients"
        )

        intercepts = classifier.get(
            "intercepts"
        )

        if (
            not isinstance(means, list)
            or len(means) != len(features)
        ):
            raise ModelLoadError(
                f"{task} scaler mean is invalid."
            )

        if (
            not isinstance(scales, list)
            or len(scales) != len(features)
        ):
            raise ModelLoadError(
                f"{task} scaler scale is invalid."
            )

        for index, value in enumerate(means):
            self._finite_number(
                value,
                f"{task} scaler mean {index}",
            )

        for index, value in enumerate(scales):
            scale = self._finite_number(
                value,
                f"{task} scaler scale {index}",
            )

            if scale <= 0:
                raise ModelLoadError(
                    f"{task} scaler scale must "
                    "be greater than zero."
                )

        if (
            not isinstance(coefficients, list)
            or len(coefficients) != len(labels)
        ):
            raise ModelLoadError(
                f"{task} coefficients are invalid."
            )

        for row_index, row in enumerate(
            coefficients
        ):
            if (
                not isinstance(row, list)
                or len(row) != len(features)
            ):
                raise ModelLoadError(
                    f"{task} coefficient row is invalid."
                )

            for column_index, value in enumerate(
                row
            ):
                self._finite_number(
                    value,
                    (
                        f"{task} coefficient "
                        f"{row_index}:{column_index}"
                    ),
                )

        if (
            not isinstance(intercepts, list)
            or len(intercepts) != len(labels)
        ):
            raise ModelLoadError(
                f"{task} intercepts are invalid."
            )

        for index, value in enumerate(intercepts):
            self._finite_number(
                value,
                f"{task} intercept {index}",
            )

        return payload

    def load(self) -> None:
        if self._loaded:
            return

        with self._lock:
            if self._loaded:
                return

            manifest_path = (
                self._model_dir
                / "runtime_model_manifest.json"
            )

            if not manifest_path.exists():
                raise ModelLoadError(
                    "Runtime model manifest was not found."
                )

            try:
                metadata = json.loads(
                    manifest_path.read_text(
                        encoding="utf-8",
                    )
                )
            except Exception as error:
                raise ModelLoadError(
                    "Runtime model manifest "
                    "could not be read."
                ) from error

            if not isinstance(metadata, dict):
                raise ModelLoadError(
                    "Runtime model manifest is invalid."
                )

            components = metadata.get(
                "components"
            )

            if not isinstance(components, dict):
                raise ModelLoadError(
                    "Runtime model components are invalid."
                )

            loaded_models: dict[
                str,
                dict[str, Any],
            ] = {}

            for task in (
                "stress",
                "mood",
            ):
                component = components.get(task)

                if not isinstance(component, dict):
                    raise ModelLoadError(
                        f"{task} runtime component "
                        "is missing."
                    )

                model_file = component.get(
                    "model_file"
                )

                if (
                    not isinstance(model_file, str)
                    or not model_file.endswith(".json")
                ):
                    raise ModelLoadError(
                        f"{task} model file metadata "
                        "is invalid."
                    )

                model_path = (
                    self._model_dir
                    / model_file
                )

                if not model_path.exists():
                    raise ModelLoadError(
                        f"{task} portable model "
                        "file was not found."
                    )

                try:
                    payload = json.loads(
                        model_path.read_text(
                            encoding="utf-8",
                        )
                    )
                except Exception as error:
                    raise ModelLoadError(
                        f"{task} portable model "
                        "could not be read."
                    ) from error

                loaded_models[task] = (
                    self._validate_payload(
                        task,
                        payload,
                    )
                )

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

        components = self._metadata.get(
            "components",
            {},
        )

        model_information: list[
            dict[str, Any]
        ] = []

        for task in (
            "burnout",
            "stress",
            "mood",
        ):
            component = components.get(
                task,
                {},
            )

            if task == "burnout":
                payload = component
            else:
                payload = self._models[task]

            model_information.append(
                {
                    "task": task,
                    "model_version": payload.get(
                        "model_version",
                        component.get(
                            "model_version",
                            "unknown",
                        ),
                    ),
                    "training_data_type": (
                        payload.get(
                            "training_data_type",
                            component.get(
                                "training_data_type",
                                "unknown",
                            ),
                        )
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
                    )
                    if task != "burnout"
                    else int(
                        component.get(
                            "feature_count",
                            0,
                        )
                    ),
                    "labels": [
                        str(label)
                        for label in payload.get(
                            "labels",
                            [],
                        )
                    ],
                    "engine_type": component.get(
                        "engine_type",
                        (
                            "portable_logistic_json"
                            if task != "burnout"
                            else "transparent_rule"
                        ),
                    ),
                    "model_file": component.get(
                        "model_file"
                    ),
                    "schema_version": payload.get(
                        "schema_version"
                    ),
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
                    "This is an experimental "
                    "wellness-support system."
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

        feature_names = [
            str(feature)
            for feature in payload["features"]
        ]

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

        means = payload[
            "preprocessing"
        ][
            "mean"
        ]

        scales = payload[
            "preprocessing"
        ][
            "scale"
        ]

        coefficients = payload[
            "classifier"
        ][
            "coefficients"
        ]

        intercepts = payload[
            "classifier"
        ][
            "intercepts"
        ]

        labels = [
            str(label)
            for label in payload["labels"]
        ]

        standardized: list[float] = []

        for index, feature in enumerate(
            feature_names
        ):
            value = self._finite_number(
                feature_values[feature],
                f"{task} feature {feature}",
            )

            mean = self._finite_number(
                means[index],
                f"{task} scaler mean {feature}",
            )

            scale = self._finite_number(
                scales[index],
                f"{task} scaler scale {feature}",
            )

            standardized.append(
                (value - mean) / scale
            )

        logits: list[float] = []

        for row_index, row in enumerate(
            coefficients
        ):
            intercept = self._finite_number(
                intercepts[row_index],
                f"{task} intercept {row_index}",
            )

            value = intercept

            for column_index, coefficient in enumerate(
                row
            ):
                value += (
                    self._finite_number(
                        coefficient,
                        (
                            f"{task} coefficient "
                            f"{row_index}:{column_index}"
                        ),
                    )
                    * standardized[column_index]
                )

            logits.append(value)

        maximum_logit = max(logits)

        exponentials = [
            math.exp(
                logit - maximum_logit
            )
            for logit in logits
        ]

        exponential_sum = sum(
            exponentials
        )

        if (
            not math.isfinite(exponential_sum)
            or exponential_sum <= 0
        ):
            raise ModelLoadError(
                f"{task} probability calculation failed."
            )

        raw_probabilities = [
            value / exponential_sum
            for value in exponentials
        ]

        prediction_index = max(
            range(len(labels)),
            key=lambda index: (
                raw_probabilities[index]
            ),
        )

        prediction = labels[
            prediction_index
        ]

        probabilities = {
            label: round(
                float(probability),
                4,
            )
            for label, probability in zip(
                labels,
                raw_probabilities,
            )
        }

        confidence = round(
            float(
                raw_probabilities[
                    prediction_index
                ]
            ),
            4,
        )

        return {
            "label": prediction,
            "confidence": confidence,
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
