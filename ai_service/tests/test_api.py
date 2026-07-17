import os

os.environ["INTERNAL_API_KEY"] = (
    "mindpulse-test-key"
)

from fastapi.testclient import TestClient

from app.main import app


client = TestClient(app)

HEADERS = {
    "X-Internal-API-Key":
        "mindpulse-test-key"
}


def test_health() -> None:
    response = client.get(
        "/health"
    )

    assert response.status_code == 200
    assert response.json()["status"] == "healthy"


def test_missing_key_rejected() -> None:
    response = client.post(
        "/api/v1/safety/check",
        json={
            "text":
                "I feel stressed today."
        },
    )

    assert response.status_code == 401


def test_journal_analysis() -> None:
    response = client.post(
        "/api/v1/analyze/journal",
        headers=HEADERS,
        json={
            "text": (
                "I feel stressed and tired, "
                "but I hope tomorrow will be better."
            ),
            "language": "en",
            "mood_score": 3,
        },
    )

    assert response.status_code == 200

    data = response.json()

    assert data["word_count"] > 0
    assert data["sentiment"] in {
        "positive",
        "neutral",
        "negative",
    }


def test_safety_detection() -> None:
    response = client.post(
        "/api/v1/safety/check",
        headers=HEADERS,
        json={
            "text":
                "I want to die."
        },
    )

    assert response.status_code == 200

    data = response.json()

    assert data["flagged"] is True
    assert data["severity"] in {
        "high",
        "critical",
    }


def test_wellness_recommendation() -> None:
    response = client.post(
        "/api/v1/recommendations/wellness",
        headers=HEADERS,
        json={
            "mood_score": 2,
            "stress_level": 5,
            "energy_level": 2,
            "sleep_hours": 5,
            "hydration_cups": 3,
            "burnout_score": 70,
        },
    )

    assert response.status_code == 200

    data = response.json()

    assert data["risk_score"] >= 0
    assert len(
        data["recommendations"]
    ) > 0



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
