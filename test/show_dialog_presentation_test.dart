import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/ui/codelessly_dialog_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'feedback_actions_test.dart' as harness;

/// A canvas of [size] holding the text 'Overlay'.
List<BaseNode> overlayScreen(Size size) => [
  CanvasNode(
    id: 'overlay',
    name: 'overlay',
    basicBoxLocal: NodeBox(0, 0, size.width, size.height),
    children: ['overlayBody'],
    properties: CanvasProperties(
      bodyId: 'overlayBody',
      safeArea: const SafeAreaModel.all(false),
    ),
  )..parentID = kRootNode,
  harness.body('overlayBody', 'overlay', ['label']),
  harness.text('label', 'overlayBody', 'Overlay', harness.brandRegular),
];

/// A canvas of [width] that hugs its content vertically: the 'Overlay' text
/// over a box [contentHeight] tall, in a body that hugs too.
List<BaseNode> huggingScreen(double width, double contentHeight) => [
  CanvasNode(
    id: 'overlay',
    name: 'overlay',
    basicBoxLocal: NodeBox(0, 0, width, 600),
    verticalFit: SizeFit.shrinkWrap,
    scaleMode: ScaleMode.responsive,
    children: ['overlayBody'],
    properties: CanvasProperties(
      bodyId: 'overlayBody',
      safeArea: const SafeAreaModel.all(false),
    ),
  )..parentID = kRootNode,
  AutoPlaceholderNode(
    id: 'overlayBody',
    name: 'overlayBody',
    basicBoxLocal: NodeBox(0, 0, width, contentHeight + 19),
    children: ['label', 'box'],
    mainAxisAlignment: MainAxisAlignmentC.start,
    crossAxisAlignment: CrossAxisAlignmentC.start,
    horizontalFit: SizeFit.expanded,
    verticalFit: SizeFit.shrinkWrap,
  )..parentID = 'overlay',
  harness.text('label', 'overlayBody', 'Overlay', harness.brandRegular),
  RectangleNode(
    id: 'box',
    name: 'box',
    basicBoxLocal: NodeBox(0, 0, 100, contentHeight),
  )..parentID = 'overlayBody',
];

Future<Rect> showOverlay(
  WidgetTester tester,
  Map<String, dynamic> extra, {
  Size design = const Size(390, 400),
  Size screen = const Size(834, 1112),
  List<BaseNode>? overlay,
}) async {
  final ActionModel action = ActionModel.fromJson({
    'type': 'showDialog',
    'destinationId': 'overlay',
    ...extra,
  });
  await harness.pumpLayouts(tester, [
    harness.layoutOf('main', harness.mainScreen(action)),
    harness.layoutOf('sheet', overlay ?? overlayScreen(design)),
  ], size: screen);
  await tester.tap(find.text('Go'));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  expect(find.text('Overlay'), findsOneWidget);
  // The overlay's canvas: the layout widget the overlay route built.
  return tester.getRect(find.byType(CodelesslyWidget).last);
}

void main() {
  testWidgets('a dialog keeps its design size, centered', (tester) async {
    final Rect box = await showOverlay(tester, {});
    expect(box.size, const Size(390, 400));
    expect(box.center, const Offset(417, 556));
  });

  testWidgets('an aligned dialog sits in its corner, inset from the edges', (
    tester,
  ) async {
    final Rect box = await showOverlay(tester, {
      'alignment': {
        'data': [-1, 1],
      },
      'insets': [96, 0, 0, 16],
    }, design: const Size(340, 300));
    expect(box.left, 96);
    expect(box.bottom, 1112 - 16);
    expect(box.size, const Size(340, 300));
  });

  testWidgets('a bottom sheet spans the screen width at its design height', (
    tester,
  ) async {
    final Rect box = await showOverlay(tester, {
      'presentation': 'bottomSheet',
    }, screen: const Size(390, 844));
    expect(box.width, 390);
    expect(box.height, 400);
    expect(box.bottom, 844);
  });

  testWidgets('a tall bottom sheet honors an explicit 88% cap', (tester) async {
    final Rect box = await showOverlay(
      tester,
      {'presentation': 'bottomSheet', 'maxHeightFactor': 0.88},
      design: const Size(390, 2000),
      screen: const Size(390, 844),
    );
    expect(box.height, closeTo(844 * 0.88, 0.5));
    expect(box.bottom, 844);
  });

  testWidgets('a bottom sheet without a cap may use the full screen', (
    tester,
  ) async {
    // The action defaults maxHeightFactor to 1, unlike the legacy 88% cap.
    final Rect box = await showOverlay(
      tester,
      {'presentation': 'bottomSheet'},
      design: const Size(390, 2000),
      screen: const Size(390, 844),
    );
    expect(box.height, 844);
    expect(box.bottom, 844);
  });

  testWidgets('a side sheet hugs the right edge at its design width', (
    tester,
  ) async {
    final Rect box = await showOverlay(tester, {
      'presentation': 'sideSheet',
      'insets': 10,
    }, design: const Size(420, 700));
    expect(box.width, 420);
    expect(box.right, 834 - 10);
    expect(box.top, 10);
    expect(box.bottom, 1112 - 10);
  });

  group('maxHeightFactor', () {
    testWidgets('a dialog that fits keeps its design height', (tester) async {
      final Rect box = await showOverlay(
        tester,
        {'maxHeightFactor': 0.9},
        design: const Size(600, 1000),
        screen: const Size(834, 1112),
      );
      expect(box.size, const Size(600, 1000));
    });

    testWidgets('a taller dialog stops at the share of the screen', (
      tester,
    ) async {
      final Rect box = await showOverlay(
        tester,
        {'maxHeightFactor': 0.9},
        design: const Size(600, 1000),
        screen: const Size(1440, 900),
      );
      expect(box.width, 600);
      expect(box.height, closeTo(810, 0.5));
      expect(box.center, const Offset(720, 450));
    });

    testWidgets('without it a dialog keeps its design height', (tester) async {
      final Rect box = await showOverlay(
        tester,
        {},
        design: const Size(600, 800),
        screen: const Size(1440, 900),
      );
      expect(box.height, 800);
    });

    testWidgets('a bottom sheet uses it instead of 88%', (tester) async {
      final Rect box = await showOverlay(
        tester,
        {'presentation': 'bottomSheet', 'maxHeightFactor': 0.5},
        design: const Size(390, 2000),
        screen: const Size(390, 844),
      );
      expect(box.height, closeTo(422, 0.5));
      expect(box.bottom, 844);
    });

    test('maxHeightFor caps by the share, ignoring unusable factors', () {
      expect(CodelesslyDialogWidget.maxHeightFor(0.9, 1000), 900);
      expect(CodelesslyDialogWidget.maxHeightFor(2, 1000), 1000);
      expect(CodelesslyDialogWidget.maxHeightFor(null, 1000), isNull);
      expect(CodelesslyDialogWidget.maxHeightFor(0, 1000), isNull);
    });
  });

  group('a canvas that hugs its content', () {
    // The box plus the label's line, far below the canvas's 600 design
    // height.
    void expectContentHeight(Rect box, double boxHeight) => expect(
      box.height,
      allOf(greaterThan(boxHeight + 10), lessThan(boxHeight + 30)),
    );

    testWidgets('makes a bottom sheet as tall as its content', (tester) async {
      final Rect box = await showOverlay(
        tester,
        {'presentation': 'bottomSheet'},
        screen: const Size(390, 844),
        overlay: huggingScreen(390, 200),
      );
      expect(box.width, 390);
      expectContentHeight(box, 200);
      expect(box.bottom, 844);
    });

    testWidgets('stops a bottom sheet at its cap', (tester) async {
      final Rect box = await showOverlay(
        tester,
        {'presentation': 'bottomSheet', 'maxHeightFactor': 0.25},
        screen: const Size(390, 844),
        overlay: huggingScreen(390, 400),
      );
      expect(box.height, closeTo(211, 0.5));
      expect(box.bottom, 844);
    });

    testWidgets('makes a side sheet as tall as its content, centered', (
      tester,
    ) async {
      final Rect box = await showOverlay(tester, {
        'presentation': 'sideSheet',
        'insets': 10,
      }, overlay: huggingScreen(420, 300));
      expect(box.width, 420);
      expect(box.right, 834 - 10);
      expectContentHeight(box, 300);
      expect(box.center.dy, closeTo(1112 / 2, 0.5));
    });

    testWidgets('makes a dialog as tall as its content', (tester) async {
      final Rect box = await showOverlay(
        tester,
        {},
        overlay: huggingScreen(400, 150),
      );
      expect(box.size.width, 400);
      expectContentHeight(box, 150);
    });
  });

  group('the actions after it run when the overlay closes', () {
    /// Shows the overlay from a button whose next action toasts 'Closed'.
    Future<void> open(WidgetTester tester, Map<String, dynamic> extra) async {
      final ActionModel show = ActionModel.fromJson({
        'type': 'showDialog',
        'destinationId': 'overlay',
        ...extra,
      });
      final List<BaseNode> main = harness.mainScreen(show);
      final ButtonNode go = main.whereType<ButtonNode>().single;
      go.reactions.add(
        Reaction(
          action: ActionModel.fromJson({
            'type': 'showToast',
            'message': 'Closed',
          }),
          trigger: TriggerModel(type: TriggerType.click),
        ),
      );
      await harness.pumpLayouts(tester, [
        harness.layoutOf('main', main),
        harness.layoutOf('sheet', overlayScreen(const Size(390, 400))),
      ], size: const Size(834, 1112));
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();
      expect(find.text('Overlay'), findsOneWidget);
      expect(find.text('Closed'), findsNothing);
    }

    Future<void> expectClosedOnce(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Overlay'), findsNothing);
      expect(find.text('Closed'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    }

    testWidgets('a dialog dismissed by its barrier', (tester) async {
      await open(tester, {});
      await tester.tapAt(const Offset(10, 10));
      await expectClosedOnce(tester);
    });

    testWidgets('a bottom sheet dismissed by its barrier', (tester) async {
      await open(tester, {'presentation': 'bottomSheet'});
      await tester.tapAt(const Offset(10, 10));
      await expectClosedOnce(tester);
    });

    testWidgets('a side sheet dismissed by its barrier', (tester) async {
      await open(tester, {'presentation': 'sideSheet'});
      await tester.tapAt(const Offset(10, 10));
      await expectClosedOnce(tester);
    });

    testWidgets('a dialog closed by the system back', (tester) async {
      await open(tester, {});
      final NavigatorState navigator = tester.state<NavigatorState>(
        find.byType(Navigator).last,
      );
      navigator.pop();
      await expectClosedOnce(tester);
    });
  });
}
