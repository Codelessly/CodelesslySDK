import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
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

Future<Rect> showOverlay(
  WidgetTester tester,
  Map<String, dynamic> extra, {
  Size design = const Size(390, 400),
  Size screen = const Size(834, 1112),
}) async {
  final ActionModel action = ActionModel.fromJson({
    'type': 'showDialog',
    'destinationId': 'overlay',
    ...extra,
  });
  await harness.pumpLayouts(tester, [
    harness.layoutOf('main', harness.mainScreen(action)),
    harness.layoutOf('sheet', overlayScreen(design)),
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

  testWidgets('a tall bottom sheet stops at 88% of the screen', (tester) async {
    final Rect box = await showOverlay(
      tester,
      {'presentation': 'bottomSheet'},
      design: const Size(390, 2000),
      screen: const Size(390, 844),
    );
    expect(box.height, closeTo(844 * 0.88, 0.5));
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
}
