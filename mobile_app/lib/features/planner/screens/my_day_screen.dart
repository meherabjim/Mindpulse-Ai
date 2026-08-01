import 'package:flutter/material.dart';

import '../../../core/settings/app_preferences_controller.dart';
import '../../digital_wellbeing/screens/mindful_screen_time_screen.dart';
import '../../prayer/screens/prayer_settings_screen.dart';
import '../../reminders/screens/smart_reminder_center_screen.dart';
import '../models/my_day_task.dart';
import '../services/my_day_repository.dart';
import 'ai_guide_v3_screen.dart';

class MyDayScreen extends StatelessWidget {
  const MyDayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _MyDayPlanner(showAppBar: false);
  }
}

class DailyScheduleScreen extends StatelessWidget {
  const DailyScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _MyDayPlanner(showAppBar: true);
  }
}

class _MyDayPlanner extends StatefulWidget {
  const _MyDayPlanner({required this.showAppBar});

  final bool showAppBar;

  @override
  State<_MyDayPlanner> createState() => _MyDayPlannerState();
}

class _MyDayPlannerState extends State<_MyDayPlanner> {
  final MyDayRepository _repository = const MyDayRepository();

  bool _loading = true;
  List<MyDayTask> _allTasks = <MyDayTask>[];
  DateTime _selectedDate = MyDayTask.dateOnly(DateTime.now());
  String? _error;

  String _t(String english, String bangla) {
    return AppPreferencesController.instance.text(english, bangla);
  }

  List<MyDayTask> get _dayTasks {
    return MyDayRepository.forDate(_allTasks, _selectedDate);
  }

  Set<String> get _conflictIds {
    return MyDayRepository.conflictIds(_dayTasks);
  }

  int get _completedCount {
    return _dayTasks.where((task) => task.completed).length;
  }

  int get _skippedCount {
    return _dayTasks.where((task) => task.skipped).length;
  }

  int get _plannedMinutes {
    return _dayTasks
        .where((task) => !task.skipped)
        .fold<int>(0, (sum, task) => sum + task.durationMinutes);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final tasks = await _repository.loadTasks();

      if (!mounted) {
        return;
      }

      setState(() {
        _allTasks = tasks;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _openEditor({MyDayTask? existing}) async {
    final result = await showModalBottomSheet<MyDayTask>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _TaskEditorSheet(
        existing: existing,
        initialDate: existing?.date ?? _selectedDate,
      ),
    );

    if (result == null) {
      return;
    }

    final tasks = await _repository.upsert(_allTasks, result);

    if (!mounted) {
      return;
    }

    setState(() {
      _allTasks = tasks;
      _selectedDate = MyDayTask.dateOnly(result.date);
    });
  }

  Future<void> _setStatus(MyDayTask task, MyDayTaskStatus status) async {
    final updated = task.copyWith(status: status);
    final tasks = await _repository.upsert(_allTasks, updated);

    if (!mounted) {
      return;
    }

    setState(() {
      _allTasks = tasks;
    });
  }

  Future<void> _deleteTask(MyDayTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(_t('Delete task?', 'কাজটি মুছবেন?')),
          content: Text(
            _t(
              'This task will be removed from My Day.',
              'কাজটি আমার দিন থেকে মুছে যাবে।',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(_t('Cancel', 'বাতিল')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(_t('Delete', 'মুছুন')),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final tasks = await _repository.delete(_allTasks, task.id);

    if (!mounted) {
      return;
    }

    setState(() {
      _allTasks = tasks;
    });
  }

  void _openAiGuide() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const AiGuideV3Screen()))
        .then((_) => _load());
  }

  void _openPrayer() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PrayerSettingsScreen()),
    );
  }

  void _openReminders() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const SmartReminderCenterScreen(),
      ),
    );
  }

  void _openTimeAnalysis() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const TimeAnalysisScreen()));
  }

  Future<void> _selectDate(DateTime date) async {
    setState(() {
      _selectedDate = MyDayTask.dateOnly(date);
    });
  }

  List<DateTime> _dateOptions() {
    final today = MyDayTask.dateOnly(DateTime.now());
    return List<DateTime>.generate(
      7,
      (index) => today.add(Duration(days: index)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                18,
                widget.showAppBar ? 10 : 18,
                18,
                120,
              ),
              children: [
                _DayHeader(
                  selectedDate: _selectedDate,
                  taskCount: _dayTasks.length,
                  completedCount: _completedCount,
                  skippedCount: _skippedCount,
                  plannedMinutes: _plannedMinutes,
                  onAdd: () => _openEditor(),
                  translate: _t,
                ),
                const SizedBox(height: 16),
                _DateStrip(
                  dates: _dateOptions(),
                  selectedDate: _selectedDate,
                  onSelected: _selectDate,
                  translate: _t,
                ),
                const SizedBox(height: 16),
                _QuickActions(
                  onAiGuide: _openAiGuide,
                  onPrayer: _openPrayer,
                  onReminders: _openReminders,
                  translate: _t,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _t('Timeline', 'সময়সূচি'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _openTimeAnalysis,
                      icon: const Icon(Icons.insights_rounded, size: 18),
                      label: Text(_t('Time analysis', 'সময় বিশ্লেষণ')),
                    ),
                  ],
                ),
                if (_conflictIds.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _ConflictNotice(
                    conflictCount: _conflictIds.length,
                    translate: _t,
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  _ErrorNotice(message: _error!),
                ],
                const SizedBox(height: 10),
                if (_dayTasks.isEmpty)
                  _EmptyDay(
                    onAdd: () => _openEditor(),
                    onAiGuide: _openAiGuide,
                    translate: _t,
                  )
                else
                  for (final task in _dayTasks)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _TimelineTaskCard(
                        task: task,
                        hasConflict: _conflictIds.contains(task.id),
                        onComplete: () => _setStatus(
                          task,
                          task.completed
                              ? MyDayTaskStatus.pending
                              : MyDayTaskStatus.completed,
                        ),
                        onSkip: () => _setStatus(
                          task,
                          task.skipped
                              ? MyDayTaskStatus.pending
                              : MyDayTaskStatus.skipped,
                        ),
                        onEdit: () => _openEditor(existing: task),
                        onDelete: () => _deleteTask(task),
                        translate: _t,
                      ),
                    ),
              ],
            ),
          );

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(title: Text(_t('My Day', 'আমার দিন')))
          : null,
      body: SafeArea(child: body),
    );
  }
}

typedef _Translate = String Function(String english, String bangla);

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.selectedDate,
    required this.taskCount,
    required this.completedCount,
    required this.skippedCount,
    required this.plannedMinutes,
    required this.onAdd,
    required this.translate,
  });

  final DateTime selectedDate;
  final int taskCount;
  final int completedCount;
  final int skippedCount;
  final int plannedMinutes;
  final VoidCallback onAdd;
  final _Translate translate;

  @override
  Widget build(BuildContext context) {
    final isToday = MyDayTask.isSameDate(selectedDate, DateTime.now());

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF4B46D8), Color(0xFF765AE9)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x334B46D8),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isToday
                ? translate('Today', 'আজ')
                : _longDateLabel(context, selectedDate),
            style: const TextStyle(
              color: Color(0xFFE8E5FF),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: Text(
                  translate('My Day', 'আমার দিন'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 29,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF4B46D8),
                ),
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: Text(translate('Add', 'যোগ করুন')),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SummaryPill(
                icon: Icons.event_note_rounded,
                label: translate('$taskCount tasks', '$taskCountটি কাজ'),
              ),
              _SummaryPill(
                icon: Icons.check_circle_outline_rounded,
                label: translate(
                  '$completedCount completed',
                  '$completedCountটি সম্পন্ন',
                ),
              ),
              if (skippedCount > 0)
                _SummaryPill(
                  icon: Icons.skip_next_rounded,
                  label: translate(
                    '$skippedCount skipped',
                    '$skippedCountটি বাদ',
                  ),
                ),
              _SummaryPill(
                icon: Icons.schedule_rounded,
                label: translate(
                  '$plannedMinutes min',
                  '$plannedMinutes মিনিট',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateStrip extends StatelessWidget {
  const _DateStrip({
    required this.dates,
    required this.selectedDate,
    required this.onSelected,
    required this.translate,
  });

  final List<DateTime> dates;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelected;
  final _Translate translate;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: dates.length,
        separatorBuilder: (_, _) => const SizedBox(width: 9),
        itemBuilder: (context, index) {
          final date = dates[index];
          final selected = MyDayTask.isSameDate(date, selectedDate);
          final colors = Theme.of(context).colorScheme;

          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => onSelected(date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 66,
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: selected
                    ? colors.primary
                    : colors.surfaceContainerHighest.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? colors.primary : colors.outlineVariant,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    index == 0
                        ? translate('Today', 'আজ')
                        : _shortWeekday(date, translate),
                    style: TextStyle(
                      color: selected
                          ? colors.onPrimary
                          : colors.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      color: selected ? colors.onPrimary : colors.onSurface,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onAiGuide,
    required this.onPrayer,
    required this.onReminders,
    required this.translate,
  });

  final VoidCallback onAiGuide;
  final VoidCallback onPrayer;
  final VoidCallback onReminders;
  final _Translate translate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionButton(
            icon: Icons.menu_book_rounded,
            label: translate('AI guide', 'AI গাইড'),
            onTap: onAiGuide,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickActionButton(
            icon: Icons.notifications_active_rounded,
            label: translate('Prayer', 'নামাজ'),
            onTap: onPrayer,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickActionButton(
            icon: Icons.alarm_rounded,
            label: translate('Reminders', 'রিমাইন্ডার'),
            onTap: onReminders,
          ),
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Column(
            children: [
              Icon(icon, color: colors.primary),
              const SizedBox(height: 7),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConflictNotice extends StatelessWidget {
  const _ConflictNotice({required this.conflictCount, required this.translate});

  final int conflictCount;
  final _Translate translate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: colors.onTertiaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              translate(
                '$conflictCount tasks overlap. Edit or reschedule them.',
                '$conflictCountটি কাজের সময় মিলে গেছে। সময় পরিবর্তন করুন।',
              ),
              style: TextStyle(
                color: colors.onTertiaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(message, style: TextStyle(color: colors.onErrorContainer)),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay({
    required this.onAdd,
    required this.onAiGuide,
    required this.translate,
  });

  final VoidCallback onAdd;
  final VoidCallback onAiGuide;
  final _Translate translate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(Icons.event_available_rounded, size: 44, color: colors.primary),
          const SizedBox(height: 12),
          Text(
            translate('No tasks for this day', 'এই দিনের কোনো কাজ নেই'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            translate(
              'Add your own task or import a reading session from AI Guide.',
              'নিজের কাজ যোগ করুন অথবা AI গাইড থেকে পড়ার সেশন আনুন।',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: Text(translate('Add task', 'কাজ যোগ করুন')),
              ),
              OutlinedButton.icon(
                onPressed: onAiGuide,
                icon: const Icon(Icons.menu_book_rounded),
                label: Text(translate('Open AI guide', 'AI গাইড খুলুন')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _TaskAction { edit, skip, delete }

class _TimelineTaskCard extends StatelessWidget {
  const _TimelineTaskCard({
    required this.task,
    required this.hasConflict,
    required this.onComplete,
    required this.onSkip,
    required this.onEdit,
    required this.onDelete,
    required this.translate,
  });

  final MyDayTask task;
  final bool hasConflict;
  final VoidCallback onComplete;
  final VoidCallback onSkip;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final _Translate translate;

  String _sourceLabel() {
    switch (task.source) {
      case 'ai_guide':
        return translate('AI Guide', 'AI গাইড');
      case 'prayer':
        return translate('Prayer', 'নামাজ');
      default:
        return translate('My task', 'নিজের কাজ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final faded = task.completed || task.skipped;

    return Opacity(
      opacity: faded ? 0.68 : 1,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 62,
            child: Padding(
              padding: const EdgeInsets.only(top: 17),
              child: Text(
                _formatTime(context, task.minutesOfDay),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: hasConflict ? colors.error : colors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Material(
              color: colors.surface,
              borderRadius: BorderRadius.circular(22),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: onEdit,
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: hasConflict ? colors.error : colors.outlineVariant,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        tooltip: task.completed
                            ? translate('Mark pending', 'অসম্পন্ন করুন')
                            : translate('Complete', 'সম্পন্ন করুন'),
                        visualDensity: VisualDensity.compact,
                        onPressed: onComplete,
                        icon: Icon(
                          task.completed
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: task.completed
                              ? colors.primary
                              : colors.outline,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                decoration: task.completed
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Wrap(
                              spacing: 7,
                              runSpacing: 5,
                              children: [
                                _TaskMeta(
                                  icon: Icons.timelapse_rounded,
                                  text:
                                      '${task.durationMinutes} '
                                      '${translate('min', 'মিনিট')}',
                                ),
                                _TaskMeta(
                                  icon: Icons.category_outlined,
                                  text: task.category,
                                ),
                                _TaskMeta(
                                  icon: Icons.auto_awesome_rounded,
                                  text: _sourceLabel(),
                                ),
                              ],
                            ),
                            if (task.notes.isNotEmpty) ...[
                              const SizedBox(height: 7),
                              Text(
                                task.notes,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            if (hasConflict) ...[
                              const SizedBox(height: 8),
                              Text(
                                translate(
                                  'Time overlaps another task',
                                  'অন্য একটি কাজের সঙ্গে সময় মিলে গেছে',
                                ),
                                style: TextStyle(
                                  color: colors.error,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                            if (task.skipped) ...[
                              const SizedBox(height: 8),
                              Text(
                                translate('Skipped', 'বাদ দেওয়া হয়েছে'),
                                style: TextStyle(
                                  color: colors.tertiary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      PopupMenuButton<_TaskAction>(
                        onSelected: (action) {
                          switch (action) {
                            case _TaskAction.edit:
                              onEdit();
                              break;
                            case _TaskAction.skip:
                              onSkip();
                              break;
                            case _TaskAction.delete:
                              onDelete();
                              break;
                          }
                        },
                        itemBuilder: (_) => <PopupMenuEntry<_TaskAction>>[
                          PopupMenuItem<_TaskAction>(
                            value: _TaskAction.edit,
                            child: Text(
                              translate('Edit or reschedule', 'Edit/সময় বদলান'),
                            ),
                          ),
                          PopupMenuItem<_TaskAction>(
                            value: _TaskAction.skip,
                            child: Text(
                              task.skipped
                                  ? translate('Return to pending', 'আবার রাখুন')
                                  : translate('Skip', 'বাদ দিন'),
                            ),
                          ),
                          PopupMenuItem<_TaskAction>(
                            value: _TaskAction.delete,
                            child: Text(translate('Delete', 'মুছুন')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskMeta extends StatelessWidget {
  const _TaskMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: colors.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
        ),
      ],
    );
  }
}

class _TaskEditorSheet extends StatefulWidget {
  const _TaskEditorSheet({required this.initialDate, this.existing});

  final DateTime initialDate;
  final MyDayTask? existing;

  @override
  State<_TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends State<_TaskEditorSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late DateTime _date;
  late TimeOfDay _time;
  late int _duration;
  late String _category;

  static const List<String> _categories = <String>[
    'পড়াশোনা',
    'কাজ',
    'ঘুম',
    'স্বাস্থ্য',
    'রুটিন',
    'ব্যক্তিগত',
  ];

  String _t(String english, String bangla) {
    return AppPreferencesController.instance.text(english, bangla);
  }

  @override
  void initState() {
    super.initState();

    final task = widget.existing;
    _titleController = TextEditingController(text: task?.title ?? '');
    _notesController = TextEditingController(text: task?.notes ?? '');
    _date = MyDayTask.dateOnly(task?.date ?? widget.initialDate);

    final totalMinutes =
        task?.minutesOfDay ??
        (TimeOfDay.now().hour * 60 + TimeOfDay.now().minute);

    _time = TimeOfDay(hour: totalMinutes ~/ 60, minute: totalMinutes % 60);

    _duration = task?.durationMinutes ?? 30;
    _category = _categories.contains(task?.category)
        ? task!.category
        : _categories.last;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _date = MyDayTask.dateOnly(selected);
    });
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(context: context, initialTime: _time);

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _time = selected;
    });
  }

  void _submit() {
    final title = _titleController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('Enter a task name.', 'কাজের নাম লিখুন।')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final now = DateTime.now();
    final existing = widget.existing;

    Navigator.of(context).pop(
      MyDayTask(
        id: existing?.id ?? now.microsecondsSinceEpoch.toString(),
        title: title,
        date: _date,
        minutesOfDay: _time.hour * 60 + _time.minute,
        durationMinutes: _duration,
        category: _category,
        source: existing?.source ?? 'manual',
        status: existing?.status ?? MyDayTaskStatus.pending,
        alarmEnabled: existing?.alarmEnabled ?? false,
        notes: _notesController.text.trim(),
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.existing == null
                  ? _t('Add task', 'কাজ যোগ করুন')
                  : _t('Edit task', 'কাজ পরিবর্তন করুন'),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _titleController,
              autofocus: widget.existing == null,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: _t('Task name', 'কাজের নাম'),
                prefixIcon: const Icon(Icons.edit_note_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: _t('Notes (optional)', 'নোট (ঐচ্ছিক)'),
                prefixIcon: const Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_rounded),
              title: Text(_t('Date', 'তারিখ')),
              subtitle: Text(_longDateLabel(context, _date)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _pickDate,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule_rounded),
              title: Text(_t('Start time', 'শুরুর সময়')),
              subtitle: Text(_time.format(context)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _pickTime,
            ),
            DropdownButtonFormField<int>(
              initialValue: _duration,
              decoration: InputDecoration(
                labelText: _t('Duration', 'সময়কাল'),
                prefixIcon: const Icon(Icons.timelapse_rounded),
              ),
              items: const <int>[10, 15, 20, 25, 30, 45, 60, 90, 120]
                  .map(
                    (minutes) => DropdownMenuItem<int>(
                      value: minutes,
                      child: Text(_t('$minutes minutes', '$minutes মিনিট')),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _duration = value;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: InputDecoration(
                labelText: _t('Category', 'ধরন'),
                prefixIcon: const Icon(Icons.category_outlined),
              ),
              items: _categories
                  .map(
                    (category) => DropdownMenuItem<String>(
                      value: category,
                      child: Text(category),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _category = value;
                  });
                }
              },
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.check_rounded),
                label: Text(_t('Save task', 'কাজ সংরক্ষণ করুন')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TimeAnalysisScreen extends StatelessWidget {
  const TimeAnalysisScreen({super.key});

  String _t(String english, String bangla) {
    return AppPreferencesController.instance.text(english, bangla);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(_t('Time analysis', 'সময় বিশ্লেষণ'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 100),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFFF08A4D), Color(0xFFE15A8A)],
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.hourglass_bottom_rounded,
                  color: Colors.white,
                  size: 34,
                ),
                const SizedBox(height: 14),
                Text(
                  _t('Where did time go?', 'সময় কোথায় গেল?'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _t(
                    'Compare your planned tasks with completed work and optional phone-use data.',
                    'পরিকল্পিত কাজ, সম্পন্ন কাজ এবং ঐচ্ছিক ফোন ব্যবহারের তথ্য তুলনা করুন।',
                  ),
                  style: const TextStyle(
                    color: Color(0xFFFFF1F4),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _AnalysisTile(
            icon: Icons.phone_android_rounded,
            title: _t('Phone-use analysis', 'ফোন ব্যবহারের বিশ্লেষণ'),
            subtitle: _t(
              'Review screen time, app patterns and mindful-use controls.',
              'স্ক্রিন টাইম, অ্যাপ ব্যবহারের ধরন ও সচেতন ব্যবহারের নিয়ন্ত্রণ দেখুন।',
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const MindfulScreenTimeScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _AnalysisTile(
            icon: Icons.event_available_rounded,
            title: _t('Planned versus completed', 'পরিকল্পনা বনাম সম্পন্ন কাজ'),
            subtitle: _t(
              'Open the timeline to review completed, skipped and overlapping tasks.',
              'সম্পন্ন, বাদ দেওয়া এবং একই সময়ে থাকা কাজ দেখতে সময়সূচি খুলুন।',
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DailyScheduleScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Text(
              _t(
                'Usage access is optional. MindPulse should use app name, duration and category—not messages or typed content.',
                'ব্যবহারের অনুমতি ঐচ্ছিক। MindPulse শুধু অ্যাপের নাম, সময় ও ধরন ব্যবহার করবে—বার্তা বা আপনার লেখা নয়।',
              ),
              style: TextStyle(color: colors.onSurfaceVariant, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalysisTile extends StatelessWidget {
  const _AnalysisTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(icon, color: colors.primary),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatTime(BuildContext context, int minutesOfDay) {
  final hour = (minutesOfDay ~/ 60).clamp(0, 23).toInt();
  final minute = (minutesOfDay % 60).clamp(0, 59).toInt();

  return TimeOfDay(hour: hour, minute: minute).format(context);
}

String _shortWeekday(DateTime date, _Translate translate) {
  const english = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const bangla = <String>['সোম', 'মঙ্গল', 'বুধ', 'বৃহঃ', 'শুক্র', 'শনি', 'রবি'];

  return translate(english[date.weekday - 1], bangla[date.weekday - 1]);
}

String _longDateLabel(BuildContext context, DateTime date) {
  return MaterialLocalizations.of(context).formatMediumDate(date);
}
