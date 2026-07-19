import 'package:flutter/material.dart';

import '../services/recovery_service.dart';

class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key});

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  final RecoveryService _service = RecoveryService();

  List<Map<String, dynamic>> _activities = <Map<String, dynamic>>[];

  List<Map<String, dynamic>> _logs = <Map<String, dynamic>>[];

  List<Map<String, dynamic>> _progress = <Map<String, dynamic>>[];

  Map<String, dynamic>? _activePlan;

  bool _loading = true;
  bool _creatingPlan = false;
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
        _service.listActivities(),
        _service.listActivityLogs(),
        _service.getActivePlan(),
        _service.listProgress(),
      ]);

      if (!mounted) return;

      setState(() {
        _activities = results[0] as List<Map<String, dynamic>>;

        _logs = results[1] as List<Map<String, dynamic>>;

        _activePlan = results[2] as Map<String, dynamic>?;

        _progress = results[3] as List<Map<String, dynamic>>;

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

  Future<void> _openActivity(Map<String, dynamic> activity) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => RecoveryActivityScreen(activity: activity),
      ),
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recovery activity completed successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      await _loadAll();
    }
  }

  Future<void> _createStarterPlan() async {
    if (_activities.isEmpty) {
      return;
    }

    setState(() {
      _creatingPlan = true;
      _errorMessage = null;
    });

    try {
      final startDate = DateTime.now();
      final endDate = startDate.add(const Duration(days: 7));

      final selectedActivities = _activities.take(3).toList();

      final tasks = <Map<String, dynamic>>[];

      for (var index = 0; index < selectedActivities.length; index++) {
        final activity = selectedActivities[index];

        tasks.add(<String, dynamic>{
          'recovery_activity_id': _integerValue(activity['id']),
          'title': activity['title']?.toString() ?? 'Recovery activity',
          'description': activity['description']?.toString(),
          'task_type': 'recovery_activity',
          'target_value': _doubleValue(activity['duration_minutes']),
          'target_unit': 'minutes',
          'scheduled_date': _dateString(startDate.add(Duration(days: index))),
          'scheduled_time': null,
        });
      }

      final plan = await _service.createPlan(
        title: 'My 7-Day Recovery Plan',
        description:
            'A simple starter plan for improving emotional and physical recovery.',
        overallGoal:
            'Build a consistent recovery routine using short daily activities.',
        startDate: _dateString(startDate),
        endDate: _dateString(endDate),
        reviewDate: _dateString(endDate),
        tasks: tasks,
      );

      if (!mounted) return;

      setState(() {
        _activePlan = plan;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Starter recovery plan created.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      await _loadAll();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _creatingPlan = false;
        });
      }
    }
  }

  Future<void> _toggleTask(Map<String, dynamic> task) async {
    final taskId = _integerValue(task['id']);

    if (taskId == null) return;

    final currentStatus = task['status']?.toString() ?? 'pending';

    final nextStatus = currentStatus == 'completed' ? 'pending' : 'completed';

    try {
      await _service.updateTask(taskId, status: nextStatus);

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

  Future<void> _updatePlanStatus(String status) async {
    final planId = _integerValue(_activePlan?['id']);

    if (planId == null) return;

    try {
      await _service.updatePlanStatus(planId, status);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Recovery plan changed to $status.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      await _loadAll();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _openProgressForm() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => RecoveryProgressScreen(
          activePlanId: _integerValue(_activePlan?['id']),
        ),
      ),
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recovery progress saved.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      await _loadAll();
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

  String _dateString(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');

    final month = date.month.toString().padLeft(2, '0');

    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'breathing':
        return Icons.air_rounded;
      case 'grounding':
        return Icons.filter_5_rounded;
      case 'focus':
        return Icons.center_focus_strong;
      case 'stretching':
        return Icons.accessibility_new_rounded;
      case 'meditation':
        return Icons.self_improvement_rounded;
      case 'sleep':
        return Icons.bedtime_rounded;
      case 'reflection':
        return Icons.favorite_outline_rounded;
      case 'digital_break':
        return Icons.phonelink_off_rounded;
      case 'physical_activity':
        return Icons.directions_walk_rounded;
      default:
        return Icons.spa_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F7FC),
        appBar: AppBar(
          title: const Text('Recovery'),
          actions: [
            IconButton(
              onPressed: _loading ? null : _loadAll,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.spa_outlined), text: 'Activities'),
              Tab(icon: Icon(Icons.checklist_rounded), text: 'Plan'),
              Tab(icon: Icon(Icons.insights_rounded), text: 'Progress'),
            ],
          ),
        ),
        body: Column(
          children: [
            if (_errorMessage != null) _buildErrorBanner(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      children: [
                        _buildActivitiesTab(),
                        _buildPlanTab(),
                        _buildProgressTab(),
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

  Widget _buildActivitiesTab() {
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          const Text(
            'Recovery activities',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Choose a short activity to reset, relax and restore your energy.',
          ),
          const SizedBox(height: 16),
          ..._activities.map((activity) => _buildActivityCard(activity)),
          const SizedBox(height: 12),
          const Text(
            'Recent activity',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (_logs.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.history_rounded),
                title: Text('No recovery activity completed yet.'),
              ),
            )
          else
            ..._logs
                .take(5)
                .map(
                  (log) => Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Icon(
                          log['status'] == 'completed'
                              ? Icons.check_rounded
                              : Icons.timelapse_rounded,
                        ),
                      ),
                      title: Text(
                        log['activity_title']?.toString() ??
                            'Recovery activity',
                      ),
                      subtitle: Text(
                        '${log['status']} • '
                        '${log['rating'] ?? '-'} / 5',
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> activity) {
    final category = activity['category']?.toString() ?? '';

    final duration = _integerValue(activity['duration_minutes']) ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openActivity(activity),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0EFFF),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  _categoryIcon(category),
                  color: const Color(0xFF6059E8),
                  size: 29,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity['title']?.toString() ?? 'Recovery activity',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      activity['description']?.toString() ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$duration minutes • '
                      '${activity['difficulty_level'] ?? 'beginner'}',
                      style: const TextStyle(
                        color: Color(0xFF69697E),
                        fontWeight: FontWeight.w600,
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

  Widget _buildPlanTab() {
    final plan = _activePlan;

    if (plan == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 60),
          const Icon(Icons.event_note_outlined, size: 78, color: Colors.grey),
          const SizedBox(height: 18),
          const Text(
            'No active recovery plan',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a simple seven-day plan using your first three recovery activities.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _creatingPlan ? null : _createStarterPlan,
            icon: _creatingPlan
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_rounded),
            label: Text(_creatingPlan ? 'Creating...' : 'Create Starter Plan'),
          ),
        ],
      );
    }

    final tasksValue = plan['tasks'];

    final tasks = tasksValue is List
        ? tasksValue
              .whereType<Map>()
              .map((task) => Map<String, dynamic>.from(task))
              .toList()
        : <Map<String, dynamic>>[];

    final progressPercent = _doubleValue(plan['progress_percent']);

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          plan['title']?.toString() ?? 'Recovery Plan',
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: _updatePlanStatus,
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'paused',
                            child: Text('Pause plan'),
                          ),
                          PopupMenuItem(
                            value: 'completed',
                            child: Text('Complete plan'),
                          ),
                          PopupMenuItem(
                            value: 'cancelled',
                            child: Text('Cancel plan'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    plan['overall_goal']?.toString() ??
                        'Improve recovery and wellness.',
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: (progressPercent / 100).clamp(0.0, 1.0).toDouble(),
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${progressPercent.toStringAsFixed(0)}% complete • '
                    '${plan['completed_tasks'] ?? 0}/${plan['task_total'] ?? 0} tasks',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${plan['start_date'] ?? ''} to ${plan['end_date'] ?? 'Ongoing'}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Plan tasks',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (tasks.isEmpty)
            const Card(
              child: ListTile(title: Text('No tasks were added to this plan.')),
            )
          else
            ...tasks.map((task) {
              final completed = task['status'] == 'completed';

              return Card(
                child: CheckboxListTile(
                  value: completed,
                  onChanged: (_) => _toggleTask(task),
                  title: Text(task['title']?.toString() ?? 'Recovery task'),
                  subtitle: Text(
                    '${task['scheduled_date'] ?? ''}'
                    '${task['target_value'] == null ? '' : ' • ${task['target_value']} ${task['target_unit'] ?? ''}'}',
                  ),
                  secondary: Icon(
                    completed
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked,
                    color: completed ? Colors.green : null,
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildProgressTab() {
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          FilledButton.icon(
            onPressed: _openProgressForm,
            icon: const Icon(Icons.add_chart_rounded),
            label: const Text('Record Today’s Progress'),
          ),
          const SizedBox(height: 18),
          const Text(
            'Recovery history',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (_progress.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.insights_rounded),
                title: Text('No recovery progress recorded yet.'),
              ),
            )
          else
            ..._progress.map((item) {
              final score = _doubleValue(item['recovery_score']);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item['progress_date']?.toString() ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${score.toStringAsFixed(1)} / 100',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF6059E8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: (score / 100).clamp(0.0, 1.0).toDouble(),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Mood ${item['mood_score'] ?? '-'} • '
                        'Stress ${item['stress_score'] ?? '-'} • '
                        'Energy ${item['energy_level'] ?? '-'}',
                      ),
                      if ((item['note']?.toString().trim() ?? '')
                          .isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(item['note'].toString()),
                      ],
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class RecoveryActivityScreen extends StatefulWidget {
  const RecoveryActivityScreen({required this.activity, super.key});

  final Map<String, dynamic> activity;

  @override
  State<RecoveryActivityScreen> createState() => _RecoveryActivityScreenState();
}

class _RecoveryActivityScreenState extends State<RecoveryActivityScreen> {
  final RecoveryService _service = RecoveryService();

  final TextEditingController _noteController = TextEditingController();

  int _rating = 5;
  bool _saving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  int _integerValue(dynamic value, {int fallback = 0}) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  Future<void> _complete() async {
    final activityId = _integerValue(widget.activity['id']);

    if (activityId <= 0) {
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      final minutes = _integerValue(
        widget.activity['duration_minutes'],
        fallback: 5,
      );

      await _service.saveActivityLog(
        activityId,
        status: 'completed',
        durationSeconds: minutes * 60,
        rating: _rating,
        note: _noteController.text,
      );

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
    final activity = widget.activity;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FC),
      appBar: AppBar(
        title: Text(activity['title']?.toString() ?? 'Recovery Activity'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity['description']?.toString() ?? '',
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                  const SizedBox(height: 14),
                  Chip(
                    avatar: const Icon(Icons.timer_outlined, size: 18),
                    label: Text('${activity['duration_minutes'] ?? 5} minutes'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Instructions',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    activity['instructions']?.toString() ?? '',
                    style: const TextStyle(height: 1.6),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'How helpful was it?',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: List.generate(5, (index) {
                      final value = index + 1;

                      return IconButton(
                        onPressed: () {
                          setState(() {
                            _rating = value;
                          });
                        },
                        icon: Icon(
                          value <= _rating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: Colors.amber,
                          size: 32,
                        ),
                      );
                    }),
                  ),
                  TextField(
                    controller: _noteController,
                    maxLength: 500,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Optional note',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _complete,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_outline_rounded),
            label: Text(_saving ? 'Saving...' : 'Mark Activity Completed'),
          ),
        ],
      ),
    );
  }
}

class RecoveryProgressScreen extends StatefulWidget {
  const RecoveryProgressScreen({this.activePlanId, super.key});

  final int? activePlanId;

  @override
  State<RecoveryProgressScreen> createState() => _RecoveryProgressScreenState();
}

class _RecoveryProgressScreenState extends State<RecoveryProgressScreen> {
  final RecoveryService _service = RecoveryService();

  final TextEditingController _noteController = TextEditingController();

  double _mood = 60;
  double _stress = 40;
  double _sleep = 7;
  double _energy = 60;
  double _habitCompletion = 50;
  double _activityCompletion = 50;
  double _burnout = 30;

  bool _saving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  String _dateString(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');

    final month = date.month.toString().padLeft(2, '0');

    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      await _service.saveProgress(
        recoveryPlanId: widget.activePlanId,
        progressDate: _dateString(DateTime.now()),
        moodScore: _mood,
        stressScore: _stress,
        sleepHours: _sleep,
        energyLevel: _energy,
        habitCompletionPercent: _habitCompletion,
        activityCompletionPercent: _activityCompletion,
        burnoutScore: _burnout,
        note: _noteController.text,
      );

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
      appBar: AppBar(title: const Text('Recovery Progress')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
          _sliderCard(
            title: 'Mood',
            subtitle: 'Higher means a better mood',
            value: _mood,
            suffix: '%',
            onChanged: (value) {
              setState(() {
                _mood = value;
              });
            },
          ),
          _sliderCard(
            title: 'Stress',
            subtitle: 'Higher means greater stress',
            value: _stress,
            suffix: '%',
            onChanged: (value) {
              setState(() {
                _stress = value;
              });
            },
          ),
          _sliderCard(
            title: 'Sleep',
            subtitle: 'Hours slept last night',
            value: _sleep,
            minimum: 0,
            maximum: 12,
            divisions: 24,
            suffix: ' hrs',
            onChanged: (value) {
              setState(() {
                _sleep = value;
              });
            },
          ),
          _sliderCard(
            title: 'Energy',
            subtitle: 'Current energy level',
            value: _energy,
            suffix: '%',
            onChanged: (value) {
              setState(() {
                _energy = value;
              });
            },
          ),
          _sliderCard(
            title: 'Habit completion',
            subtitle: 'Daily habit completion',
            value: _habitCompletion,
            suffix: '%',
            onChanged: (value) {
              setState(() {
                _habitCompletion = value;
              });
            },
          ),
          _sliderCard(
            title: 'Activity completion',
            subtitle: 'Recovery activity completion',
            value: _activityCompletion,
            suffix: '%',
            onChanged: (value) {
              setState(() {
                _activityCompletion = value;
              });
            },
          ),
          _sliderCard(
            title: 'Wellness strain score',
            subtitle: 'Higher means greater work/study strain',
            value: _burnout,
            suffix: '%',
            onChanged: (value) {
              setState(() {
                _burnout = value;
              });
            },
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _noteController,
                maxLength: 1000,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Progress note',
                  hintText: 'Write a short note about today...',
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Saving...' : 'Save Recovery Progress'),
          ),
        ],
      ),
    );
  }

  Widget _sliderCard({
    required String title,
    required String subtitle,
    required double value,
    required String suffix,
    required ValueChanged<double> onChanged,
    double minimum = 0,
    double maximum = 100,
    int divisions = 20,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)}$suffix',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF6059E8),
                  ),
                ),
              ],
            ),
            Slider(
              value: value,
              min: minimum,
              max: maximum,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
