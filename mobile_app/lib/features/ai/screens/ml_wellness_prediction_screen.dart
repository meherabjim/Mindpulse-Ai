import 'package:flutter/material.dart';

import '../services/ai_mobile_service.dart';

class MlWellnessPredictionScreen extends StatefulWidget {
  const MlWellnessPredictionScreen({super.key});

  @override
  State<MlWellnessPredictionScreen> createState() =>
      _MlWellnessPredictionScreenState();
}

class _MlWellnessPredictionScreenState
    extends State<MlWellnessPredictionScreen> {
  final AiMobileService _service = AiMobileService();

  int _moodScore = 3;
  int _stressLevel = 3;
  int _energyLevel = 3;

  double _sleepHours = 7;

  int _sleepQuality = 3;
  int _focusLevel = 3;
  int _motivationLevel = 3;
  int _restlessnessLevel = 3;
  int _workStudyPressure = 3;
  int _physicalActivityMinutes = 30;
  int _hydrationCups = 6;
  int _socialWithdrawal = 2;

  bool _loading = false;
  String? _errorMessage;

  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _predict() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final response = await _service.predictWellness(
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
        hydrationCups: _hydrationCups,
        socialWithdrawal: _socialWithdrawal,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _result = _asMap(response['data']);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
        _loading = false;
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

  double _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildIntroductionCard(),
        const SizedBox(height: 14),
        _buildCoreIndicators(),
        const SizedBox(height: 12),
        _buildStudyAndLifestyleIndicators(),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _loading ? null : _predict,
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.psychology_alt_outlined),
          label: Text(
            _loading ? 'Analyzing indicators...' : 'Run ML Wellness Prediction',
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 14),
          _buildErrorCard(),
        ],
        if (_result != null) ...[const SizedBox(height: 18), _buildResult()],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildIntroductionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.model_training_outlined),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'ML Wellness Prediction',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Enter today’s indicators to estimate wellness patterns, '
              'stress, and mood categories.',
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: const Text(
                'These models were trained with synthetic demo data. '
                'Results are experimental and are not a diagnosis.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoreIndicators() {
    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const Icon(Icons.favorite_outline),
        title: const Text(
          'Core wellness indicators',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        children: [
          _metricSlider(
            title: 'Mood',
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
            title: 'Social withdrawal',
            value: _socialWithdrawal.toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            valueLabel: '$_socialWithdrawal / 5',
            onChanged: (value) {
              setState(() {
                _socialWithdrawal = value.round();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStudyAndLifestyleIndicators() {
    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const Icon(Icons.school_outlined),
        title: const Text(
          'Study and lifestyle indicators',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        children: [
          _metricSlider(
            title: 'Focus level',
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
            title: 'Motivation level',
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
            title: 'Work/study pressure',
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
            title: 'Hydration',
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
        ],
      ),
    );
  }

  Widget _metricSlider({
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String valueLabel,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
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
    );
  }

  Widget _buildErrorCard() {
    return Card(
      color: Colors.red.shade50,
      child: ListTile(
        leading: Icon(Icons.error_outline, color: Colors.red.shade700),
        title: const Text('Prediction failed'),
        subtitle: Text(_errorMessage ?? 'Unknown error'),
      ),
    );
  }

  Widget _buildResult() {
    final result = _result!;

    final predictions = _asMap(result['predictions']);

    final productionReady = result['production_ready'] == true;

    final warning = result['warning']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Prediction result',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Chip(
                      label: Text(
                        productionReady ? 'PRODUCTION' : 'DEMO MODEL',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Engine: '
                  '${result['engine'] ?? 'unknown'}',
                ),
                Text(
                  'Training data: '
                  '${result['training_data_type'] ?? 'unknown'}',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _predictionCard(
          title: 'Wellness strain indicator',
          icon: Icons.battery_alert_outlined,
          prediction: _asMap(predictions['burnout']),
        ),
        const SizedBox(height: 10),
        _predictionCard(
          title: 'Stress level',
          icon: Icons.bolt_outlined,
          prediction: _asMap(predictions['stress']),
        ),
        const SizedBox(height: 10),
        _predictionCard(
          title: 'Mood category',
          icon: Icons.mood_outlined,
          prediction: _asMap(predictions['mood']),
        ),
        if (warning.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            color: Colors.amber.shade50,
            child: ListTile(
              leading: Icon(Icons.info_outline, color: Colors.amber.shade900),
              title: const Text('Model limitation'),
              subtitle: Text(warning),
            ),
          ),
        ],
      ],
    );
  }

  Widget _predictionCard({
    required String title,
    required IconData icon,
    required Map<String, dynamic> prediction,
  }) {
    final label = prediction['label']?.toString() ?? 'unknown';

    final confidence = _asDouble(prediction['confidence']);

    final probabilities = _asMap(prediction['probabilities']);

    final probabilityEntries = probabilities.entries.toList()
      ..sort((first, second) {
        final firstValue = _asDouble(first.value);

        final secondValue = _asDouble(second.value);

        return secondValue.compareTo(firstValue);
      });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Chip(label: Text(label.toUpperCase())),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Confidence: '
              '${(confidence * 100).toStringAsFixed(1)}%',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: confidence.clamp(0.0, 1.0).toDouble(),
              minHeight: 9,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 14),
            const Text(
              'Probability distribution',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: probabilityEntries.map((entry) {
                final percentage = _asDouble(entry.value) * 100;

                return Chip(
                  label: Text(
                    '${entry.key}: '
                    '${percentage.toStringAsFixed(1)}%',
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            Text(
              'Model version: '
              '${prediction['model_version'] ?? 'unknown'}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
