import 'package:flutter/material.dart';

import '../../safety/widgets/safety_escalation_card.dart';

import '../services/wellness_scan_service.dart';

class WellnessScanScreen extends StatefulWidget {
  const WellnessScanScreen({super.key});

  @override
  State<WellnessScanScreen> createState() => _WellnessScanScreenState();
}

class _WellnessScanScreenState extends State<WellnessScanScreen> {
  final WellnessScanService _service = WellnessScanService();

  List<Map<String, dynamic>> _questions = <Map<String, dynamic>>[];

  List<Map<String, dynamic>> _history = <Map<String, dynamic>>[];

  Map<String, dynamic>? _latestScan;
  Map<String, dynamic>? _latestBurnout;

  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait<dynamic>([
        _service.listQuestions(),
        _service.getLatestScan(),
        _service.getScanHistory(),
        _service.getLatestBurnout(),
      ]);

      final historyResult = results[2] as Map<String, dynamic>;

      if (!mounted) return;

      setState(() {
        _questions = results[0] as List<Map<String, dynamic>>;

        _latestScan = results[1] as Map<String, dynamic>?;

        _history =
            historyResult['scans'] as List<Map<String, dynamic>>? ??
            <Map<String, dynamic>>[];

        _latestBurnout = results[3] as Map<String, dynamic>?;

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

  Future<void> _startScan() async {
    if (_questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active wellness questions are available.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      return;
    }

    final scan = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute<Map<String, dynamic>>(
        builder: (_) => WellnessQuestionnaireScreen(questions: _questions),
      ),
    );

    if (scan == null || !mounted) {
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => WellnessScanResultScreen(scan: scan),
      ),
    );

    if (mounted) {
      await _loadData();
    }
  }

  Future<void> _openScan(Map<String, dynamic> summary) async {
    final scanId = _integerValue(summary['id']);

    if (scanId == null) return;

    try {
      final scan = await _service.getScanById(scanId);

      if (!mounted) return;

      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => WellnessScanResultScreen(scan: scan),
        ),
      );
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

  double _doubleValue(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _displayDate(dynamic value) {
    final text = value?.toString() ?? '';

    if (text.isEmpty) {
      return 'Unknown date';
    }

    final normalized = text.replaceFirst('T', ' ').replaceFirst('Z', '');

    return normalized.length >= 16 ? normalized.substring(0, 16) : normalized;
  }

  Color _riskColor(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'low':
        return Colors.green;
      case 'mild':
        return Colors.amber.shade800;
      case 'moderate':
        return Colors.orange.shade800;
      case 'elevated':
        return Colors.red.shade700;
      default:
        return Colors.grey;
    }
  }

  IconData _riskIcon(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'low':
        return Icons.check_circle_rounded;
      case 'mild':
        return Icons.info_rounded;
      case 'moderate':
        return Icons.warning_amber_rounded;
      case 'elevated':
        return Icons.warning_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  String _riskLabel(String value) {
    if (value.isEmpty) {
      return 'UNKNOWN';
    }

    return value.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FC),
      appBar: AppBar(
        title: const Text('Wellness Scan'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadData,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _startScan,
        icon: const Icon(Icons.health_and_safety),
        label: const Text('Start Scan'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                children: [
                  if (_errorMessage != null) _buildErrorBanner(),
                  _buildIntroductionCard(),
                  const SizedBox(height: 16),
                  if (_latestScan == null)
                    _buildNoScanCard()
                  else
                    _buildLatestScanCard(),
                  if (_latestBurnout != null) ...[
                    const SizedBox(height: 16),
                    _buildBurnoutCard(),
                  ],
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Previous Scans',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        '${_history.length}',
                        style: const TextStyle(
                          color: Color(0xFF6059E8),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_history.isEmpty)
                    _buildEmptyHistory()
                  else
                    ..._history.map(_buildHistoryCard),
                ],
              ),
            ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: Colors.red.shade700),
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

  Widget _buildIntroductionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5C58E8), Color(0xFF875EF0)],
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: const [
          BoxShadow(
            color: Color(0x335C58E8),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0x33FFFFFF),
              borderRadius: BorderRadius.circular(19),
            ),
            child: const Icon(
              Icons.monitor_heart_outlined,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Check your current wellbeing',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_questions.length} questions • '
                  'about 2–3 minutes',
                  style: const TextStyle(
                    color: Color(0xFFEDEBFF),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 9),
                const Text(
                  'Answer honestly to receive an explainable wellness-risk summary and practical guidance.',
                  style: TextStyle(color: Color(0xFFEDEBFF), height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoScanCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 42),
        child: Column(
          children: [
            const Icon(
              Icons.health_and_safety_outlined,
              size: 68,
              color: Colors.grey,
            ),
            const SizedBox(height: 14),
            const Text(
              'No wellness scan completed yet.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 15),
            FilledButton.icon(
              onPressed: _startScan,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Start First Scan'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLatestScanCard() {
    final scan = _latestScan!;

    final score = _doubleValue(scan['total_score']);

    final riskLevel = scan['risk_level']?.toString() ?? 'unknown';

    final riskColor = _riskColor(riskLevel);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openScan(scan),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Latest Scan Result',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Icon(_riskIcon(riskLevel), color: riskColor),
                ],
              ),
              const SizedBox(height: 17),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    score.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 38,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      color: riskColor,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 4),
                    child: Text('/ 100'),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: riskColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      _riskLabel(riskLevel),
                      style: TextStyle(
                        color: riskColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              LinearProgressIndicator(
                value: (score / 100).clamp(0, 1),
                minHeight: 9,
                borderRadius: BorderRadius.circular(10),
                color: riskColor,
                backgroundColor: riskColor.withValues(alpha: 0.12),
              ),
              const SizedBox(height: 14),
              Text(
                scan['summary']?.toString() ?? '',
                style: const TextStyle(height: 1.45, color: Color(0xFF67677A)),
              ),
              const SizedBox(height: 11),
              Text(
                _displayDate(scan['completed_at']),
                style: const TextStyle(color: Color(0xFF85859A), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBurnoutCard() {
    final assessment = _latestBurnout!;

    final score = _doubleValue(assessment['burnout_score']);

    final riskLevel = assessment['risk_level']?.toString() ?? 'unknown';

    final riskColor = _riskColor(riskLevel);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Row(
          children: [
            CircleAvatar(
              radius: 27,
              backgroundColor: riskColor.withValues(alpha: 0.12),
              child: Icon(Icons.psychology_alt_outlined, color: riskColor),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Latest Wellness Strain',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${score.toStringAsFixed(1)} / 100 • '
                    '${_riskLabel(riskLevel)}',
                    style: TextStyle(
                      color: riskColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Source: ${assessment['assessment_source'] ?? 'unknown'}',
                    style: const TextStyle(
                      color: Color(0xFF85859A),
                      fontSize: 12,
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

  Widget _buildEmptyHistory() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 35, horizontal: 20),
        child: Center(
          child: Text(
            'Completed scans will appear here.',
            style: TextStyle(color: Color(0xFF74748A)),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> scan) {
    final score = _doubleValue(scan['total_score']);

    final riskLevel = scan['risk_level']?.toString() ?? 'unknown';

    final riskColor = _riskColor(riskLevel);

    return Card(
      margin: const EdgeInsets.only(bottom: 11),
      child: ListTile(
        onTap: () => _openScan(scan),
        leading: CircleAvatar(
          backgroundColor: riskColor.withValues(alpha: 0.12),
          child: Icon(_riskIcon(riskLevel), color: riskColor),
        ),
        title: Text(
          '${score.toStringAsFixed(1)} / 100',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          '${_riskLabel(riskLevel)} • '
          '${_displayDate(scan['completed_at'])}',
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class WellnessQuestionnaireScreen extends StatefulWidget {
  const WellnessQuestionnaireScreen({required this.questions, super.key});

  final List<Map<String, dynamic>> questions;

  @override
  State<WellnessQuestionnaireScreen> createState() =>
      _WellnessQuestionnaireScreenState();
}

class _WellnessQuestionnaireScreenState
    extends State<WellnessQuestionnaireScreen> {
  final WellnessScanService _service = WellnessScanService();

  final PageController _pageController = PageController();

  final Map<int, int> _answers = <int, int>{};

  int _currentIndex = 0;
  bool _submitting = false;

  String? _errorMessage;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _currentQuestion => widget.questions[_currentIndex];

  int get _totalQuestions => widget.questions.length;

  int? _questionId(Map<String, dynamic> question) {
    final value = question['id'];

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '');
  }

  int? _selectedAnswer(Map<String, dynamic> question) {
    final id = _questionId(question);

    return id == null ? null : _answers[id];
  }

  void _selectAnswer(Map<String, dynamic> question, int value) {
    final id = _questionId(question);

    if (id == null) return;

    setState(() {
      _answers[id] = value;
      _errorMessage = null;
    });
  }

  Future<void> _continue() async {
    if (_selectedAnswer(_currentQuestion) == null) {
      setState(() {
        _errorMessage = 'Select an answer before continuing.';
      });

      return;
    }

    if (_currentIndex == _totalQuestions - 1) {
      await _submit();
      return;
    }

    setState(() {
      _currentIndex += 1;
      _errorMessage = null;
    });

    await _pageController.animateToPage(
      _currentIndex,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  Future<void> _back() async {
    if (_currentIndex == 0) return;

    setState(() {
      _currentIndex -= 1;
      _errorMessage = null;
    });

    await _pageController.animateToPage(
      _currentIndex,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  Future<void> _submit() async {
    if (_answers.length != _totalQuestions) {
      setState(() {
        _errorMessage = 'All wellness questions must be answered.';
      });

      return;
    }

    final answers = widget.questions.map((question) {
      final id = _questionId(question);

      return <String, dynamic>{
        'question_id': id,
        'response_value': id == null ? null : _answers[id],
        'response_text': null,
      };
    }).toList();

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final scan = await _service.submitScan(answers);

      if (!mounted) return;

      Navigator.of(context).pop(scan);
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

  List<MapEntry<int, String>> _options(String responseScale) {
    switch (responseScale) {
      case '1_to_10':
        return List<MapEntry<int, String>>.generate(
          10,
          (index) => MapEntry<int, String>(index + 1, '${index + 1}'),
        );

      case 'yes_no':
        return const <MapEntry<int, String>>[
          MapEntry<int, String>(0, 'No'),
          MapEntry<int, String>(1, 'Yes'),
        ];

      default:
        return const <MapEntry<int, String>>[
          MapEntry<int, String>(1, 'Not at all'),
          MapEntry<int, String>(2, 'Slightly'),
          MapEntry<int, String>(3, 'Moderately'),
          MapEntry<int, String>(4, 'Very much'),
          MapEntry<int, String>(5, 'Extremely'),
        ];
    }
  }

  String _categoryLabel(dynamic value) {
    final text = value?.toString() ?? '';

    if (text.isEmpty) {
      return 'Wellness';
    }

    return text
        .replaceAll('_', ' ')
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) {
          return '${word[0].toUpperCase()}'
              '${word.substring(1)}';
        })
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_submitting,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F7FC),
        appBar: AppBar(
          title: const Text('Wellness Scan'),
          automaticallyImplyLeading: !_submitting,
        ),
        body: Column(
          children: [
            _buildProgressHeader(),
            if (_errorMessage != null) _buildErrorBanner(),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _totalQuestions,
                itemBuilder: (context, index) {
                  return _buildQuestionPage(widget.questions[index]);
                },
              ),
            ),
            _buildNavigationBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 15),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Question ${_currentIndex + 1} '
                'of $_totalQuestions',
                style: const TextStyle(
                  color: Color(0xFF6059E8),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                '${_answers.length} answered',
                style: const TextStyle(color: Color(0xFF74748A)),
              ),
            ],
          ),
          const SizedBox(height: 11),
          LinearProgressIndicator(
            value: (_currentIndex + 1) / _totalQuestions,
            minHeight: 8,
            borderRadius: BorderRadius.circular(10),
          ),
        ],
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
      child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade800)),
    );
  }

  Widget _buildQuestionPage(Map<String, dynamic> question) {
    final responseScale = question['response_scale']?.toString() ?? '1_to_5';

    final selected = _selectedAnswer(question);

    final options = _options(responseScale);

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Chip(
          avatar: const Icon(Icons.category_outlined, size: 18),
          label: Text(_categoryLabel(question['category'])),
        ),
        const SizedBox(height: 17),
        Text(
          question['question_text']?.toString() ?? 'Wellness question',
          style: const TextStyle(
            fontSize: 25,
            height: 1.3,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 9),
        const Text(
          'Choose the answer that best describes your recent experience.',
          style: TextStyle(color: Color(0xFF74748A), height: 1.45),
        ),
        const SizedBox(height: 25),
        if (responseScale == '1_to_10')
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: options.map((option) {
              return ChoiceChip(
                selected: selected == option.key,
                label: Text(option.value),
                onSelected: (_) {
                  _selectAnswer(question, option.key);
                },
              );
            }).toList(),
          )
        else
          ...options.map((option) {
            final isSelected = selected == option.key;

            return Card(
              margin: const EdgeInsets.only(bottom: 11),
              color: isSelected ? const Color(0xFFF0EFFF) : Colors.white,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  _selectAnswer(question, option.key);
                },
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: isSelected
                            ? const Color(0xFF6059E8)
                            : const Color(0xFFF0F0F5),
                        foregroundColor: isSelected
                            ? Colors.white
                            : const Color(0xFF74748A),
                        child: Text(
                          '${option.key}',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Text(
                          option.value,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        isSelected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked,
                        color: isSelected
                            ? const Color(0xFF6059E8)
                            : Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildNavigationBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 15,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          children: [
            if (_currentIndex > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _submitting ? null : _back,
                  child: const Text('Back'),
                ),
              ),
            if (_currentIndex > 0) const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _continue,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _currentIndex == _totalQuestions - 1
                            ? Icons.health_and_safety
                            : Icons.arrow_forward_rounded,
                      ),
                label: Text(
                  _submitting
                      ? 'Analysing...'
                      : _currentIndex == _totalQuestions - 1
                      ? 'Complete Scan'
                      : 'Continue',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WellnessScanResultScreen extends StatelessWidget {
  const WellnessScanResultScreen({required this.scan, super.key});

  final Map<String, dynamic> scan;

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
    return value is List ? value : <dynamic>[];
  }

  double _doubleValue(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  Color _riskColor(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'low':
        return Colors.green;
      case 'mild':
        return Colors.amber.shade800;
      case 'moderate':
        return Colors.orange.shade800;
      case 'elevated':
        return Colors.red.shade700;
      default:
        return Colors.grey;
    }
  }

  String _label(dynamic value) {
    final text = value?.toString() ?? '';

    if (text.isEmpty) {
      return 'Wellness';
    }

    return text
        .replaceAll('_', ' ')
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) {
          return '${word[0].toUpperCase()}'
              '${word.substring(1)}';
        })
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final score = _doubleValue(scan['total_score']);

    final riskLevel = scan['risk_level']?.toString() ?? 'unknown';

    final riskColor = _riskColor(riskLevel);

    final normalizedRisk = riskLevel.toLowerCase();

    final showSafetySupport =
        normalizedRisk == 'elevated' ||
        normalizedRisk == 'high' ||
        normalizedRisk == 'critical' ||
        score >= 70;

    final mainFactors = _asList(scan['main_factors']).map(_asMap).toList();

    final answers = _asList(scan['answers']).map(_asMap).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FC),
      appBar: AppBar(title: const Text('Scan Result')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: riskColor,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: riskColor.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                const Text(
                  'Wellness Strain Indicator',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  score.toStringAsFixed(1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 52,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '${riskLevel.toUpperCase()} LEVEL',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 18),
                LinearProgressIndicator(
                  value: (score / 100).clamp(0, 1),
                  minHeight: 10,
                  backgroundColor: const Color(0x44FFFFFF),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  borderRadius: BorderRadius.circular(10),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (showSafetySupport) ...[
            SafetyEscalationCard(
              severity: riskLevel,
              title: 'Elevated wellness support',
              message:
                  'This scan shows elevated '
                  'wellness strain. Consider '
                  'contacting someone you trust '
                  'or seeking qualified support. '
                  'Use local emergency support '
                  'when there is immediate danger.',
            ),
            const SizedBox(height: 16),
          ],
          _informationCard(
            icon: Icons.insights_outlined,
            title: 'Result Summary',
            text: scan['summary']?.toString() ?? 'No summary available.',
          ),
          const SizedBox(height: 14),
          _informationCard(
            icon: Icons.health_and_safety_outlined,
            title: 'Recommended Action',
            text:
                scan['recommendation']?.toString() ??
                'Continue regular wellness tracking.',
          ),
          if (mainFactors.isNotEmpty) ...[
            const SizedBox(height: 22),
            const Text(
              'Main Contributing Factors',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 11),
            ...mainFactors.map((factor) {
              final riskScore = _doubleValue(factor['risk_score']);

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _label(
                                factor['category'] ?? factor['question_code'],
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Text(
                            '${riskScore.toStringAsFixed(0)}%',
                            style: const TextStyle(
                              color: Color(0xFF6059E8),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      LinearProgressIndicator(
                        value: (riskScore / 100).clamp(0, 1),
                        minHeight: 7,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
          if (answers.isNotEmpty) ...[
            const SizedBox(height: 22),
            ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 14),
              childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              backgroundColor: Colors.white,
              collapsedBackgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              collapsedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'View Submitted Answers',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              children: answers.map((answer) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    answer['question_text']?.toString() ?? 'Wellness question',
                  ),
                  subtitle: Text(_label(answer['category'])),
                  trailing: CircleAvatar(
                    child: Text('${answer['response_value'] ?? '-'}'),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: const Color(0xFFF0EFFF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: Color(0xFF6059E8)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This wellness result is informational and non-diagnostic. It does not replace professional medical or mental-health care.',
                    style: TextStyle(height: 1.45),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _informationCard({
    required IconData icon,
    required String title,
    required String text,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFF0EFFF),
              child: Icon(icon, color: const Color(0xFF6059E8)),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    text,
                    style: const TextStyle(
                      height: 1.5,
                      color: Color(0xFF67677A),
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
}
