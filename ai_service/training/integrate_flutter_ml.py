from pathlib import Path


ROOT = Path(
    r"E:\project 3\MindPulse-AI"
)

SERVICE_PATH = (
    ROOT
    / "mobile_app"
    / "lib"
    / "features"
    / "ai"
    / "services"
    / "ai_mobile_service.dart"
)

SCREEN_PATH = (
    ROOT
    / "mobile_app"
    / "lib"
    / "features"
    / "ai"
    / "screens"
    / "ai_wellness_screen.dart"
)


def patch_service() -> None:
    text = SERVICE_PATH.read_text(
        encoding="utf-8"
    )

    marker = (
        "  Future<Map<String, dynamic>> "
        "predictWellness({"
    )

    method_block = r'''
  Future<Map<String, dynamic>> predictWellness({
    required int moodScore,
    required int stressLevel,
    required int energyLevel,
    required double sleepHours,
    required int sleepQuality,
    required int focusLevel,
    required int motivationLevel,
    required int restlessnessLevel,
    required int workStudyPressure,
    required int physicalActivityMinutes,
    required int hydrationCups,
    required int socialWithdrawal,
  }) {
    return _authorizedRequest(
      method: 'POST',
      path: '/ai/wellness/predict',
      body: {
        'mood_score': moodScore,
        'stress_level': stressLevel,
        'energy_level': energyLevel,
        'sleep_hours': sleepHours,
        'sleep_quality': sleepQuality,
        'focus_level': focusLevel,
        'motivation_level': motivationLevel,
        'restlessness_level': restlessnessLevel,
        'work_study_pressure': workStudyPressure,
        'physical_activity_minutes':
            physicalActivityMinutes,
        'hydration_cups': hydrationCups,
        'social_withdrawal': socialWithdrawal,
      },
    );
  }

'''

    insertion_marker = (
        "  Future<Map<String, dynamic>> "
        "_authorizedRequest({"
    )

    if marker not in text:
        if insertion_marker not in text:
            raise RuntimeError(
                "Service insertion marker "
                "was not found."
            )

        text = text.replace(
            insertion_marker,
            method_block
            + insertion_marker,
            1,
        )

    SERVICE_PATH.write_text(
        text,
        encoding="utf-8",
    )


def patch_screen() -> None:
    text = SCREEN_PATH.read_text(
        encoding="utf-8"
    )

    import_line = (
        "import "
        "'ml_wellness_prediction_screen.dart';"
    )

    if import_line not in text:
        service_import = (
            "import "
            "'../services/ai_mobile_service.dart';"
        )

        if service_import not in text:
            raise RuntimeError(
                "AI service import was not found."
            )

        text = text.replace(
            service_import,
            service_import
            + "\n"
            + import_line,
            1,
        )

    text = text.replace(
        "      length: 2,",
        "      length: 3,",
        1,
    )

    old_tabs = '''            tabs: [
              Tab(icon: Icon(Icons.auto_awesome), text: 'Wellness Plan'),
              Tab(icon: Icon(Icons.menu_book_outlined), text: 'Journal AI'),
            ],'''

    new_tabs = '''            tabs: [
              Tab(
                icon: Icon(Icons.auto_awesome),
                text: 'Wellness Plan',
              ),
              Tab(
                icon: Icon(Icons.menu_book_outlined),
                text: 'Journal AI',
              ),
              Tab(
                icon: Icon(Icons.model_training_outlined),
                text: 'ML Prediction',
              ),
            ],'''

    if (
        "text: 'ML Prediction'"
        not in text
    ):
        if old_tabs not in text:
            raise RuntimeError(
                "TabBar marker was not found."
            )

        text = text.replace(
            old_tabs,
            new_tabs,
            1,
        )

    old_children = (
        "                children: "
        "[_buildWellnessTab(), "
        "_buildJournalTab()],"
    )

    new_children = '''                children: [
                  _buildWellnessTab(),
                  _buildJournalTab(),
                  const MlWellnessPredictionScreen(),
                ],'''

    if (
        "const MlWellnessPredictionScreen()"
        not in text
    ):
        if old_children not in text:
            raise RuntimeError(
                "TabBarView marker was not found."
            )

        text = text.replace(
            old_children,
            new_children,
            1,
        )

    SCREEN_PATH.write_text(
        text,
        encoding="utf-8",
    )


def main() -> None:
    patch_service()
    patch_screen()

    print(
        "Flutter ML integration completed."
    )

    print(
        "New tab: ML Prediction"
    )


if __name__ == "__main__":
    main()
