import 'package:flutter/material.dart';

class ReminderAdaptiveControls extends StatelessWidget {
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
    return pauseUntil > DateTime.now().millisecondsSinceEpoch;
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

  String _pauseLabel(BuildContext context) {
    if (!_isPaused) {
      return 'Not paused';
    }

    final dateTime = DateTime.fromMillisecondsSinceEpoch(pauseUntil);

    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(dateTime));

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
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune_rounded, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Comfort controls',
                  style: TextStyle(fontWeight: FontWeight.bold),
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

          if (lastFeedback.isNotEmpty && lastFeedback != 'none')
            Text(
              'Last feedback: '
              '$lastFeedback',
              style: const TextStyle(fontSize: 12),
            ),

          const SizedBox(height: 10),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onHelpful,
                icon: const Icon(Icons.thumb_up_alt_outlined),
                label: const Text('Helpful'),
              ),

              OutlinedButton.icon(
                onPressed: frequencyLevel >= 2 ? null : onRemindLess,
                icon: const Icon(Icons.remove_circle_outline),
                label: Text(
                  frequencyLevel >= 2 ? 'Lowest frequency' : 'Remind less',
                ),
              ),

              OutlinedButton.icon(
                onPressed: onPauseThreeDays,
                icon: const Icon(Icons.pause_circle_outline),
                label: const Text('Pause 3 days'),
              ),

              if (_isPaused || frequencyLevel > 0)
                TextButton.icon(
                  onPressed: onResumeNormal,
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Resume normal'),
                ),
            ],
          ),

          const SizedBox(height: 4),

          const Text(
            'MindPulse never increases reminder '
            'frequency automatically.',
            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}
