import re
from collections import Counter

from app.models.schemas import (
    EmotionScore,
    JournalAnalysisResponse,
    RecommendationItem,
    SafetyAssessment,
    WellnessRecommendationRequest,
    WellnessRecommendationResponse,
)


TOKEN_PATTERN = re.compile(
    r"[A-Za-z']+|[\u0980-\u09FF]+"
)

POSITIVE_WORDS = {
    "good",
    "great",
    "happy",
    "calm",
    "better",
    "hope",
    "hopeful",
    "grateful",
    "relaxed",
    "progress",
    "success",
    "ভালো",
    "খুশি",
    "শান্ত",
    "আশা",
    "আশাবাদী",
    "কৃতজ্ঞ",
    "উন্নতি",
    "সফল",
}

NEGATIVE_WORDS = {
    "bad",
    "sad",
    "angry",
    "stress",
    "stressed",
    "anxious",
    "worried",
    "tired",
    "exhausted",
    "lonely",
    "hopeless",
    "overwhelmed",
    "খারাপ",
    "দুঃখ",
    "রাগ",
    "চাপ",
    "দুশ্চিন্তা",
    "ক্লান্ত",
    "একাকী",
    "হতাশ",
    "অসহায়",
}

EMOTION_WORDS = {
    "stress": {
        "stress",
        "stressed",
        "pressure",
        "overwhelmed",
        "চাপ",
        "টেনশন",
    },
    "anxiety": {
        "anxious",
        "worried",
        "fear",
        "panic",
        "দুশ্চিন্তা",
        "ভয়",
        "আতঙ্ক",
    },
    "sadness": {
        "sad",
        "lonely",
        "unhappy",
        "cry",
        "দুঃখ",
        "একাকী",
        "কান্না",
        "মনখারাপ",
    },
    "anger": {
        "angry",
        "furious",
        "annoyed",
        "রাগ",
        "বিরক্ত",
    },
    "hope": {
        "hope",
        "hopeful",
        "better",
        "progress",
        "আশা",
        "উন্নতি",
        "ভালো",
    },
    "calm": {
        "calm",
        "peaceful",
        "relaxed",
        "শান্ত",
        "স্বস্তি",
    },
}

CRITICAL_PHRASES = {
    "kill myself",
    "end my life",
    "hurt myself",
    "take my own life",
    "নিজেকে মেরে ফেল",
    "নিজেকে শেষ করে দেব",
    "আত্মহত্যা করব",
    "নিজেকে আঘাত করব",
}

HIGH_RISK_PHRASES = {
    "want to die",
    "wish i were dead",
    "do not want to live",
    "don't want to live",
    "suicide",
    "মরে যেতে চাই",
    "বাঁচতে চাই না",
    "আত্মহত্যা",
}

MODERATE_PHRASES = {
    "cannot go on",
    "can't go on",
    "everything is hopeless",
    "no reason to continue",
    "সব শেষ",
    "কোনো আশা নেই",
    "আর পারছি না",
}


def normalize(text: str) -> str:
    return re.sub(
        r"\s+",
        " ",
        text.strip().lower(),
    )


def tokenize(text: str) -> list[str]:
    return TOKEN_PATTERN.findall(
        normalize(text)
    )


def detect_language(text: str) -> str:
    bengali_count = len(
        re.findall(
            r"[\u0980-\u09FF]",
            text,
        )
    )

    english_count = len(
        re.findall(
            r"[A-Za-z]",
            text,
        )
    )

    if bengali_count > english_count:
        return "bn"

    if english_count > 0:
        return "en"

    return "unknown"


def assess_safety(
    text: str,
) -> SafetyAssessment:
    normalized = normalize(text)

    if any(
        phrase in normalized
        for phrase in CRITICAL_PHRASES
    ):
        return SafetyAssessment(
            flagged=True,
            severity="critical",
            matched_signals=[
                "direct_self_harm_intent"
            ],
            emergency_action_recommended=True,
            guidance=[
                (
                    "Contact local emergency services "
                    "or urgent professional support now."
                ),
                (
                    "Stay with a trusted person and "
                    "move away from possible means of harm."
                ),
                (
                    "Do not rely only on the MindPulse "
                    "application during an emergency."
                ),
            ],
        )

    if any(
        phrase in normalized
        for phrase in HIGH_RISK_PHRASES
    ):
        return SafetyAssessment(
            flagged=True,
            severity="high",
            matched_signals=[
                "high_risk_self_harm_language"
            ],
            emergency_action_recommended=True,
            guidance=[
                (
                    "Contact a trusted person immediately."
                ),
                (
                    "Seek urgent professional or emergency "
                    "support if there is immediate danger."
                ),
            ],
        )

    if any(
        phrase in normalized
        for phrase in MODERATE_PHRASES
    ):
        return SafetyAssessment(
            flagged=True,
            severity="moderate",
            matched_signals=[
                "severe_hopelessness_language"
            ],
            emergency_action_recommended=False,
            guidance=[
                (
                    "Reach out to a trusted person and "
                    "consider professional support."
                )
            ],
        )

    return SafetyAssessment(
        flagged=False,
        severity="low",
        matched_signals=[],
        emergency_action_recommended=False,
        guidance=[
            (
                "Continue regular wellness check-ins "
                "and seek support when needed."
            )
        ],
    )


def analyze_sentiment(
    tokens: list[str],
) -> tuple[str, float, float]:
    positive = sum(
        token in POSITIVE_WORDS
        for token in tokens
    )

    negative = sum(
        token in NEGATIVE_WORDS
        for token in tokens
    )

    total = positive + negative

    if total == 0:
        return "neutral", 0.0, 0.30

    score = (
        positive - negative
    ) / total

    score = round(
        max(-1.0, min(1.0, score)),
        3,
    )

    if score > 0.15:
        label = "positive"
    elif score < -0.15:
        label = "negative"
    else:
        label = "neutral"

    confidence = round(
        min(
            0.95,
            0.45 + total * 0.08,
        ),
        3,
    )

    return label, score, confidence


def detect_emotions(
    tokens: list[str],
) -> list[EmotionScore]:
    token_counts = Counter(tokens)
    emotion_counts: dict[str, int] = {}

    for emotion, words in (
        EMOTION_WORDS.items()
    ):
        count = sum(
            token_counts[word]
            for word in words
        )

        if count > 0:
            emotion_counts[emotion] = count

    total = sum(
        emotion_counts.values()
    )

    if total == 0:
        return []

    ranked = sorted(
        emotion_counts.items(),
        key=lambda item: item[1],
        reverse=True,
    )

    return [
        EmotionScore(
            emotion=emotion,
            score=round(
                count / total,
                3,
            ),
        )
        for emotion, count in ranked[:4]
    ]


def analyze_journal(
    text: str,
    mood_score: int | None,
) -> JournalAnalysisResponse:
    tokens = tokenize(text)

    sentiment, score, confidence = (
        analyze_sentiment(tokens)
    )

    emotions = detect_emotions(tokens)
    safety = assess_safety(text)

    insights: list[str] = []

    if sentiment == "positive":
        insights.append(
            "The entry contains mainly positive emotional language."
        )
    elif sentiment == "negative":
        insights.append(
            "The entry contains notable difficult emotional language."
        )
    else:
        insights.append(
            "The entry contains balanced or limited emotional signals."
        )

    if emotions:
        insights.append(
            "The strongest detected emotional theme is "
            f"{emotions[0].emotion}."
        )

    if mood_score is not None:
        if mood_score <= 2:
            insights.append(
                "The mood score suggests that additional "
                "support may be useful."
            )
        elif mood_score >= 4:
            insights.append(
                "The mood score indicates a relatively "
                "positive day."
            )

    return JournalAnalysisResponse(
        sentiment=sentiment,
        sentiment_score=score,
        confidence=confidence,
        word_count=len(tokens),
        detected_language=detect_language(
            text
        ),
        emotions=emotions,
        key_insights=insights,
        safety=safety,
        disclaimer=(
            "This automated wellness analysis is "
            "informational and does not provide a "
            "medical or mental-health diagnosis."
        ),
    )


def calculate_risk(
    data: WellnessRecommendationRequest,
) -> float:
    stress = (
        (data.stress_level - 1)
        / 4
        * 30
    )

    mood = (
        (5 - data.mood_score)
        / 4
        * 25
    )

    energy = (
        (5 - data.energy_level)
        / 4
        * 20
    )

    sleep_deficit = max(
        0.0,
        7.0 - data.sleep_hours,
    )

    sleep = min(
        25.0,
        sleep_deficit / 7.0 * 25,
    )

    lifestyle_score = (
        stress
        + mood
        + energy
        + sleep
    )

    if data.burnout_score is not None:
        lifestyle_score = (
            lifestyle_score * 0.60
            + data.burnout_score * 0.40
        )

    return round(
        max(
            0.0,
            min(100.0, lifestyle_score),
        ),
        2,
    )


def risk_level(score: float) -> str:
    if score < 25:
        return "low"

    if score < 45:
        return "mild"

    if score < 65:
        return "moderate"

    return "elevated"


def wellness_recommendation(
    data: WellnessRecommendationRequest,
) -> WellnessRecommendationResponse:
    score = calculate_risk(data)
    level = risk_level(score)

    interpretations = {
        "low": (
            "Current indicators appear generally manageable."
        ),
        "mild": (
            "Some wellness strain is present."
        ),
        "moderate": (
            "Several indicators suggest meaningful wellness strain."
        ),
        "elevated": (
            "Current indicators suggest substantial wellness strain."
        ),
    }

    recommendations: list[RecommendationItem] = []

    if data.stress_level >= 4:
        recommendations.append(
            RecommendationItem(
                category="stress",
                title="Take a structured calming break",
                action=(
                    "Practise slow breathing for 3 to 5 minutes "
                    "and divide the next task into one small step."
                ),
                reason="The recorded stress level is high.",
                priority="high",
            )
        )

    if data.sleep_hours < 6:
        recommendations.append(
            RecommendationItem(
                category="sleep",
                title="Protect tonight's sleep window",
                action=(
                    "Use a consistent bedtime and reduce "
                    "stimulating screen use before sleep."
                ),
                reason="The recorded sleep duration is low.",
                priority="high",
            )
        )

    if data.energy_level <= 2:
        recommendations.append(
            RecommendationItem(
                category="energy",
                title="Choose a low-demand recovery activity",
                action=(
                    "Take a short walk, stretch gently, "
                    "or complete a breathing exercise."
                ),
                reason="The recorded energy level is low.",
                priority="medium",
            )
        )

    if data.hydration_cups < 6:
        recommendations.append(
            RecommendationItem(
                category="hydration",
                title="Improve hydration gradually",
                action=(
                    "Drink water now and use reminders "
                    "throughout the day."
                ),
                reason="The recorded hydration amount is low.",
                priority="medium",
            )
        )

    if data.mood_score <= 2:
        recommendations.append(
            RecommendationItem(
                category="support",
                title="Connect with a trusted person",
                action=(
                    "Share how the day has felt with a "
                    "trusted friend, family member, teacher, "
                    "or supervisor."
                ),
                reason="The recorded mood score is low.",
                priority="high",
            )
        )

    if level == "elevated":
        recommendations.append(
            RecommendationItem(
                category="professional_support",
                title="Consider qualified professional support",
                action=(
                    "Contact an appropriate qualified "
                    "professional for an individual assessment."
                ),
                reason=(
                    "Multiple indicators show elevated "
                    "wellness strain."
                ),
                priority="high",
            )
        )

    if not recommendations:
        recommendations.append(
            RecommendationItem(
                category="maintenance",
                title="Continue regular check-ins",
                action=(
                    "Record mood, stress, energy, and sleep "
                    "consistently."
                ),
                reason=(
                    "Current indicators appear relatively stable."
                ),
                priority="low",
            )
        )

    return WellnessRecommendationResponse(
        risk_score=score,
        risk_level=level,
        interpretation=interpretations[level],
        recommendations=recommendations[:6],
        safety_note=(
            "Seek urgent local support if there is immediate "
            "danger or risk of self-harm."
        ),
        disclaimer=(
            "This recommendation is an automated wellness aid, "
            "not a diagnosis or replacement for qualified care."
        ),
    )
