// HUMAN_COMPANION_PERMISSIONS_UI_V1

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../digital_wellbeing/services/screen_time_insight_service.dart';
import '../services/companion_settings_service.dart';
import '../services/movement_insight_service.dart';

class CompanionPermissionsScreen extends StatefulWidget {
  const CompanionPermissionsScreen({super.key});

  @override
  State<CompanionPermissionsScreen> createState() =>
      _CompanionPermissionsScreenState();
}

class _CompanionPermissionsScreenState extends State<CompanionPermissionsScreen>
    with WidgetsBindingObserver {
  final CompanionSettingsService _settingsService = CompanionSettingsService();

  final MovementInsightService _movementService = MovementInsightService();

  final ScreenTimeInsightService _screenTimeService =
      ScreenTimeInsightService();

  CompanionPermissions? _permissions;

  bool _loading = true;
  bool _saving = false;

  bool _hasUsageAccess = false;
  bool _hasMovementPermission = false;
  bool _stepCounterAvailable = false;

  String? _error;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    unawaited(_load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshDeviceAccess());
    }
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final permissions = await _settingsService.load();

      var usageAccess = false;
      var movementPermission = false;
      var stepCounterAvailable = false;

      if (Platform.isAndroid) {
        try {
          usageAccess = await _screenTimeService.hasUsageAccess();
        } catch (_) {
          usageAccess = false;
        }

        try {
          movementPermission = await _movementService.hasPermission();

          stepCounterAvailable = await _movementService
              .isStepCounterAvailable();
        } catch (_) {
          movementPermission = false;
          stepCounterAvailable = false;
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _permissions = permissions;

        _hasUsageAccess = usageAccess;

        _hasMovementPermission = movementPermission;

        _stepCounterAvailable = stepCounterAvailable;

        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _refreshDeviceAccess() async {
    if (!Platform.isAndroid) {
      return;
    }

    var usageAccess = _hasUsageAccess;
    var movementPermission = _hasMovementPermission;

    var stepCounterAvailable = _stepCounterAvailable;

    try {
      usageAccess = await _screenTimeService.hasUsageAccess();
    } catch (_) {
      // Preserve the last known state.
    }

    try {
      movementPermission = await _movementService.hasPermission();

      stepCounterAvailable = await _movementService.isStepCounterAvailable();
    } catch (_) {
      // Preserve the last known state.
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _hasUsageAccess = usageAccess;

      _hasMovementPermission = movementPermission;

      _stepCounterAvailable = stepCounterAvailable;
    });
  }

  Future<void> _save(CompanionPermissions value) async {
    if (_saving) {
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await _settingsService.save(value);

      if (!mounted) {
        return;
      }

      setState(() {
        _permissions = value;
        _saving = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _togglePhoneUsage(bool enabled) async {
    final current = _permissions;

    if (current == null) {
      return;
    }

    await _save(current.copyWith(phoneUsage: enabled));

    if (enabled && Platform.isAndroid && !_hasUsageAccess && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'MindPulse permission is enabled. '
            'Android Usage Access is still required.',
          ),
        ),
      );
    }
  }

  Future<void> _toggleMovement(bool enabled) async {
    final current = _permissions;

    if (current == null) {
      return;
    }

    await _save(current.copyWith(movement: enabled));

    if (!enabled || !Platform.isAndroid) {
      return;
    }

    try {
      final granted = await _movementService.hasPermission();

      if (!granted) {
        await _movementService.requestPermission();
      }

      await Future<void>.delayed(const Duration(milliseconds: 350));

      await _refreshDeviceAccess();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.toString();
      });
    }
  }

  Future<void> _openUsageAccess() async {
    try {
      await _screenTimeService.openUsageAccessSettings();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.toString();
      });
    }
  }

  Future<void> _openMovementSettings() async {
    try {
      await _movementService.openAppSettings();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.toString();
      });
    }
  }

  Widget _sectionCard({
    required String title,
    required String description,
    required List<Widget> children,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            Text(
              description,
              style: const TextStyle(color: Color(0xFF68687A), height: 1.35),
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _statusRow({
    required IconData icon,
    required String label,
    required bool available,
    required String enabledText,
    required String disabledText,
  }) {
    final color = available ? Colors.green.shade700 : Colors.orange.shade800;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  available ? enabledText : disabledText,
                  style: const TextStyle(color: Color(0xFF6B6B7B), height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final permissions = _permissions;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FC),
      appBar: AppBar(
        title: const Text('Companion permissions'),
        actions: [
          IconButton(
            tooltip: 'Refresh permissions',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : permissions == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error ??
                      'Companion settings '
                          'could not be loaded.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              children: [
                Card(
                  color: const Color(0xFFEDEBFF),
                  margin: EdgeInsets.zero,
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.volunteer_activism_outlined,
                              color: Color(0xFF5750D8),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'You stay in control',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'MindPulse uses only the '
                          'signals you choose. Turning '
                          'a signal off keeps it out of '
                          'the companion context.',
                          style: TextStyle(height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  Card(
                    color: Colors.red.shade50,
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        _error!,
                        style: TextStyle(color: Colors.red.shade800),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                _sectionCard(
                  title: 'Daily context signals',
                  description:
                      'Choose which local '
                      'wellbeing signals may be '
                      'combined for supportive '
                      'suggestions.',
                  children: [
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.phone_android_outlined),
                      title: const Text('Phone-usage insights'),
                      subtitle: const Text(
                        'Uses private daily '
                        'aggregates such as '
                        'total use and longest '
                        'session. It does not '
                        'read messages or '
                        'screen content.',
                      ),
                      value: permissions.phoneUsage,
                      onChanged: _saving
                          ? null
                          : (value) async {
                              await _togglePhoneUsage(value);
                            },
                    ),
                    const Divider(height: 1),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.directions_walk_outlined),
                      title: const Text('Movement and steps'),
                      subtitle: const Text(
                        'Uses a local daily '
                        'step aggregate when '
                        'the device supports '
                        'a step-counter '
                        'sensor.',
                      ),
                      value: permissions.movement,
                      onChanged: _saving
                          ? null
                          : (value) async {
                              await _toggleMovement(value);
                            },
                    ),
                    const Divider(height: 1),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.fact_check_outlined),
                      title: const Text('Daily check-in context'),
                      subtitle: const Text(
                        'Allows mood, stress, '
                        'energy, sleep and '
                        'work/study pressure '
                        'to guide suggestions.',
                      ),
                      value: permissions.checkin,
                      onChanged: _saving
                          ? null
                          : (value) async {
                              await _save(permissions.copyWith(checkin: value));
                            },
                    ),
                    const Divider(height: 1),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.self_improvement_outlined),
                      title: const Text('Recovery context'),
                      subtitle: const Text(
                        'Allows completed '
                        'recovery activities '
                        'and helpful feedback '
                        'to reduce repetitive '
                        'suggestions.',
                      ),
                      value: permissions.recovery,
                      onChanged: _saving
                          ? null
                          : (value) async {
                              await _save(
                                permissions.copyWith(recovery: value),
                              );
                            },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _sectionCard(
                  title: 'Support preferences',
                  description:
                      'These controls affect how '
                      'MindPulse communicates with '
                      'you. They do not enable '
                      'diagnosis or emergency '
                      'automation.',
                  children: [
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.auto_awesome_outlined),
                      title: const Text('AI personalization'),
                      subtitle: const Text(
                        'Allows approved '
                        'companion context to '
                        'shape supportive AI '
                        'wording. Experimental '
                        'models remain '
                        'non-diagnostic.',
                      ),
                      value: permissions.aiPersonalization,
                      onChanged: _saving
                          ? null
                          : (value) async {
                              await _save(
                                permissions.copyWith(aiPersonalization: value),
                              );
                            },
                    ),
                    const Divider(height: 1),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(
                        Icons.notifications_active_outlined,
                      ),
                      title: const Text('Supportive reminders'),
                      subtitle: const Text(
                        'Allows gentle and '
                        'optional wellbeing '
                        'reminders. It never '
                        'contacts another '
                        'person automatically.',
                      ),
                      value: permissions.supportiveReminders,
                      onChanged: _saving
                          ? null
                          : (value) async {
                              await _save(
                                permissions.copyWith(
                                  supportiveReminders: value,
                                ),
                              );
                            },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _sectionCard(
                  title: 'Android access status',
                  description:
                      'MindPulse consent and '
                      'Android system permission '
                      'are separate controls.',
                  children: [
                    _statusRow(
                      icon: Icons.query_stats_outlined,
                      label: 'Usage Access',
                      available: _hasUsageAccess,
                      enabledText:
                          'Android Usage Access '
                          'is available.',
                      disabledText:
                          'Android Usage Access '
                          'has not been granted.',
                    ),
                    _statusRow(
                      icon: Icons.directions_walk_outlined,
                      label: 'Physical activity permission',
                      available: _hasMovementPermission,
                      enabledText:
                          'Physical activity '
                          'permission is available.',
                      disabledText:
                          'Physical activity '
                          'permission has not '
                          'been granted.',
                    ),
                    _statusRow(
                      icon: Icons.sensors_outlined,
                      label: 'Step-counter sensor',
                      available: _stepCounterAvailable,
                      enabledText:
                          'A step-counter sensor '
                          'is available.',
                      disabledText:
                          'No step-counter sensor '
                          'was detected. Emulator '
                          'devices commonly do not '
                          'provide one.',
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        OutlinedButton.icon(
                          onPressed: Platform.isAndroid
                              ? _openUsageAccess
                              : null,
                          icon: const Icon(Icons.settings_outlined),
                          label: const Text('Usage Access'),
                        ),
                        OutlinedButton.icon(
                          onPressed: Platform.isAndroid
                              ? _openMovementSettings
                              : null,
                          icon: const Icon(Icons.security_outlined),
                          label: const Text('App permissions'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  margin: EdgeInsets.zero,
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Privacy boundary',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'MindPulse does not read '
                          'private messages, typed '
                          'text, passwords, contact '
                          'lists, microphone audio '
                          'or continuous exact '
                          'location. Companion '
                          'signals remain optional.',
                          style: TextStyle(height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_saving) ...[
                  const SizedBox(height: 18),
                  const LinearProgressIndicator(),
                ],
              ],
            ),
    );
  }
}
