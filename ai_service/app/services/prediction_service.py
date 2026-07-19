from fastapi import HTTPException
from fastapi import status

from app.models.schemas import (
    MLPredictionRequest,
    ModelPrediction,
    WellnessMLPredictionResponse,
    WellnessRecommendationRequest,
)

from app.services.engine import (
    calculate_risk,
    risk_level,
)

from app.services.model_loader import (
    ModelLoadError,
    model_registry,
)


def get_model_status() -> dict[str, object]:
    return model_registry.status()


def _predict_burnout_rule(
    request: MLPredictionRequest,
) -> ModelPrediction:
    wellness_request = WellnessRecommendationRequest(
        mood_score=request.mood_score,
        stress_level=request.stress_level,
        energy_level=request.energy_level,
        sleep_hours=request.sleep_hours,
        hydration_cups=request.hydration_cups,
        burnout_score=None,
    )

    score = calculate_risk(
        wellness_request
    )

    label = risk_level(
        score
    )

    labels = (
        "low",
        "mild",
        "moderate",
        "elevated",
    )

    probabilities = {
        candidate_label: (
            1.0
            if candidate_label == label
            else 0.0
        )
        for candidate_label in labels
    }

    return ModelPrediction(
        label=label,
        confidence=1.0,
        probabilities=probabilities,
        model_version=(
            "wellness-rule-1.0.0"
        ),
        training_data_type=(
            "not_applicable_rule_based"
        ),
        production_ready=False,
    )


def predict_wellness(
    request: MLPredictionRequest,
) -> WellnessMLPredictionResponse:
    feature_values = request.model_dump()

    try:
        model_predictions = {
            task: ModelPrediction(
                **model_registry.predict(
                    task,
                    feature_values,
                )
            )
            for task in (
                "stress",
                "mood",
            )
        }
    except ModelLoadError as error:
        raise HTTPException(
            status_code=(
                status.HTTP_503_SERVICE_UNAVAILABLE
            ),
            detail=str(error),
        ) from error

    predictions = {
        "burnout": _predict_burnout_rule(
            request
        ),
        **model_predictions,
    }

    model_status = model_registry.status()

    return WellnessMLPredictionResponse(
        engine=(
            "mindpulse-hybrid-wellness-v1"
        ),
        production_ready=bool(
            model_status.get(
                "production_ready",
                False,
            )
        ),
        training_data_type=(
            "hybrid_rule_and_synthetic_demo"
        ),
        warning=(
            "Burnout uses transparent wellness "
            "rule version 1.0.0. Stress and mood "
            "use synthetic demonstration models. "
            "Burnout confidence is deterministic "
            "rule output, not a statistical "
            "probability. Results are not clinical "
            "evidence."
        ),
        predictions=predictions,
    )
