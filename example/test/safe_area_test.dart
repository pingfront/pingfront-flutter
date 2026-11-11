// The example's screens keep their content inside the safe area on every edge on its own. A foldable
// iPhone (iPhone Duo) puts its controls in a bar on one side, so the left and right insets differ, and
// which side depends on the pose and on the half of Split View the app is in.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pingfront_flutter_example/main.dart';

const _size = Size(466, 678);

/// The side bar on the right (the outer display), or on the left (an app in the right half of Split View).
const _barRight = EdgeInsets.only(right: 84, bottom: 20);
const _barLeft = EdgeInsets.only(left: 84, bottom: 20);

Future<void> _pump(WidgetTester tester, Widget page, EdgeInsets padding) async {
  tester.view.physicalSize = _size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding(
    left: padding.left,
    right: padding.right,
    bottom: padding.bottom,
  );
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: page));
  await tester.pumpAndSettle();
}

/// Every match is inside the left and right insets; with [bottom], also above the bottom one (rows of a
/// scrolling list may be built below the screen, so they are only checked at the sides).
void _expectInside(
  WidgetTester tester,
  Finder finder,
  EdgeInsets padding, {
  bool bottom = false,
}) {
  final count = finder.evaluate().length;
  expect(count, greaterThan(0));
  for (var index = 0; index < count; index++) {
    final rect = tester.getRect(finder.at(index));
    expect(rect.left, greaterThanOrEqualTo(padding.left), reason: '$rect');
    expect(
      rect.right,
      lessThanOrEqualTo(_size.width - padding.right),
      reason: '$rect',
    );
    if (bottom) {
      expect(
        rect.bottom,
        lessThanOrEqualTo(_size.height - padding.bottom),
        reason: '$rect',
      );
    }
  }
}

void main() {
  for (final (name, padding) in [('right', _barRight), ('left', _barLeft)]) {
    testWidgets('the paywall button stays clear of a bar on the $name', (
      tester,
    ) async {
      await _pump(tester, const PaywallPage(offerId: 'pro_yearly'), padding);
      _expectInside(tester, find.byType(FilledButton), padding, bottom: true);
    });

    testWidgets('the alarm rows stay clear of a bar on the $name', (
      tester,
    ) async {
      await _pump(tester, const AlarmsPage(), padding);
      _expectInside(tester, find.byType(ListTile), padding);
    });

    testWidgets('the home rows stay clear of a bar on the $name', (
      tester,
    ) async {
      await _pump(tester, const HomePage(), padding);
      _expectInside(tester, find.byType(ListTile), padding);
    });
  }
}
