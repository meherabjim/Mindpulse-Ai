from datetime import datetime
from pathlib import Path
import re
import shutil


path = Path(
    r"E:\project 3\MindPulse-AI\mobile_app"
    r"\lib\features\reminders\screens"
    r"\smart_reminder_center_screen.dart"
)

if not path.exists():
    raise RuntimeError(
        "Smart Reminder screen was not found."
    )

backup = (
    path.parent
    / (
        "smart_reminder_center_screen."
        + datetime.now().strftime(
            "%Y%m%d_%H%M%S"
        )
        + ".backup.dart"
    )
)

shutil.copy2(
    path,
    backup,
)

text = path.read_text(
    encoding="utf-8",
)


def find_matching(
    source: str,
    start: int,
    opening: str,
    closing: str,
) -> int:
    depth = 0

    for index in range(
        start,
        len(source),
    ):
        character = source[index]

        if character == opening:
            depth += 1
        elif character == closing:
            depth -= 1

            if depth == 0:
                return index

    raise RuntimeError(
        f"Matching {closing} was not found."
    )


# ==========================================
# Add dart:async
# ==========================================

async_import = "import 'dart:async';"

if async_import not in text:
    flutter_import = (
        "import 'package:flutter/material.dart';"
    )

    if flutter_import not in text:
        raise RuntimeError(
            "Flutter material import was not found."
        )

    text = text.replace(
        flutter_import,
        async_import
        + "\n\n"
        + flutter_import,
        1,
    )


# ==========================================
# Add auto-save state fields
# ==========================================

if "_autoSaveTimer" not in text:
    field_marker = (
        "  bool _loading = true;\n"
        "  bool _saving = false;\n"
    )

    field_replacement = (
        "  bool _loading = true;\n"
        "  bool _saving = false;\n"
        "  bool _hasPendingSave = false;\n"
        "  bool _saveInProgress = false;\n\n"
        "  Timer? _autoSaveTimer;\n"
    )

    if field_marker not in text:
        raise RuntimeError(
            "Reminder state fields were not found."
        )

    text = text.replace(
        field_marker,
        field_replacement,
        1,
    )


# ==========================================
# Replace manual _save with auto-save engine
# ==========================================

old_save_start = text.find(
    "  Future<void> _save() async {"
)

if old_save_start != -1:
    opening_brace = text.find(
        "{",
        old_save_start,
    )

    old_save_end = find_matching(
        text,
        opening_brace,
        "{",
        "}",
    )

    new_save_engine = r'''  void _updateConfiguration(
    VoidCallback update,
  ) {
    setState(update);
    _scheduleAutoSave();
  }

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();

    _hasPendingSave = true;

    if (mounted && !_saving) {
      setState(() {
        _saving = true;
      });
    }

    _autoSaveTimer = Timer(
      const Duration(
        milliseconds: 350,
      ),
      _saveAutomatically,
    );
  }

  Future<void> _saveAutomatically() async {
    if (_saveInProgress) {
      _hasPendingSave = true;
      return;
    }

    _saveInProgress = true;

    try {
      do {
        _hasPendingSave = false;

        await _service.saveConfiguration(
          _configuration,
        );
      } while (_hasPendingSave);

      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
        _errorMessage = null;
      });
    } catch (error) {
      _hasPendingSave = false;

      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
        _errorMessage =
            'Reminder settings could not be saved: '
            '$error';
      });
    } finally {
      _saveInProgress = false;
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();

    
    if (_hasPendingSave) {
      unawaited(
        _service.saveConfiguration(
          _configuration,
        ),
      );
    }

    super.dispose();
  }
'''

    text = (
        text[:old_save_start]
        + new_save_engine
        + text[old_save_end + 1:]
    )


# ==========================================
# Convert configuration setState blocks
# into auto-saving updates
# ==========================================

old_marker = "setState(() {"
new_marker = "_updateConfiguration(() {"

search_position = 0

while True:
    block_start = text.find(
        old_marker,
        search_position,
    )

    if block_start == -1:
        break

    opening_brace = text.find(
        "{",
        block_start,
    )

    block_end = find_matching(
        text,
        opening_brace,
        "{",
        "}",
    )

    block = text[
        block_start:block_end + 1
    ]

    # Only user preference changes contain
    # _configuration[...].
    # Loading/error setState blocks remain unchanged.
    if "_configuration[" in block:
        text = (
            text[:block_start]
            + new_marker
            + text[
                block_start
                + len(old_marker):
            ]
        )

        search_position = (
            block_start
            + len(new_marker)
        )
    else:
        search_position = (
            block_end + 1
        )


# ==========================================
# Replace AppBar save button with status
# ==========================================

if "'Auto-saved'" not in text:
    app_bar_start = text.find(
        "appBar: AppBar("
    )

    if app_bar_start == -1:
        raise RuntimeError(
            "AppBar was not found."
        )

    actions_start = text.find(
        "actions: [",
        app_bar_start,
    )

    if actions_start == -1:
        raise RuntimeError(
            "AppBar actions were not found."
        )

    list_open = text.find(
        "[",
        actions_start,
    )

    list_close = find_matching(
        text,
        list_open,
        "[",
        "]",
    )

    status_actions = r'''actions: [
          Padding(
            padding:
                const EdgeInsets.only(
              right: 16,
            ),
            child: Center(
              child: Row(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  Icon(
                    _saving
                        ? Icons.sync_rounded
                        : Icons
                            .cloud_done_outlined,
                    size: 18,
                  ),
                  const SizedBox(
                    width: 6,
                  ),
                  Text(
                    _saving
                        ? 'Saving...'
                        : 'Auto-saved',
                  ),
                ],
              ),
            ),
          ),
        ]'''

    text = (
        text[:actions_start]
        + status_actions
        + text[list_close + 1:]
    )


# ==========================================
# Remove bottom manual Save button
# ==========================================

save_label = text.find(
    "'Save Reminder Preferences'"
)

if save_label != -1:
    widget_start = text.rfind(
        "FilledButton.icon(",
        0,
        save_label,
    )

    if widget_start == -1:
        raise RuntimeError(
            "Bottom Save button start was not found."
        )

    line_start = text.rfind(
        "\n",
        0,
        widget_start,
    ) + 1

    opening_parenthesis = text.find(
        "(",
        widget_start,
    )

    widget_end = find_matching(
        text,
        opening_parenthesis,
        "(",
        ")",
    ) + 1

    if (
        widget_end < len(text)
        and text[widget_end] == ","
    ):
        widget_end += 1

    remaining = text[widget_end:]

    spacer_match = re.match(
        r"\s*const\s+SizedBox\(\s*"
        r"height:\s*10\s*,?\s*"
        r"\)\s*,",
        remaining,
        flags=re.DOTALL,
    )

    if spacer_match:
        widget_end += (
            spacer_match.end()
        )

    text = (
        text[:line_start]
        + text[widget_end:]
    )


# ==========================================
# Update helper text
# ==========================================

old_message = (
    "'ও vibration নিজে নির্বাচন করবেন।',"
)

new_message = (
    "'ও vibration নিজে নির্বাচন করবেন। '\n"
    "              'পরিবর্তনগুলো স্বয়ংক্রিয়ভাবে save হবে।',"
)

if (
    old_message in text
    and
    "পরিবর্তনগুলো স্বয়ংক্রিয়ভাবে save হবে"
    not in text
):
    text = text.replace(
        old_message,
        new_message,
        1,
    )


path.write_text(
    text,
    encoding="utf-8",
)

print(
    "Smart Reminder auto-save integrated successfully."
)

print(
    f"Backup created: {backup}"
)


