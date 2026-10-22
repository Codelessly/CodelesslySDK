import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'feedback_actions_test.dart'
    show brandRegular, layoutOf, mainScreen, pumpLayouts, text;

/// A 180 × 120 menu canvas with one line of text.
SDKPublishLayout menu() => layoutOf('menuLayout', [
  CanvasNode(
    id: 'menu',
    name: 'menu',
    basicBoxLocal: NodeBox(0, 0, 180, 120),
    scaleMode: ScaleMode.responsive,
    children: ['menuBody'],
    properties: CanvasProperties(
      bodyId: 'menuBody',
      safeArea: const SafeAreaModel.all(false),
    ),
  )..parentID = kRootNode,
  AutoPlaceholderNode(
    id: 'menuBody',
    name: 'menuBody',
    basicBoxLocal: NodeBox(0, 0, 180, 120),
    children: ['item'],
    mainAxisAlignment: MainAxisAlignmentC.start,
    horizontalFit: SizeFit.expanded,
    verticalFit: SizeFit.expanded,
  )..parentID = 'menu',
  text('item', 'menuBody', 'Snooze 1 hour', brandRegular),
]);

Rect menuRect(WidgetTester tester) => tester.getRect(
  find
      .ancestor(
        of: find.text('Snooze 1 hour'),
        matching: find.byType(CodelesslyWidget),
      )
      .first,
);

Future<void> open(
  WidgetTester tester,
  DialogPlacement placement, {
  Size size = const Size(390, 844),
}) async {
  await pumpLayouts(tester, [
    layoutOf(
      'main',
      mainScreen(
        ShowDialogAction(
          destinationId: 'menu',
          placement: placement,
          anchorGap: 6,
        ),
      ),
    ),
    menu(),
  ], size: size);
  await tester.tap(find.text('Go'));
  await tester.pumpAndSettle();
  expect(find.text('Snooze 1 hour'), findsOneWidget);
}

void main() {
  testWidgets('an anchored dialog opens just below its trigger', (
    tester,
  ) async {
    await open(tester, DialogPlacement.anchored);
    final Rect go = tester.getRect(
      find.ancestor(of: find.text('Go'), matching: find.byType(FitBox)).first,
    );
    final Rect shown = menuRect(tester);
    expect(shown.top, closeTo(go.bottom + 6, 1));
    expect(shown.left, closeTo(go.left.clamp(8, 390 - 180 - 8), 1));
    expect(shown.size, const Size(180, 120));
  });

  testWidgets('a bottom sheet spans the screen width at the bottom', (
    tester,
  ) async {
    await open(tester, DialogPlacement.bottomSheet);
    final Rect shown = menuRect(tester);
    expect(shown.width, 390);
    expect(shown.height, 120);
    expect(shown.bottom, 844);
  });

  testWidgets('adaptive is a sheet on mobile', (tester) async {
    await open(tester, DialogPlacement.adaptive);
    expect(menuRect(tester).bottom, 844);
    expect(menuRect(tester).width, 390);
  });

  testWidgets('adaptive is centered on desktop', (tester) async {
    await open(tester, DialogPlacement.adaptive, size: const Size(1440, 900));
    final Rect shown = menuRect(tester);
    expect(shown.size, const Size(180, 120));
    expect(shown.center, const Offset(720, 450));
  });

  testWidgets('an anchored dialog without room below opens above', (
    tester,
  ) async {
    await pumpLayouts(tester, [
      layoutOf(
        'main',
        mainScreen(
          ShowDialogAction(
            destinationId: 'menu',
            placement: DialogPlacement.anchored,
          ),
        ),
      ),
      menu(),
    ], size: const Size(390, 200));
    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();
    final Rect shown = menuRect(tester);
    expect(shown.top, greaterThanOrEqualTo(8));
    expect(shown.bottom, lessThanOrEqualTo(192));
  });
}
