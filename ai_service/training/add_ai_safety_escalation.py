from __future__ import annotations

from datetime import datetime
from pathlib import Path
import re
import shutil


PROJECT_ROOT = Path(r"E:\project 3\MindPulse-AI")
FLUTTER_ROOT = PROJECT_ROOT / "mobile_app"

ai_screen = (
    FLUTTER_ROOT
    / "lib"
    / "features"
    / "ai"
    / "screens"
    / "ai_wellness_screen.dart"
)

widget_dir = (
    FLUTTER_ROOT
    / "lib"
    / "features"
    / "safety"
    / "widgets"
)

widget_path = (
    widget_dir
    / "safety_escalation_card.dart"
)

emergency_screen = (
    FLUTTER_ROOT
    / "lib"
    / "features"
    / "safety"
    / "screens"
    / "emergency_support_screen.dart"
)

for required in (ai_screen, emergency_screen):
    if not required.exists():
        raise RuntimeError(
            f"Required file was not found: {required}"
        )

backup_dir = (
    PROJECT_ROOT
    / "backups"
    / (
        "safety_escalation_"
        + datetime.now().strftime("%Y%m%d_%H%M%S")
    )
)
backup_dir.mkdir(
    parents=True,
    exist_ok=True,
)

shutil.copy2(
    ai_screen,
    backup_dir / ai_screen.name,
)

if widget_path.exists():
    shutil.copy2(
        widget_path,
        backup_dir / widget_path.name,
    )

widget_dir.mkdir(
    parents=True,
    exist_ok=True,
)

WIDGET_SOURCE = r'''import 'package:flutter/material.dart';

import '../screens/emergency_support_screen.dart';

class SafetyEscalationCard extends StatelessWidget {
  const SafetyEscalationCard({
    required this.severity,
    this.title = 'Support is available',
    this.message =
        'You do not have to handle this moment alone. '
        'Consider contacting someone you trust or opening '
        'the Safety Support screen.',
    super.key,
  });

  final String severity;
  final String title;
  final String message;

  bool get _isUrgent {
    final value = severity.toLowerCase();

    return value == 'high' ||
        value == 'critical';
  }

  @override
  Widget build(BuildContext context) {
    final color = _isUrgent
        ? Colors.red.shade700
        : Colors.orange.shade800;

    return Card(
      color: _isUrgent
          ? Colors.red.shade50
          : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Icon(
                  _isUrgent
                      ? Icons
                            .health_and_safety_outlined
                      : Icons
                            .support_agent_outlined,
                  color: color,
                  size: 30,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: color,
                          fontSize: 18,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Safety level: '
                        '${severity.toUpperCase()}',
                        style: TextStyle(
                          color: color,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(message),
            const SizedBox(height: 10),
            const Text(
              'MindPulse will not call or message '
              'anyone automatically.',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: color,
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) =>
                          const EmergencySupportScreen(),
                    ),
                  );
                },
                icon: const Icon(
                  Icons
                      .health_and_safety_outlined,
                ),
                label: const Text(
                  'Open Safety Support',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
'''

widget_path.write_text(
    WIDGET_SOURCE,
    encoding="utf-8",
)

text = ai_screen.read_text(
    encoding="utf-8",
)

import_line = (
    "import '../../safety/widgets/"
    "safety_escalation_card.dart';"
)

if import_line not in text:
    material_import = (
        "import 'package:flutter/material.dart';"
    )

    if material_import not in text:
        raise RuntimeError(
            "Flutter material import was not found "
            "in ai_wellness_screen.dart."
        )

    text = text.replace(
        material_import,
        material_import + "\n\n" + import_line,
        1,
    )

card_call = "SafetyEscalationCard("

if card_call not in text:
    marker_pattern = re.compile(
        r"(\s*const SizedBox\(height:\s*12\),\s*"
        r"\n\s*const Text\(\s*"
        r"\n\s*'Key insights',)",
        re.MULTILINE,
    )

    insertion = r'''
        if (flagged) ...[
          SafetyEscalationCard(
            severity:
                safety['severity']
                    ?.toString() ??
                'moderate',
          ),
          const SizedBox(height: 12),
        ],
'''

    match = marker_pattern.search(text)

    if match is None:
        raise RuntimeError(
            "The Key insights marker was not found. "
            "The AI screen was not modified."
        )

    text = (
        text[:match.start()]
        + insertion
        + text[match.start():]
    )

ai_screen.write_text(
    text,
    encoding="utf-8",
)

print(
    "AI Journal safety escalation "
    "integrated successfully."
)
print(f"Backup created: {backup_dir}")
print(f"Created: {widget_path}")
print(f"Updated: {ai_screen}")
