from fastapi import HTTPException
from fastapi import status

from app.models.schemas import (
    MLPredictionRequest,
    ModelPrediction,
    WellnessMLPredictionResponse,
)

from app.services.model_loader import (
    ModelLoadError,
    model_registry,
)


def get_model_status() -> dict[str, object]:
    return model_registry.status()


def predict_wellness(
    request: MLPredictionRequest,
) -> WellnessMLPredictionResponse:
    feature_values = request.model_dump()

    try:
        predictions = {
            task: ModelPrediction(
                **model_registry.predict(
                    task,
                    feature_values,
                )
            )
            for task in (
                "burnout",
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

    model_status = model_registry.status()

    return WellnessMLPredictionResponse(
        engine=(
            "mindpulse-random-forest"
        ),
        production_ready=bool(
            model_status.get(
                "production_ready",
                False,
            )
        ),
        training_data_type=str(
            model_status.get(
                "training_data_type",
                "unknown",
            )
        ),
        warning=str(
            model_status.get(
                "warning",
                (
                    "This is an experimental "
                    "wellness-support prediction."
                ),
            )
        ),
        predictions=predictions,
    )
