import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/navigation/app_navigator.dart';
import 'core/services/firebase_messaging_service.dart';
import 'core/settings/app_preferences_controller.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/services/auth_service.dart';
import 'features/onboarding/screens/onboarding_gate.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AppPreferencesController.instance.load();

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  runApp(const MindPulseApp());

  unawaited(_initializeFirebaseMessaging());
}

Future<void> _initializeFirebaseMessaging() async {
  try {
    await FirebaseMessagingService.instance.initialize();
  } catch (error, stackTrace) {
    debugPrint('MindPulse: Firebase Messaging initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

// MINDPULSE LIVE LANGUAGE THEME V3
class MindPulseApp extends StatelessWidget {
  const MindPulseApp({super.key});

  static const Color primaryColor = Color(0xFF6059E8);

  @override
  Widget build(BuildContext context) {
    final preferences = AppPreferencesController.instance;

    return AnimatedBuilder(
      animation: preferences,
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: AppNavigator.navigatorKey,
          title: 'MindPulse AI',
          debugShowCheckedModeBanner: false,
          locale: preferences.locale,
          supportedLocales: const <Locale>[Locale('en'), Locale('bn')],
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          themeMode: preferences.themeMode,
          home: const AuthGate(),
        );
      },
    );
  }

  ThemeData _theme(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: brightness,
    );

    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF121218)
          : const Color(0xFFF7F7FC),
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF1D1D26) : Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark
            ? const Color(0xFF121218)
            : const Color(0xFFF7F7FC),
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF22222C) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryColor, width: 1.6),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? const Color(0xFF1A1A22) : Colors.white,
        indicatorColor: isDark
            ? const Color(0xFF37324E)
            : const Color(0xFFE9E8FF),
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthService _authService = AuthService();

  late Future<bool> _loginCheck;

  @override
  void initState() {
    super.initState();
    _loginCheck = _checkLogin();
  }

  Future<bool> _checkLogin() async {
    try {
      return await _authService.isLoggedIn();
    } catch (error) {
      debugPrint('MindPulse: Login check failed: $error');
      return false;
    }
  }

  Future<void> refreshAuthentication() async {
    setState(() {
      _loginCheck = _checkLogin();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _loginCheck,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return const LoginScreen();
        }

        final loggedIn = snapshot.data ?? false;

        if (loggedIn) {
          return const OnboardingGate();
        }

        return const LoginScreen();
      },
    );
  }
}
