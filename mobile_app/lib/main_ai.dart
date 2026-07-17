import 'package:flutter/material.dart';

import 'features/ai/screens/ai_wellness_screen.dart';

void main() {
  runApp(const MindPulseAiApp());
}

class MindPulseAiApp extends StatelessWidget {
  const MindPulseAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MindPulse AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5B5FEF)),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      home: const AiWellnessScreen(),
    );
  }
}
