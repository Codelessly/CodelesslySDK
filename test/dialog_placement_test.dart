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
  DialogAnchor anchor = DialogAnchor.none,
  DialogPresentation presentation = DialogPresentation.dialog,
  double sheetBelowWidth = 600,
}) async {
  await pumpLayouts(tester, [
    layoutOf(
      'main',
      mainScreen(
        ShowDialogAction(
          destinationId: 'menu',
          placement: placement,
          anchor: anchor,
          anchorGap: 6,
          presentation: presentation,
          sheetBelowWidth: sheetBelowWidth,
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

  testWidgets('a trigger anchor places a belowStart dialog below its trigger', (
    tester,
  ) async {
    await open(
      tester,
      DialogPlacement.belowStart,
      anchor: DialogAnchor.trigger,
    );
    final Rect go = tester.getRect(
      find.ancestor(of: find.text('Go'), matching: find.byType(FitBox)).first,
    );
    final Rect shown = menuRect(tester);
    expect(shown.top, closeTo(go.bottom + 6, 1));
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

  // A menu: a popover at its trigger on wide screens, a sheet on phones.
  testWidgets('an adaptive anchored menu is a popover on desktop', (
    tester,
  ) async {
    await open(
      tester,
      DialogPlacement.belowStart,
      anchor: DialogAnchor.trigger,
      presentation: DialogPresentation.adaptive,
      size: const Size(1440, 900),
    );
    final Rect go = tester.getRect(
      find.ancestor(of: find.text('Go'), matching: find.byType(FitBox)).first,
    );
    final Rect shown = menuRect(tester);
    expect(shown.top, closeTo(go.bottom + 6, 1));
    expect(shown.size, const Size(180, 120));
  });

  testWidgets('an adaptive anchored menu is a sheet on mobile', (tester) async {
    await open(
      tester,
      DialogPlacement.belowStart,
      anchor: DialogAnchor.trigger,
      presentation: DialogPresentation.adaptive,
    );
    expect(menuRect(tester).bottom, 844);
    expect(menuRect(tester).width, 390);
  });

  // Switchboard's phone layout ends at 640, not the default 600: at 620 its
  // menus must be sheets, as the rest of the screen is the phone layout.
  testWidgets('an adaptive menu takes the app\'s sheet breakpoint', (
    tester,
  ) async {
    await open(
      tester,
      DialogPlacement.belowStart,
      anchor: DialogAnchor.trigger,
      presentation: DialogPresentation.adaptive,
      size: const Size(620, 900),
    );
    expect(menuRect(tester).width, isNot(620));
  });

  testWidgets(
    'below the app\'s sheet breakpoint, an adaptive menu is a sheet',
    (tester) async {
      await open(
        tester,
        DialogPlacement.belowStart,
        anchor: DialogAnchor.trigger,
        presentation: DialogPresentation.adaptive,
        size: const Size(620, 900),
        sheetBelowWidth: 640,
      );
      expect(menuRect(tester).bottom, 900);
      expect(menuRect(tester).width, 620);
    },
  );

  // Switchboard's menus are popovers on desktop with nothing dimmed behind
  // them, and sheets over a scrim on phones, from one adaptive action.
  testWidgets('an adaptive menu dims behind its sheet, not its popover', (
    tester,
  ) async {
    Color? barrier() =>
        tester.widgetList<ModalBarrier>(find.byType(ModalBarrier)).last.color;
    await open(
      tester,
      DialogPlacement.belowStart,
      anchor: DialogAnchor.trigger,
      presentation: DialogPresentation.adaptive,
      size: const Size(1440, 900),
    );
    expect(barrier(), anyOf(isNull, Colors.transparent));
  });

  testWidgets('an adaptive menu sheet keeps its barrier color', (tester) async {
    await open(
      tester,
      DialogPlacement.belowStart,
      anchor: DialogAnchor.trigger,
      presentation: DialogPresentation.adaptive,
    );
    final Color? color = tester
        .widgetList<ModalBarrier>(find.byType(ModalBarrier))
        .last
        .color;
    expect(color, isNotNull);
    expect(color!.a, greaterThan(0));
  });
}
