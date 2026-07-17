from pathlib import Path


root = Path(__file__).resolve().parents[1]

schemas_path = root / "app" / "models" / "schemas.py"
routes_path = root / "app" / "api" / "routes.py"
tests_path = root / "tests" / "test_api.py"
requirements_path = root / "requirements.txt"


schemas_text = schemas_path.read_text(
    encoding="utf-8"
)

schema_marker = "class MLPredictionRequest"

schema_block = r'''


class MLPredictionRequest(BaseModel):
    mood_score: int = Field(
        ge=1,
        le=5,
    )

    stress_level: int = Field(
        ge=1,
        le=5,
    )

    energy_level: int = Field(
        ge=1,
        le=5,
    )

    sleep_hours: float = Field(
        ge=0,
        le=24,
    )

    sleep_quality: int = Field(
        ge=1,
        le=5,
    )

    focus_level: int = Field(
        ge=1,
        le=5,
    )

    motivation_level: int = Field(
        ge=1,
        le=5,
    )

    restlessness_level: int = Field(
        ge=1,
        le=5,
    )

    work_study_pressure: int = Field(
        ge=1,
        le=5,
    )

    physical_activity_minutes: int = Field(
        default=0,
        ge=0,
        le=1440,
    )

    hydration_cups: int = Field(
        default=0,
        ge=0,
        le=30,
    )

    social_withdrawal: int = Field(
        ge=1,
        le=5,
    )


class ModelPrediction(BaseModel):
    label: str
    confidence: float = Field(
        ge=0,
        le=1,
    )
    probabilities: dict[str, float]
    model_version: str
    training_data_type: str
    production_ready: bool


class WellnessMLPredictionResponse(BaseModel):
    engine: str
    production_ready: bool
    training_data_type: str
    warning: str
    predictions: dict[
        str,
        ModelPrediction,
    ]
'''

if schema_marker not in schemas_text:
    schemas_text += schema_block

schemas_path.write_text(
    schemas_text,
    encoding="utf-8",
)


routes_text = '''from fastapi import APIRouter, Depends

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
)

from app.services.engine import (
    analyze_journal,
    assess_safety,
    wellness_recommendation,
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
'''

routes_path.write_text(
    routes_text,
    encoding="utf-8",
)


tests_text = tests_path.read_text(
    encoding="utf-8"
)

test_marker = "def test_model_status"

test_block = r'''


def test_model_status() -> None:
    response = client.get(
        "/api/v1/models/status",
        headers=HEADERS,
    )

    assert response.status_code == 200

    data = response.json()

    assert data["available"] is True
    assert data["production_ready"] is False

    tasks = {
        item["task"]
        for item in data["models"]
    }

    assert tasks == {
        "burnout",
        "stress",
        "mood",
    }


def test_ml_wellness_prediction() -> None:
    response = client.post(
        "/api/v1/predictions/wellness",
        headers=HEADERS,
        json={
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
        },
    )

    assert response.status_code == 200

    data = response.json()

    assert data["production_ready"] is False

    assert set(
        data["predictions"].keys()
    ) == {
        "burnout",
        "stress",
        "mood",
    }

    for prediction in (
        data["predictions"].values()
    ):
        assert prediction["label"]
        assert 0 <= prediction["confidence"] <= 1
        assert prediction["probabilities"]
'''

if test_marker not in tests_text:
    tests_text += test_block

tests_path.write_text(
    tests_text,
    encoding="utf-8",
)


requirements = requirements_path.read_text(
    encoding="utf-8"
).splitlines()

required_packages = [
    "numpy==2.5.1",
    "pandas==3.0.3",
    "scikit-learn==1.9.0",
    "joblib==1.5.3",
]

existing_names = {
    line.split("==")[0].strip().lower()
    for line in requirements
    if line.strip()
}

for package in required_packages:
    package_name = (
        package.split("==")[0].lower()
    )

    if package_name not in existing_names:
        requirements.append(package)

requirements_path.write_text(
    "\n".join(requirements).rstrip()
    + "\n",
    encoding="utf-8",
)

print(
    "FastAPI ML integration completed."
)
