from typing import Literal

from pydantic import BaseModel, Field, field_validator


SentimentLabel = Literal[
    "positive",
    "neutral",
    "negative",
]

SafetySeverity = Literal[
    "low",
    "moderate",
    "high",
    "critical",
]

RiskLevel = Literal[
    "low",
    "mild",
    "moderate",
    "elevated",
]


class JournalAnalysisRequest(BaseModel):
    text: str = Field(
        min_length=1,
        max_length=10000,
    )

    language: Literal[
        "auto",
        "en",
        "bn",
    ] = "auto"

    mood_score: int | None = Field(
        default=None,
        ge=1,
        le=5,
    )

    @field_validator("text")
    @classmethod
    def validate_text(cls, value: str) -> str:
        value = value.strip()

        if not value:
            raise ValueError(
                "Journal text cannot be empty."
            )

        return value


class SafetyCheckRequest(BaseModel):
    text: str = Field(
        min_length=1,
        max_length=5000,
    )

    @field_validator("text")
    @classmethod
    def validate_text(cls, value: str) -> str:
        value = value.strip()

        if not value:
            raise ValueError(
                "Text cannot be empty."
            )

        return value


class WellnessRecommendationRequest(BaseModel):
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

    hydration_cups: int = Field(
        default=0,
        ge=0,
        le=30,
    )

    burnout_score: float | None = Field(
        default=None,
        ge=0,
        le=100,
    )


class SafetyAssessment(BaseModel):
    flagged: bool
    severity: SafetySeverity
    matched_signals: list[str]
    emergency_action_recommended: bool
    guidance: list[str]


class EmotionScore(BaseModel):
    emotion: str
    score: float


class JournalAnalysisResponse(BaseModel):
    sentiment: SentimentLabel
    sentiment_score: float
    confidence: float
    word_count: int
    detected_language: str
    emotions: list[EmotionScore]
    key_insights: list[str]
    safety: SafetyAssessment
    disclaimer: str


class RecommendationItem(BaseModel):
    category: str
    title: str
    action: str
    reason: str
    priority: Literal[
        "low",
        "medium",
        "high",
    ]


class WellnessRecommendationResponse(BaseModel):
    risk_score: float
    risk_level: RiskLevel
    interpretation: str
    recommendations: list[RecommendationItem]
    safety_note: str
    disclaimer: str


class HealthResponse(BaseModel):
    success: bool
    service: str
    status: str
    environment: str



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
