from datetime import datetime
from pathlib import Path
import re
import shutil


screen_path = Path(
    r"E:\project 3\MindPulse-AI\mobile_app"
    r"\lib\features\reminders\screens"
    r"\smart_reminder_center_screen.dart"
)

if not screen_path.exists():
    raise RuntimeError(
        "Smart Reminder screen was not found."
    )

backup_path = screen_path.with_name(
    "smart_reminder_center_screen."
    + datetime.now().strftime(
        "%Y%m%d_%H%M%S"
    )
    + ".before_wakeup_v2.dart"
)

shutil.copy2(
    screen_path,
    backup_path,
)

text = screen_path.read_text(
    encoding="utf-8",
)


# ------------------------------------------
# 1. Add default wake-up configuration
# ------------------------------------------

if "'wake_up_minutes':" not in text:
    pattern = re.compile(
        r"('master_enabled'\s*:\s*false\s*,)"
    )

    text, count = pattern.subn(
        r"\1"
        "\n      'wake_up_minutes': 420,"
        "\n      'morning_delay_minutes': 20,",
        text,
        count=1,
    )

    if count != 1:
        raise RuntimeError(
            "Master configuration marker "
            "was not found."
        )


# ------------------------------------------
# 2. Normalize older saved configurations
# ------------------------------------------

normalization_call = (
    "_ensureMorningRoutineConfiguration();"
)

if normalization_call not in text:
    pattern = re.compile(
        r"(_configuration\s*=\s*"
        r"stored\s*\?\?\s*"
        r"_defaultConfiguration\s*;)"
    )

    text, count = pattern.subn(
        r"\1"
        "\n\n        "
        "_ensureMorningRoutineConfiguration();",
        text,
        count=1,
    )

    if count != 1:
        raise RuntimeError(
            "Stored configuration assignment "
            "was not found."
        )


# ------------------------------------------
# 3. Add Morning Routine methods and card
# ------------------------------------------

if (
    "Widget _buildMorningRoutineCard()"
    not in text
):
    insertion_marker = (
        "  Widget _buildHumanCentredCard() {"
    )

    if insertion_marker not in text:
        raise RuntimeError(
            "Human-centred card function "
            "was not found."
        )

    morning_methods = r'''  void _ensureMorningRoutineConfiguration() {
    _configuration.putIfAbsent(
      'wake_up_minutes',
      () => 420,
    );

    _configuration.putIfAbsent(
      'morning_delay_minutes',
      () => 20,
    );

    _applyMorningSchedule();
  }

  int _configurationMinutes(
    String key,
    int fallback,
    int minimum,
    int maximum,
  ) {
    final value =
        (_configuration[key] as num?)
                ?.toInt() ??
            fallback;

    return value
        .clamp(minimum, maximum)
        .toInt();
  }

  void _applyMorningSchedule() {
    final wakeUpMinutes =
        _configurationMinutes(
      'wake_up_minutes',
      420,
      0,
      1439,
    );

    final delayMinutes =
        _configurationMinutes(
      'morning_delay_minutes',
      20,
      0,
      120,
    );

    final scheduledMinutes =
        (wakeUpMinutes + delayMinutes) %
            1440;

    final reminders = _reminders;

    final morningIndex =
        reminders.indexWhere(
      (reminder) =>
          reminder['id'] ==
          'morning_checkin',
    );

    if (morningIndex < 0) {
      return;
    }

    reminders[morningIndex]['hour'] =
        scheduledMinutes ~/ 60;

    reminders[morningIndex]['minute'] =
        scheduledMinutes % 60;

    _configuration['reminders'] =
        reminders;
  }

  Future<void> _pickWakeUpTime() async {
    final currentMinutes =
        _configurationMinutes(
      'wake_up_minutes',
      420,
      0,
      1439,
    );

    final selected =
        await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: currentMinutes ~/ 60,
        minute: currentMinutes % 60,
      ),
      helpText:
          'আপনি সাধারণত কয়টায় ঘুম থেকে ওঠেন?',
    );

    if (
        selected == null ||
        !mounted
    ) {
      return;
    }

    _updateConfiguration(() {
      _configuration[
        'wake_up_minutes'
      ] =
          selected.hour * 60 +
          selected.minute;

      _applyMorningSchedule();
    });
  }

  Widget _buildMorningRoutineCard() {
    final wakeUpMinutes =
        _configurationMinutes(
      'wake_up_minutes',
      420,
      0,
      1439,
    );

    final delayMinutes =
        _configurationMinutes(
      'morning_delay_minutes',
      20,
      0,
      120,
    );

    final checkInMinutes =
        (wakeUpMinutes + delayMinutes) %
            1440;

    const supportedDelays = <int>[
      10,
      20,
      30,
      45,
      60,
    ];

    final selectedDelay =
        supportedDelays.contains(
          delayMinutes,
        )
            ? delayMinutes
            : 20;

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.wb_sunny_outlined,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Morning Routine',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'আপনি কখন ঘুম থেকে ওঠেন সেটি নির্বাচন করুন। '
              'MindPulse আপনার পছন্দ অনুযায়ী কিছুক্ষণ পরে '
              'gentle Morning Check-in reminder দেবে।',
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed:
                  _pickWakeUpTime,
              icon: const Icon(
                Icons.alarm_outlined,
              ),
              label: Text(
                'Wake-up time: '
                '${_formatMinutes(wakeUpMinutes)}',
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<int>(
              key: ValueKey<int>(
                selectedDelay,
              ),
              initialValue:
                  selectedDelay,
              decoration:
                  const InputDecoration(
                labelText:
                    'Check-in reminder delay',
                border:
                    OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem<int>(
                  value: 10,
                  child: Text(
                    'ঘুম থেকে ওঠার 10 মিনিট পরে',
                  ),
                ),
                DropdownMenuItem<int>(
                  value: 20,
                  child: Text(
                    'ঘুম থেকে ওঠার 20 মিনিট পরে',
                  ),
                ),
                DropdownMenuItem<int>(
                  value: 30,
                  child: Text(
                    'ঘুম থেকে ওঠার 30 মিনিট পরে',
                  ),
                ),
                DropdownMenuItem<int>(
                  value: 45,
                  child: Text(
                    'ঘুম থেকে ওঠার 45 মিনিট পরে',
                  ),
                ),
                DropdownMenuItem<int>(
                  value: 60,
                  child: Text(
                    'ঘুম থেকে ওঠার 1 ঘণ্টা পরে',
                  ),
                ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                _updateConfiguration(() {
                  _configuration[
                    'morning_delay_minutes'
                  ] = value;

                  _applyMorningSchedule();
                });
              },
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(
                      alpha: 0.35,
                    ),
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
              ),
              child: Text(
                'Morning Check-in প্রায় '
                '${_formatMinutes(checkInMinutes)}-এ আসবে।',
                style: const TextStyle(
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'এটি wake-up alarm নয়। Morning Check-in '
              'চালু থাকলে gentle notification এবং '
              'আপনার নির্বাচিত voice বা vibration ব্যবহার হবে।',
              style: TextStyle(
                fontSize: 12,
                fontStyle:
                    FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

'''

    text = text.replace(
        insertion_marker,
        morning_methods +
        insertion_marker,
        1,
    )


# ------------------------------------------
# 4. Add card between master and quiet hours
# ------------------------------------------

if "_buildMorningRoutineCard()," not in text:
    pattern = re.compile(
        r"(_buildMasterCard\(\)\s*,"
        r"\s*const SizedBox\(\s*"
        r"height\s*:\s*14\s*,?\s*"
        r"\)\s*,)"
        r"(\s*_buildQuietHoursCard\(\)\s*,)"
    )

    replacement = (
        r"\1"
        "\n\n          "
        "_buildMorningRoutineCard(),"
        "\n\n          "
        "const SizedBox(height: 14),"
        r"\2"
    )

    text, count = pattern.subn(
        replacement,
        text,
        count=1,
    )

    if count != 1:
        raise RuntimeError(
            "Master and Quiet Hours cards "
            "could not be located."
        )


# ------------------------------------------
# 5. Detect Morning Check-in card
# ------------------------------------------

function_start = text.find(
    "  Widget _buildReminderCard("
)

if function_start == -1:
    raise RuntimeError(
        "Reminder card function "
        "was not found."
    )

if (
    "final isMorningCheckIn ="
    not in text[function_start:]
):
    function_text = text[function_start:]

    pattern = re.compile(
        r"(final\s+isInterval\s*=\s*"
        r"reminder\['type'\]\s*==\s*"
        r"'interval'\s*;)"
    )

    replacement = (
        r"\1"
        "\n\n    final isMorningCheckIn ="
        "\n        reminder['id'] =="
        "\n        'morning_checkin';"
    )

    patched_function, count = (
        pattern.subn(
            replacement,
            function_text,
            count=1,
        )
    )

    if count != 1:
        raise RuntimeError(
            "Formatted isInterval declaration "
            "was not found."
        )

    text = (
        text[:function_start] +
        patched_function
    )


# ------------------------------------------
# 6. Make Morning Check-in time read-only
# ------------------------------------------

if (
    "Automatically set from Morning Routine"
    not in text
):
    function_start = text.find(
        "  Widget _buildReminderCard("
    )

    interval_position = text.find(
        "if (isInterval)",
        function_start,
    )

    if interval_position == -1:
        raise RuntimeError(
            "Interval reminder UI "
            "was not found."
        )

    remaining = text[interval_position:]

    pattern = re.compile(
        r"\n(\s*)else\s*"
        r"\n\s*OutlinedButton\.icon\("
    )

    replacement = r'''
          else if (isMorningCheckIn)
            InputDecorator(
              decoration:
                  const InputDecoration(
                labelText:
                    'Morning Check-in time',
                helperText:
                    'Automatically set from Morning Routine',
                border:
                    OutlineInputBorder(),
              ),
              child: Text(
                reminderTimeText,
                style: const TextStyle(
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            )
          else
            OutlinedButton.icon('''

    patched_remaining, count = (
        pattern.subn(
            replacement,
            remaining,
            count=1,
        )
    )

    if count != 1:
        raise RuntimeError(
            "Daily reminder time button "
            "was not found."
        )

    text = (
        text[:interval_position] +
        patched_remaining
    )


screen_path.write_text(
    text,
    encoding="utf-8",
)

print(
    "Wake-up routine integrated successfully."
)

print(
    f"Backup created: {backup_path}"
)

