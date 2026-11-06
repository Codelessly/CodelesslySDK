import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Finder _of(String id) =>
    find.byKey(ValueKey('Rectangle Transformer of $id [$id]'));

/// A 300x660 truck diagram whose wheel sits in its bottom-right quarter.
({FrameNode truck, RectangleNode wheel}) _truck({
  Fit? fit = Fit.contain,
  AlignmentModel alignment = AlignmentModel.center,
  SizeFit fits = SizeFit.expanded,
  bool clipsContent = true,
}) {
  final RectangleNode wheel = RectangleNode(
    id: 'wheel',
    name: 'wheel',
    basicBoxLocal: NodeBox(150, 330, 150, 330),
    positioningMode: PositioningMode.pin,
    edgePins: const EdgePinsModel(
      left: 150,
      top: 330,
      right: null,
      bottom: null,
    ),
  )..parentID = 'truck';
  final FrameNode truck = FrameNode(
    id: 'truck',
    name: 'truck',
    basicBoxLocal: NodeBox(0, 0, 300, 660),
    children: ['wheel'],
    horizontalFit: fits,
    verticalFit: fits,
    contentFit: fit,
    contentAlignment: alignment,
    clipsContent: clipsContent,
  )..parentID = kRootNode;
  return (truck: truck, wheel: wheel);
}

Future<void> _pump(
  WidgetTester tester,
  List<BaseNode> nodes, {
  required Size box,
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
          child: SizedBox.fromSize(
            size: box,
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

/// The clipping render objects between [id]'s rectangle and the frame
/// [frameId]'s rectangle, the frame's own included.
List<RenderObject> _clipsAbove(WidgetTester tester, String id, String frameId) {
  final RenderObject frame = tester.renderObject(_of(frameId));
  final List<RenderObject> clips = [];
  RenderObject? node = tester.renderObject(_of(id)).parent;
  bool clips_(RenderObject o) =>
      o is RenderClipRect ||
      o is RenderClipRRect ||
      o is RenderClipRSuperellipse ||
      o is RenderClipPath ||
      o is RenderClipOval ||
      (o is RenderFittedBox && o.clipBehavior != Clip.none);
  while (node != null) {
    if (clips_(node)) clips.add(node);
    if (identical(node, frame)) break;
    node = node.parent;
  }
  // The frame's rectangle wraps its clip; look one level into it as well.
  void down(RenderObject o, int depth) {
    if (depth == 0) return;
    o.visitChildren((c) {
      if (clips_(c) && !clips.contains(c)) clips.add(c);
      down(c, depth - 1);
    });
  }

  down(frame, 3);
  return clips;
}

void main() {
  testWidgets('scaled content does not clip its children unless the frame '
      'clips', (tester) async {
    // A card's drop shadow paints past the frame's box: only the frame's
    // own clipsContent may cut it.
    final (:truck, :wheel) = _truck(clipsContent: false);
    await _pump(tester, [truck, wheel], box: const Size(600, 330));
    expect(_clipsAbove(tester, 'wheel', 'truck'), isEmpty);
    expect(
      tester.getRect(_of('wheel')),
      const Rect.fromLTWH(225 + 75, 165, 75, 165),
    );
  });

  testWidgets('a clipping frame with scaled content still clips', (
    tester,
  ) async {
    final (:truck, :wheel) = _truck();
    await _pump(tester, [truck, wheel], box: const Size(600, 330));
    expect(_clipsAbove(tester, 'wheel', 'truck'), isNotEmpty);
  });

  testWidgets('contain scales the design into a short wide box, centered', (
    tester,
  ) async {
    final (:truck, :wheel) = _truck();
    await _pump(tester, [truck, wheel], box: const Size(600, 330));
    // Scale 0.5: the 150x330 content sits centered in 600 wide.
    expect(tester.getRect(_of('truck')), const Rect.fromLTWH(0, 0, 600, 330));
    expect(
      tester.getRect(_of('wheel')),
      const Rect.fromLTWH(225 + 75, 165, 75, 165),
    );
  });

  testWidgets('contain scales the design up into a bigger box', (tester) async {
    final (:truck, :wheel) = _truck();
    await _pump(tester, [truck, wheel], box: const Size(600, 1320));
    expect(
      tester.getRect(_of('wheel')),
      const Rect.fromLTWH(300, 660, 300, 660),
    );
  });

  testWidgets('scaleDown never scales up', (tester) async {
    final (:truck, :wheel) = _truck(
      fit: Fit.scaleDown,
      alignment: AlignmentModel.topLeft,
    );
    await _pump(tester, [truck, wheel], box: const Size(600, 1320));
    expect(
      tester.getRect(_of('wheel')),
      const Rect.fromLTWH(150, 330, 150, 330),
    );
  });

  testWidgets('a fixed-size frame shows its content unscaled', (tester) async {
    final (:truck, :wheel) = _truck(fits: SizeFit.fixed);
    await _pump(tester, [truck, wheel], box: const Size(600, 1320));
    expect(tester.getRect(_of('truck')), const Rect.fromLTWH(0, 0, 300, 660));
    expect(
      tester.getRect(_of('wheel')),
      const Rect.fromLTWH(150, 330, 150, 330),
    );
  });

  testWidgets('without a content fit the children are not scaled', (
    tester,
  ) async {
    final (:truck, :wheel) = _truck(fit: null);
    await _pump(tester, [truck, wheel], box: const Size(600, 330));
    expect(tester.getSize(_of('wheel')), const Size(150, 330));
  });

  test('contentFit round-trips through JSON and is omitted when unset', () {
    final (:truck, wheel: _) = _truck(
      fit: Fit.scaleDown,
      alignment: AlignmentModel.topCenter,
    );
    final FrameNode copy = FrameNode.fromJson(truck.toJson());
    expect(copy.contentFit, Fit.scaleDown);
    expect(copy.contentAlignment, AlignmentModel.topCenter);
    final Map plain = _truck(fit: null).truck.toJson();
    expect(plain.containsKey('contentFit'), isFalse);
    expect(plain.containsKey('contentAlignment'), isFalse);
  });

  testWidgets('children of a frame scaled from its contentSize are placed in '
      'the design space, not the frame box', (tester) async {
    // A 1200x720 trail map drawn into a 390x234 frame: a chair at (300,
    // 300) in the map lands at 0.325 of that. Placing it by its share of
    // the frame's own free space (390 - 60) sent it to x 1036 of the map.
    final RectangleNode chair = RectangleNode(
      id: 'chair',
      name: 'chair',
      basicBoxLocal: NodeBox(300, 300, 60, 60),
      positioningMode: PositioningMode.align,
      edgePins: const EdgePinsModel(left: 300, top: 300, right: null, bottom: null),
    )..parentID = 'map';
    final FrameNode map = FrameNode(
      id: 'map',
      name: 'map',
      basicBoxLocal: NodeBox(0, 0, 390, 234),
      children: ['chair'],
      contentFit: Fit.contain,
      contentSize: const SizeC(1200, 720),
    )..parentID = kRootNode;
    await _pump(tester, [map, chair], box: const Size(390, 234));
    final Rect rect = tester.getRect(_of('chair'));
    expect(rect.left, moreOrLessEquals(97.5, epsilon: 0.01));
    expect(rect.top, moreOrLessEquals(97.5, epsilon: 0.01));
    expect(rect.width, moreOrLessEquals(19.5, epsilon: 0.01));
  });
}
