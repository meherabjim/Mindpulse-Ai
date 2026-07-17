import 'package:flutter/material.dart';

import '../../features/auth/screens/login_screen.dart';

class AppNavigator {
  AppNavigator._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static bool _redirectScheduled = false;

  static void goToLogin() {
    if (_redirectScheduled) {
      return;
    }

    _redirectScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = navigatorKey.currentState;

      if (navigator != null) {
        navigator.pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }

      _redirectScheduled = false;
    });
  }
}
