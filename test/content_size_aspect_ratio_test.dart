import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Finder _of(String id) =>
    find.byKey(ValueKey('Rectangle Transformer of $id [$id]'));

/// A boarding-pass face designed at 340x214 that fills the width it gets:
/// the editor stored its box at [box] (the size it solved for it), while its
/// content keeps the 340x214 design. A 170x107 stamp sits in the design's
/// bottom-right quarter.
({FrameNode face, RectangleNode stamp}) _face({
  NodeBox? box,
  SizeC? contentSize = const SizeC(340, 214),
  double? aspectRatio = 340 / 214,
}) {
  final RectangleNode stamp = RectangleNode(
    id: 'stamp',
    name: 'stamp',
    basicBoxLocal: NodeBox(170, 107, 170, 107),
    positioningMode: PositioningMode.pin,
    edgePins: const EdgePinsModel(
      left: 170,
      top: 107,
      right: null,
      bottom: null,
    ),
  )..parentID = 'face';
  final FrameNode face =
      FrameNode(
          id: 'face',
          name: 'face',
          basicBoxLocal: box ?? NodeBox(0, 0, 680, 428),
          children: ['stamp'],
          horizontalFit: SizeFit.expanded,
          verticalFit: SizeFit.fixed,
          contentFit: Fit.contain,
          contentSize: contentSize,
        )
        ..layoutAspectRatio = aspectRatio
        ..parentID = kRootNode;
  return (face: face, stamp: stamp);
}

Future<void> _pump(
  WidgetTester tester,
  List<BaseNode> nodes, {
  required double width,
}) async {
  tester.view.physicalSize = const Size(1440, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final registry = NodeRegistry()..setNodes({for (final n in nodes) n.id: n});
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: CodelesslyContext.empty(),
      child: MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            height: 1200,
            child: Align(
              alignment: Alignment.topLeft,
              child: Builder(
                builder: (context) => manager.buildWidgetFromNode(
                  nodes.first,
                  context,
                  settings: const WidgetBuildSettings(debugLabel: 'test'),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  expect(tester.takeException(), isNull);
}

void main() {
  for (final double width in [340, 680, 390]) {
    testWidgets('a filling face keeps 340:214 and scales from its design at '
        '$width wide', (tester) async {
      final (:face, :stamp) = _face();
      await _pump(tester, [face, stamp], width: width);
      final double scale = width / 340;
      final Rect f = tester.getRect(_of('face'));
      expect(f.width, moreOrLessEquals(width));
      expect(f.height, moreOrLessEquals(214 * scale));
      final Rect s = tester.getRect(_of('stamp'));
      expect(s.left, moreOrLessEquals(170 * scale));
      expect(s.top, moreOrLessEquals(107 * scale));
      expect(s.width, moreOrLessEquals(170 * scale));
      expect(s.height, moreOrLessEquals(107 * scale));
    });
  }

  testWidgets('without a content size the frame scales from its own box', (
    tester,
  ) async {
    // The old behavior: the box the editor stored is the design.
    final (:face, :stamp) = _face(contentSize: null, aspectRatio: null);
    await _pump(tester, [face, stamp], width: 680);
    expect(tester.getRect(_of('face')), const Rect.fromLTWH(0, 0, 680, 428));
    expect(
      tester.getRect(_of('stamp')),
      const Rect.fromLTWH(170, 107, 170, 107),
    );
  });

  testWidgets('a rectangle with an aspect ratio derives its height', (
    tester,
  ) async {
    final RectangleNode card = RectangleNode(
      id: 'card',
      name: 'card',
      basicBoxLocal: NodeBox(0, 0, 100, 100),
      horizontalFit: SizeFit.expanded,
    )..layoutAspectRatio = 1.5;
    card.parentID = kRootNode;
    await _pump(tester, [card], width: 300);
    expect(tester.getSize(_of('card')), const Size(300, 200));
  });

  test('keepAspectRatio leads with the width and stays in bounds', () {
    const fills = (fillWidth: true, fillHeight: false);
    Size? keep(double? w, double? h, BoxConstraints c, [f = fills]) =>
        RenderFitBox.keepAspectRatio(w, h, 2, c, f);
    expect(
      keep(400, 50, const BoxConstraints(maxWidth: 400, maxHeight: 1000)),
      const Size(400, 200),
    );
    // Too tall for the room: the height caps and the width follows.
    expect(
      keep(400, 50, const BoxConstraints(maxWidth: 400, maxHeight: 100)),
      const Size(200, 100),
    );
    // Only the height fills: it leads.
    expect(
      keep(50, 300, const BoxConstraints(maxWidth: 1000, maxHeight: 300), (
        fillWidth: false,
        fillHeight: true,
      )),
      const Size(600, 300),
    );
    // A hugging width follows the height.
    expect(keep(null, 100, const BoxConstraints()), const Size(200, 100));
    expect(keep(null, null, const BoxConstraints()), isNull);
  });

  test('an icon\'s built-in 1:1 ratio does not wrap it', () {
    final BaseNode icon = NodeJsonConverter().fromJson({
      'id': 'icon',
      'name': 'icon',
      'type': 'icon',
      'basicBoxLocal': [0, 0, 24, 24],
      'properties': {
        'icon': {'type': 'icon', 'show': true},
      },
    })!;
    const Widget child = SizedBox();
    expect(identical(wrapWithAspectRatio(icon, child), child), isTrue);
    icon.layoutAspectRatio = 2;
    expect(wrapWithAspectRatio(icon, child), isA<FitBox>());
  });

  test('contentSize and aspectRatio round-trip through JSON', () {
    final (:face, stamp: _) = _face();
    final FrameNode copy = FrameNode.fromJson(face.toJson());
    expect(copy.contentSize, const SizeC(340, 214));
    expect(copy.layoutAspectRatio, face.layoutAspectRatio);
  });
}
