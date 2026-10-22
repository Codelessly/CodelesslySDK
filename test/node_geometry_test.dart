import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const List<Size> screens = [Size(390, 844), Size(834, 1194), Size(1440, 900)];

RectangleNode rect(
  String id,
  NodeBox box, {
  String parent = 'frame',
  EdgePinsModel? pins,
  EdgeInsetsModel margin = EdgeInsetsModel.zero,
  int rotation = 0,
  bool visible = true,
}) => RectangleNode(
  id: id,
  name: id,
  basicBoxLocal: box,
  edgePins:
      pins ?? EdgePinsModel(left: box.x, top: box.y, right: null, bottom: null),
  positioningMode: PositioningMode.pin,
  margin: margin,
  rotationDegrees: rotation,
  visible: visible,
)..parentID = parent;

FrameNode frame(
  String id,
  NodeBox box,
  List<BaseNode> children, {
  SizeFit horizontalFit = SizeFit.expanded,
  SizeFit verticalFit = SizeFit.expanded,
  bool isScrollable = false,
  bool clipsContent = false,
  String parent = kRootNode,
  EdgePinsModel pins = EdgePinsModel.standard,
}) => FrameNode(
  id: id,
  name: id,
  basicBoxLocal: box,
  children: [for (final child in children) child.id],
  horizontalFit: horizontalFit,
  verticalFit: verticalFit,
  isScrollable: isScrollable,
  edgePins: pins,
  positioningMode: PositioningMode.pin,
  clipsContent: clipsContent,
)..parentID = parent;

Finder rectOf(BaseNode node) =>
    find.byKey(ValueKey('Rectangle Transformer of ${node.debugLabel}'));

/// Pumps [root] under a [NodeGeometryScope] with probes on every node.
/// [wrap] places the scope inside host widgets, like the editor's zoom.
Future<NodeGeometryRegistry> pump(
  WidgetTester tester,
  BaseNode root,
  List<BaseNode> nodes, {
  Size screen = const Size(800, 600),
  NodeBuildDecorator? decorator = const GeometryProbeDecorator(),
  Widget Function(Widget scope)? wrap,
}) async {
  tester.view.physicalSize = screen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final nodeRegistry = NodeRegistry()
    ..setNodes({
      for (final node in [root, ...nodes]) node.id: node,
    });
  final manager = PassiveNodeTransformerManager(
    nodeRegistry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  )..decorator = decorator;
  final registry = NodeGeometryRegistry();
  addTearDown(registry.dispose);
  final Widget scope = NodeGeometryScope(
    registry: registry,
    child: Builder(
      builder: (context) => manager.buildWidgetFromNode(
        root,
        context,
        settings: const WidgetBuildSettings(debugLabel: 'test'),
      ),
    ),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: CodelesslyContext.empty(),
      child: MaterialApp(home: wrap?.call(scope) ?? scope),
    ),
  );
  expect(tester.takeException(), isNull);
  return registry;
}

/// The global rect of [registry]'s scope origin.
Offset scopeOrigin(NodeGeometryRegistry registry) =>
    registry.root!.localToGlobal(Offset.zero);

void expectRect(Rect actual, Rect expected, {String? reason}) {
  for (final (a, e) in [
    (actual.left, expected.left),
    (actual.top, expected.top),
    (actual.right, expected.right),
    (actual.bottom, expected.bottom),
  ]) {
    expect(a, moreOrLessEquals(e, epsilon: 0.01), reason: '$reason: $actual');
  }
}

/// A full-screen freeform body with pinned, stretched, margined and nested
/// children.
(FrameNode, List<BaseNode>) screenTree() {
  final children = <BaseNode>[
    rect('topLeft', NodeBox(20, 30, 120, 60)),
    rect(
      'bottomRight',
      NodeBox(0, 0, 100, 50),
      pins: const EdgePinsModel(left: null, top: null, right: 24, bottom: 16),
    ),
    rect(
      'stretched',
      NodeBox(40, 120, 300, 40),
      pins: const EdgePinsModel(left: 40, top: 120, right: 40, bottom: null),
    ),
    rect(
      'margined',
      NodeBox(60, 200, 80, 80),
      margin: const EdgeInsetsModel.only(left: 10, top: 6, right: 4, bottom: 8),
    ),
  ];
  final inner = rect('inner', NodeBox(10, 10, 40, 30), parent: 'card');
  final card = frame(
    'card',
    NodeBox(160, 300, 200, 120),
    [inner],
    horizontalFit: SizeFit.fixed,
    verticalFit: SizeFit.fixed,
    parent: 'frame',
    pins: const EdgePinsModel(left: 160, top: 300, right: null, bottom: null),
  );
  return (
    frame('frame', NodeBox(0, 0, 390, 844), [...children, card]),
    [...children, card, inner],
  );
}

void main() {
  group('geometry matches the painted boxes', () {
    for (final screen in screens) {
      testWidgets('at ${screen.width.toInt()}x${screen.height.toInt()}', (
        tester,
      ) async {
        final (root, nodes) = screenTree();
        final registry = await pump(tester, root, nodes, screen: screen);
        final Offset origin = scopeOrigin(registry);

        for (final node in [root, ...nodes]) {
          final NodeGeometry? geometry = registry.geometryOf(node.id);
          expect(geometry, isNotNull, reason: node.id);
          expectRect(
            geometry!.bounds.shift(origin),
            tester.getRect(rectOf(node)),
            reason: node.id,
          );
          expect(geometry.painted, isTrue, reason: node.id);
        }

        // The margin box is the node box grown by its margin.
        final Rect margined = registry.geometryOf('margined')!.bounds;
        final Rect outer = registry
            .geometryOf('margined', layer: NodeBuildLayer.margin)!
            .bounds;
        expectRect(
          outer,
          Rect.fromLTRB(
            margined.left - 10,
            margined.top - 6,
            margined.right + 4,
            margined.bottom + 8,
          ),
          reason: 'margin box',
        );

        // Pins hold at every width: the right/bottom pinned node and the
        // stretched node follow the screen, not the design size.
        expectRect(
          registry.geometryOf('bottomRight')!.bounds,
          Rect.fromLTWH(
            screen.width - 24 - 100,
            screen.height - 16 - 50,
            100,
            50,
          ),
          reason: 'bottomRight',
        );
        expect(
          registry.geometryOf('stretched')!.bounds.width,
          moreOrLessEquals(screen.width - 80),
        );
      });
    }
  });

  testWidgets('geometry is in scope coordinates under a zoom transform', (
    tester,
  ) async {
    final (root, nodes) = screenTree();
    final registry = await pump(
      tester,
      root,
      nodes,
      wrap: (scope) => Transform.scale(
        scale: 2.5,
        alignment: Alignment.topLeft,
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: 390,
          maxWidth: 390,
          minHeight: 844,
          maxHeight: 844,
          child: scope,
        ),
      ),
    );
    final Rect inScope = registry.geometryOf('inner')!.bounds;
    expectRect(inScope, const Rect.fromLTWH(170, 310, 40, 30));
    // Mapping to the screen through the root gives the painted rect.
    final Matrix4 toScreen = registry.root!.getTransformTo(null);
    expectRect(
      MatrixUtils.transformRect(toScreen, inScope),
      tester.getRect(rectOf(nodes.last)),
      reason: 'screen rect',
    );
  });

  testWidgets('a rotated node reports its rotated quad', (tester) async {
    final spun = rect('spun', NodeBox(100, 100, 200, 100), rotation: 90);
    final registry = await pump(
      tester,
      frame('frame', NodeBox(0, 0, 800, 600), [spun]),
      [spun],
    );
    final NodeGeometry geometry = registry.geometryOf('spun')!;
    final Offset center = geometry.bounds.center;
    expect(center.dx, moreOrLessEquals(200));
    expect(center.dy, moreOrLessEquals(150));
    // Rotated a quarter turn about its center: 100 wide and 200 tall.
    expect(geometry.bounds.width, moreOrLessEquals(100));
    expect(geometry.bounds.height, moreOrLessEquals(200));
    final List<Offset> quad = geometry.quad;
    expect((quad[1] - quad[0]).distance, moreOrLessEquals(200));
    expect((quad[1] - quad[0]).direction, moreOrLessEquals(math.pi / 2));
    // The margin box isn't rotated: rotation is inside it.
    expectRect(
      registry.geometryOf('spun', layer: NodeBuildLayer.margin)!.bounds,
      const Rect.fromLTWH(100, 100, 200, 100),
    );
  });

  testWidgets('scrolling moves geometry without relayout and notifies', (
    tester,
  ) async {
    final children = [
      for (int i = 0; i < 10; i++) rect('r$i', NodeBox(0, i * 100.0, 50, 50)),
    ];
    final registry = await pump(
      tester,
      frame(
        'frame',
        NodeBox(0, 0, 200, 300),
        children,
        horizontalFit: SizeFit.fixed,
        verticalFit: SizeFit.fixed,
        isScrollable: true,
        clipsContent: true,
      ),
      children,
      wrap: (scope) => Align(alignment: Alignment.topLeft, child: scope),
    );
    final double before = registry.geometryOf('r3')!.bounds.top;
    int notifications = 0;
    registry.addListener(() => notifications++);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -120),
    );
    await tester.pump();

    final NodeGeometry after = registry.geometryOf('r3')!;
    expect(notifications, greaterThan(0));
    expect(after.bounds.top, lessThan(before));
    expectRect(
      after.bounds.shift(scopeOrigin(registry)),
      tester.getRect(rectOf(children[3])),
      reason: 'scrolled',
    );
    // The scroll view clips its content to the frame.
    final NodeGeometry first = registry.geometryOf('r0')!;
    expect(first.clip, isNotNull);
    expect(first.visibleBounds.height, lessThan(first.bounds.height));
  });

  testWidgets('a clipping frame clips the visible bounds', (tester) async {
    final spill = rect('spill', NodeBox(150, 20, 100, 40), parent: 'card');
    final card = frame(
      'card',
      NodeBox(0, 0, 200, 100),
      [spill],
      horizontalFit: SizeFit.fixed,
      verticalFit: SizeFit.fixed,
      clipsContent: true,
      parent: 'frame',
    );
    final registry = await pump(
      tester,
      frame('frame', NodeBox(0, 0, 800, 600), [card]),
      [card, spill],
    );
    final NodeGeometry geometry = registry.geometryOf('spill')!;
    expectRect(geometry.bounds, const Rect.fromLTWH(150, 20, 100, 40));
    expectRect(geometry.visibleBounds, const Rect.fromLTWH(150, 20, 50, 40));
  });

  group('hit testing', () {
    testWidgets('returns the deepest node first, and the top sibling', (
      tester,
    ) async {
      final (root, nodes) = screenTree();
      final under = rect('under', NodeBox(400, 400, 100, 100));
      final over = rect('over', NodeBox(450, 450, 100, 100));
      final registry = await pump(
        tester,
        frame('frame', root.basicBoxLocal, [
          ...nodes.where((n) => n.parentID == 'frame'),
          under,
          over,
        ]),
        [...nodes, under, over],
        screen: const Size(800, 600),
      );

      List<String> idsAt(Offset point) => [
        for (final hit in registry.hitTest(point)) hit.nodeId,
      ];

      expect(idsAt(const Offset(175, 315)), ['inner', 'card', 'frame']);
      expect(idsAt(const Offset(165, 305)), ['card', 'frame']);
      expect(idsAt(const Offset(475, 475)), ['over', 'under', 'frame']);
      expect(idsAt(const Offset(525, 525)), ['over', 'frame']);
      expect(idsAt(const Offset(425, 425)), ['under', 'frame']);
      // Inside the margin of a node, but outside its box.
      final Offset inMargin =
          registry
              .geometryOf('margined', layer: NodeBuildLayer.margin)!
              .bounds
              .topLeft +
          const Offset(2, 2);
      expect(idsAt(inMargin), ['frame']);
      expect(
        [
          for (final hit in registry.hitTest(
            inMargin,
            layer: NodeBuildLayer.margin,
          ))
            hit.nodeId,
        ],
        ['margined', 'frame'],
      );
      // Skipping a node skips its subtree, so what is under it is hit.
      expect(
        [
          for (final hit in registry.hitTest(
            const Offset(475, 475),
            skip: (hit) => hit.nodeId == 'over',
          ))
            hit.nodeId,
        ],
        ['under', 'frame'],
      );
    });

    testWidgets('overflowing children are hit unless their parent clips', (
      tester,
    ) async {
      final out = rect('out', NodeBox(150, 20, 100, 40), parent: 'open');
      final open = frame(
        'open',
        NodeBox(0, 0, 200, 100),
        [out],
        horizontalFit: SizeFit.fixed,
        verticalFit: SizeFit.fixed,
        parent: 'frame',
      );
      final cut = rect('cut', NodeBox(150, 20, 100, 40), parent: 'clipped');
      final clipped = frame(
        'clipped',
        NodeBox(0, 200, 200, 100),
        [cut],
        horizontalFit: SizeFit.fixed,
        verticalFit: SizeFit.fixed,
        clipsContent: true,
        parent: 'frame',
        pins: const EdgePinsModel(left: 0, top: 200, right: null, bottom: null),
      );
      final registry = await pump(
        tester,
        frame('frame', NodeBox(0, 0, 800, 600), [open, clipped]),
        [open, out, clipped, cut],
      );
      List<String> idsAt(Offset point) => [
        for (final hit in registry.hitTest(point)) hit.nodeId,
      ];
      expect(idsAt(const Offset(230, 40)), ['out', 'frame']);
      expect(idsAt(const Offset(170, 40)), ['out', 'open', 'frame']);
      expect(idsAt(const Offset(230, 240)), ['frame']);
      expect(idsAt(const Offset(170, 240)), ['cut', 'clipped', 'frame']);
    });

    testWidgets('a hidden node is laid out but neither painted nor hit', (
      tester,
    ) async {
      final hidden = rect('hidden', NodeBox(10, 10, 100, 100), visible: false);
      final registry = await pump(
        tester,
        frame('frame', NodeBox(0, 0, 800, 600), [hidden]),
        [hidden],
      );
      final NodeGeometry geometry = registry.geometryOf('hidden')!;
      expect(geometry.painted, isFalse);
      expect(geometry.visibleBounds, Rect.zero);
      expect(
        [for (final hit in registry.hitTest(const Offset(50, 50))) hit.nodeId],
        ['frame'],
      );
    });
  });

  testWidgets('list items register one instance per built item', (
    tester,
  ) async {
    final item = RectangleNode(
      id: 'item',
      name: 'item',
      basicBoxLocal: NodeBox(0, 0, 300, 80),
    )..parentID = 'list';
    final list = ListViewNode(
      id: 'list',
      name: 'list',
      basicBoxLocal: NodeBox(0, 0, 300, 400),
      properties: ListViewProperties(itemCount: 3),
      children: ['item'],
    )..parentID = kRootNode;
    final registry = await pump(tester, list, [
      item,
    ], wrap: (scope) => Align(alignment: Alignment.topLeft, child: scope));
    final List<NodeGeometry> instances = registry.instancesOf('item');
    expect(
      [for (final g in instances) g.instance],
      [
        [0],
        [1],
        [2],
      ],
    );
    for (int i = 0; i < 3; i++) {
      expect(instances[i].bounds.top, moreOrLessEquals(i * 80.0));
    }
    expect(registry.primaryOf('item')!.instance, [0]);
    expect(
      registry.hitTest(const Offset(20, 100)).first,
      const NodeHit('item', [1]),
    );
  });

  testWidgets('without a decorator nothing is probed', (tester) async {
    final (root, nodes) = screenTree();
    final registry = await pump(tester, root, nodes, decorator: null);
    expect(find.byType(GeometryProbe), findsNothing);
    expect(registry.nodeIds, isEmpty);
  });

  testWidgets('a paint offset moves a node without layout', (tester) async {
    final (root, nodes) = screenTree();
    final registry = await pump(tester, root, nodes);
    final Rect card = registry.geometryOf('card')!.bounds;
    final Rect inner = registry.geometryOf('inner')!.bounds;
    final Rect painted = tester.getRect(rectOf(nodes.last));

    expect(registry.setPaintOffset('card', const Offset(40, -25)), isTrue);
    expect(registry.setPaintOffset('missing', const Offset(1, 1)), isFalse);
    final RenderObject probe = tester.renderObject(
      find.byType(GeometryProbe).first,
    );
    await tester.pump();
    expect(probe.debugNeedsLayout, isFalse);

    expectRect(
      registry.geometryOf('card')!.bounds,
      card.shift(const Offset(40, -25)),
    );
    expectRect(
      registry.geometryOf('card', layer: NodeBuildLayer.margin)!.bounds,
      card.shift(const Offset(40, -25)),
    );
    expectRect(
      registry.geometryOf('inner')!.bounds,
      inner.shift(const Offset(40, -25)),
    );
    expectRect(
      tester.getRect(rectOf(nodes.last)),
      painted.shift(const Offset(40, -25)),
    );
    expect(
      registry.hitTest(inner.center + const Offset(40, -25)).first.nodeId,
      'inner',
    );

    registry.setPaintOffset('card', Offset.zero);
    await tester.pump();
    expectRect(registry.geometryOf('inner')!.bounds, inner);
  });

  testWidgets('removed nodes unregister', (tester) async {
    final (root, nodes) = screenTree();
    final registry = await pump(tester, root, nodes);
    expect(registry.nodeIds, contains('inner'));
    await tester.pumpWidget(const SizedBox());
    expect(registry.nodeIds, isEmpty);
    expect(registry.root, isNull);
  });
}
