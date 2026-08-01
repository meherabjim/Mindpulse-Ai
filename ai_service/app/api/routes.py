from fastapi import APIRouter, Depends

from app.core.security import (
    verify_internal_api_key,
)

from app.models.schemas import (
    JournalAnalysisRequest,
    JournalAnalysisResponse,
    MLPredictionRequest,
    SafetyAssessment,
    SafetyCheckRequest,
    WellnessMLPredictionResponse,
    WellnessRecommendationRequest,
    WellnessRecommendationResponse,
    ReadingPlanRequest,
    ReadingPlanResponse,
)

from app.services.engine import (
    analyze_journal,
    assess_safety,
    wellness_recommendation,
)

from app.services.reading_plan import (
    generate_reading_plan,
)

from app.services.prediction_service import (
    get_model_status,
    predict_wellness,
)


router = APIRouter(
    prefix="/api/v1",
    tags=["MindPulse AI"],
    dependencies=[
        Depends(
            verify_internal_api_key
        )
    ],
)


@router.post(
    "/analyze/journal",
    response_model=JournalAnalysisResponse,
)
async def journal_analysis(
    request: JournalAnalysisRequest,
) -> JournalAnalysisResponse:
    return analyze_journal(
        request.text,
        request.mood_score,
    )


@router.post(
    "/safety/check",
    response_model=SafetyAssessment,
)
async def safety_check(
    request: SafetyCheckRequest,
) -> SafetyAssessment:
    return assess_safety(
        request.text
    )


@router.post(
    "/recommendations/wellness",
    response_model=WellnessRecommendationResponse,
)
async def recommendation(
    request: WellnessRecommendationRequest,
) -> WellnessRecommendationResponse:
    return wellness_recommendation(
        request
    )


@router.post(
    "/reading/plan",
    response_model=ReadingPlanResponse,
)
async def reading_plan(
    request: ReadingPlanRequest,
) -> ReadingPlanResponse:
    return generate_reading_plan(
        request
    )


@router.get(
    "/models/status",
)
async def models_status() -> dict[str, object]:
    return get_model_status()


@router.post(
    "/predictions/wellness",
    response_model=WellnessMLPredictionResponse,
)
async def wellness_ml_prediction(
    request: MLPredictionRequest,
) -> WellnessMLPredictionResponse:
    return predict_wellness(
        request
    )
