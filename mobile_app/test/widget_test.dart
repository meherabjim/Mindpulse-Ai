import 'package:flutter_test/flutter_test.dart';
import 'package:mindpulse_ai/main.dart';

void main() {
  testWidgets('Splash opens MindPulse dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(const MindPulseApp());

    expect(find.text('MindPulse AI'), findsOneWidget);
    expect(
      find.text('Understand your mind.\nImprove your wellbeing.'),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pumpAndSettle();

    expect(find.text('AI Wellness Assistant'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
  });
}
