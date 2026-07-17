import 'package:flutter/material.dart';

import '../../safety/widgets/safety_escalation_card.dart';
import '../../recommendations/screens/recommendation_followup_screen.dart';
import '../../safety/screens/emergency_support_screen.dart';

import '../services/ai_mobile_service.dart';
import 'ml_wellness_prediction_screen.dart';

class AiWellnessScreen extends StatefulWidget {
  const AiWellnessScreen({super.key});

  @override
  State<AiWellnessScreen> createState() => _AiWellnessScreenState();
}

class _AiWellnessScreenState extends State<AiWellnessScreen> {
  final AiMobileService _service = AiMobileService();

  final TextEditingController _journalController = TextEditingController(
    text:
        'Today I felt stressed and tired because of study pressure, '
        'but I remain hopeful that I can improve gradually.',
  );

  int _moodScore = 3;
  int _stressLevel = 3;
  int _energyLevel = 3;
  double _sleepHours = 7;
  int _hydrationCups = 6;
  double _burnoutScore = 40;

  bool _healthLoading = true;
  bool _wellnessLoading = false;
  bool _journalLoading = false;
  bool _serviceAvailable = false;

  String _serviceStatus = 'Checking AI service...';
  String? _errorMessage;

  Map<String, dynamic>? _wellnessResult;
  Map<String, dynamic>? _journalResult;

  @override
  void initState() {
    super.initState();
    _checkHealth();
  }

  @override
  void dispose() {
    _journalController.dispose();
    _service.dispose();
    super.dispose();
  }

  Future<void> _checkHealth() async {
    setState(() {
      _healthLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _service.health();
      final data = _asMap(response['data']);

      if (!mounted) {
        return;
      }

      setState(() {
        _serviceStatus =
            '${data['service'] ?? 'MindPulse AI'}: '
            '${data['status'] ?? 'healthy'}';

        _serviceAvailable = true;
        _healthLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _serviceStatus = 'AI service unavailable';
        _serviceAvailable = false;
        _errorMessage = error.toString();
        _healthLoading = false;
      });
    }
  }

  Future<void> _generateWellnessPlan() async {
    setState(() {
      _wellnessLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _service.getRecommendations(
        moodScore: _moodScore,
        stressLevel: _stressLevel,
        energyLevel: _energyLevel,
        sleepHours: _sleepHours,
        hydrationCups: _hydrationCups,
        burnoutScore: _burnoutScore,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _wellnessResult = _asMap(response['data']);
        _wellnessLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
        _wellnessLoading = false;
      });
    }
  }

  Future<void> _analyzeJournal() async {
    final text = _journalController.text.trim();

    if (text.isEmpty) {
      setState(() {
        _errorMessage = 'Please write a journal entry first.';
      });

      return;
    }

    setState(() {
      _journalLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _service.analyzeJournal(
        text: text,
        moodScore: _moodScore,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _journalResult = _asMap(response['data']);
        _journalLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
        _journalLoading = false;
      });
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: const Text('MindPulse AI'),
          centerTitle: false,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.auto_awesome), text: 'Wellness Plan'),
              Tab(icon: Icon(Icons.menu_book_outlined), text: 'Journal AI'),
              Tab(
                icon: Icon(Icons.model_training_outlined),
                text: 'ML Prediction',
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            _buildServiceStatus(),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Material(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
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
                  ),
                ),
              ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildWellnessTab(),
                  _buildJournalTab(),
                  const MlWellnessPredictionScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceStatus() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E7EF)),
      ),
      child: Row(
        children: [
          if (_healthLoading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              _serviceAvailable ? Icons.check_circle : Icons.error_outline,
              color: _serviceAvailable ? Colors.green : Colors.red,
              size: 20,
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _serviceStatus,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            onPressed: _healthLoading ? null : _checkHealth,
            icon: const Icon(Icons.refresh),
            tooltip: 'Check again',
          ),
        ],
      ),
    );
  }

  Widget _buildWellnessTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Daily wellness indicators',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'Adjust today’s values to receive an explainable '
          'wellness plan.',
        ),
        const SizedBox(height: 18),
        _metricSlider(
          title: 'Mood',
          leftLabel: 'Very low',
          rightLabel: 'Very good',
          helperText:
              'Choose how your mood feels today. A lower value indicates more strain.',
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
          leftLabel: 'Very low',
          rightLabel: 'Very high',
          helperText:
              'Choose your current stress level. A higher value indicates more strain.',
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
          leftLabel: 'Very low',
          rightLabel: 'Very high',
          helperText:
              'Choose your current energy level. A lower value indicates more strain.',
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
          title: 'Sleep',
          leftLabel: '0 hours',
          rightLabel: '12 hours',
          helperText:
              'Enter the approximate hours slept. This prototype treats less than 7 hours as a sleep deficit.',
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
          title: 'Hydration',
          leftLabel: '0 cups',
          rightLabel: '16 cups',
          helperText:
              'Hydration is used to select practical guidance. It does not directly change the strain indicator.',
          value: _hydrationCups.toDouble(),
          min: 0,
          max: 15,
          divisions: 15,
          valueLabel: '$_hydrationCups cups',
          onChanged: (value) {
            setState(() {
              _hydrationCups = value.round();
            });
          },
        ),
        _metricSlider(
          title: 'Existing wellness strain score',
          leftLabel: '0',
          rightLabel: '100',
          helperText:
              'Use the most recent available wellness strain indicator. A higher value increases the combined strain indicator.',
          value: _burnoutScore,
          min: 0,
          max: 100,
          divisions: 20,
          valueLabel: '${_burnoutScore.round()} / 100',
          onChanged: (value) {
            setState(() {
              _burnoutScore = value;
            });
          },
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _wellnessLoading ? null : _generateWellnessPlan,
          icon: _wellnessLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome),
          label: Text(
            _wellnessLoading ? 'Generating...' : 'Create Wellness Support Plan',
          ),
        ),
        if (_wellnessResult != null) ...[
          const SizedBox(height: 18),
          _buildWellnessResult(),
        ],
      ],
    );
  }

  Widget _metricSlider({
    required String title,
    required String leftLabel,
    required String rightLabel,
    required String valueLabel,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    String? helperText,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

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
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    valueLabel,
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            if (helperText != null && helperText.trim().isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(
                helperText,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              label: valueLabel,
              onChanged: onChanged,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      leftLabel,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      rightLabel,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWellnessResult() {
    final result = _wellnessResult!;

    final riskScore = (result['risk_score'] as num?)?.toDouble() ?? 0;
    final riskLevel = result['risk_level']?.toString() ?? 'unknown';

    final normalizedRisk = riskLevel.toLowerCase();

    final showSafetySupport =
        normalizedRisk == 'elevated' ||
        normalizedRisk == 'high' ||
        normalizedRisk == 'critical' ||
        riskScore >= 70;

    final interpretation = result['interpretation']?.toString() ?? '';

    final recommendations = _asList(result['recommendations']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Wellness support summary',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${riskScore.toStringAsFixed(1)} / 100',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Chip(label: Text(riskLevel.toUpperCase())),
                  ],
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: (riskScore / 100).clamp(0, 1),
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 14),
                Text(interpretation),
              ],
            ),
          ),
        ),
        if (showSafetySupport) ...[
          const SizedBox(height: 12),
          SafetyEscalationCard(
            severity: riskLevel,
            title: 'Elevated AI wellness support',
            message:
                'Your wellness indicators show '
                'elevated strain. Consider '
                'contacting someone you trust '
                'or seeking qualified support. '
                'Use emergency support when '
                'there is immediate danger.',
          ),
        ],
        const SizedBox(height: 12),
        const Text(
          'Recommended actions',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...recommendations.map((item) {
          final recommendation = _asMap(item);

          return _buildRecommendationCard(recommendation);
        }),
        const SizedBox(height: 6),
        Text(
          result['disclaimer']?.toString() ??
              'This is not a medical diagnosis.',
          style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  int _recommendationDuration(String category) {
    switch (category) {
      case 'hydration':
        return 120;

      case 'stress':
      case 'support':
      case 'maintenance':
        return 300;

      case 'sleep':
      case 'energy':
        return 600;

      default:
        return 300;
    }
  }

  Widget _buildRecommendationCard(Map<String, dynamic> recommendation) {
    final category = recommendation['category']?.toString() ?? 'general';

    final title = recommendation['title']?.toString() ?? 'Wellness action';

    final action = recommendation['action']?.toString() ?? '';

    final priority =
        recommendation['priority']?.toString().toLowerCase() ?? 'medium';

    final durationSeconds = _recommendationDuration(category);

    final isProfessionalSupport = category == 'professional_support';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(child: Icon(Icons.checklist_rounded)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(action, style: const TextStyle(height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text(priority.toUpperCase())),
                if (!isProfessionalSupport)
                  Chip(
                    avatar: const Icon(Icons.schedule_outlined, size: 18),
                    label: Text(
                      '${durationSeconds ~/ 60} '
                      'min suggested',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: isProfessionalSupport
                  ? FilledButton.tonalIcon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const EmergencySupportScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.health_and_safety_outlined),
                      label: const Text('Review support options'),
                    )
                  : FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => RecommendationFollowupScreen(
                              category: category,
                              title: title,
                              action: action,
                              priority: priority,
                              suggestedDurationSeconds: durationSeconds,
                              beforeMood: _moodScore,
                              beforeStress: _stressLevel,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.play_circle_outline),
                      label: const Text('Start follow-up'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJournalTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'AI journal reflection',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'Your full journal text is analyzed temporarily. '
          'Only privacy-safe summary metadata is logged.',
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _journalController,
          minLines: 7,
          maxLines: 12,
          maxLength: 10000,
          decoration: const InputDecoration(
            labelText: 'How are you feeling today?',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: _journalLoading ? null : _analyzeJournal,
          icon: _journalLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.psychology_alt_outlined),
          label: Text(_journalLoading ? 'Analyzing...' : 'Analyze Journal'),
        ),
        if (_journalResult != null) ...[
          const SizedBox(height: 18),
          _buildJournalResult(),
        ],
      ],
    );
  }

  Widget _buildJournalResult() {
    final result = _journalResult!;

    final safety = _asMap(result['safety']);

    final insights = _asList(result['key_insights']);

    final emotions = _asList(result['emotions']);

    final flagged = safety['flagged'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Journal analysis',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      label: Text(
                        'Sentiment: '
                        '${result['sentiment'] ?? 'neutral'}',
                      ),
                    ),
                    Chip(
                      label: Text(
                        'Confidence: '
                        '${(((result['confidence'] as num?)?.toDouble() ?? 0) * 100).round()}%',
                      ),
                    ),
                    Chip(
                      label: Text(
                        'Language: '
                        '${result['detected_language'] ?? 'unknown'}',
                      ),
                    ),
                  ],
                ),
                if (emotions.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'Detected emotional themes',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: emotions.map((item) {
                      final emotion = _asMap(item);

                      return Chip(
                        label: Text(
                          emotion['emotion']?.toString() ?? 'emotion',
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: flagged ? Colors.red.shade50 : Colors.green.shade50,
          child: ListTile(
            leading: Icon(
              flagged
                  ? Icons.warning_amber_rounded
                  : Icons.verified_user_outlined,
              color: flagged ? Colors.red.shade700 : Colors.green.shade700,
            ),
            title: Text(
              flagged
                  ? 'Safety concern detected'
                  : 'No immediate safety signal detected',
            ),
            subtitle: Text('Severity: ${safety['severity'] ?? 'low'}'),
          ),
        ),
        if (flagged) ...[
          SafetyEscalationCard(
            severity: safety['severity']?.toString() ?? 'moderate',
          ),
          const SizedBox(height: 12),
        ],

        const SizedBox(height: 12),
        const Text(
          'Key insights',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...insights.map(
          (item) => Card(
            child: ListTile(
              leading: const Icon(Icons.lightbulb_outline),
              title: Text(item.toString()),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          result['disclaimer']?.toString() ??
              'This analysis is informational only.',
          style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }
}
