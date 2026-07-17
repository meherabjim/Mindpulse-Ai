import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'core/navigation/app_navigator.dart';
import 'core/services/firebase_messaging_service.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/services/auth_service.dart';
import 'features/onboarding/screens/onboarding_gate.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  runApp(const MindPulseApp());

  // App UI চালু হওয়ার পর notification service initialize হবে।
  // এতে startup-এর সময় main thread-এর চাপ কিছুটা কমবে।
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

class MindPulseApp extends StatelessWidget {
  const MindPulseApp({super.key});

  static const Color primaryColor = Color(0xFF6059E8);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: AppNavigator.navigatorKey,
      title: 'MindPulse AI',
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFFF7F7FC),

        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.light,
        ),

        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,

          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),

          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE4E3EE)),
          ),

          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE4E3EE)),
          ),

          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: primaryColor, width: 1.6),
          ),
        ),

        navigationBarTheme: const NavigationBarThemeData(
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ),

      home: const AuthGate(),
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

        final bool loggedIn = snapshot.data ?? false;

        if (loggedIn) {
          return const OnboardingGate();
        }

        return const LoginScreen();
      },
    );
  }
}
