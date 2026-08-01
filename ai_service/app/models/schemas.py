from datetime import datetime
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

ReadingItemType = Literal[
    "textbook",
    "supplementary",
    "book",
    "novel",
    "magazine",
    "article",
    "research_paper",
    "own_material",
]

ReadingDifficulty = Literal[
    "unknown",
    "easy",
    "medium",
    "hard",
]

WeekdayCode = Literal[
    "mon",
    "tue",
    "wed",
    "thu",
    "fri",
    "sat",
    "sun",
]


class ReadingEducationProfile(BaseModel):
    education_system: str = Field(min_length=1, max_length=60)
    education_level: str = Field(min_length=1, max_length=60)
    class_or_year: str = Field(default="", max_length=80)
    stream: str = Field(default="", max_length=80)
    board_or_curriculum: str = Field(default="", max_length=120)
    degree: str = Field(default="", max_length=120)
    major: str = Field(default="", max_length=120)
    semester: str = Field(default="", max_length=80)
    subjects: list[str] = Field(default_factory=list, max_length=30)
    preferred_language: Literal["bn", "en", "both"] = "bn"

    @field_validator("subjects")
    @classmethod
    def validate_subjects(cls, value: list[str]) -> list[str]:
        cleaned: list[str] = []
        seen: set[str] = set()
        for raw in value:
            subject = str(raw).strip()
            if not subject:
                continue
            key = subject.casefold()
            if key in seen:
                continue
            seen.add(key)
            cleaned.append(subject[:100])
        return cleaned


class ReadingItemInput(BaseModel):
    id: str = Field(min_length=1, max_length=160)
    type: ReadingItemType
    title: str = Field(min_length=1, max_length=300)
    author: str = Field(default="", max_length=240)
    publisher: str = Field(default="", max_length=240)
    published_date: str = Field(default="", max_length=80)
    subject: str = Field(default="", max_length=120)
    language: str = Field(default="", max_length=40)
    identifier: str = Field(default="", max_length=120)
    source: Literal[
        "google_books",
        "crossref",
        "open_library",
        "nctb",
        "manual",
    ] = "manual"
    source_url: str = Field(default="", max_length=1000)
    user_difficulty: ReadingDifficulty = "unknown"
    priority: int = Field(default=3, ge=1, le=5)

    @field_validator("title")
    @classmethod
    def validate_title(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Reading item title cannot be empty.")
        return value


class ReadingAvailability(BaseModel):
    session_minutes: int = Field(default=30, ge=10, le=120)
    sessions_per_week: int = Field(default=3, ge=1, le=14)
    preferred_days: list[WeekdayCode] = Field(
        default_factory=lambda: ["mon", "wed", "sat"],
        min_length=1,
        max_length=7,
    )
    preferred_start_minutes: int = Field(default=1140, ge=0, le=1439)


class ReadingPlanRequest(BaseModel):
    profile: ReadingEducationProfile
    items: list[ReadingItemInput] = Field(min_length=1, max_length=30)
    availability: ReadingAvailability
    goal: str = Field(default="general_reading", min_length=1, max_length=100)
    target_date: str | None = Field(default=None, max_length=40)


class ReadingDifficultyAssessment(BaseModel):
    item_id: str
    label: ReadingDifficulty
    confidence: float = Field(ge=0, le=1)
    basis: list[str]
    note: str


class ReadingPlanSession(BaseModel):
    session_id: str
    day: WeekdayCode
    day_label: str
    start_minutes: int = Field(ge=0, le=1439)
    duration_minutes: int = Field(ge=10, le=120)
    item_id: str
    title: str
    subject: str
    focus: str
    reason: str
    difficulty: ReadingDifficulty
    confidence: float = Field(ge=0, le=1)


class ReadingPlanSource(BaseModel):
    name: str
    usage: str


class ReadingPlanResponse(BaseModel):
    plan_id: str
    engine: str
    generated_at: datetime
    language: Literal["bn", "en"]
    summary: str
    overall_confidence: float = Field(ge=0, le=1)
    difficulty_assessments: list[ReadingDifficultyAssessment]
    sessions: list[ReadingPlanSession]
    assumptions: list[str]
    sources: list[ReadingPlanSource]
    disclaimer: str
