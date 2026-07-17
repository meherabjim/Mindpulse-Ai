$ErrorActionPreference = "Stop"

$root =
  "E:\project 3\MindPulse-AI"

$python =
  "$root\ai_service\.venv\Scripts\python.exe"

$flutter =
  "E:\Android\flutter\bin\flutter.bat"

$dart =
  "E:\Android\flutter\bin\dart.bat"

$temporaryTest =
  "$root\ai_service\tests\manual_safety_qa_temp.py"

$requiredFiles = @(
  $python,
  "$root\ai_service\app\main.py",
  "$root\ai_service\tests\test_api.py",
  "$root\backend\src\services\ai.service.js",
  "$root\backend\src\controllers\ai.controller.js",
  "$root\backend\src\routes\ai.routes.js",
  "$root\backend\scripts\testAiService.js",
  "$root\mobile_app\lib\features\ai\screens\ai_wellness_screen.dart",
  "$root\mobile_app\lib\features\safety\widgets\safety_escalation_card.dart"
)

$missing = @(
  $requiredFiles |
  Where-Object {
    -not (Test-Path $_)
  }
)

if ($missing.Count -gt 0) {
  Write-Host "Missing required files:" -ForegroundColor Red

  $missing |
    ForEach-Object {
      Write-Host $_ -ForegroundColor Red
    }

  throw "AI safety E2E validation stopped."
}

@'
import os

os.environ["INTERNAL_API_KEY"] = "mindpulse-test-key"

from fastapi.testclient import TestClient

from app.main import app


client = TestClient(app)

HEADERS = {
    "X-Internal-API-Key": "mindpulse-test-key",
}


def assert_case(
    name: str,
    text: str,
    expected_flagged: bool,
    expected_severity: str,
) -> None:
    response = client.post(
        "/api/v1/safety/check",
        headers=HEADERS,
        json={"text": text},
    )

    assert response.status_code == 200, (
        name,
        response.status_code,
        response.text,
    )

    data = response.json()

    assert data["flagged"] is expected_flagged, (
        name,
        data,
    )

    assert data["severity"] == expected_severity, (
        name,
        data,
    )

    assert isinstance(
        data["emergency_action_recommended"],
        bool,
    )

    print(
        f"PASS {name}: "
        f"flagged={data['flagged']} "
        f"severity={data['severity']}"
    )


def main() -> None:
    missing_key = client.post(
        "/api/v1/safety/check",
        json={"text": "I feel stressed today."},
    )

    assert missing_key.status_code == 401

    print("PASS missing internal API key: 401")

    cases = [
        (
            "safe_en",
            "I feel stressed today, but I am safe.",
            False,
            "low",
        ),
        (
            "moderate_en",
            "I cannot go on.",
            True,
            "moderate",
        ),
        (
            "high_en",
            "I want to die.",
            True,
            "high",
        ),
        (
            "critical_en",
            "I will end my life.",
            True,
            "critical",
        ),
        (
            "moderate_bn",
            "আর পারছি না।",
            True,
            "moderate",
        ),
        (
            "high_bn",
            "মরে যেতে চাই।",
            True,
            "high",
        ),
        (
            "critical_bn",
            "আত্মহত্যা করব।",
            True,
            "critical",
        ),
    ]

    for case in cases:
        assert_case(*case)

    journal = client.post(
        "/api/v1/analyze/journal",
        headers=HEADERS,
        json={
            "text": "আত্মহত্যা করব।",
            "language": "bn",
            "mood_score": 1,
        },
    )

    assert journal.status_code == 200, journal.text

    journal_data = journal.json()

    assert journal_data["safety"]["flagged"] is True
    assert journal_data["safety"]["severity"] == "critical"

    print(
        "PASS journal safety escalation: "
        "flagged=True severity=critical"
    )

    wellness = client.post(
        "/api/v1/recommendations/wellness",
        headers=HEADERS,
        json={
            "mood_score": 1,
            "stress_level": 5,
            "energy_level": 1,
            "sleep_hours": 0,
            "hydration_cups": 0,
            "burnout_score": 100,
        },
    )

    assert wellness.status_code == 200, wellness.text

    wellness_data = wellness.json()

    assert wellness_data["risk_level"] == "elevated"
    assert wellness_data["risk_score"] >= 70
    assert len(wellness_data["recommendations"]) > 0

    print(
        "PASS elevated wellness support: "
        f"score={wellness_data['risk_score']} "
        f"level={wellness_data['risk_level']}"
    )

    print("")
    print("FastAPI multilingual safety QA passed.")


if __name__ == "__main__":
    main()
'@ | Set-Content `
  -Path $temporaryTest `
  -Encoding UTF8

$previousPythonPath = $env:PYTHONPATH

try {
  Write-Host ""
  Write-Host "STEP 1/4 — FastAPI existing tests" `
    -ForegroundColor Cyan

  Set-Location "$root\ai_service"

  & $python -m pytest `
    "tests\test_api.py" `
    -q

  if ($LASTEXITCODE -ne 0) {
    throw "Existing FastAPI tests failed."
  }

  Write-Host ""
  Write-Host "STEP 2/4 — Multilingual safety QA" `
    -ForegroundColor Cyan

  $env:PYTHONPATH = "$root\ai_service"

  & $python $temporaryTest

  if ($LASTEXITCODE -ne 0) {
    throw "Multilingual safety QA failed."
  }

  Write-Host ""
  Write-Host "STEP 3/4 — Node/FastAPI bridge" `
    -ForegroundColor Cyan

  $fastApiListening =
    Test-NetConnection `
      -ComputerName "127.0.0.1" `
      -Port 8000 `
      -InformationLevel Quiet

  if (-not $fastApiListening) {
    throw (
      "FastAPI is not listening on port 8000. " +
      "Start it and run this QA script again."
    )
  }

  Set-Location "$root\backend"

  node --check `
    "src\services\ai.service.js"

  if ($LASTEXITCODE -ne 0) {
    throw "ai.service.js syntax check failed."
  }

  node --check `
    "src\controllers\ai.controller.js"

  if ($LASTEXITCODE -ne 0) {
    throw "ai.controller.js syntax check failed."
  }

  node --check `
    "src\routes\ai.routes.js"

  if ($LASTEXITCODE -ne 0) {
    throw "ai.routes.js syntax check failed."
  }

  node `
    "scripts\testAiService.js"

  if ($LASTEXITCODE -ne 0) {
    throw "Node-to-FastAPI bridge test failed."
  }

  Write-Host ""
  Write-Host "STEP 4/4 — Flutter static validation" `
    -ForegroundColor Cyan

  Set-Location "$root\mobile_app"

  & $dart format `
    "lib\features\ai\screens\ai_wellness_screen.dart" `
    "lib\features\ai\services\ai_mobile_service.dart" `
    "lib\features\safety\widgets\safety_escalation_card.dart"

  if ($LASTEXITCODE -ne 0) {
    throw "Dart format failed."
  }

  & $flutter analyze

  if ($LASTEXITCODE -ne 0) {
    throw "Flutter analyze failed."
  }

  Write-Host ""
  Write-Host (
    "AI safety E2E automated validation passed."
  ) -ForegroundColor Green

  Write-Host (
    "No database migration or source patch was applied."
  )
}
finally {
  $env:PYTHONPATH = $previousPythonPath

  Remove-Item `
    -Path $temporaryTest `
    -Force `
    -ErrorAction SilentlyContinue
}