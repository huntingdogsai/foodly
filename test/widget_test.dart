import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodly/main.dart';

import 'foodly_test_backend.dart';

void main() {
  testWidgets('Foodly production app signs in and renders home',
      (tester) async {
    installFoodlyTestPreferences();
    final backend = await tester.runAsync(FoodlyTestBackend.start);
    addTearDown(() => backend?.close());

    await HttpOverrides.runWithHttpOverrides(() async {
      await tester.pumpWidget(FoodlyProductionApp(
        apiBaseUrl: backend!.url.toString(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Foodly'), findsWidgets);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Email'),
        'ada@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Password'),
        'demo1234',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pump();
      await _pumpUntil(tester, find.text('Products'));

      expect(
        find.text('Products'),
        findsOneWidget,
        reason: _visibleText(tester).join(' | '),
      );
      expect(
        find.text('Coke'),
        findsOneWidget,
        reason: _visibleText(tester).join(' | '),
      );
    }, FoodlyRealHttpOverrides());
  });
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 20; attempt += 1) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    if (finder.evaluate().isNotEmpty) return;
  }
  await tester.pumpAndSettle();
}

List<String> _visibleText(WidgetTester tester) {
  return tester
      .widgetList<Text>(find.byType(Text))
      .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
      .where((value) => value.trim().isNotEmpty)
      .toList(growable: false);
}
