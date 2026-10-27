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

      await _signIn(tester);

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

  testWidgets('Favourites are kept per account, across restarts',
      (tester) async {
    installFoodlyTestPreferences();
    final backend = await tester.runAsync(FoodlyTestBackend.start);
    addTearDown(() => backend?.close());

    await HttpOverrides.runWithHttpOverrides(() async {
      await tester.pumpWidget(FoodlyProductionApp(
        apiBaseUrl: backend!.url.toString(),
      ));
      await tester.pumpAndSettle();
      await _signIn(tester);

      const noFavourites =
          'No favourites yet: tap a heart to keep a product here.';
      await _pumpUntil(tester, find.text(noFavourites));
      expect(
        find.text(noFavourites),
        findsOneWidget,
        reason: _visibleText(tester).join(' | '),
      );
      expect(
        find.text('Coke'),
        findsOneWidget,
        reason: _visibleText(tester).join(' | '),
      );

      final cokeHeart = find.descendant(
        of: find.widgetWithText(ListTile, 'Coke'),
        matching: find.byTooltip('Add to favourites'),
      );
      await tester.ensureVisible(cokeHeart);
      await tester.tap(cokeHeart);
      await _pumpUntil(tester, find.text(noFavourites), gone: true);
      expect(
        find.text('Coke'),
        findsNWidgets(2),
        reason: _visibleText(tester).join(' | '),
      );
      expect(
        find.byTooltip('Remove from favourites'),
        findsNWidgets(2),
        reason: _visibleText(tester).join(' | '),
      );

      // The app started again with the same storage: the favourite is back.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(FoodlyProductionApp(
        apiBaseUrl: backend.url.toString(),
      ));
      await tester.pumpAndSettle();
      await _signIn(tester);
      await _pumpUntil(tester, find.byTooltip('Remove from favourites'));
      expect(
        find.text('Coke'),
        findsNWidgets(2),
        reason: _visibleText(tester).join(' | '),
      );

      final removeHeart = find.byTooltip('Remove from favourites').first;
      await tester.ensureVisible(removeHeart);
      await tester.tap(removeHeart);
      await _pumpUntil(tester, find.text(noFavourites));
      expect(
        find.text('Coke'),
        findsOneWidget,
        reason: _visibleText(tester).join(' | '),
      );
      expect(
        find.byTooltip('Remove from favourites'),
        findsNothing,
        reason: _visibleText(tester).join(' | '),
      );

      // Signed out, the favourites and their hearts are gone from the screen.
      await _tapNavigation(tester, 'Account');
      await _pumpUntil(tester, find.widgetWithText(FilledButton, 'Sign out'));
      await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
      await _pumpUntil(tester, find.widgetWithText(FilledButton, 'Sign out'),
          gone: true);
      await _tapNavigation(tester, 'Home');
      await _pumpUntil(tester, find.text('Sign in to keep favourites.'));
      expect(
        find.text('Sign in to keep favourites.'),
        findsOneWidget,
        reason: _visibleText(tester).join(' | '),
      );
      expect(
        find.byTooltip('Add to favourites'),
        findsNothing,
        reason: _visibleText(tester).join(' | '),
      );
    }, FoodlyRealHttpOverrides());
  });
}

/// The navigation bar is the list's first row: back to the top, then the tap.
Future<void> _tapNavigation(WidgetTester tester, String label) async {
  await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(label),
  ));
  await tester.pump();
}

Future<void> _signIn(WidgetTester tester) async {
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
}

Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  bool gone = false,
}) async {
  for (var attempt = 0; attempt < 20; attempt += 1) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    if (finder.evaluate().isEmpty == gone) return;
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
