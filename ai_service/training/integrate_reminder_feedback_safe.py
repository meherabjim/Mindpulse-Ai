from __future__ import annotations

from datetime import datetime
from pathlib import Path
import re
import shutil


PROJECT_ROOT = Path(r"E:\project 3\MindPulse-AI")
FLUTTER_ROOT = PROJECT_ROOT / "mobile_app"
KOTLIN_ROOT = (
    FLUTTER_ROOT
    / "android"
    / "app"
    / "src"
    / "main"
    / "kotlin"
)

main_activity = next(
    KOTLIN_ROOT.rglob("MainActivity.kt"),
    None,
)

if main_activity is None:
    raise RuntimeError(
        "MainActivity.kt was not found."
    )

kotlin_dir = main_activity.parent

worker_path = (
    kotlin_dir
    / "SmartReminderWorker.kt"
)

screen_path = (
    FLUTTER_ROOT
    / "lib"
    / "features"
    / "reminders"
    / "screens"
    / "smart_reminder_center_screen.dart"
)

widget_dir = (
    FLUTTER_ROOT
    / "lib"
    / "features"
    / "reminders"
    / "widgets"
)

widget_path = (
    widget_dir
    / "reminder_adaptive_controls.dart"
)

for required_file in [
    worker_path,
    screen_path,
]:
    if not required_file.exists():
        raise RuntimeError(
            f"Required file not found: "
            f"{required_file}"
        )

backup_dir = (
    PROJECT_ROOT
    / "backups"
    / (
        "reminder_feedback_"
        + datetime.now().strftime(
            "%Y%m%d_%H%M%S"
        )
    )
)

backup_dir.mkdir(
    parents=True,
    exist_ok=True,
)

for source in [
    worker_path,
    screen_path,
]:
    shutil.copy2(
        source,
        backup_dir / source.name,
    )

widget_dir.mkdir(
    parents=True,
    exist_ok=True,
)


WIDGET_SOURCE = r'''import 'package:flutter/material.dart';

class ReminderAdaptiveControls
    extends StatelessWidget {
  const ReminderAdaptiveControls({
    required this.frequencyLevel,
    required this.pauseUntil,
    required this.helpfulCount,
    required this.lastFeedback,
    required this.onHelpful,
    required this.onRemindLess,
    required this.onPauseThreeDays,
    required this.onResumeNormal,
    super.key,
  });

  final int frequencyLevel;
  final int pauseUntil;
  final int helpfulCount;
  final String lastFeedback;

  final VoidCallback onHelpful;
  final VoidCallback onRemindLess;
  final VoidCallback onPauseThreeDays;
  final VoidCallback onResumeNormal;

  bool get _isPaused {
    return pauseUntil >
        DateTime.now()
            .millisecondsSinceEpoch;
  }

  String get _frequencyLabel {
    switch (frequencyLevel) {
      case 1:
        return 'Less frequent';

      case 2:
        return 'Minimum frequency';

      default:
        return 'Normal frequency';
    }
  }

  String _pauseLabel(
    BuildContext context,
  ) {
    if (!_isPaused) {
      return 'Not paused';
    }

    final dateTime =
        DateTime
            .fromMillisecondsSinceEpoch(
              pauseUntil,
            );

    final time =
        MaterialLocalizations.of(context)
            .formatTimeOfDay(
              TimeOfDay.fromDateTime(
                dateTime,
              ),
            );

    return 'Paused until '
        '${dateTime.day}/'
        '${dateTime.month}/'
        '${dateTime.year} '
        '$time';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin:
          const EdgeInsets.only(
        top: 8,
      ),
      padding:
          const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(
              alpha: 0.45,
            ),
        borderRadius:
            BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.tune_rounded,
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Comfort controls',
                  style: TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            '$_frequencyLabel · '
            '${_pauseLabel(context)}',
          ),

          if (helpfulCount > 0)
            Text(
              'Marked helpful '
              '$helpfulCount time(s).',
            ),

          if (
              lastFeedback.isNotEmpty &&
              lastFeedback != 'none')
            Text(
              'Last feedback: '
              '$lastFeedback',
              style: const TextStyle(
                fontSize: 12,
              ),
            ),

          const SizedBox(height: 10),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onHelpful,
                icon: const Icon(
                  Icons
                      .thumb_up_alt_outlined,
                ),
                label: const Text(
                  'Helpful',
                ),
              ),

              OutlinedButton.icon(
                onPressed:
                    frequencyLevel >= 2
                        ? null
                        : onRemindLess,
                icon: const Icon(
                  Icons
                      .remove_circle_outline,
                ),
                label: Text(
                  frequencyLevel >= 2
                      ? 'Lowest frequency'
                      : 'Remind less',
                ),
              ),

              OutlinedButton.icon(
                onPressed:
                    onPauseThreeDays,
                icon: const Icon(
                  Icons
                      .pause_circle_outline,
                ),
                label: const Text(
                  'Pause 3 days',
                ),
              ),

              if (
                  _isPaused ||
                  frequencyLevel > 0)
                TextButton.icon(
                  onPressed:
                      onResumeNormal,
                  icon: const Icon(
                    Icons.restart_alt_rounded,
                  ),
                  label: const Text(
                    'Resume normal',
                  ),
                ),
            ],
          ),

          const SizedBox(height: 4),

          const Text(
            'MindPulse never increases reminder '
            'frequency automatically.',
            style: TextStyle(
              fontSize: 12,
              fontStyle:
                  FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
'''


def patch_screen() -> None:
    text = screen_path.read_text(
        encoding="utf-8"
    )

    import_line = (
        "import '../widgets/"
        "reminder_adaptive_controls.dart';"
    )

    if import_line not in text:
        marker = (
            "import '../services/"
            "smart_reminder_service.dart';"
        )

        if marker not in text:
            raise RuntimeError(
                "Reminder service import "
                "was not found."
            )

        text = text.replace(
            marker,
            marker + "\n" + import_line,
            1,
        )

    if (
        "ReminderAdaptiveControls("
        not in text
    ):
        marker = '''          Align(
            alignment: Alignment.centerLeft,

            child: TextButton.icon(
'''

        block = '''          ReminderAdaptiveControls(
            frequencyLevel:
                (reminder['frequency_level']
                            as num?)
                        ?.toInt() ??
                    0,
            pauseUntil:
                (reminder['pause_until']
                            as num?)
                        ?.toInt() ??
                    0,
            helpfulCount:
                (reminder['helpful_count']
                            as num?)
                        ?.toInt() ??
                    0,
            lastFeedback:
                reminder['last_feedback']
                        ?.toString() ??
                    'none',
            onHelpful: () {
              _updateConfiguration(() {
                final reminders =
                    _reminders;

                final currentCount =
                    (reminders[index]
                                ['helpful_count']
                            as num?)
                        ?.toInt() ??
                    0;

                reminders[index]
                    ['helpful_count'] =
                    currentCount + 1;

                reminders[index]
                    ['last_feedback'] =
                    'helpful';

                _configuration[
                  'reminders'
                ] = reminders;
              });
            },
            onRemindLess: () {
              _updateConfiguration(() {
                final reminders =
                    _reminders;

                final currentLevel =
                    (reminders[index]
                                ['frequency_level']
                            as num?)
                        ?.toInt() ??
                    0;

                reminders[index]
                    ['frequency_level'] =
                    (currentLevel + 1)
                        .clamp(0, 2)
                        .toInt();

                reminders[index]
                    ['last_feedback'] =
                    'remind_less';

                _configuration[
                  'reminders'
                ] = reminders;
              });
            },
            onPauseThreeDays: () {
              _updateConfiguration(() {
                final reminders =
                    _reminders;

                reminders[index]
                    ['pause_until'] =
                    DateTime.now()
                        .add(
                          const Duration(
                            days: 3,
                          ),
                        )
                        .millisecondsSinceEpoch;

                reminders[index]
                    ['last_feedback'] =
                    'paused_3_days';

                _configuration[
                  'reminders'
                ] = reminders;
              });
            },
            onResumeNormal: () {
              _updateConfiguration(() {
                final reminders =
                    _reminders;

                reminders[index]
                    ['frequency_level'] =
                    0;

                reminders[index]
                    ['pause_until'] =
                    0;

                reminders[index]
                    ['last_feedback'] =
                    'normal';

                _configuration[
                  'reminders'
                ] = reminders;
              });
            },
          ),

          const SizedBox(height: 8),

          Align(
            alignment: Alignment.centerLeft,

            child: TextButton.icon(
'''

        if marker not in text:
            raise RuntimeError(
                "Reminder test button marker "
                "was not found."
            )

        text = text.replace(
            marker,
            block,
            1,
        )

    screen_path.write_text(
        text,
        encoding="utf-8",
    )


def patch_worker() -> None:
    text = worker_path.read_text(
        encoding="utf-8"
    )

    import_line = (
        "import java.util.concurrent.TimeUnit"
    )

    if import_line not in text:
        marker = (
            "import java.util.Locale"
        )

        if marker not in text:
            raise RuntimeError(
                "Worker Locale import "
                "was not found."
            )

        text = text.replace(
            marker,
            marker + "\n" + import_line,
            1,
        )

    if (
        'reminder.optLong(\n'
        '                    "pause_until"'
        not in text
    ):
        marker = '''            if (reminderId.isBlank()) {
                continue
            }
'''

        block = '''            if (reminderId.isBlank()) {
                continue
            }

            val pauseUntil =
                reminder.optLong(
                    "pause_until",
                    0L
                )

            if (pauseUntil > now) {
                continue
            }

            val frequencyLevel =
                reminder.optInt(
                    "frequency_level",
                    0
                ).coerceIn(
                    0,
                    2
                )
'''

        if marker not in text:
            raise RuntimeError(
                "Worker reminder ID marker "
                "was not found."
            )

        text = text.replace(
            marker,
            block,
            1,
        )

    if (
        '"adaptive_last_delivery_'
        not in text
    ):
        marker = '''            if (!due) {
                continue
            }
'''

        block = '''            if (
                reminderType !=
                    "interval" &&
                frequencyLevel > 0
            ) {
                val lastAdaptiveDelivery =
                    preferences.getLong(
                        "adaptive_last_delivery_" +
                            reminderId,
                        0L
                    )

                val minimumGap =
                    TimeUnit.DAYS.toMillis(
                        (
                            frequencyLevel +
                                1
                        ).toLong()
                    )

                if (
                    lastAdaptiveDelivery >
                        0L &&
                    now -
                        lastAdaptiveDelivery <
                        minimumGap
                ) {
                    continue
                }
            }

            if (!due) {
                continue
            }
'''

        if marker not in text:
            raise RuntimeError(
                "Worker due marker "
                "was not found."
            )

        text = text.replace(
            marker,
            block,
            1,
        )

        delivery_marker = '''            saveReminderDelivery(
                preferences,
                reminderId,
                reminderType,
                today,
                now
            )
'''

        delivery_block = '''            saveReminderDelivery(
                preferences,
                reminderId,
                reminderType,
                today,
                now
            )

            preferences.edit()
                .putLong(
                    "adaptive_last_delivery_" +
                        reminderId,
                    now
                )
                .apply()
'''

        if delivery_marker not in text:
            raise RuntimeError(
                "Worker delivery marker "
                "was not found."
            )

        text = text.replace(
            delivery_marker,
            delivery_block,
            1,
        )

    if (
        "effectiveIntervalMinutes"
        not in text
    ):
        marker = '''        val lastSentAt =
            preferences.getLong(
                "last_interval_$reminderId",
                0L
            )
'''

        block = '''        val frequencyLevel =
            reminder.optInt(
                "frequency_level",
                0
            ).coerceIn(
                0,
                2
            )

        val effectiveIntervalMinutes =
            (
                intervalMinutes *
                    (
                        frequencyLevel +
                            1
                    )
            ).coerceIn(
                60,
                480
            )

        val lastSentAt =
            preferences.getLong(
                "last_interval_$reminderId",
                0L
            )
'''

        if marker not in text:
            raise RuntimeError(
                "Worker interval marker "
                "was not found."
            )

        text = text.replace(
            marker,
            block,
            1,
        )

        expression = (
            "intervalMinutes * 60_000L"
        )

        if expression not in text:
            raise RuntimeError(
                "Worker interval expression "
                "was not found."
            )

        text = text.replace(
            expression,
            (
                "effectiveIntervalMinutes "
                "* 60_000L"
            ),
            1,
        )

    worker_path.write_text(
        text,
        encoding="utf-8",
    )


widget_path.write_text(
    WIDGET_SOURCE,
    encoding="utf-8",
)

patch_screen()
patch_worker()

print(
    "Reminder feedback and adaptive "
    "frequency integrated successfully."
)

print(
    f"Backup created: {backup_dir}"
)