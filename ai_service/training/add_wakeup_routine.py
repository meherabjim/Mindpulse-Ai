from datetime import datetime
from pathlib import Path
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
    + ".before_wakeup.dart"
)

shutil.copy2(
    screen_path,
    backup_path,
)

text = screen_path.read_text(
    encoding="utf-8",
)


# ==========================================
# 1. Add wake-up configuration defaults
# ==========================================

if "'wake_up_minutes':" not in text:
    marker = (
        "      'master_enabled': false,\n"
    )

    replacement = (
        "      'master_enabled': false,\n"
        "      'wake_up_minutes': 420,\n"
        "      'morning_delay_minutes': 20,\n"
    )

    if marker not in text:
        raise RuntimeError(
            "Default configuration marker "
            "was not found."
        )

    text = text.replace(
        marker,
        replacement,
        1,
    )


# ==========================================
# 2. Normalize older saved configuration
# ==========================================

normalization_call = (
    "        _ensureMorningRoutineConfiguration();"
)

if normalization_call not in text:
    marker = (
        "        _configuration =\n"
        "            stored ??\n"
        "            _defaultConfiguration;"
    )

    if marker not in text:
        marker = (
            "        _configuration = stored ?? "
            "_defaultConfiguration;"
        )

    if marker not in text:
        raise RuntimeError(
            "Configuration loading marker "
            "was not found."
        )

    text = text.replace(
        marker,
        marker
        + "\n\n"
        + normalization_call,
        1,
    )


# ==========================================
# 3. Add wake-up helper methods and card
# ==========================================

if (
    "Widget _buildMorningRoutineCard()"
    not in text
):
    insertion_marker = (
        "  Widget _buildHumanCentredCard() {"
    )

    if insertion_marker not in text:
        raise RuntimeError(
            "Human-centred card marker "
            "was not found."
        )

    new_methods = r'''  void _ensureMorningRoutineConfiguration() {
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

  void _applyMorningSchedule() {
    final wakeUpMinutes = (((
                  _configuration[
                        'wake_up_minutes'
                      ]
                      as num?
                )
                ?.toInt() ??
            420)
        .clamp(0, 1439)
        .toInt());

    final delayMinutes = (((
                  _configuration[
                        'morning_delay_minutes'
                      ]
                      as num?
                )
                ?.toInt() ??
            20)
        .clamp(0, 120)
        .toInt());

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
    final currentMinutes = (((
                  _configuration[
                        'wake_up_minutes'
                      ]
                      as num?
                )
                ?.toInt() ??
            420)
        .clamp(0, 1439)
        .toInt());

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
    final wakeUpMinutes = (((
                  _configuration[
                        'wake_up_minutes'
                      ]
                      as num?
                )
                ?.toInt() ??
            420)
        .clamp(0, 1439)
        .toInt());

    final delayMinutes = (((
                  _configuration[
                        'morning_delay_minutes'
                      ]
                      as num?
                )
                ?.toInt() ??
            20)
        .clamp(0, 120)
        .toInt());

    final checkInMinutes =
        (wakeUpMinutes + delayMinutes) %
        1440;

    final supportedDelays =
        <int>[
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
                  Icons.alarm_outlined,
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
              'আপনার ঘুম থেকে ওঠার সময় অনুযায়ী '
              'Morning Check-in reminder স্বয়ংক্রিয়ভাবে '
              'নির্ধারিত হবে।',
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed:
                  _pickWakeUpTime,
              icon: const Icon(
                Icons.wb_sunny_outlined,
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
                    'Wake-up-এর 10 মিনিট পরে',
                  ),
                ),
                DropdownMenuItem<int>(
                  value: 20,
                  child: Text(
                    'Wake-up-এর 20 মিনিট পরে',
                  ),
                ),
                DropdownMenuItem<int>(
                  value: 30,
                  child: Text(
                    'Wake-up-এর 30 মিনিট পরে',
                  ),
                ),
                DropdownMenuItem<int>(
                  value: 45,
                  child: Text(
                    'Wake-up-এর 45 মিনিট পরে',
                  ),
                ),
                DropdownMenuItem<int>(
                  value: 60,
                  child: Text(
                    'Wake-up-এর 1 ঘণ্টা পরে',
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
              'এটি loud alarm নয়। Morning Check-in '
              'চালু থাকলে gentle notification এবং '
              'আপনার নির্বাচিত voice/vibration ব্যবহার হবে।',
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
        new_methods
        + insertion_marker,
        1,
    )


# ==========================================
# 4. Add Morning Routine card to screen
# ==========================================

if "_buildMorningRoutineCard()," not in text:
    marker = (
        "          _buildMasterCard(),\n\n"
        "          const SizedBox(height: 14),\n\n"
        "          _buildQuietHoursCard(),"
    )

    replacement = (
        "          _buildMasterCard(),\n\n"
        "          const SizedBox(height: 14),\n\n"
        "          _buildMorningRoutineCard(),\n\n"
        "          const SizedBox(height: 14),\n\n"
        "          _buildQuietHoursCard(),"
    )

    if marker not in text:
        raise RuntimeError(
            "Master/Quiet Hours card marker "
            "was not found."
        )

    text = text.replace(
        marker,
        replacement,
        1,
    )


# ==========================================
# 5. Make morning reminder time read-only
# ==========================================

function_marker = (
    "  Widget _buildReminderCard("
)

function_start = text.find(
    function_marker
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
    marker = (
        "    final isInterval =\n"
        "        reminder['type'] ==\n"
        "        'interval';"
    )

    replacement = (
        marker
        + "\n\n"
        + "    final isMorningCheckIn =\n"
        + "        reminder['id'] ==\n"
        + "        'morning_checkin';"
    )

    if marker not in text[function_start:]:
        raise RuntimeError(
            "Reminder type marker "
            "was not found."
        )

    absolute_position = text.find(
        marker,
        function_start,
    )

    text = (
        text[:absolute_position]
        + replacement
        + text[
            absolute_position
            + len(marker):
        ]
    )


if (
    "'Automatically set from Morning Routine'"
    not in text
):
    target = (
        "          else\n"
        "            OutlinedButton.icon("
    )

    replacement = r'''          else if (isMorningCheckIn)
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

    position = text.find(
        target,
        function_start,
    )

    if position == -1:
        raise RuntimeError(
            "Reminder time button marker "
            "was not found."
        )

    text = (
        text[:position]
        + replacement
        + text[
            position
            + len(target):
        ]
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
