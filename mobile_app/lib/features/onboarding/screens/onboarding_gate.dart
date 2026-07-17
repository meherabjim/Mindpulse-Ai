import 'package:flutter/material.dart';

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
    _statusFuture = _accountService.getOnboardingStatus();
  }

  void _retry() {
    setState(() {
      _statusFuture = _accountService.getOnboardingStatus();
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _statusFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF7F7FC),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: const Color(0xFFF7F7FC),
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
                      const Text(
                        'Unable to check account setup.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
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
                        label: const Text('Retry'),
                      ),
                      TextButton(
                        onPressed: _logout,
                        child: const Text('Logout'),
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
