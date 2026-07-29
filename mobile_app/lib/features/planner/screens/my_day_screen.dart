import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/settings/app_preferences_controller.dart';
import '../../digital_wellbeing/screens/mindful_screen_time_screen.dart';
import '../../reminders/screens/smart_reminder_center_screen.dart';

class MyDayScreen extends StatelessWidget {
  const MyDayScreen({super.key});

  String _t(String english, String bangla) {
    return AppPreferencesController.instance.text(english, bangla);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(18, 18, 18, 0),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF4B46D8), Color(0xFF8A5AF5)],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x334B46D8),
                    blurRadius: 26,
                    offset: Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      _t('YOUR PERSONAL ROUTE', 'আপনার ব্যক্তিগত পথ'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _t('My Day', 'আমার দিন'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 31,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _t(
                      'Build a realistic day with schedule, AI guidance and honest time analysis.',
                      'সময়সূচি, AI নির্দেশনা এবং সময় বিশ্লেষণ দিয়ে বাস্তবসম্মত একটি দিন সাজান।',
                    ),
                    style: const TextStyle(
                      color: Color(0xFFF0ECFF),
                      height: 1.5,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(
                  _t('Choose a path', 'একটি পথ বেছে নিন'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 224,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _ModuleCard(
                        icon: Icons.calendar_month_rounded,
                        title: _t('Daily schedule', 'দৈনিক সময়সূচি'),
                        subtitle: _t(
                          'Plan tasks, duration and alarm needs.',
                          'কাজ, সময়কাল ও অ্যালার্মের প্রয়োজন ঠিক করুন।',
                        ),
                        gradient: const [Color(0xFF5A54E8), Color(0xFF7867F2)],
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const DailyScheduleScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 14),
                      _ModuleCard(
                        icon: Icons.menu_book_rounded,
                        title: _t('AI guide', 'AI গাইড'),
                        subtitle: _t(
                          'Create a 10-book journey from names or smart suggestions.',
                          'নাম অথবা স্মার্ট পরামর্শ থেকে ১০ বইয়ের যাত্রা তৈরি করুন।',
                        ),
                        gradient: const [Color(0xFF0D9E91), Color(0xFF35C6AE)],
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const AiGuideScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 14),
                      _ModuleCard(
                        icon: Icons.hourglass_bottom_rounded,
                        title: _t('Where did time go?', 'সময় কোথায় গেল?'),
                        subtitle: _t(
                          'Compare planned time with actual phone use.',
                          'পরিকল্পিত সময়ের সঙ্গে ফোন ব্যবহারের বাস্তব সময় তুলনা করুন।',
                        ),
                        gradient: const [Color(0xFFF28C4B), Color(0xFFE45C8C)],
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const TimeAnalysisScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest.withValues(
                      alpha: 0.55,
                    ),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _t(
                                'MindPulse planning rule',
                                'MindPulse পরিকল্পনার নিয়ম',
                              ),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _t(
                                'Your plan remains under your control. Suggestions are shown first; important changes require your confirmation.',
                                'আপনার পরিকল্পনার নিয়ন্ত্রণ আপনার কাছেই থাকবে। আগে পরামর্শ দেখানো হবে; গুরুত্বপূর্ণ পরিবর্তনে আপনার সম্মতি লাগবে।',
                              ),
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 238,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradient,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: gradient.first.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const Spacer(),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFF6F3FF),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DailyScheduleScreen extends StatefulWidget {
  const DailyScheduleScreen({super.key});

  @override
  State<DailyScheduleScreen> createState() => _DailyScheduleScreenState();
}

class _DailyScheduleScreenState extends State<DailyScheduleScreen> {
  static const _storageKey = 'mindpulse_my_day_schedule_v1';

  List<_DayTask> _tasks = <_DayTask>[];
  bool _loading = true;

  String _t(String english, String bangla) {
    return AppPreferencesController.instance.text(english, bangla);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storageKey);

    final tasks = <_DayTask>[];
    if (raw != null && raw.trim().isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final item in decoded.whereType<Map>()) {
          tasks.add(_DayTask.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    tasks.sort((a, b) => a.minutesOfDay.compareTo(b.minutesOfDay));

    if (!mounted) return;
    setState(() {
      _tasks = tasks;
      _loading = false;
    });
  }

  Future<void> _save() async {
    _tasks.sort((a, b) => a.minutesOfDay.compareTo(b.minutesOfDay));
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _storageKey,
      jsonEncode(_tasks.map((task) => task.toJson()).toList()),
    );
  }

  Future<void> _addSuggestedDay() async {
    if (_tasks.isNotEmpty) return;

    setState(() {
      _tasks = <_DayTask>[
        const _DayTask(
          id: 'wake',
          title: 'ঘুম থেকে ওঠা',
          minutesOfDay: 420,
          durationMinutes: 20,
          category: 'রুটিন',
          alarmEnabled: true,
          completed: false,
        ),
        const _DayTask(
          id: 'study',
          title: 'মনোযোগ দিয়ে পড়াশোনা',
          minutesOfDay: 540,
          durationMinutes: 45,
          category: 'পড়াশোনা',
          alarmEnabled: false,
          completed: false,
        ),
        const _DayTask(
          id: 'reading',
          title: 'বই পড়া',
          minutesOfDay: 1200,
          durationMinutes: 25,
          category: 'বই',
          alarmEnabled: false,
          completed: false,
        ),
        const _DayTask(
          id: 'sleep',
          title: 'ঘুমের প্রস্তুতি',
          minutesOfDay: 1350,
          durationMinutes: 30,
          category: 'ঘুম',
          alarmEnabled: true,
          completed: false,
        ),
      ];
    });

    await _save();
  }

  Future<void> _openEditor({_DayTask? existing}) async {
    final result = await showModalBottomSheet<_DayTask>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TaskEditorSheet(existing: existing),
    );

    if (result == null || !mounted) return;

    setState(() {
      final index = _tasks.indexWhere((item) => item.id == result.id);
      if (index >= 0) {
        _tasks[index] = result;
      } else {
        _tasks.add(result);
      }
    });

    await _save();
  }

  Future<void> _delete(_DayTask task) async {
    setState(() => _tasks.removeWhere((item) => item.id == task.id));
    await _save();
  }

  Future<void> _toggleComplete(_DayTask task) async {
    setState(() {
      final index = _tasks.indexWhere((item) => item.id == task.id);
      if (index >= 0) {
        _tasks[index] = task.copyWith(completed: !task.completed);
      }
    });
    await _save();
  }

  Future<void> _openAlarmCentre() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const SmartReminderCenterScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final completeCount = _tasks.where((task) => task.completed).length;
    final progress = _tasks.isEmpty ? 0.0 : completeCount / _tasks.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('Daily schedule', 'দৈনিক সময়সূচি')),
        actions: [
          IconButton(
            tooltip: _t('Alarm centre', 'অ্যালার্ম কেন্দ্র'),
            onPressed: _openAlarmCentre,
            icon: const Icon(Icons.alarm_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add_rounded),
        label: Text(_t('Add task', 'কাজ যোগ করুন')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF514BDD), Color(0xFF7A67F2)],
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t('Today’s progress', 'আজকের অগ্রগতি'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _t(
                          '$completeCount of ${_tasks.length} tasks completed',
                          '${_tasks.length}টির মধ্যে $completeCountটি কাজ সম্পন্ন',
                        ),
                        style: const TextStyle(color: Color(0xFFF0ECFF)),
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 10,
                          color: Colors.white,
                          backgroundColor: Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (_tasks.isEmpty)
                  _EmptySchedule(
                    onAddSuggestion: _addSuggestedDay,
                    onAddOwn: () => _openEditor(),
                  )
                else
                  ..._tasks.map(
                    (task) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Dismissible(
                        key: ValueKey<String>(task.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 22),
                          decoration: BoxDecoration(
                            color: colors.errorContainer,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            color: colors.error,
                          ),
                        ),
                        onDismissed: (_) => _delete(task),
                        child: Material(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(24),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: () => _openEditor(existing: task),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: colors.outlineVariant,
                                ),
                              ),
                              child: Row(
                                children: [
                                  InkWell(
                                    borderRadius: BorderRadius.circular(50),
                                    onTap: () => _toggleComplete(task),
                                    child: Padding(
                                      padding: const EdgeInsets.all(2),
                                      child: Icon(
                                        task.completed
                                            ? Icons.check_circle_rounded
                                            : Icons
                                                  .radio_button_unchecked_rounded,
                                        color: task.completed
                                            ? const Color(0xFF20A997)
                                            : colors.outline,
                                        size: 30,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 13),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          task.title,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            decoration: task.completed
                                                ? TextDecoration.lineThrough
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          '${_formatTime(task.minutesOfDay)} • ${task.durationMinutes} মিনিট • ${task.category}',
                                          style: TextStyle(
                                            color: colors.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (task.alarmEnabled)
                                    Icon(
                                      Icons.alarm_on_rounded,
                                      color: colors.primary,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: colors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _t(
                            'Use the alarm centre to choose sound, voice and exact reminder behaviour for important tasks.',
                            'গুরুত্বপূর্ণ কাজের sound, voice ও নির্দিষ্ট reminder আচরণ ঠিক করতে অ্যালার্ম কেন্দ্র ব্যবহার করুন।',
                          ),
                          style: TextStyle(
                            color: colors.onPrimaryContainer,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _EmptySchedule extends StatelessWidget {
  const _EmptySchedule({required this.onAddSuggestion, required this.onAddOwn});

  final VoidCallback onAddSuggestion;
  final VoidCallback onAddOwn;

  @override
  Widget build(BuildContext context) {
    final isBangla = AppPreferencesController.instance.isBangla;
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.event_note_rounded,
              color: colors.primary,
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isBangla
                ? 'আজকের সময়সূচি এখনো তৈরি হয়নি'
                : 'Today’s schedule is empty',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            isBangla
                ? 'নিজের কাজ যোগ করুন অথবা MindPulse-এর নমুনা দিন দিয়ে শুরু করুন।'
                : 'Add your own tasks or begin with a MindPulse sample day.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant, height: 1.45),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onAddSuggestion,
            icon: const Icon(Icons.auto_awesome_rounded),
            label: Text(isBangla ? 'নমুনা দিন যোগ করুন' : 'Add sample day'),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onAddOwn,
            icon: const Icon(Icons.add_rounded),
            label: Text(isBangla ? 'নিজের কাজ যোগ করুন' : 'Add my task'),
          ),
        ],
      ),
    );
  }
}

class _TaskEditorSheet extends StatefulWidget {
  const _TaskEditorSheet({this.existing});

  final _DayTask? existing;

  @override
  State<_TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends State<_TaskEditorSheet> {
  late final TextEditingController _titleController;
  late TimeOfDay _time;
  late int _duration;
  late String _category;
  late bool _alarmEnabled;

  static const _categories = <String>[
    'পড়াশোনা',
    'বই',
    'ঘুম',
    'কাজ',
    'রুটিন',
    'স্বাস্থ্য',
    'ব্যক্তিগত',
  ];

  @override
  void initState() {
    super.initState();
    final task = widget.existing;
    _titleController = TextEditingController(text: task?.title ?? '');
    final totalMinutes =
        task?.minutesOfDay ??
        (TimeOfDay.now().hour * 60 + TimeOfDay.now().minute);
    _time = TimeOfDay(hour: totalMinutes ~/ 60, minute: totalMinutes % 60);
    _duration = task?.durationMinutes ?? 30;
    _category = task?.category ?? _categories.first;
    _alarmEnabled = task?.alarmEnabled ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(context: context, initialTime: _time);
    if (selected == null || !mounted) return;
    setState(() => _time = selected);
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final existing = widget.existing;
    Navigator.of(context).pop(
      _DayTask(
        id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        minutesOfDay: _time.hour * 60 + _time.minute,
        durationMinutes: _duration,
        category: _category,
        alarmEnabled: _alarmEnabled,
        completed: existing?.completed ?? false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBangla = AppPreferencesController.instance.isBangla;

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
              isBangla ? 'কাজের বিবরণ' : 'Task details',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _titleController,
              autofocus: widget.existing == null,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: isBangla ? 'কাজের নাম' : 'Task name',
                prefixIcon: const Icon(Icons.edit_note_rounded),
              ),
            ),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule_rounded),
              title: Text(isBangla ? 'শুরুর সময়' : 'Start time'),
              subtitle: Text(_time.format(context)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _pickTime,
            ),
            DropdownButtonFormField<int>(
              initialValue: _duration,
              decoration: InputDecoration(
                labelText: isBangla ? 'সময়কাল' : 'Duration',
                prefixIcon: const Icon(Icons.timelapse_rounded),
              ),
              items: const [15, 20, 25, 30, 45, 60, 90]
                  .map(
                    (minutes) => DropdownMenuItem<int>(
                      value: minutes,
                      child: Text('$minutes মিনিট'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _duration = value);
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: InputDecoration(
                labelText: isBangla ? 'ধরন' : 'Category',
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
                if (value != null) setState(() => _category = value);
              },
            ),
            const SizedBox(height: 10),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(isBangla ? 'অ্যালার্ম প্রয়োজন' : 'Alarm needed'),
              subtitle: Text(
                isBangla
                    ? 'Sound ও voice অ্যালার্ম কেন্দ্র থেকে ঠিক করা যাবে।'
                    : 'Sound and voice can be configured in the alarm centre.',
              ),
              value: _alarmEnabled,
              onChanged: (value) => setState(() => _alarmEnabled = value),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.check_rounded),
                label: Text(isBangla ? 'কাজটি সংরক্ষণ করুন' : 'Save task'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AiGuideScreen extends StatefulWidget {
  const AiGuideScreen({super.key});

  @override
  State<AiGuideScreen> createState() => _AiGuideScreenState();
}

class _AiGuideScreenState extends State<AiGuideScreen> {
  static const _storageKey = 'mindpulse_book_guide_v1';

  final TextEditingController _bookInputController = TextEditingController();
  final Random _random = Random();

  List<_BookGuide> _books = <_BookGuide>[];
  bool _loading = true;
  bool _generating = false;
  String? _message;

  static const _starterBooks = <String>[
    'Atomic Habits',
    'Deep Work',
    'The Psychology of Money',
    'Man’s Search for Meaning',
    'The Alchemist',
    'Thinking, Fast and Slow',
    'Ikigai',
    'The 7 Habits of Highly Effective People',
    'A Brief History of Time',
    'The Little Prince',
    'Sapiens',
    'Make Time',
    'Mindset',
    'Essentialism',
    'The Power of Habit',
    'Quiet',
    'Start With Why',
    'The Courage to Be Disliked',
    'Grit',
    'Digital Minimalism',
  ];

  String _t(String english, String bangla) {
    return AppPreferencesController.instance.text(english, bangla);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _bookInputController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storageKey);
    final books = <_BookGuide>[];

    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final item in decoded.whereType<Map>()) {
          books.add(_BookGuide.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _books = books;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _storageKey,
      jsonEncode(_books.map((book) => book.toJson()).toList()),
    );
  }

  Future<void> _generatePlan() async {
    final entered = _bookInputController.text
        .split(RegExp(r'[\n,]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    final queries = <String>[];
    queries.addAll(entered.take(10));

    if (queries.isEmpty) {
      final shuffled = List<String>.from(_starterBooks)..shuffle(_random);
      queries.addAll(shuffled.take(10));
    } else if (queries.length < 10) {
      final available =
          _starterBooks
              .where(
                (book) => !queries.any(
                  (query) => query.toLowerCase() == book.toLowerCase(),
                ),
              )
              .toList()
            ..shuffle(_random);
      queries.addAll(available.take(10 - queries.length));
    }

    setState(() {
      _generating = true;
      _message = null;
    });

    final results = await Future.wait(queries.map(_fetchBook));
    results.sort((a, b) => a.difficultyScore.compareTo(b.difficultyScore));

    if (!mounted) return;
    setState(() {
      _books = results;
      _generating = false;
      _message = _t(
        'Your 10-book journey is ready. Easier books are placed earlier and demanding books later.',
        'আপনার ১০ বইয়ের যাত্রা প্রস্তুত। তুলনামূলক সহজ বই আগে এবং কঠিন বই পরে রাখা হয়েছে।',
      );
    });

    await _save();
  }

  Future<_BookGuide> _fetchBook(String query) async {
    try {
      final uri = Uri.https(
        'www.googleapis.com',
        '/books/v1/volumes',
        <String, String>{
          'q': 'intitle:$query',
          'maxResults': '1',
          'printType': 'books',
        },
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        return _fallbackBook(query);
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return _fallbackBook(query);
      final items = decoded['items'];
      if (items is! List || items.isEmpty) return _fallbackBook(query);

      final first = items.first;
      if (first is! Map) return _fallbackBook(query);
      final volume = first['volumeInfo'];
      if (volume is! Map) return _fallbackBook(query);

      final info = Map<String, dynamic>.from(volume);
      final title = info['title']?.toString().trim();
      final authorsRaw = info['authors'];
      final authors = authorsRaw is List
          ? authorsRaw.map((item) => item.toString()).join(', ')
          : '';
      final categoriesRaw = info['categories'];
      final categories = categoriesRaw is List
          ? categoriesRaw.map((item) => item.toString()).toList()
          : <String>[];
      final pages = info['pageCount'] is num
          ? (info['pageCount'] as num).toInt()
          : int.tryParse(info['pageCount']?.toString() ?? '') ?? 0;
      final description = info['description']?.toString() ?? '';
      final score = _difficultyScore(
        title: title ?? query,
        categories: categories,
        pages: pages,
        description: description,
      );

      return _BookGuide(
        title: title?.isNotEmpty == true ? title! : query,
        author: authors,
        difficultyScore: score,
        difficulty: _difficultyLabel(score),
        sessionMinutes: score >= 4
            ? 35
            : score >= 2
            ? 25
            : 20,
        sessionsPerWeek: score >= 4 ? 2 : 3,
        source: 'Google Books',
      );
    } catch (_) {
      return _fallbackBook(query);
    }
  }

  _BookGuide _fallbackBook(String query) {
    final score = _difficultyScore(
      title: query,
      categories: const <String>[],
      pages: 0,
      description: '',
    );
    return _BookGuide(
      title: query,
      author: '',
      difficultyScore: score,
      difficulty: _difficultyLabel(score),
      sessionMinutes: score >= 4
          ? 35
          : score >= 2
          ? 25
          : 20,
      sessionsPerWeek: score >= 4 ? 2 : 3,
      source: 'Local estimate',
    );
  }

  int _difficultyScore({
    required String title,
    required List<String> categories,
    required int pages,
    required String description,
  }) {
    var score = 0;
    final text =
        '${title.toLowerCase()} ${categories.join(' ').toLowerCase()} ${description.toLowerCase()}';

    if (pages >= 450) {
      score += 2;
    } else if (pages >= 300) {
      score += 1;
    }

    const demandingTerms = <String>[
      'advanced',
      'philosophy',
      'economics',
      'science',
      'physics',
      'mathematics',
      'psychology',
      'technical',
      'history',
      'theory',
      'research',
    ];

    for (final term in demandingTerms) {
      if (text.contains(term)) score += 1;
    }

    if (description.length > 1300) score += 1;
    return score.clamp(0, 6).toInt();
  }

  String _difficultyLabel(int score) {
    if (score >= 4) return _t('Challenging', 'কঠিন');
    if (score >= 2) return _t('Moderate', 'মাঝারি');
    return _t('Accessible', 'সহজ');
  }

  Future<void> _clear() async {
    setState(() {
      _books = <_BookGuide>[];
      _message = null;
    });
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('AI guide', 'AI গাইড')),
        actions: [
          if (_books.isNotEmpty)
            IconButton(
              tooltip: _t('Create again', 'আবার তৈরি করুন'),
              onPressed: _generating ? null : _clear,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF098F84), Color(0xFF38C6A9)],
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.auto_stories_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _t('10-book journey', '১০ বইয়ের যাত্রা'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _t(
                          'Enter book names if you have them. Leave it empty and MindPulse will create a balanced starter list.',
                          'বইয়ের নাম জানা থাকলে লিখুন। খালি রাখলে MindPulse একটি ভারসাম্যপূর্ণ starter list তৈরি করবে।',
                        ),
                        style: const TextStyle(
                          color: Color(0xFFE9FFF8),
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (_books.isEmpty) ...[
                  TextField(
                    controller: _bookInputController,
                    minLines: 5,
                    maxLines: 8,
                    decoration: InputDecoration(
                      labelText: _t(
                        'Book names — one per line (optional)',
                        'বইয়ের নাম—প্রতি লাইনে একটি (ঐচ্ছিক)',
                      ),
                      alignLabelWithHint: true,
                      hintText: 'Atomic Habits\nDeep Work\n...',
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 92),
                        child: Icon(Icons.library_books_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _generating ? null : _generatePlan,
                      icon: _generating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome_rounded),
                      label: Text(
                        _generating
                            ? _t(
                                'Creating your guide...',
                                'আপনার গাইড তৈরি হচ্ছে...',
                              )
                            : _t(
                                'Create my 10-book guide',
                                'আমার ১০ বইয়ের গাইড তৈরি করুন',
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _t(
                      'Difficulty is an estimate from available title, category, description and edition metadata. It is not a universal reading-level score.',
                      'কঠিনতা title, category, description ও edition metadata থেকে করা একটি অনুমান। এটি কোনো সার্বজনীন reading-level score নয়।',
                    ),
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      height: 1.4,
                      fontSize: 12,
                    ),
                  ),
                ] else ...[
                  if (_message != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.primaryContainer.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _message!,
                        style: TextStyle(
                          color: colors.onPrimaryContainer,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  ..._books.asMap().entries.map((entry) {
                    final index = entry.key;
                    final book = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.all(17),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: colors.outlineVariant),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 48,
                              height: 58,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: index == 0
                                      ? const [
                                          Color(0xFF0E9E91),
                                          Color(0xFF42CBB0),
                                        ]
                                      : const [
                                          Color(0xFF6059E8),
                                          Color(0xFF8D7CF7),
                                        ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          book.title,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      if (index == 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 9,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFDCF8F1),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: const Text(
                                            'ACTIVE',
                                            style: TextStyle(
                                              color: Color(0xFF087E73),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (book.author.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      book.author,
                                      style: TextStyle(
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 7,
                                    children: [
                                      _Pill(text: book.difficulty),
                                      _Pill(
                                        text: '${book.sessionMinutes} মিনিট',
                                      ),
                                      _Pill(
                                        text:
                                            'সপ্তাহে ${book.sessionsPerWeek} দিন',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    book.source,
                                    style: TextStyle(
                                      color: colors.onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  OutlinedButton.icon(
                    onPressed: _clear,
                    icon: const Icon(Icons.edit_rounded),
                    label: Text(
                      _t('Change book list', 'বইয়ের তালিকা পরিবর্তন করুন'),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: colors.onSurfaceVariant,
          fontSize: 11,
          fontWeight: FontWeight.w700,
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
                colors: [Color(0xFFF08A4D), Color(0xFFE15A8A)],
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
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _t(
                    'Understand planned time, focused time and distracting phone use without judging every app automatically.',
                    'প্রতিটি app-কে স্বয়ংক্রিয়ভাবে খারাপ না ধরে পরিকল্পিত সময়, মনোযোগের সময় ও বিক্ষিপ্ত ফোন ব্যবহার বুঝুন।',
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
              'স্ক্রিন টাইম, app ব্যবহারের ধরন ও সচেতন ব্যবহারের নিয়ন্ত্রণ দেখুন।',
            ),
            color: const Color(0xFFE15A8A),
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
              'Your daily schedule completion is used to build this comparison.',
              'দৈনিক সময়সূচির সম্পন্ন কাজ থেকে এই তুলনা তৈরি হবে।',
            ),
            color: const Color(0xFF5B55E8),
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
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('Privacy first', 'গোপনীয়তা আগে'),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  _t(
                    'Usage access is optional. MindPulse should use app name, duration and category—not messages, typed text or private content.',
                    'Usage access ঐচ্ছিক। MindPulse শুধু app-এর নাম, ব্যবহারের সময় ও category ব্যবহার করবে—message, লেখা বা ব্যক্তিগত content নয়।',
                  ),
                  style: TextStyle(color: colors.onSurfaceVariant, height: 1.5),
                ),
              ],
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
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
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

class _DayTask {
  const _DayTask({
    required this.id,
    required this.title,
    required this.minutesOfDay,
    required this.durationMinutes,
    required this.category,
    required this.alarmEnabled,
    required this.completed,
  });

  final String id;
  final String title;
  final int minutesOfDay;
  final int durationMinutes;
  final String category;
  final bool alarmEnabled;
  final bool completed;

  _DayTask copyWith({bool? completed}) {
    return _DayTask(
      id: id,
      title: title,
      minutesOfDay: minutesOfDay,
      durationMinutes: durationMinutes,
      category: category,
      alarmEnabled: alarmEnabled,
      completed: completed ?? this.completed,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'minutes_of_day': minutesOfDay,
      'duration_minutes': durationMinutes,
      'category': category,
      'alarm_enabled': alarmEnabled,
      'completed': completed,
    };
  }

  factory _DayTask.fromJson(Map<String, dynamic> json) {
    return _DayTask(
      id:
          json['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: json['title']?.toString() ?? '',
      minutesOfDay: (json['minutes_of_day'] as num?)?.toInt() ?? 540,
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 30,
      category: json['category']?.toString() ?? 'ব্যক্তিগত',
      alarmEnabled: json['alarm_enabled'] == true,
      completed: json['completed'] == true,
    );
  }
}

class _BookGuide {
  const _BookGuide({
    required this.title,
    required this.author,
    required this.difficultyScore,
    required this.difficulty,
    required this.sessionMinutes,
    required this.sessionsPerWeek,
    required this.source,
  });

  final String title;
  final String author;
  final int difficultyScore;
  final String difficulty;
  final int sessionMinutes;
  final int sessionsPerWeek;
  final String source;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'title': title,
      'author': author,
      'difficulty_score': difficultyScore,
      'difficulty': difficulty,
      'session_minutes': sessionMinutes,
      'sessions_per_week': sessionsPerWeek,
      'source': source,
    };
  }

  factory _BookGuide.fromJson(Map<String, dynamic> json) {
    return _BookGuide(
      title: json['title']?.toString() ?? '',
      author: json['author']?.toString() ?? '',
      difficultyScore: (json['difficulty_score'] as num?)?.toInt() ?? 1,
      difficulty: json['difficulty']?.toString() ?? 'মাঝারি',
      sessionMinutes: (json['session_minutes'] as num?)?.toInt() ?? 25,
      sessionsPerWeek: (json['sessions_per_week'] as num?)?.toInt() ?? 3,
      source: json['source']?.toString() ?? 'Local estimate',
    );
  }
}

String _formatTime(int minutesOfDay) {
  final hour = (minutesOfDay ~/ 60).clamp(0, 23).toInt();
  final minute = (minutesOfDay % 60).clamp(0, 59).toInt();
  final period = hour >= 12 ? 'PM' : 'AM';
  final displayHour = hour % 12 == 0 ? 12 : hour % 12;
  return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
}
