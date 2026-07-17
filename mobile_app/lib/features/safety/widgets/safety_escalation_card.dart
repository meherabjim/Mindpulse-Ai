import 'package:flutter/material.dart';

import '../screens/emergency_support_screen.dart';

class SafetyEscalationCard extends StatelessWidget {
  const SafetyEscalationCard({
    required this.severity,
    this.title = 'Support is available',
    this.message =
        'You do not have to handle this moment alone. '
        'Consider contacting someone you trust or opening '
        'the Safety Support screen.',
    super.key,
  });

  final String severity;
  final String title;
  final String message;

  bool get _isUrgent {
    final value = severity.toLowerCase();

    return value == 'elevated' || value == 'high' || value == 'critical';
  }

  @override
  Widget build(BuildContext context) {
    final color = _isUrgent ? Colors.red.shade700 : Colors.orange.shade800;

    return Card(
      color: _isUrgent ? Colors.red.shade50 : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _isUrgent
                      ? Icons.health_and_safety_outlined
                      : Icons.support_agent_outlined,
                  color: color,
                  size: 30,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: color,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Safety level: '
                        '${severity.toUpperCase()}',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(message),
            const SizedBox(height: 10),
            const Text(
              'MindPulse will not call or message '
              'anyone automatically.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: color),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => const EmergencySupportScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.health_and_safety_outlined),
                label: const Text('Open Safety Support'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
