import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindpulse_ai/features/auth/screens/login_screen.dart';
import 'package:mindpulse_ai/features/auth/screens/register_screen.dart';

void main() {
  testWidgets('login exposes registration without prayer setup', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    expect(find.text('MindPulse AI'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Smart prayer alarms'), findsNothing);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('registration exposes required fields and notice', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
    expect(find.text('Join MindPulse AI'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(4));
    expect(find.byType(CheckboxListTile), findsOneWidget);
  });
}
