import 'dart:async';

import 'package:flutter/material.dart';
import '../../onboarding/screens/onboarding_gate.dart';

import '../../auth/screens/login_screen.dart';
import '../../auth/services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;

  late final Animation<double> _fadeAnimation;

  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,

      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,

      curve: Curves.easeOut,
    );

    _scaleAnimation = Tween<double>(begin: 0.86, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _animationController.forward();

    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    await Future.delayed(const Duration(milliseconds: 2200));

    if (!mounted) return;

    final loggedIn = await AuthService().isLoggedIn();

    if (!mounted) return;

    if (loggedIn) {
      _openDashboard();
    } else {
      _openLogin();
    }
  }

  void _openDashboard() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 450),

        pageBuilder: (context, animation, secondaryAnimation) {
          return const OnboardingGate();
        },

        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _openLogin() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 450),

        pageBuilder: (context, animation, secondaryAnimation) {
          return const LoginScreen();
        },

        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,

            end: Alignment.bottomRight,

            colors: [Color(0xFF4D49D8), Color(0xFF655AE9), Color(0xFF8A63F2)],
          ),
        ),

        child: SafeArea(
          child: Stack(
            children: [
              const Positioned(
                top: -80,

                right: -65,

                child: _DecorativeCircle(size: 230, opacity: 0.08),
              ),

              const Positioned(
                bottom: -110,

                left: -80,

                child: _DecorativeCircle(size: 280, opacity: 0.07),
              ),

              Center(
                child: FadeTransition(
                  opacity: _fadeAnimation,

                  child: ScaleTransition(
                    scale: _scaleAnimation,

                    child: Column(
                      mainAxisSize: MainAxisSize.min,

                      children: [
                        Container(
                          width: 112,

                          height: 112,

                          decoration: BoxDecoration(
                            color: Colors.white,

                            borderRadius: BorderRadius.circular(34),
                          ),

                          child: const Icon(
                            Icons.psychology_alt_rounded,

                            size: 62,

                            color: Color(0xFF6059E8),
                          ),
                        ),

                        const SizedBox(height: 28),

                        const Text(
                          "MindPulse AI",

                          style: TextStyle(
                            color: Colors.white,

                            fontSize: 36,

                            fontWeight: FontWeight.w900,
                          ),
                        ),

                        const SizedBox(height: 10),

                        const Text(
                          "Understand your mind.\nImprove your wellbeing.",

                          textAlign: TextAlign.center,

                          style: TextStyle(
                            color: Color(0xFFE7E4FF),

                            fontSize: 16,
                          ),
                        ),

                        const SizedBox(height: 42),

                        const CircularProgressIndicator(color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ),

              const Positioned(
                left: 0,

                right: 0,

                bottom: 26,

                child: Text(
                  "Private • Secure • AI-powered",

                  textAlign: TextAlign.center,

                  style: TextStyle(color: Color(0xFFDDD9FF), fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DecorativeCircle extends StatelessWidget {
  const _DecorativeCircle({required this.size, required this.opacity});

  final double size;

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,

      height: size,

      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: opacity),

        shape: BoxShape.circle,
      ),
    );
  }
}
