import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindpulse_ai/features/splash/screens/splash_screen.dart';

const Key authenticatedDestinationKey = Key('authenticated-destination');

const Key unauthenticatedDestinationKey = Key('unauthenticated-destination');

Future<void> completeSplashDelay(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 2200));

  await tester.pump();

  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Splash opens authenticated destination', (
    WidgetTester tester,
  ) async {
    var authenticationChecks = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: SplashScreen(
          authChecker: () async {
            authenticationChecks += 1;
            return true;
          },
          authenticatedBuilder: (_) {
            return const Scaffold(
              key: authenticatedDestinationKey,
              body: Center(child: Text('Authenticated destination')),
            );
          },
          unauthenticatedBuilder: (_) {
            return const Scaffold(
              key: unauthenticatedDestinationKey,
              body: Center(child: Text('Unauthenticated destination')),
            );
          },
        ),
      ),
    );

    expect(find.text('MindPulse AI'), findsOneWidget);

    expect(
      find.text(
        'Understand your mind.\n'
        'Improve your wellbeing.',
      ),
      findsOneWidget,
    );

    expect(find.byKey(authenticatedDestinationKey), findsNothing);

    await completeSplashDelay(tester);

    expect(authenticationChecks, 1);

    expect(find.byKey(authenticatedDestinationKey), findsOneWidget);

    expect(find.byKey(unauthenticatedDestinationKey), findsNothing);
  });

  testWidgets('Splash opens unauthenticated destination', (
    WidgetTester tester,
  ) async {
    var authenticationChecks = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: SplashScreen(
          authChecker: () async {
            authenticationChecks += 1;
            return false;
          },
          authenticatedBuilder: (_) {
            return const Scaffold(
              key: authenticatedDestinationKey,
              body: Center(child: Text('Authenticated destination')),
            );
          },
          unauthenticatedBuilder: (_) {
            return const Scaffold(
              key: unauthenticatedDestinationKey,
              body: Center(child: Text('Unauthenticated destination')),
            );
          },
        ),
      ),
    );

    expect(find.text('MindPulse AI'), findsOneWidget);

    await completeSplashDelay(tester);

    expect(authenticationChecks, 1);

    expect(find.byKey(unauthenticatedDestinationKey), findsOneWidget);

    expect(find.byKey(authenticatedDestinationKey), findsNothing);
  });
}
