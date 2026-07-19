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


def test_burnout_prediction_uses_transparent_rule() -> None:
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

    assert (
        data["engine"]
        == "mindpulse-hybrid-wellness-v1"
    )

    assert (
        data["training_data_type"]
        == "hybrid_rule_and_synthetic_demo"
    )

    assert set(
        data["predictions"]
    ) == {
        "burnout",
        "stress",
        "mood",
    }

    burnout = data[
        "predictions"
    ][
        "burnout"
    ]

    assert burnout["label"] in {
        "low",
        "mild",
        "moderate",
        "elevated",
    }

    assert (
        burnout["model_version"]
        == "wellness-rule-1.0.0"
    )

    assert (
        burnout["training_data_type"]
        == "not_applicable_rule_based"
    )

    assert (
        burnout["production_ready"]
        is False
    )

    assert burnout["confidence"] == 1.0

    assert set(
        burnout["probabilities"]
    ) == {
        "low",
        "mild",
        "moderate",
        "elevated",
    }

    assert (
        sum(
            burnout[
                "probabilities"
            ].values()
        )
        == 1.0
    )

    assert (
        burnout[
            "probabilities"
        ][
            burnout["label"]
        ]
        == 1.0
    )


def test_model_status_reports_burnout_rule() -> None:
    response = client.get(
        "/api/v1/models/status",
        headers=HEADERS,
    )

    assert response.status_code == 200

    data = response.json()

    models = {
        item["task"]: item
        for item in data["models"]
    }

    assert set(models) == {
        "burnout",
        "stress",
        "mood",
    }

    burnout = models["burnout"]

    assert (
        burnout["model_version"]
        == "wellness-rule-1.0.0"
    )

    assert (
        burnout["training_data_type"]
        == "not_applicable_rule_based"
    )

    assert (
        burnout["engine_type"]
        == "transparent_rule"
    )


def test_portable_json_models_are_active() -> None:
    status_response = client.get(
        "/api/v1/models/status",
        headers=HEADERS,
    )

    assert status_response.status_code == 200

    status_data = status_response.json()

    models = {
        item["task"]: item
        for item in status_data["models"]
    }

    for task in (
        "stress",
        "mood",
    ):
        model = models[task]

        assert (
            model["engine_type"]
            == "portable_logistic_json"
        )

        assert (
            model["model_file"]
            == f"{task}_model.json"
        )

        assert (
            model["schema_version"]
            == "mindpulse-portable-logistic-1"
        )

        assert (
            model["model_version"]
            == f"{task}-portable-demo-1.0.0"
        )

        assert (
            model["production_ready"]
            is False
        )

    prediction_response = client.post(
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

    assert prediction_response.status_code == 200

    prediction_data = (
        prediction_response.json()
    )

    assert set(
        prediction_data["predictions"]
    ) == {
        "burnout",
        "stress",
        "mood",
    }

    for task in (
        "stress",
        "mood",
    ):
        prediction = (
            prediction_data[
                "predictions"
            ][
                task
            ]
        )

        assert (
            prediction["model_version"]
            == f"{task}-portable-demo-1.0.0"
        )

        assert (
            prediction["training_data_type"]
            == "synthetic_demo"
        )

        assert (
            prediction["production_ready"]
            is False
        )

        assert prediction["label"]

        assert (
            0
            <= prediction["confidence"]
            <= 1
        )

        probability_sum = sum(
            prediction[
                "probabilities"
            ].values()
        )

        assert abs(
            probability_sum - 1.0
        ) <= 0.001
