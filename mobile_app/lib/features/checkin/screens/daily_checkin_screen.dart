import 'package:flutter/material.dart';

import '../services/daily_checkin_service.dart';

class DailyCheckinScreen extends StatefulWidget {
  const DailyCheckinScreen({super.key});

  @override
  State<DailyCheckinScreen> createState() => _DailyCheckinScreenState();
}

class _DailyCheckinScreenState extends State<DailyCheckinScreen> {
  final DailyCheckinService _service = DailyCheckinService();

  final TextEditingController _noteController = TextEditingController();

  int _moodScore = 3;
  int _stressLevel = 3;
  int _energyLevel = 3;
  double _sleepHours = 7;
  int _sleepQuality = 3;
  int _focusLevel = 3;
  int _motivationLevel = 3;
  int _restlessnessLevel = 3;
  int _workStudyPressure = 3;
  int _physicalActivityMinutes = 20;
  int _waterIntakeGlasses = 6;

  bool _loading = true;
  bool _submitting = false;

  String? _errorMessage;
  Map<String, dynamic>? _todayCheckin;
  List<Map<String, dynamic>> _history = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _loadCheckinData();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadCheckinData() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      final results = await Future.wait([
        _service.getTodayCheckin(),
        _service.getCheckinHistory(),
      ]);

      final todayPayload = results[0];
      final historyPayload = results[1];

      final todayData = _asMap(todayPayload['data']);

      final historyData = _asMap(historyPayload['data']);

      final hasCheckin = todayData['has_checkin'] == true;

      final todayCheckin = hasCheckin
          ? _asMap(todayData['checkin'])
          : <String, dynamic>{};

      final historyItems = _asList(
        historyData['checkins'],
      ).map(_asMap).toList();

      if (!mounted) return;

      setState(() {
        _todayCheckin = todayCheckin.isEmpty ? null : todayCheckin;

        _history = historyItems;
        _loading = false;
      });

      if (todayCheckin.isNotEmpty) {
        _applyExistingCheckin(todayCheckin);
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString();
        _loading = false;
      });
    }
  }

  void _applyExistingCheckin(Map<String, dynamic> checkin) {
    if (!mounted) return;

    setState(() {
      _moodScore = _integerValue(checkin['mood_score'], fallback: 3);

      _stressLevel = _integerValue(checkin['stress_level'], fallback: 3);

      _energyLevel = _integerValue(checkin['energy_level'], fallback: 3);

      _sleepHours = _doubleValue(checkin['sleep_hours'], fallback: 7);

      _sleepQuality = _integerValue(checkin['sleep_quality'], fallback: 3);

      _focusLevel = _integerValue(checkin['focus_level'], fallback: 3);

      _motivationLevel = _integerValue(
        checkin['motivation_level'],
        fallback: 3,
      );

      _restlessnessLevel = _integerValue(
        checkin['restlessness_level'],
        fallback: 3,
      );

      _workStudyPressure = _integerValue(
        checkin['work_study_pressure'],
        fallback: 3,
      );

      _physicalActivityMinutes = _integerValue(
        checkin['physical_activity_minutes'],
        fallback: 0,
      );

      _waterIntakeGlasses = _integerValue(
        checkin['water_intake_glasses'],
        fallback: 0,
      );

      _noteController.text = checkin['note']?.toString() ?? '';
    });
  }

  Future<void> _submitCheckin() async {
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final response = await _service.submitCheckin(
        moodScore: _moodScore,
        stressLevel: _stressLevel,
        energyLevel: _energyLevel,
        sleepHours: _sleepHours,
        sleepQuality: _sleepQuality,
        focusLevel: _focusLevel,
        motivationLevel: _motivationLevel,
        restlessnessLevel: _restlessnessLevel,
        workStudyPressure: _workStudyPressure,
        physicalActivityMinutes: _physicalActivityMinutes,
        waterIntakeGlasses: _waterIntakeGlasses,
        note: _noteController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response['message']?.toString() ??
                'Daily check-in saved successfully.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

      await _loadCheckinData();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }

  List<dynamic> _asList(dynamic value) {
    if (value is List) {
      return value;
    }

    return <dynamic>[];
  }

  int _integerValue(dynamic value, {required int fallback}) {
    if (value is num) {
      return value.round();
    }

    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  double _doubleValue(dynamic value, {required double fallback}) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F7FC),
        appBar: AppBar(
          title: const Text('Daily Check-in'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.favorite_outline), text: 'Today'),
              Tab(icon: Icon(Icons.history), text: 'History'),
            ],
          ),
          actions: [
            IconButton(
              onPressed: _loading ? null : _loadCheckinData,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: Column(
          children: [
            if (_errorMessage != null) _buildErrorBanner(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      children: [_buildTodayTab(), _buildHistoryTab()],
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildTodaySummary(),
        const SizedBox(height: 16),
        const Text(
          'How are you feeling today?',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          'Adjust the indicators below. '
          'Submitting again today will update '
          'today’s existing check-in.',
        ),
        const SizedBox(height: 18),
        _metricSlider(
          title: 'Mood',
          subtitle: '1 = Very low, 5 = Excellent',
          icon: Icons.mood,
          value: _moodScore.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          valueLabel: '$_moodScore / 5',
          onChanged: (value) {
            setState(() {
              _moodScore = value.round();
            });
          },
        ),
        _metricSlider(
          title: 'Stress',
          subtitle: '1 = Very low, 5 = Very high',
          icon: Icons.psychology_outlined,
          value: _stressLevel.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          valueLabel: '$_stressLevel / 5',
          onChanged: (value) {
            setState(() {
              _stressLevel = value.round();
            });
          },
        ),
        _metricSlider(
          title: 'Energy',
          subtitle: '1 = Exhausted, 5 = Energetic',
          icon: Icons.bolt_outlined,
          value: _energyLevel.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          valueLabel: '$_energyLevel / 5',
          onChanged: (value) {
            setState(() {
              _energyLevel = value.round();
            });
          },
        ),
        _metricSlider(
          title: 'Sleep duration',
          subtitle: 'Hours slept last night',
          icon: Icons.bedtime_outlined,
          value: _sleepHours,
          min: 0,
          max: 12,
          divisions: 24,
          valueLabel: '${_sleepHours.toStringAsFixed(1)} hours',
          onChanged: (value) {
            setState(() {
              _sleepHours = value;
            });
          },
        ),
        _metricSlider(
          title: 'Sleep quality',
          subtitle: '1 = Very poor, 5 = Excellent',
          icon: Icons.nightlight_outlined,
          value: _sleepQuality.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          valueLabel: '$_sleepQuality / 5',
          onChanged: (value) {
            setState(() {
              _sleepQuality = value.round();
            });
          },
        ),
        _metricSlider(
          title: 'Focus',
          subtitle: 'Ability to concentrate today',
          icon: Icons.center_focus_strong,
          value: _focusLevel.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          valueLabel: '$_focusLevel / 5',
          onChanged: (value) {
            setState(() {
              _focusLevel = value.round();
            });
          },
        ),
        _metricSlider(
          title: 'Motivation',
          subtitle: 'Motivation for study or work',
          icon: Icons.trending_up,
          value: _motivationLevel.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          valueLabel: '$_motivationLevel / 5',
          onChanged: (value) {
            setState(() {
              _motivationLevel = value.round();
            });
          },
        ),
        _metricSlider(
          title: 'Restlessness',
          subtitle: '1 = Calm, 5 = Very restless',
          icon: Icons.motion_photos_on_outlined,
          value: _restlessnessLevel.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          valueLabel: '$_restlessnessLevel / 5',
          onChanged: (value) {
            setState(() {
              _restlessnessLevel = value.round();
            });
          },
        ),
        _metricSlider(
          title: 'Study pressure',
          subtitle: 'Current academic or work pressure',
          icon: Icons.school_outlined,
          value: _workStudyPressure.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          valueLabel: '$_workStudyPressure / 5',
          onChanged: (value) {
            setState(() {
              _workStudyPressure = value.round();
            });
          },
        ),
        _metricSlider(
          title: 'Physical activity',
          subtitle: 'Minutes of activity today',
          icon: Icons.directions_walk_outlined,
          value: _physicalActivityMinutes.toDouble(),
          min: 0,
          max: 180,
          divisions: 36,
          valueLabel: '$_physicalActivityMinutes minutes',
          onChanged: (value) {
            setState(() {
              _physicalActivityMinutes = value.round();
            });
          },
        ),
        _metricSlider(
          title: 'Water intake',
          subtitle: 'Glasses of water today',
          icon: Icons.water_drop_outlined,
          value: _waterIntakeGlasses.toDouble(),
          min: 0,
          max: 15,
          divisions: 15,
          valueLabel: '$_waterIntakeGlasses glasses',
          onChanged: (value) {
            setState(() {
              _waterIntakeGlasses = value.round();
            });
          },
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _noteController,
              minLines: 3,
              maxLines: 6,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Optional note',
                hintText: 'Write a short reflection about today...',
                alignLabelWithHint: true,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _submitting ? null : _submitCheckin,
          icon: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_circle_outline),
          label: Text(
            _submitting
                ? 'Saving...'
                : _todayCheckin == null
                ? 'Save Today’s Check-in'
                : 'Update Today’s Check-in',
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _buildTodaySummary() {
    if (_todayCheckin == null) {
      return Card(
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.today_outlined)),
          title: const Text('No check-in submitted today'),
          subtitle: const Text(
            'Complete the form to record '
            'your current wellness status.',
          ),
        ),
      );
    }

    final burnoutScore = _doubleValue(
      _todayCheckin!['burnout_score'],
      fallback: 0,
    );

    final riskLevel =
        _todayCheckin!['risk_level']?.toString() ??
        _todayCheckin!['burnout_risk_level']?.toString() ??
        'unknown';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.verified_outlined, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Today’s check-in saved',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ],
            ),
            if (burnoutScore > 0) ...[
              const SizedBox(height: 14),
              Text(
                'Wellness strain score: '
                '${burnoutScore.toStringAsFixed(1)} / 100',
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (burnoutScore / 100).clamp(0.0, 1.0).toDouble(),
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(height: 8),
              Text(
                'Risk level: '
                '${riskLevel.toUpperCase()}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metricSlider({
    required String title,
    required String subtitle,
    required IconData icon,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String valueLabel,
    required ValueChanged<double> onChanged,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
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
                  valueLabel,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              label: valueLabel,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_history.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadCheckinData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Icon(Icons.history_toggle_off, size: 72, color: Colors.grey),
            SizedBox(height: 18),
            Center(
              child: Text(
                'No check-in history found.',
                style: TextStyle(fontSize: 17),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCheckinData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _history.length,
        itemBuilder: (context, index) {
          return _buildHistoryCard(_history[index]);
        },
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> checkin) {
    final date = checkin['checkin_date']?.toString() ?? 'Unknown date';

    final mood = _integerValue(checkin['mood_score'], fallback: 0);

    final stress = _integerValue(checkin['stress_level'], fallback: 0);

    final energy = _integerValue(checkin['energy_level'], fallback: 0);

    final sleep = _doubleValue(checkin['sleep_hours'], fallback: 0);

    final burnout = _doubleValue(checkin['burnout_score'], fallback: 0);

    final risk =
        checkin['risk_level']?.toString() ??
        checkin['burnout_risk_level']?.toString() ??
        '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(child: Text(mood > 0 ? '$mood' : '-')),
        title: Text(date, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          'Mood $mood • Stress $stress • '
          'Energy $energy',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        children: [
          _historyRow('Sleep', '${sleep.toStringAsFixed(1)} hours'),
          _historyRow(
            'Water',
            '${_integerValue(checkin['water_intake_glasses'], fallback: 0)} glasses',
          ),
          _historyRow(
            'Activity',
            '${_integerValue(checkin['physical_activity_minutes'], fallback: 0)} minutes',
          ),
          if (burnout > 0)
            _historyRow(
              'Wellness strain',
              '${burnout.toStringAsFixed(1)} / 100'
                  '${risk.isEmpty ? '' : ' • ${risk.toUpperCase()}'}',
            ),
          if ((checkin['note']?.toString().trim() ?? '').isNotEmpty)
            _historyRow('Note', checkin['note'].toString()),
        ],
      ),
    );
  }

  Widget _historyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
