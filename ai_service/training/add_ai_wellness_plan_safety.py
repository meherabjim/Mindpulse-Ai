from datetime import datetime
from pathlib import Path
import shutil


PROJECT_ROOT = Path(
    r"E:\project 3\MindPulse-AI"
)

AI_SCREEN = (
    PROJECT_ROOT
    / "mobile_app"
    / "lib"
    / "features"
    / "ai"
    / "screens"
    / "ai_wellness_screen.dart"
)

SAFETY_WIDGET = (
    PROJECT_ROOT
    / "mobile_app"
    / "lib"
    / "features"
    / "safety"
    / "widgets"
    / "safety_escalation_card.dart"
)

for required in (
    AI_SCREEN,
    SAFETY_WIDGET,
):
    if not required.exists():
        raise RuntimeError(
            f"Required file was not found: {required}"
        )

backup_dir = (
    PROJECT_ROOT
    / "backups"
    / (
        "ai_wellness_plan_safety_"
        + datetime.now().strftime(
            "%Y%m%d_%H%M%S"
        )
    )
)

backup_dir.mkdir(
    parents=True,
    exist_ok=True,
)

shutil.copy2(
    AI_SCREEN,
    backup_dir / AI_SCREEN.name,
)

text = AI_SCREEN.read_text(
    encoding="utf-8",
)

method_start_marker = (
    "  Widget _buildWellnessResult() {"
)

method_end_marker = (
    "  Widget _buildJournalTab() {"
)

method_start = text.find(
    method_start_marker
)

method_end = text.find(
    method_end_marker,
    method_start,
)

if method_start == -1 or method_end == -1:
    raise RuntimeError(
        "AI wellness result method "
        "was not found."
    )

before = text[:method_start]
method = text[method_start:method_end]
after = text[method_end:]


condition_marker = (
    "final showSafetySupport ="
)

if condition_marker not in method:
    risk_marker = (
        "    final riskLevel = "
        "result['risk_level']"
        "?.toString() ?? 'unknown';"
    )

    if risk_marker not in method:
        raise RuntimeError(
            "Wellness risk-level declaration "
            "was not found."
        )

    condition_block = '''

    final normalizedRisk =
        riskLevel.toLowerCase();

    final showSafetySupport =
        normalizedRisk == 'elevated' ||
        normalizedRisk == 'high' ||
        normalizedRisk == 'critical' ||
        riskScore >= 70;
'''

    method = method.replace(
        risk_marker,
        risk_marker + condition_block,
        1,
    )


card_title_marker = (
    "'Elevated AI wellness support'"
)

if card_title_marker not in method:
    insertion_marker = '''        ),
        const SizedBox(height: 12),
        const Text(
          'Recommended actions','''

    replacement = '''        ),
        if (showSafetySupport) ...[
          const SizedBox(height: 12),
          SafetyEscalationCard(
            severity: riskLevel,
            title:
                'Elevated AI wellness support',
            message:
                'Your wellness indicators show '
                'elevated strain. Consider '
                'contacting someone you trust '
                'or seeking qualified support. '
                'Use emergency support when '
                'there is immediate danger.',
          ),
        ],
        const SizedBox(height: 12),
        const Text(
          'Recommended actions','''

    if insertion_marker not in method:
        raise RuntimeError(
            "Recommended actions insertion "
            "marker was not found."
        )

    method = method.replace(
        insertion_marker,
        replacement,
        1,
    )


AI_SCREEN.write_text(
    before + method + after,
    encoding="utf-8",
)

print(
    "AI Wellness Plan safety integration "
    "completed successfully."
)

print(
    f"Backup created: {backup_dir}"
)

print(
    f"Updated: {AI_SCREEN}"
)
