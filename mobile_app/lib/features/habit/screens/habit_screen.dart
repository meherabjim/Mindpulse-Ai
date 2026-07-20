import 'package:flutter/material.dart';

import '../services/habit_service.dart';

class HabitScreen extends StatefulWidget {
  const HabitScreen({super.key});

  @override
  State<HabitScreen> createState() => _HabitScreenState();
}

class _HabitScreenState extends State<HabitScreen> {
  final HabitService _service = HabitService();

  List<Map<String, dynamic>> _todayHabits = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _allHabits = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _templates = <Map<String, dynamic>>[];

  String _todayDate = '';
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait<dynamic>([
        _service.listTodayHabits(),
        _service.listHabits(),
        _service.listTemplates(),
      ]);

      final todayResult = results[0] as Map<String, dynamic>;

      if (!mounted) return;

      setState(() {
        _todayDate = todayResult['date']?.toString() ?? '';
        _todayHabits = todayResult['habits'] as List<Map<String, dynamic>>;
        _allHabits = results[1] as List<Map<String, dynamic>>;
        _templates = results[2] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openEditor({
    Map<String, dynamic>? habit,
    Map<String, dynamic>? template,
  }) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => HabitEditorScreen(habit: habit, template: template),
      ),
    );

    if (changed == true && mounted) {
      await _loadAll();
    }
  }

  Future<void> _openDetails(Map<String, dynamic> habit) async {
    final habitId = _integerValue(habit['id']);

    if (habitId == null) return;

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => HabitDetailsScreen(habitId: habitId),
      ),
    );

    if (changed == true && mounted) {
      await _loadAll();
    }
  }

  Future<void> _saveStatus(Map<String, dynamic> habit, String status) async {
    final habitId = _integerValue(habit['id']);

    if (habitId == null) return;

    final target = _doubleValue(habit['target_value'], fallback: 1);

    try {
      await _service.saveHabitLog(
        habitId,
        logDate: _todayDate.isEmpty ? null : _todayDate,
        status: status,
        completedValue: status == 'completed' ? target : null,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'completed'
                ? 'Habit completed successfully.'
                : 'Habit marked as skipped.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

      await _loadAll();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _archiveHabit(Map<String, dynamic> habit) async {
    final habitId = _integerValue(habit['id']);

    if (habitId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Archive this habit?'),
          content: Text(
            '${habit['name'] ?? 'This habit'} will be removed from your active habit list.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Archive'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _service.archiveHabit(habitId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Habit archived successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      await _loadAll();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  int? _integerValue(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '');
  }

  double _doubleValue(dynamic value, {double fallback = 0}) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  Map<String, dynamic> _todayLog(Map<String, dynamic> habit) {
    final value = habit['today_log'];

    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }

  String _frequencyText(Map<String, dynamic> habit) {
    final frequency = habit['frequency_type']?.toString() ?? 'daily';

    if (frequency == 'daily') {
      return 'Every day';
    }

    final daysValue = habit['schedule_days'];

    if (daysValue is List && daysValue.isNotEmpty) {
      return daysValue
          .map((day) {
            final value = day.toString();
            return value.isEmpty
                ? ''
                : '${value[0].toUpperCase()}${value.substring(1)}';
          })
          .where((day) => day.isNotEmpty)
          .join(', ');
    }

    return frequency == 'weekly' ? 'Weekly' : 'Specific days';
  }

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'hydration':
        return Icons.water_drop_outlined;
      case 'sleep':
        return Icons.bedtime_outlined;
      case 'exercise':
      case 'physical activity':
      case 'fitness':
        return Icons.directions_run_rounded;
      case 'mindfulness':
      case 'meditation':
        return Icons.self_improvement_rounded;
      case 'study':
      case 'focus':
        return Icons.menu_book_outlined;
      case 'nutrition':
      case 'food':
        return Icons.restaurant_outlined;
      default:
        return Icons.task_alt_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F7FC),
        appBar: AppBar(
          title: const Text('Habit Tracker'),
          actions: [
            IconButton(
              onPressed: _loading ? null : _loadAll,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.today_outlined), text: 'Today'),
              Tab(icon: Icon(Icons.checklist_rounded), text: 'All Habits'),
              Tab(icon: Icon(Icons.auto_awesome_outlined), text: 'Templates'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openEditor(),
          icon: const Icon(Icons.add_rounded),
          label: const Text('New Habit'),
        ),
        body: Column(
          children: [
            if (_errorMessage != null) _buildErrorBanner(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      children: [
                        _buildTodayTab(),
                        _buildAllHabitsTab(),
                        _buildTemplatesTab(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red.shade800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayTab() {
    final completedCount = _todayHabits.where((habit) {
      return _todayLog(habit)['status'] == 'completed';
    }).length;

    final progress = _todayHabits.isEmpty
        ? 0.0
        : completedCount / _todayHabits.length;

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF5C58E8), Color(0xFF875EF0)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Today’s habits',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _todayDate,
                  style: const TextStyle(color: Color(0xFFEDEBFF)),
                ),
                const SizedBox(height: 18),
                Text(
                  '$completedCount of ${_todayHabits.length} completed',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 9),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor: const Color(0x44FFFFFF),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  borderRadius: BorderRadius.circular(10),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_todayHabits.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 45),
                child: Column(
                  children: [
                    Icon(
                      Icons.event_available_outlined,
                      size: 65,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 14),
                    Text(
                      'No habits scheduled for today.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._todayHabits.map(_buildTodayHabitCard),
        ],
      ),
    );
  }

  Widget _buildTodayHabitCard(Map<String, dynamic> habit) {
    final log = _todayLog(habit);
    final status = log['status']?.toString() ?? 'pending';
    final completed = status == 'completed';
    final skipped = status == 'skipped';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: completed
                      ? Colors.green.shade50
                      : const Color(0xFFF0EFFF),
                  child: Icon(
                    completed
                        ? Icons.check_rounded
                        : _categoryIcon(habit['category']?.toString() ?? ''),
                    color: completed ? Colors.green : const Color(0xFF6059E8),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: InkWell(
                    onTap: () => _openDetails(habit),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          habit['name']?.toString() ?? 'Habit',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            decoration: completed
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${habit['target_value'] ?? 1} ${habit['unit'] ?? ''}',
                          style: const TextStyle(color: Color(0xFF74748A)),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _openDetails(habit),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: completed
                        ? null
                        : () => _saveStatus(habit, 'completed'),
                    icon: const Icon(Icons.check_rounded),
                    label: Text(completed ? 'Completed' : 'Complete'),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: skipped
                      ? null
                      : () => _saveStatus(habit, 'skipped'),
                  child: Text(skipped ? 'Skipped' : 'Skip'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllHabitsTab() {
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        children: [
          const Text(
            'Your habits',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(
            '${_allHabits.length} active habit(s)',
            style: const TextStyle(color: Color(0xFF74748A)),
          ),
          const SizedBox(height: 14),
          if (_allHabits.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 45),
                child: Column(
                  children: [
                    Icon(
                      Icons.checklist_rtl_rounded,
                      size: 65,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 14),
                    Text(
                      'No habits created yet.',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._allHabits.map(_buildHabitCard),
        ],
      ),
    );
  }

  Widget _buildHabitCard(Map<String, dynamic> habit) {
    final currentStreak = _integerValue(habit['current_streak']) ?? 0;

    final longestStreak = _integerValue(habit['longest_streak']) ?? 0;

    final active = habit['is_active'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDetails(habit),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 53,
                    height: 53,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0EFFF),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Icon(
                      _categoryIcon(habit['category']?.toString() ?? ''),
                      color: const Color(0xFF6059E8),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          habit['name']?.toString() ?? 'Habit',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${habit['category'] ?? 'General'} • ${_frequencyText(habit)}',
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Target: ${habit['target_value'] ?? 1} ${habit['unit'] ?? ''}',
                          style: const TextStyle(color: Color(0xFF74748A)),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _openEditor(habit: habit);
                      } else if (value == 'archive') {
                        _archiveHabit(habit);
                      } else if (value == 'history') {
                        _openDetails(habit);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'history',
                        child: Text('View history'),
                      ),
                      PopupMenuItem(value: 'edit', child: Text('Edit habit')),
                      PopupMenuItem(
                        value: 'archive',
                        child: Text('Archive habit'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: const Icon(
                      Icons.local_fire_department_rounded,
                      size: 18,
                    ),
                    label: Text('$currentStreak day streak'),
                  ),
                  Chip(
                    avatar: const Icon(Icons.emoji_events_outlined, size: 18),
                    label: Text('Best $longestStreak'),
                  ),
                  Chip(
                    avatar: Icon(
                      active
                          ? Icons.play_circle_outline
                          : Icons.pause_circle_outline,
                      size: 18,
                    ),
                    label: Text(active ? 'Active' : 'Paused'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTemplatesTab() {
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        children: [
          const Text(
            'Habit templates',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text('Start quickly using a ready-made wellness habit.'),
          const SizedBox(height: 14),
          ..._templates.map(
            (template) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                contentPadding: const EdgeInsets.all(15),
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFF0EFFF),
                  child: Icon(
                    _categoryIcon(template['category']?.toString() ?? ''),
                    color: const Color(0xFF6059E8),
                  ),
                ),
                title: Text(
                  template['name']?.toString() ?? 'Habit template',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${template['description'] ?? ''}\n'
                    'Target: ${template['default_target_value'] ?? 1} '
                    '${template['default_unit'] ?? ''}',
                  ),
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.add_circle_outline_rounded),
                onTap: () => _openEditor(template: template),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HabitEditorScreen extends StatefulWidget {
  const HabitEditorScreen({this.habit, this.template, super.key});

  final Map<String, dynamic>? habit;
  final Map<String, dynamic>? template;

  @override
  State<HabitEditorScreen> createState() => _HabitEditorScreenState();
}

class _HabitEditorScreenState extends State<HabitEditorScreen> {
  static const List<String> _weekdays = <String>[
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  final HabitService _service = HabitService();

  late final TextEditingController _nameController;
  late final TextEditingController _categoryController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _targetController;
  late final TextEditingController _unitController;

  String _frequencyType = 'daily';
  final Set<String> _selectedDays = <String>{};

  bool _reminderEnabled = false;
  TimeOfDay? _reminderTime;
  late DateTime _startDate;
  DateTime? _endDate;
  bool _isActive = true;

  bool _saving = false;
  String? _errorMessage;

  bool get _isEditing => widget.habit != null;

  int? get _habitId {
    final value = widget.habit?['id'];

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '');
  }

  int? get _templateId {
    final value = widget.template?['id'];

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '');
  }

  @override
  void initState() {
    super.initState();

    final source = widget.habit ?? widget.template ?? <String, dynamic>{};

    _nameController = TextEditingController(
      text: source['name']?.toString() ?? '',
    );

    _categoryController = TextEditingController(
      text: source['category']?.toString() ?? '',
    );

    _descriptionController = TextEditingController(
      text: source['description']?.toString() ?? '',
    );

    _targetController = TextEditingController(
      text: (source['target_value'] ?? source['default_target_value'] ?? 1)
          .toString(),
    );

    _unitController = TextEditingController(
      text: (source['unit'] ?? source['default_unit'] ?? '').toString(),
    );

    _frequencyType = source['frequency_type']?.toString() ?? 'daily';

    final days = source['schedule_days'];

    if (days is List) {
      _selectedDays.addAll(days.map((day) => day.toString()));
    }

    _reminderEnabled = source['reminder_enabled'] == true;
    _reminderTime = _parseTime(source['reminder_time']);

    _startDate =
        DateTime.tryParse(source['start_date']?.toString() ?? '') ??
        DateTime.now();

    _endDate = DateTime.tryParse(source['end_date']?.toString() ?? '');

    _isActive = source['is_active'] == null
        ? true
        : source['is_active'] == true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _targetController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  TimeOfDay? _parseTime(dynamic value) {
    final text = value?.toString() ?? '';

    if (text.length < 5) return null;

    final parts = text.substring(0, 5).split(':');

    if (parts.length != 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) return null;

    return TimeOfDay(hour: hour, minute: minute);
  }

  String _dateString(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  String? _timeString(TimeOfDay? time) {
    if (time == null) return null;

    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  String _dayLabel(String day) {
    return '${day[0].toUpperCase()}${day.substring(1, 3)}';
  }

  Future<void> _pickStartDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (selected == null || !mounted) return;

    setState(() {
      _startDate = selected;

      if (_endDate != null && _endDate!.isBefore(selected)) {
        _endDate = null;
      }
    });
  }

  Future<void> _pickEndDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate.add(const Duration(days: 30)),
      firstDate: _startDate,
      lastDate: DateTime(2100),
    );

    if (selected == null || !mounted) return;

    setState(() {
      _endDate = selected;
    });
  }

  Future<void> _pickReminderTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _reminderTime ?? const TimeOfDay(hour: 9, minute: 0),
    );

    if (selected == null || !mounted) return;

    setState(() {
      _reminderTime = selected;
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final category = _categoryController.text.trim();
    final target = double.tryParse(_targetController.text.trim());

    if (name.length < 2) {
      setState(() {
        _errorMessage = 'Habit name must contain at least 2 characters.';
      });
      return;
    }

    if (category.isEmpty) {
      setState(() {
        _errorMessage = 'Habit category is required.';
      });
      return;
    }

    if (target == null || target <= 0) {
      setState(() {
        _errorMessage = 'Target value must be greater than 0.';
      });
      return;
    }

    if (_frequencyType == 'specific_days' && _selectedDays.isEmpty) {
      setState(() {
        _errorMessage = 'Select at least one day for this habit.';
      });
      return;
    }

    if (_frequencyType == 'weekly' && _selectedDays.length != 1) {
      setState(() {
        _errorMessage = 'A weekly habit requires exactly one day.';
      });
      return;
    }

    if (_reminderEnabled && _reminderTime == null) {
      setState(() {
        _errorMessage = 'Select a reminder time.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      final scheduleDays = _frequencyType == 'daily'
          ? null
          : _selectedDays.toList();

      if (_isEditing) {
        final habitId = _habitId;

        if (habitId == null) {
          throw const HabitApiException('Habit ID is invalid.');
        }

        await _service.updateHabit(
          habitId,
          name: name,
          description: _descriptionController.text,
          category: category,
          frequencyType: _frequencyType,
          scheduleDays: scheduleDays,
          targetValue: target,
          unit: _unitController.text,
          reminderEnabled: _reminderEnabled,
          reminderTime: _timeString(_reminderTime),
          startDate: _dateString(_startDate),
          endDate: _endDate == null ? null : _dateString(_endDate!),
          isActive: _isActive,
        );
      } else {
        await _service.createHabit(
          templateId: _templateId,
          name: name,
          description: _descriptionController.text,
          category: category,
          frequencyType: _frequencyType,
          scheduleDays: scheduleDays,
          targetValue: target,
          unit: _unitController.text,
          reminderEnabled: _reminderEnabled,
          reminderTime: _timeString(_reminderTime),
          startDate: _dateString(_startDate),
          endDate: _endDate == null ? null : _dateString(_endDate!),
        );
      }

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FC),
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Habit' : 'Create Habit'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving...' : 'Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          if (widget.template != null)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFF0EFFF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Template selected: ${widget.template?['name'] ?? ''}',
                style: const TextStyle(
                  color: Color(0xFF6059E8),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (_errorMessage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red.shade800),
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    maxLength: 120,
                    decoration: const InputDecoration(
                      labelText: 'Habit name',
                      prefixIcon: Icon(Icons.task_alt_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _categoryController,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      hintText: 'Hydration, Sleep, Study...',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _descriptionController,
                    maxLength: 500,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Schedule',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 13),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Frequency',
                      prefixIcon: Icon(Icons.repeat_rounded),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _frequencyType,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(
                            value: 'daily',
                            child: Text('Daily'),
                          ),
                          DropdownMenuItem(
                            value: 'specific_days',
                            child: Text('Specific days'),
                          ),
                          DropdownMenuItem(
                            value: 'weekly',
                            child: Text('Weekly'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;

                          setState(() {
                            _frequencyType = value;

                            if (value == 'daily') {
                              _selectedDays.clear();
                            }

                            if (value == 'weekly' && _selectedDays.length > 1) {
                              final first = _selectedDays.first;
                              _selectedDays
                                ..clear()
                                ..add(first);
                            }
                          });
                        },
                      ),
                    ),
                  ),
                  if (_frequencyType != 'daily') ...[
                    const SizedBox(height: 15),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: _weekdays.map((day) {
                        final selected = _selectedDays.contains(day);

                        return FilterChip(
                          label: Text(_dayLabel(day)),
                          selected: selected,
                          onSelected: (isSelected) {
                            setState(() {
                              if (_frequencyType == 'weekly') {
                                _selectedDays.clear();

                                if (isSelected) {
                                  _selectedDays.add(day);
                                }
                              } else if (isSelected) {
                                _selectedDays.add(day);
                              } else {
                                _selectedDays.remove(day);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _targetController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Target value',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _unitController,
                      maxLength: 40,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        hintText: 'glasses',
                        counterText: '',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: const Text('Start date'),
                  subtitle: Text(_dateString(_startDate)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _pickStartDate,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.event_outlined),
                  title: const Text('End date'),
                  subtitle: Text(
                    _endDate == null ? 'No end date' : _dateString(_endDate!),
                  ),
                  trailing: _endDate == null
                      ? const Icon(Icons.chevron_right_rounded)
                      : IconButton(
                          tooltip: 'Clear end date',
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            setState(() {
                              _endDate = null;
                            });
                          },
                          icon: const Icon(Icons.clear_rounded),
                        ),
                  onTap: _pickEndDate,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  value: _reminderEnabled,
                  onChanged: (value) {
                    setState(() {
                      _reminderEnabled = value;
                    });
                  },
                  secondary: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Enable reminder'),
                  subtitle: const Text('Receive a reminder for this habit.'),
                ),
                if (_reminderEnabled) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.schedule_rounded),
                    title: const Text('Reminder time'),
                    subtitle: Text(
                      _reminderTime == null
                          ? 'Select time'
                          : _timeString(_reminderTime)!,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _pickReminderTime,
                  ),
                ],
                if (_isEditing) ...[
                  const Divider(height: 1),
                  SwitchListTile.adaptive(
                    value: _isActive,
                    onChanged: (value) {
                      setState(() {
                        _isActive = value;
                      });
                    },
                    secondary: const Icon(Icons.play_circle_outline),
                    title: const Text('Active habit'),
                    subtitle: const Text(
                      'Paused habits will not appear in today’s list.',
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(
              _saving
                  ? 'Saving...'
                  : _isEditing
                  ? 'Update Habit'
                  : 'Create Habit',
            ),
          ),
        ],
      ),
    );
  }
}

class HabitDetailsScreen extends StatefulWidget {
  const HabitDetailsScreen({required this.habitId, super.key});

  final int habitId;

  @override
  State<HabitDetailsScreen> createState() => _HabitDetailsScreenState();
}

class _HabitDetailsScreenState extends State<HabitDetailsScreen> {
  final HabitService _service = HabitService();

  Map<String, dynamic>? _habit;
  List<Map<String, dynamic>> _logs = <Map<String, dynamic>>[];

  bool _loading = true;
  String? _errorMessage;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final result = await _service.getHabitLogs(widget.habitId, limit: 60);

      if (!mounted) return;

      setState(() {
        _habit = result['habit'] as Map<String, dynamic>;
        _logs = result['logs'] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _editHabit() async {
    final habit = _habit;

    if (habit == null) return;

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => HabitEditorScreen(habit: habit)),
    );

    if (changed == true && mounted) {
      _changed = true;
      await _loadDetails();
    }
  }

  Future<void> _saveStatus(String status) async {
    final habit = _habit;

    if (habit == null) return;

    final target = habit['target_value'] is num
        ? (habit['target_value'] as num).toDouble()
        : double.tryParse(habit['target_value']?.toString() ?? '') ?? 1;

    try {
      await _service.saveHabitLog(
        widget.habitId,
        status: status,
        completedValue: status == 'completed' ? target : null,
      );

      _changed = true;

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'completed'
                ? 'Habit completed.'
                : 'Habit marked as skipped.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

      await _loadDetails();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _archive() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Archive habit?'),
          content: const Text(
            'This habit will be removed from your active habit list.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Archive'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _service.archiveHabit(widget.habitId);

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Map<String, dynamic> _todayLog(Map<String, dynamic> habit) {
    final value = habit['today_log'];

    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && _changed && result != true) {
          return;
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F7FC),
        appBar: AppBar(
          title: const Text('Habit Details'),
          actions: [
            IconButton(
              onPressed: _habit == null ? null : _editHabit,
              icon: const Icon(Icons.edit_outlined),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'archive') {
                  _archive();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'archive', child: Text('Archive habit')),
              ],
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_errorMessage!),
                ),
              )
            : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final habit = _habit!;

    final currentStreak =
        int.tryParse(habit['current_streak']?.toString() ?? '') ?? 0;

    final longestStreak =
        int.tryParse(habit['longest_streak']?.toString() ?? '') ?? 0;

    final todayStatus = _todayLog(habit)['status']?.toString() ?? 'pending';

    return RefreshIndicator(
      onRefresh: _loadDetails,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF5C58E8), Color(0xFF875EF0)],
              ),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  habit['name']?.toString() ?? 'Habit',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  habit['description']?.toString() ??
                      'No description provided.',
                  style: const TextStyle(color: Color(0xFFEDEBFF), height: 1.5),
                ),
                const SizedBox(height: 17),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _headerChip(
                      Icons.local_fire_department_rounded,
                      '$currentStreak streak',
                    ),
                    _headerChip(
                      Icons.emoji_events_outlined,
                      'Best $longestStreak',
                    ),
                    _headerChip(
                      Icons.flag_outlined,
                      '${habit['target_value'] ?? 1} ${habit['unit'] ?? ''}',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: todayStatus == 'completed'
                          ? null
                          : () => _saveStatus('completed'),
                      icon: const Icon(Icons.check_rounded),
                      label: Text(
                        todayStatus == 'completed'
                            ? 'Completed Today'
                            : 'Complete Today',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: todayStatus == 'skipped'
                        ? null
                        : () => _saveStatus('skipped'),
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Habit information',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 9),
          Card(
            child: Column(
              children: [
                _infoTile(
                  Icons.category_outlined,
                  'Category',
                  habit['category']?.toString() ?? 'General',
                ),
                const Divider(height: 1),
                _infoTile(
                  Icons.repeat_rounded,
                  'Frequency',
                  habit['frequency_type']?.toString() ?? 'daily',
                ),
                const Divider(height: 1),
                _infoTile(
                  Icons.calendar_today_outlined,
                  'Start date',
                  habit['start_date']?.toString() ?? '',
                ),
                const Divider(height: 1),
                _infoTile(
                  Icons.notifications_outlined,
                  'Reminder',
                  habit['reminder_enabled'] == true
                      ? habit['reminder_time']?.toString() ?? 'Enabled'
                      : 'Disabled',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Completion history',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 9),
          if (_logs.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.history_rounded),
                title: Text('No habit logs recorded yet.'),
              ),
            )
          else
            ..._logs.map(
              (log) => Card(
                margin: const EdgeInsets.only(bottom: 9),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: log['status'] == 'completed'
                        ? Colors.green.shade50
                        : Colors.orange.shade50,
                    child: Icon(
                      log['status'] == 'completed'
                          ? Icons.check_rounded
                          : Icons.skip_next_rounded,
                      color: log['status'] == 'completed'
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                  title: Text(
                    log['log_date']?.toString() ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${log['status'] ?? 'pending'}'
                    '${log['completed_value'] == null ? '' : ' • ${log['completed_value']} ${habit['unit'] ?? ''}'}',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _headerChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0x33FFFFFF),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 17),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String title, String value) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 340;

        final valueText = Text(
          value,
          maxLines: compact ? 3 : 2,
          overflow: TextOverflow.ellipsis,
          textAlign: compact ? TextAlign.left : TextAlign.right,
          style: const TextStyle(fontWeight: FontWeight.w700),
        );

        return ListTile(
          leading: Icon(icon),
          title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: compact
              ? Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: valueText,
                )
              : null,
          trailing: compact
              ? null
              : ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * 0.42,
                  ),
                  child: valueText,
                ),
        );
      },
    );
  }
}
