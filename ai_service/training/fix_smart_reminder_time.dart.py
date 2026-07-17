from pathlib import Path
import re


path = Path(
    r"E:\project 3\MindPulse-AI\mobile_app"
    r"\lib\features\reminders\screens"
    r"\smart_reminder_center_screen.dart"
)

text = path.read_text(
    encoding="utf-8",
)

function_marker = (
    "  Widget _buildReminderCard("
)

function_start = text.find(
    function_marker
)

if function_start == -1:
    raise RuntimeError(
        "_buildReminderCard function was not found."
    )


# Add simple, type-safe time variables.
if "final reminderTimeText =" not in text:
    enabled_pattern = re.compile(
        r"    final enabled\s*=\s*"
        r"reminder\['enabled'\]\s*==\s*true;"
    )

    match = enabled_pattern.search(
        text,
        function_start,
    )

    if match is None:
        raise RuntimeError(
            "Reminder enabled variable was not found."
        )

    time_variables = r'''

    final reminderHour =
        (reminder['hour'] as num?)
                ?.toInt() ??
            7;

    final reminderMinute =
        (reminder['minute'] as num?)
                ?.toInt() ??
            0;

    final reminderTimeText =
        _formatMinutes(
          reminderHour * 60 +
              reminderMinute,
        );
'''

    insert_at = match.end()

    text = (
        text[:insert_at]
        + time_variables
        + text[insert_at:]
    )


# Replace the malformed Time label.
time_position = text.find(
    "'Time: '",
    function_start,
)

if time_position == -1:
    raise RuntimeError(
        "Malformed Time label was not found."
    )

label_start = text.rfind(
    "              label: Text(",
    function_start,
    time_position,
)

if label_start == -1:
    raise RuntimeError(
        "Time label start was not found."
    )

label_end_marker = (
    "\n              ),\n"
    "            ),"
)

label_end = text.find(
    label_end_marker,
    time_position,
)

if label_end == -1:
    raise RuntimeError(
        "Time label ending was not found."
    )

label_end += len(
    "\n              ),"
)

correct_label = """              label: Text(
                'Time: $reminderTimeText',
              ),"""

text = (
    text[:label_start]
    + correct_label
    + text[label_end:]
)

path.write_text(
    text,
    encoding="utf-8",
)

print(
    "Smart Reminder time expression fixed successfully."
)
