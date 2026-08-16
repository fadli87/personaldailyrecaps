import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sf_daily_recap/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: SFDailyRecapApp(),
      ),
    );

    // Verify that MaterialApp is created.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
