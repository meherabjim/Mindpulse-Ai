from __future__ import annotations

from datetime import datetime
from pathlib import Path
import re
import shutil


ROOT = Path(
    r"E:\project 3\MindPulse-AI"
)

SCREEN = (
    ROOT
    / "mobile_app"
    / "lib"
    / "features"
    / "ai"
    / "screens"
    / "ai_wellness_screen.dart"
)

if not SCREEN.exists():
    raise RuntimeError(
        f"AI wellness screen was not found: "
        f"{SCREEN}"
    )


backup_dir = (
    ROOT
    / "backups"
    / (
        "ai_slider_guidance_"
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
    SCREEN,
    backup_dir / SCREEN.name,
)


text = SCREEN.read_text(
    encoding="utf-8",
)


wellness_start = text.find(
    "  Widget _buildWellnessTab()"
)

wellness_end = text.find(
    "  Widget _buildWellnessResult()",
    wellness_start,
)

if (
    wellness_start == -1
    or wellness_end == -1
):
    raise RuntimeError(
        "Wellness input section was not found."
    )


before = text[:wellness_start]
wellness_section = text[
    wellness_start:wellness_end
]
after = text[wellness_end:]


method_match = re.search(
    r"([A-Za-z_][A-Za-z0-9_]*)"
    r"\(\s*\n\s*title:\s*'Mood'\s*,",
    wellness_section,
)

if method_match is None:
    raise RuntimeError(
        "Mood slider call was not found."
    )

slider_method = method_match.group(1)


slider_settings = {
    "Mood": {
        "left": "Very low",
        "right": "Very good",
        "helper": (
            "Choose how your mood feels today. "
            "A lower value indicates more strain."
        ),
    },

    "Stress": {
        "left": "Very low",
        "right": "Very high",
        "helper": (
            "Choose your current stress level. "
            "A higher value indicates more strain."
        ),
    },

    "Energy": {
        "left": "Very low",
        "right": "Very high",
        "helper": (
            "Choose your current energy level. "
            "A lower value indicates more strain."
        ),
    },

    "Sleep": {
        "left": "0 hours",
        "right": "12 hours",
        "helper": (
            "Enter the approximate hours slept. "
            "This prototype treats less than "
            "7 hours as a sleep deficit."
        ),
    },

    "Hydration": {
        "left": "0 cups",
        "right": "16 cups",
        "helper": (
            "Hydration is used to select practical "
            "guidance. It does not directly change "
            "the strain indicator."
        ),
    },

    "Existing burnout score": {
        "left": "0",
        "right": "100",
        "helper": (
            "Use the most recent available burnout "
            "indicator. A higher value increases "
            "the combined strain indicator."
        ),
    },
}


def add_guidance(
    source: str,
    title: str,
    left: str,
    right: str,
    helper: str,
) -> tuple[str, bool]:
    escaped_title = re.escape(title)

    pattern = re.compile(
        rf"({re.escape(slider_method)}"
        rf"\(\s*\n"
        rf"(?P<indent>\s*)"
        rf"title:\s*'{escaped_title}'\s*,)"
    )

    match = pattern.search(source)

    if match is None:
        raise RuntimeError(
            f"Slider was not found: {title}"
        )

    block_preview = source[
        match.start():
        min(
            len(source),
            match.start() + 700,
        )
    ]

    if "leftLabel:" in block_preview:
        return source, False

    indent = match.group("indent")

    insertion = (
        match.group(1)
        + "\n"
        + indent
        + f"leftLabel: '{left}',"
        + "\n"
        + indent
        + f"rightLabel: '{right}',"
        + "\n"
        + indent
        + "helperText: "
        + repr(helper)
        + ","
    )

    source = (
        source[:match.start()]
        + insertion
        + source[match.end():]
    )

    return source, True


updated_count = 0

for title, settings in (
    slider_settings.items()
):
    wellness_section, changed = (
        add_guidance(
            wellness_section,
            title,
            settings["left"],
            settings["right"],
            settings["helper"],
        )
    )

    if changed:
        updated_count += 1


text = (
    before
    + wellness_section
    + after
)


definition_start = text.find(
    f"  Widget {slider_method}("
)

if definition_start == -1:
    raise RuntimeError(
        "Slider widget definition "
        "was not found."
    )


next_widget_match = re.search(
    r"\n  Widget "
    r"[A-Za-z_][A-Za-z0-9_]*\(",
    text[definition_start + 1:],
)

if next_widget_match is None:
    raise RuntimeError(
        "Could not determine the end "
        "of the slider widget."
    )


definition_end = (
    definition_start
    + 1
    + next_widget_match.start()
)


new_method = r'''  Widget __SLIDER_METHOD__({
    required String title,
    required String leftLabel,
    required String rightLabel,
    required String valueLabel,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    String? helperText,
  }) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme
                        .primaryContainer,
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                  ),
                  child: Text(
                    valueLabel,
                    style: TextStyle(
                      color: colorScheme
                          .onPrimaryContainer,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            if (
              helperText != null &&
              helperText.trim().isNotEmpty
            ) ...[
              const SizedBox(height: 7),
              Text(
                helperText,
                style: TextStyle(
                  color: colorScheme
                      .onSurfaceVariant,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              label: valueLabel,
              onChanged: onChanged,
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      leftLabel,
                      style: TextStyle(
                        color: colorScheme
                            .onSurfaceVariant,
                        fontSize: 12,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      rightLabel,
                      textAlign:
                          TextAlign.right,
                      style: TextStyle(
                        color: colorScheme
                            .onSurfaceVariant,
                        fontSize: 12,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
'''.replace(
    "__SLIDER_METHOD__",
    slider_method,
)


text = (
    text[:definition_start]
    + new_method
    + text[definition_end:]
)


SCREEN.write_text(
    text,
    encoding="utf-8",
)


print(
    "AI wellness slider guidance "
    "updated successfully."
)

print(
    f"Slider method detected: "
    f"{slider_method}"
)

print(
    f"Slider calls updated: "
    f"{updated_count}"
)

print(
    f"Backup created: "
    f"{backup_dir}"
)

print(
    f"Updated: {SCREEN}"
)

print(
    "Backend formulas and database "
    "were not changed."
)
