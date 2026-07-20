import 'package:flutter/material.dart';

import '../services/weekly_report_service.dart';

class WeeklyReportScreen extends StatefulWidget {
  const WeeklyReportScreen({super.key});

  @override
  State<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends State<WeeklyReportScreen> {
  final WeeklyReportService _service = WeeklyReportService();

  List<Map<String, dynamic>> _reports = <Map<String, dynamic>>[];

  Map<String, dynamic>? _selectedReport;

  bool _loading = true;
  bool _generating = false;
  bool _loadingDetails = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final reports = await _service.listReports();

      Map<String, dynamic>? selected;

      if (reports.isNotEmpty) {
        final reportId = _integerValue(reports.first['id']);

        if (reportId != null) {
          selected = await _service.getReport(reportId);
        } else {
          selected = reports.first;
        }
      }

      if (!mounted) return;

      setState(() {
        _reports = reports;
        _selectedReport = selected;
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

  Future<void> _generateReport() async {
    setState(() {
      _generating = true;
      _errorMessage = null;
    });

    try {
      final report = await _service.generateWeeklyReport();

      final reports = await _service.listReports();

      if (!mounted) return;

      setState(() {
        _reports = reports;
        _selectedReport = report;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Weekly wellness report generated successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _generating = false;
        });
      }
    }
  }

  Future<void> _selectReport(Map<String, dynamic> report) async {
    final reportId = _integerValue(report['id']);

    if (reportId == null) {
      return;
    }

    setState(() {
      _loadingDetails = true;
      _errorMessage = null;
    });

    try {
      final details = await _service.getReport(reportId);

      if (!mounted) return;

      setState(() {
        _selectedReport = details;
        _loadingDetails = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString();
        _loadingDetails = false;
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
    return value is List ? value : <dynamic>[];
  }

  int? _integerValue(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '');
  }

  double? _numberValue(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '');
  }

  String _displayNumber(
    dynamic value, {
    int decimals = 1,
    String emptyValue = '—',
  }) {
    final number = _numberValue(value);

    if (number == null) {
      return emptyValue;
    }

    if (number % 1 == 0) {
      return number.toStringAsFixed(0);
    }

    return number.toStringAsFixed(decimals);
  }

  String _titleForType(dynamic type) {
    switch (type?.toString()) {
      case 'monthly':
        return 'Monthly Wellness Report';
      case 'burnout':
        return 'Wellness Strain Report';
      case 'habit':
        return 'Habit Report';
      case 'sleep':
        return 'Sleep Report';
      case 'recovery':
        return 'Recovery Report';
      case 'custom':
        return 'Custom Wellness Report';
      default:
        return 'Weekly Wellness Report';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FC),
      appBar: AppBar(
        title: const Text('Weekly Report'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadReports,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _generating ? null : _generateReport,
        icon: _generating
            ? const SizedBox(
                width: 19,
                height: 19,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.auto_awesome_rounded),
        label: Text(_generating ? 'Generating...' : 'Generate Report'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadReports,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                children: [
                  if (_errorMessage != null) _buildErrorBanner(),
                  if (_loadingDetails)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 14),
                      child: LinearProgressIndicator(),
                    ),
                  if (_selectedReport == null)
                    _buildEmptyState()
                  else
                    _buildReport(_selectedReport!),
                  const SizedBox(height: 22),
                  _buildHistory(),
                ],
              ),
            ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
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

  Widget _buildEmptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 50),
        child: Column(
          children: [
            const Icon(
              Icons.insights_outlined,
              size: 78,
              color: Color(0xFF85859A),
            ),
            const SizedBox(height: 18),
            const Text(
              'No wellness report yet',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 9),
            const Text(
              'Generate a report to review your '
              'check-ins, habits, sleep, recovery '
              'and wellness progress.',
              textAlign: TextAlign.center,
              style: TextStyle(height: 1.5),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _generating ? null : _generateReport,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Generate Weekly Report'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReport(Map<String, dynamic> report) {
    final metrics = _asMap(report['metrics']);

    final checkins = _asMap(metrics['checkins']);

    final wellness = _asMap(metrics['wellness']);

    final habits = _asMap(metrics['habits']);

    final recovery = _asMap(metrics['recovery']);

    final journals = _asMap(metrics['journals']);

    final burnout = _asMap(metrics['burnout']);

    final files = _asList(report['files']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeaderCard(report),
        const SizedBox(height: 16),
        _sectionTitle('Weekly summary', Icons.summarize_outlined),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Text(
              report['summary']?.toString() ?? 'No summary is available.',
              style: const TextStyle(height: 1.6, fontSize: 15),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _sectionTitle('Key metrics', Icons.dashboard_customize_outlined),
        const SizedBox(height: 10),
        _buildMetricsGrid(
          checkins: checkins,
          wellness: wellness,
          habits: habits,
          recovery: recovery,
          journals: journals,
          burnout: burnout,
        ),
        const SizedBox(height: 20),
        _sectionTitle('Wellness indicators', Icons.stacked_line_chart_rounded),
        const SizedBox(height: 10),
        _buildIndicators(checkins, habits, recovery, burnout),
        const SizedBox(height: 20),
        _sectionTitle('Recommendations', Icons.lightbulb_outline_rounded),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFF0EFFF),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFF6059E8),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    report['recommendations']?.toString() ??
                        'Continue reviewing your wellness progress regularly.',
                    style: const TextStyle(height: 1.6),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (files.isNotEmpty) ...[
          const SizedBox(height: 20),
          _sectionTitle('Report files', Icons.picture_as_pdf_outlined),
          const SizedBox(height: 10),
          ...files.map((fileValue) {
            final file = _asMap(fileValue);

            return Card(
              child: ListTile(
                leading: const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: Colors.red,
                ),
                title: Text(
                  file['file_name']?.toString() ?? 'Wellness report PDF',
                ),
                subtitle: Text(
                  file['mime_type']?.toString() ?? 'application/pdf',
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildHeaderCard(Map<String, dynamic> report) {
    final status = report['status']?.toString() ?? 'completed';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5C58E8), Color(0xFF875EF0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x335C58E8),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded, color: Colors.white, size: 31),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _titleForType(report['report_type']),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x33FFFFFF),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '${report['period_start'] ?? ''}  →  '
            '${report['period_end'] ?? ''}',
            style: const TextStyle(
              color: Color(0xFFEDEBFF),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Generated ${report['generated_at'] ?? report['created_at'] ?? ''}',
            style: const TextStyle(color: Color(0xFFDCD9FF)),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid({
    required Map<String, dynamic> checkins,
    required Map<String, dynamic> wellness,
    required Map<String, dynamic> habits,
    required Map<String, dynamic> recovery,
    required Map<String, dynamic> journals,
    required Map<String, dynamic> burnout,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _metricBox(
              width: itemWidth,
              icon: Icons.check_circle_outline,
              title: 'Check-ins',
              value: _displayNumber(
                checkins['count'],
                decimals: 0,
                emptyValue: '0',
              ),
            ),
            _metricBox(
              width: itemWidth,
              icon: Icons.mood_outlined,
              title: 'Average mood',
              value: '${_displayNumber(checkins['average_mood'])} / 5',
            ),
            _metricBox(
              width: itemWidth,
              icon: Icons.bedtime_outlined,
              title: 'Average sleep',
              value: '${_displayNumber(checkins['average_sleep_hours'])} hrs',
            ),
            _metricBox(
              width: itemWidth,
              icon: Icons.water_drop_outlined,
              title: 'Hydration days',
              value: _displayNumber(
                checkins['hydration_target_days'],
                decimals: 0,
                emptyValue: '0',
              ),
            ),
            _metricBox(
              width: itemWidth,
              icon: Icons.task_alt_rounded,
              title: 'Habit completion',
              value: '${_displayNumber(habits['completion_percent'])}%',
            ),
            _metricBox(
              width: itemWidth,
              icon: Icons.spa_outlined,
              title: 'Recovery activities',
              value: _displayNumber(
                recovery['completed_activities'],
                decimals: 0,
                emptyValue: '0',
              ),
            ),
            _metricBox(
              width: itemWidth,
              icon: Icons.menu_book_outlined,
              title: 'Journal entries',
              value: _displayNumber(
                journals['count'],
                decimals: 0,
                emptyValue: '0',
              ),
            ),
            _metricBox(
              width: itemWidth,
              icon: Icons.health_and_safety_outlined,
              title: 'Wellness scans',
              value: _displayNumber(
                wellness['scan_count'],
                decimals: 0,
                emptyValue: '0',
              ),
            ),
            _metricBox(
              width: itemWidth,
              icon: Icons.local_fire_department_outlined,
              title: 'Wellness strain score',
              value: '${_displayNumber(burnout['average_score'])} / 100',
            ),
            _metricBox(
              width: itemWidth,
              icon: Icons.warning_amber_rounded,
              title: 'Risk level',
              value:
                  burnout['latest_risk_level']?.toString().toUpperCase() ?? '—',
            ),
          ],
        );
      },
    );
  }

  Widget _metricBox({
    required double width,
    required IconData icon,
    required String title,
    required String value,
  }) {
    return SizedBox(
      width: width,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0EFFF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: const Color(0xFF6059E8)),
              ),
              const SizedBox(height: 13),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(title, style: const TextStyle(color: Color(0xFF74748A))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIndicators(
    Map<String, dynamic> checkins,
    Map<String, dynamic> habits,
    Map<String, dynamic> recovery,
    Map<String, dynamic> burnout,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          children: [
            _indicator(
              title: 'Mood',
              value: _numberValue(checkins['average_mood']),
              maximum: 5,
            ),
            _indicator(
              title: 'Stress',
              value: _numberValue(checkins['average_stress']),
              maximum: 5,
            ),
            _indicator(
              title: 'Energy',
              value: _numberValue(checkins['average_energy']),
              maximum: 5,
            ),
            _indicator(
              title: 'Habit completion',
              value: _numberValue(habits['completion_percent']),
              maximum: 100,
              suffix: '%',
            ),
            _indicator(
              title: 'Recovery score',
              value: _numberValue(recovery['average_recovery_score']),
              maximum: 100,
              suffix: '%',
            ),
            _indicator(
              title: 'Wellness strain score',
              value: _numberValue(burnout['average_score']),
              maximum: 100,
              suffix: '%',
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _indicator({
    required String title,
    required double? value,
    required double maximum,
    String suffix = '',
    bool isLast = false,
  }) {
    final normalized = value == null
        ? 0.0
        : (value / maximum).clamp(0.0, 1.0).toDouble();

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 17),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                value == null ? 'No data' : '${_displayNumber(value)}$suffix',
                style: const TextStyle(
                  color: Color(0xFF6059E8),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: normalized,
            minHeight: 9,
            borderRadius: BorderRadius.circular(10),
          ),
        ],
      ),
    );
  }

  Widget _buildHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Report history', Icons.history_rounded),
        const SizedBox(height: 10),
        if (_reports.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.history_rounded),
              title: Text('No report history is available.'),
            ),
          )
        else
          ..._reports.map((report) {
            final selectedId = _integerValue(_selectedReport?['id']);

            final reportId = _integerValue(report['id']);

            final selected = selectedId != null && selectedId == reportId;

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              color: selected ? const Color(0xFFF0EFFF) : null,
              child: ListTile(
                onTap: () => _selectReport(report),
                leading: CircleAvatar(
                  backgroundColor: selected
                      ? const Color(0xFF6059E8)
                      : const Color(0xFFE9E8FF),
                  child: Icon(
                    Icons.insights_rounded,
                    color: selected ? Colors.white : const Color(0xFF6059E8),
                  ),
                ),
                title: Text(
                  _titleForType(report['report_type']),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${report['period_start'] ?? ''} to '
                  '${report['period_end'] ?? ''}',
                ),
                trailing: Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.chevron_right_rounded,
                  color: selected ? const Color(0xFF6059E8) : null,
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF6059E8)),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
