import 'package:flutter/material.dart';

import '../../../core/settings/app_preferences_controller.dart';
import '../../account/services/account_service.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/services/auth_service.dart';
import '../../dashboard/screens/main_dashboard_screen.dart';
import 'onboarding_screen.dart';

class OnboardingGate extends StatefulWidget {
  const OnboardingGate({super.key});

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  final AccountService _accountService = AccountService();

  late Future<Map<String, dynamic>> _statusFuture;

  @override
  void initState() {
    super.initState();
    _statusFuture = _loadStatusAndPreferences();
  }

  Future<Map<String, dynamic>> _loadStatusAndPreferences() async {
    final results = await Future.wait<dynamic>([
      _accountService.getOnboardingStatus(),
      _accountService.getSettings(),
    ]);

    final status = _asMap(results[0]);
    final settings = _asMap(results[1]);
    final appSettings = _asMap(settings['app_settings']);

    _applyPreferencesAfterFrame(
      languageCode: appSettings['language_code']?.toString(),
      themeMode: appSettings['theme_mode']?.toString(),
    );

    return status;
  }

  void _applyPreferencesAfterFrame({String? languageCode, String? themeMode}) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      await AppPreferencesController.instance.apply(
        languageCode: languageCode,
        themeMode: themeMode,
      );
    });
  }

  void _retry() {
    setState(() {
      _statusFuture = _loadStatusAndPreferences();
    });
  }

  Future<void> _logout() async {
    await AuthService().logout();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _statusFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          final bangla = AppPreferencesController.instance.isBangla;
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cloud_off_rounded,
                        size: 70,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        bangla
                            ? 'অ্যাকাউন্ট সেটআপ যাচাই করা যাচ্ছে না।'
                            : 'Unable to check account setup.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        snapshot.error.toString(),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _retry,
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(bangla ? 'আবার চেষ্টা করুন' : 'Retry'),
                      ),
                      TextButton(
                        onPressed: _logout,
                        child: Text(bangla ? 'লগআউট' : 'Logout'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        final status = snapshot.data ?? <String, dynamic>{};

        final onboardingCompleted = status['onboarding_completed'] == true;

        final requiredConsentsCompleted =
            status['required_consents_completed'] == true;

        if (onboardingCompleted && requiredConsentsCompleted) {
          return const MainDashboardScreen();
        }

        return OnboardingScreen(initialStatus: status);
      },
    );
  }
}
