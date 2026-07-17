from datetime import datetime
from pathlib import Path
import re
import shutil


project_root = Path(
    r"E:\project 3\MindPulse-AI"
)

mobile_root = (
    project_root
    / "mobile_app"
)

wellness_path = (
    mobile_root
    / "lib"
    / "features"
    / "wellness"
    / "screens"
    / "wellness_scan_screen.dart"
)

safety_widget_path = (
    mobile_root
    / "lib"
    / "features"
    / "safety"
    / "widgets"
    / "safety_escalation_card.dart"
)

for required_path in (
    wellness_path,
    safety_widget_path,
):
    if not required_path.exists():
        raise RuntimeError(
            f"Required file was not found: "
            f"{required_path}"
        )

backup_dir = (
    project_root
    / "backups"
    / (
        "wellness_scan_safety_"
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
    wellness_path,
    backup_dir / wellness_path.name,
)

shutil.copy2(
    safety_widget_path,
    backup_dir / safety_widget_path.name,
)


# =========================================
# 1. Update reusable safety card
# Elevated wellness risk should use urgent UI
# =========================================

widget_text = safety_widget_path.read_text(
    encoding="utf-8",
)

if "value == 'elevated'" not in widget_text:
    urgent_pattern = re.compile(
        r"return\s+value\s*==\s*'high'\s*"
        r"\|\|\s*"
        r"value\s*==\s*'critical'\s*;"
    )

    urgent_replacement = (
        "return value == 'elevated' ||\n"
        "        value == 'high' ||\n"
        "        value == 'critical';"
    )

    widget_text, count = urgent_pattern.subn(
        urgent_replacement,
        widget_text,
        count=1,
    )

    if count != 1:
        raise RuntimeError(
            "Safety-card urgency condition "
            "was not found."
        )

    safety_widget_path.write_text(
        widget_text,
        encoding="utf-8",
    )


# =========================================
# 2. Add SafetyEscalationCard import
# =========================================

wellness_text = wellness_path.read_text(
    encoding="utf-8",
)

import_line = (
    "import '../../safety/widgets/"
    "safety_escalation_card.dart';"
)

if import_line not in wellness_text:
    material_import = (
        "import 'package:flutter/material.dart';"
    )

    if material_import not in wellness_text:
        raise RuntimeError(
            "Flutter material import "
            "was not found."
        )

    wellness_text = wellness_text.replace(
        material_import,
        material_import
        + "\n\n"
        + import_line,
        1,
    )


# =========================================
# 3. Add elevated-risk condition
# Only inside WellnessScanResultScreen
# =========================================

class_marker = (
    "class WellnessScanResultScreen "
    "extends StatelessWidget"
)

class_start = wellness_text.find(
    class_marker
)

if class_start == -1:
    raise RuntimeError(
        "WellnessScanResultScreen "
        "was not found."
    )

result_text = wellness_text[class_start:]

condition_marker = (
    "final showSafetySupport ="
)

if condition_marker not in result_text:
    risk_color_marker = (
        "    final riskColor = "
        "_riskColor(riskLevel);"
    )

    risk_color_position = result_text.find(
        risk_color_marker
    )

    if risk_color_position == -1:
        raise RuntimeError(
            "Result riskColor declaration "
            "was not found."
        )

    condition_block = '''

    final normalizedRisk =
        riskLevel.toLowerCase();

    final showSafetySupport =
        normalizedRisk == 'elevated' ||
        normalizedRisk == 'high' ||
        normalizedRisk == 'critical' ||
        score >= 70;
'''

    insert_at = (
        risk_color_position
        + len(risk_color_marker)
    )

    result_text = (
        result_text[:insert_at]
        + condition_block
        + result_text[insert_at:]
    )

    wellness_text = (
        wellness_text[:class_start]
        + result_text
    )


# =========================================
# 4. Add card after risk-score header
# =========================================

class_start = wellness_text.find(
    class_marker
)

result_text = wellness_text[class_start:]

wellness_card_marker = (
    "title: "
    "'Elevated wellness support'"
)

if wellness_card_marker not in result_text:
    summary_marker = '''          const SizedBox(height: 16),
          _informationCard(
            icon: Icons.insights_outlined,
            title: 'Result Summary','''

    safety_block = '''          const SizedBox(height: 16),
          if (showSafetySupport) ...[
            SafetyEscalationCard(
              severity: riskLevel,
              title:
                  'Elevated wellness support',
              message:
                  'This scan shows elevated '
                  'wellness strain. Consider '
                  'contacting someone you trust '
                  'or seeking qualified support. '
                  'Use local emergency support '
                  'when there is immediate danger.',
            ),
            const SizedBox(height: 16),
          ],
          _informationCard(
            icon: Icons.insights_outlined,
            title: 'Result Summary','''

    if summary_marker not in result_text:
        raise RuntimeError(
            "Result Summary insertion marker "
            "was not found."
        )

    result_text = result_text.replace(
        summary_marker,
        safety_block,
        1,
    )

    wellness_text = (
        wellness_text[:class_start]
        + result_text
    )


wellness_path.write_text(
    wellness_text,
    encoding="utf-8",
)

print(
    "Wellness Scan safety integration "
    "completed successfully."
)

print(
    f"Backup created: {backup_dir}"
)

print(
    f"Updated: {wellness_path}"
)

print(
    f"Updated: {safety_widget_path}"
)
