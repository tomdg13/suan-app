// Basic smoke test — confirms the app boots without throwing.
// Expand this later with real widget tests as screens stabilize.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:suan_market_app/main.dart';

void main() {
  testWidgets('App boots and shows the storefront app bar', (WidgetTester tester) async {
    await tester.pumpWidget(const SuanMarketApp());

    // The storefront title should appear in the AppBar on launch.
    expect(find.text('ສວນມັວກອມ Market'), findsOneWidget);
  });
}
