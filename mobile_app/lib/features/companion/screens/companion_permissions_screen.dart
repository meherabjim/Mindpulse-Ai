// HUMAN_COMPANION_PERMISSIONS_UI_V2

import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../../../core/settings/app_preferences_controller.dart';
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
  bool _hasNotificationPermission = false;

  String? _error;

  String _t(String english, String bangla) {
    return AppPreferencesController.instance.text(english, bangla);
  }

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

  Future<bool> _notificationPermissionStatus() async {
    try {
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();

      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      return false;
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

      final notificationPermission = await _notificationPermissionStatus();

      if (!mounted) return;

      setState(() {
        _permissions = permissions;
        _hasUsageAccess = usageAccess;
        _hasMovementPermission = movementPermission;
        _stepCounterAvailable = stepCounterAvailable;
        _hasNotificationPermission = notificationPermission;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _refreshDeviceAccess() async {
    var usageAccess = _hasUsageAccess;
    var movementPermission = _hasMovementPermission;
    var stepCounterAvailable = _stepCounterAvailable;

    if (Platform.isAndroid) {
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
    }

    final notificationPermission = await _notificationPermissionStatus();

    if (!mounted) return;

    setState(() {
      _hasUsageAccess = usageAccess;
      _hasMovementPermission = movementPermission;
      _stepCounterAvailable = stepCounterAvailable;
      _hasNotificationPermission = notificationPermission;
    });
  }

  Future<void> _save(CompanionPermissions value) async {
    if (_saving) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await _settingsService.save(value);

      if (!mounted) return;

      setState(() {
        _permissions = value;
        _saving = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _saving = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _togglePhoneUsage(bool enabled) async {
    final current = _permissions;

    if (current == null) return;

    await _save(current.copyWith(phoneUsage: enabled));

    if (enabled && Platform.isAndroid && !_hasUsageAccess && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Companion access is enabled. Android Usage Access is still required.',
              'সহকারীর অনুমতি চালু হয়েছে। Android Usage Access এখনো দিতে হবে।',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _toggleMovement(bool enabled) async {
    final current = _permissions;

    if (current == null) return;

    await _save(current.copyWith(movement: enabled));

    if (!enabled || !Platform.isAndroid) return;

    try {
      final granted = await _movementService.hasPermission();

      if (!granted) {
        await _movementService.requestPermission();
      }

      await Future<void>.delayed(const Duration(milliseconds: 350));
      await _refreshDeviceAccess();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
      });
    }
  }

  Future<void> _enableAll() async {
    final allEnabled = const CompanionPermissions(
      phoneUsage: true,
      movement: true,
      checkin: true,
      recovery: true,
      aiPersonalization: true,
      supportiveReminders: true,
    );

    await _save(allEnabled);

    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {
      // The device may not expose a notification prompt.
    }

    if (Platform.isAndroid) {
      try {
        final granted = await _movementService.hasPermission();

        if (!granted) {
          await _movementService.requestPermission();
        }
      } catch (_) {
        // The status section will show the actual result.
      }
    }

    await Future<void>.delayed(const Duration(milliseconds: 350));
    await _refreshDeviceAccess();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _hasUsageAccess
              ? _t(
                  'All companion controls are enabled.',
                  'সহকারীর সব নিয়ন্ত্রণ চালু হয়েছে।',
                )
              : _t(
                  'Companion controls are enabled. Open Android Usage Access to complete phone-usage access.',
                  'সহকারীর নিয়ন্ত্রণ চালু হয়েছে। ফোন ব্যবহারের অনুমতি সম্পূর্ণ করতে Android Usage Access খুলুন।',
                ),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _disableAll() async {
    await _save(
      const CompanionPermissions(
        phoneUsage: false,
        movement: false,
        checkin: false,
        recovery: false,
        aiPersonalization: false,
        supportiveReminders: false,
      ),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _t(
            'All companion data controls are off.',
            'সহকারীর সব তথ্য নিয়ন্ত্রণ বন্ধ হয়েছে।',
          ),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openUsageAccess() async {
    try {
      await _screenTimeService.openUsageAccessSettings();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
      });
    }
  }

  Future<void> _openMovementSettings() async {
    try {
      await _movementService.openAppSettings();
    } catch (error) {
      if (!mounted) return;

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
    final colors = Theme.of(context).colorScheme;

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
              style: TextStyle(color: colors.onSurfaceVariant, height: 1.35),
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
    final colors = Theme.of(context).colorScheme;
    final color = available ? Colors.green.shade700 : colors.error;

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
                  style: TextStyle(color: colors.onSurfaceVariant, height: 1.3),
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
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(
          _t(
            'Companion permissions and controls',
            'সহকারীর অনুমতি ও নিয়ন্ত্রণ',
          ),
        ),
        actions: [
          IconButton(
            tooltip: _t('Refresh permissions', 'অনুমতি হালনাগাদ করুন'),
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
                      _t(
                        'Companion settings could not be loaded.',
                        'সহকারীর সেটিংস লোড করা যায়নি।',
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              children: [
                Card(
                  color: colors.primaryContainer,
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.volunteer_activism_outlined,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _t(
                                  'You stay in control',
                                  'নিয়ন্ত্রণ আপনার হাতে',
                                ),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _t(
                            'MindPulse uses only the signals you choose. All companion permissions and access controls are managed on this one screen.',
                            'MindPulse শুধু আপনার বেছে নেওয়া তথ্য ব্যবহার করে। সহকারীর সব অনুমতি ও প্রবেশাধিকার এই একটি স্ক্রিন থেকে নিয়ন্ত্রণ করা যাবে।',
                          ),
                          style: const TextStyle(height: 1.4),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            FilledButton.icon(
                              onPressed: _saving ? null : _enableAll,
                              icon: const Icon(Icons.done_all_rounded),
                              label: Text(
                                _t('Enable all', 'সব অনুমতি চালু করুন'),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _saving ? null : _disableAll,
                              icon: const Icon(Icons.block_outlined),
                              label: Text(_t('Turn all off', 'সব বন্ধ করুন')),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  Card(
                    color: colors.errorContainer,
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        _error!,
                        style: TextStyle(color: colors.onErrorContainer),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                _sectionCard(
                  title: _t('Daily context signals', 'দৈনিক তথ্যের অনুমতি'),
                  description: _t(
                    'Choose which local wellbeing signals may be combined for supportive suggestions.',
                    'সহায়ক পরামর্শ তৈরির জন্য ফোনে থাকা কোন সুস্থতা-সংক্রান্ত তথ্য ব্যবহার করা যাবে তা বেছে নিন।',
                  ),
                  children: [
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.phone_android_outlined),
                      title: Text(
                        _t('Phone-usage insights', 'ফোন ব্যবহারের তথ্য'),
                      ),
                      subtitle: Text(
                        _t(
                          'Uses daily totals and longest sessions. It never reads messages or screen content.',
                          'প্রতিদিনের মোট ব্যবহার ও দীর্ঘ সেশনের তথ্য ব্যবহার করে। ব্যক্তিগত বার্তা বা পর্দার লেখা পড়ে না।',
                        ),
                      ),
                      value: permissions.phoneUsage,
                      onChanged: _saving ? null : _togglePhoneUsage,
                    ),
                    const Divider(height: 1),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.directions_walk_outlined),
                      title: Text(
                        _t('Movement and steps', 'হাঁটা ও নড়াচড়ার তথ্য'),
                      ),
                      subtitle: Text(
                        _t(
                          'Uses a local daily step total when the device supports a step counter.',
                          'ফোনে স্টেপ কাউন্টার থাকলে দৈনিক মোট পদক্ষেপের তথ্য ব্যবহার করে।',
                        ),
                      ),
                      value: permissions.movement,
                      onChanged: _saving ? null : _toggleMovement,
                    ),
                    const Divider(height: 1),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.fact_check_outlined),
                      title: Text(
                        _t('Daily check-in context', 'দৈনিক চেক-ইনের তথ্য'),
                      ),
                      subtitle: Text(
                        _t(
                          'Uses mood, stress, energy, sleep and work or study pressure.',
                          'মেজাজ, চাপ, শক্তি, ঘুম এবং কাজ বা পড়াশোনার চাপের তথ্য ব্যবহার করে।',
                        ),
                      ),
                      value: permissions.checkin,
                      onChanged: _saving
                          ? null
                          : (value) {
                              unawaited(
                                _save(permissions.copyWith(checkin: value)),
                              );
                            },
                    ),
                    const Divider(height: 1),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.self_improvement_outlined),
                      title: Text(_t('Recovery context', 'পুনরুদ্ধারের তথ্য')),
                      subtitle: Text(
                        _t(
                          'Uses completed recovery activities and your helpful feedback.',
                          'সম্পন্ন পুনরুদ্ধার কার্যক্রম ও আপনার সহায়ক মতামত ব্যবহার করে।',
                        ),
                      ),
                      value: permissions.recovery,
                      onChanged: _saving
                          ? null
                          : (value) {
                              unawaited(
                                _save(permissions.copyWith(recovery: value)),
                              );
                            },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _sectionCard(
                  title: _t('Support preferences', 'সহায়তার পছন্দ'),
                  description: _t(
                    'Choose how the companion may personalize and remind you. These controls do not enable diagnosis or emergency automation.',
                    'সহকারী কীভাবে ব্যক্তিগত পরামর্শ ও রিমাইন্ডার দেবে তা বেছে নিন। এগুলো চিকিৎসা নির্ণয় বা স্বয়ংক্রিয় জরুরি ব্যবস্থা চালু করে না।',
                  ),
                  children: [
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.auto_awesome_outlined),
                      title: Text(_t('AI personalization', 'এআই ব্যক্তিগতকরণ')),
                      subtitle: Text(
                        _t(
                          'Allows approved companion context to shape supportive AI wording.',
                          'অনুমোদিত তথ্য ব্যবহার করে সহায়ক এআই বার্তা ব্যক্তিগতভাবে সাজায়।',
                        ),
                      ),
                      value: permissions.aiPersonalization,
                      onChanged: _saving
                          ? null
                          : (value) {
                              unawaited(
                                _save(
                                  permissions.copyWith(
                                    aiPersonalization: value,
                                  ),
                                ),
                              );
                            },
                    ),
                    const Divider(height: 1),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(
                        Icons.notifications_active_outlined,
                      ),
                      title: Text(
                        _t('Supportive reminders', 'সহায়ক রিমাইন্ডার'),
                      ),
                      subtitle: Text(
                        _t(
                          'Allows gentle optional wellbeing reminders. It never contacts another person automatically.',
                          'সহজ ও ঐচ্ছিক সুস্থতা রিমাইন্ডার দেয়। কাউকে স্বয়ংক্রিয়ভাবে যোগাযোগ করে না।',
                        ),
                      ),
                      value: permissions.supportiveReminders,
                      onChanged: _saving
                          ? null
                          : (value) {
                              unawaited(
                                _save(
                                  permissions.copyWith(
                                    supportiveReminders: value,
                                  ),
                                ),
                              );
                            },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _sectionCard(
                  title: _t('Device access status', 'ডিভাইস অনুমতির অবস্থা'),
                  description: _t(
                    'MindPulse consent and Android system permissions are separate. Both must be available for some signals.',
                    'MindPulse-এর সম্মতি ও Android-এর সিস্টেম অনুমতি আলাদা। কিছু তথ্যের জন্য দুটিই প্রয়োজন।',
                  ),
                  children: [
                    _statusRow(
                      icon: Icons.notifications_outlined,
                      label: _t('Notification permission', 'নোটিফিকেশন অনুমতি'),
                      available: _hasNotificationPermission,
                      enabledText: _t(
                        'Notifications are allowed.',
                        'নোটিফিকেশন অনুমতি দেওয়া আছে।',
                      ),
                      disabledText: _t(
                        'Notifications are not allowed.',
                        'নোটিফিকেশন অনুমতি দেওয়া হয়নি।',
                      ),
                    ),
                    _statusRow(
                      icon: Icons.query_stats_outlined,
                      label: 'Usage Access',
                      available: _hasUsageAccess,
                      enabledText: _t(
                        'Android Usage Access is available.',
                        'Android Usage Access চালু আছে।',
                      ),
                      disabledText: _t(
                        'Android Usage Access has not been granted.',
                        'Android Usage Access দেওয়া হয়নি।',
                      ),
                    ),
                    _statusRow(
                      icon: Icons.directions_walk_outlined,
                      label: _t(
                        'Physical activity permission',
                        'শারীরিক কার্যকলাপের অনুমতি',
                      ),
                      available: _hasMovementPermission,
                      enabledText: _t(
                        'Physical activity permission is available.',
                        'শারীরিক কার্যকলাপের অনুমতি দেওয়া আছে।',
                      ),
                      disabledText: _t(
                        'Physical activity permission has not been granted.',
                        'শারীরিক কার্যকলাপের অনুমতি দেওয়া হয়নি।',
                      ),
                    ),
                    _statusRow(
                      icon: Icons.sensors_outlined,
                      label: _t('Step-counter sensor', 'স্টেপ কাউন্টার সেন্সর'),
                      available: _stepCounterAvailable,
                      enabledText: _t(
                        'A step-counter sensor is available.',
                        'স্টেপ কাউন্টার সেন্সর পাওয়া গেছে।',
                      ),
                      disabledText: _t(
                        'No step-counter sensor was detected. Emulator devices commonly do not provide one.',
                        'স্টেপ কাউন্টার সেন্সর পাওয়া যায়নি। সাধারণত এমুলেটরে এটি থাকে না।',
                      ),
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
                          label: Text(
                            _t('Open Usage Access', 'Usage Access খুলুন'),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: Platform.isAndroid
                              ? _openMovementSettings
                              : null,
                          icon: const Icon(Icons.security_outlined),
                          label: Text(
                            _t('Open app permissions', 'অ্যাপের অনুমতি খুলুন'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _t('Privacy boundary', 'গোপনীয়তার সীমা'),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _t(
                            'MindPulse does not read private messages, typed text, passwords, contact lists, microphone audio or continuous exact location. Companion signals remain optional.',
                            'MindPulse ব্যক্তিগত বার্তা, টাইপ করা লেখা, পাসওয়ার্ড, যোগাযোগ তালিকা, মাইক্রোফোনের শব্দ অথবা সার্বক্ষণিক সুনির্দিষ্ট অবস্থান পড়ে না। সহকারীর সব তথ্য ঐচ্ছিক।',
                          ),
                          style: const TextStyle(height: 1.4),
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
