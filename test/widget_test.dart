// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

// ignore: unused_import
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:myapp/screens/flash_screen.dart';
import 'package:myapp/screens/onboarding_screen.dart'; // Import this
import 'package:shared_preferences/shared_preferences.dart'; // Import this

void main() {
  testWidgets('App starts with SplashScreen', (WidgetTester tester) async {
    // Mock SharedPreferences
    SharedPreferences.setMockInitialValues({});

    // Build SplashScreen directly (avoid main.dart Hive init issues)
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    // Verify that SplashScreen is present.
    expect(find.byType(SplashScreen), findsOneWidget);

    // Drain the timer (4 seconds)
    await tester.pump(const Duration(seconds: 4));
    // Handle navigation frame
    await tester.pump();

    // SplashScreen should ideally navigate away,
    // expecting OnboardingScreen (since isFirstLaunch default is true in mock empty prefs?
    // actually prefs.getBool returns null, ?? true. So yes.)
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });
}
