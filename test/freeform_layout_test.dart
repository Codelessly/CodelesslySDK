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
  PositioningMode mode = PositioningMode.align,
  AlignmentModel alignment = AlignmentModel.none,
  SizeFit horizontalFit = SizeFit.fixed,
  SizeFit verticalFit = SizeFit.fixed,
}) => RectangleNode(
  id: id,
  name: id,
  basicBoxLocal: box,
  edgePins:
      pins ?? EdgePinsModel(left: box.x, top: box.y, right: null, bottom: null),
  positioningMode: mode,
  alignment: alignment,
  horizontalFit: horizontalFit,
  verticalFit: verticalFit,
)..parentID = parent;

FrameNode frame(
  String id,
  NodeBox box,
  List<BaseNode> children, {
  SizeFit horizontalFit = SizeFit.expanded,
  SizeFit verticalFit = SizeFit.expanded,
  EdgeInsetsModel padding = EdgeInsetsModel.zero,
  bool isScrollable = false,
  String parent = kRootNode,
  EdgePinsModel pins = EdgePinsModel.standard,
}) => FrameNode(
  id: id,
  name: id,
  basicBoxLocal: box,
  children: [for (final child in children) child.id],
  horizontalFit: horizontalFit,
  verticalFit: verticalFit,
  padding: padding,
  isScrollable: isScrollable,
  edgePins: pins,
  clipsContent: false,
)..parentID = parent;

Finder rectOf(BaseNode node) =>
    find.byKey(ValueKey('Rectangle Transformer of ${node.debugLabel}'));

enum Host { tight, loose, scroll }

/// Pumps [root] on a [screen] sized view and returns every node's global rect.
Future<Map<String, Rect>> pump(
  WidgetTester tester,
  BaseNode root,
  List<BaseNode> nodes, {
  required Size screen,
  Host host = Host.tight,
  List<BaseNode> extra = const [],
}) async {
  tester.view.physicalSize = screen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final registry = NodeRegistry()
    ..setNodes({
      for (final node in [root, ...nodes, ...extra]) node.id: node,
    });
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  final Widget built = Builder(
    builder: (context) => manager.buildWidgetFromNode(
      root,
      context,
      settings: const WidgetBuildSettings(debugLabel: 'test'),
    ),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: CodelesslyContext.empty(),
      child: MaterialApp(
        home: switch (host) {
          Host.tight => built,
          Host.loose => Scaffold(body: Center(child: built)),
          Host.scroll => Scaffold(body: SingleChildScrollView(child: built)),
        },
      ),
    ),
  );
  expect(tester.takeException(), isNull);
  return {
    for (final node in [root, ...nodes]) node.id: tester.getRect(rectOf(node)),
  };
}

void expectOnScreen(
  Map<String, Rect> rects,
  Size screen,
  Iterable<String> ids,
) {
  final Rect bounds = Offset.zero & screen;
  for (final id in ids) {
    final Rect r = rects[id]!;
    expect(r.width, greaterThan(0), reason: '$id has no width: $r');
    expect(r.height, greaterThan(0), reason: '$id has no height: $r');
    expect(
      bounds.inflate(0.01).contains(r.topLeft) &&
          bounds.inflate(0.01).contains(r.bottomRight),
      isTrue,
      reason: '$id at $r is not inside the $screen screen',
    );
  }
}

/// A full-screen freeform body designed at [design], with one child of every
/// placement kind.
(FrameNode, List<BaseNode>) freeformScreen(Size design) {
  final double w = design.width;
  final double h = design.height;
  final children = <BaseNode>[
    // Default drop: align mode with its design x/y as left/top pins.
    rect('dropped', NodeBox(w - 340, 40, 300, 80)),
    rect('droppedLeft', NodeBox(0, 140, 200, 60)),
    // Explicitly pinned to the left.
    rect(
      'pinnedLeft',
      NodeBox(w * 0.6, 220, 140, 60),
      mode: PositioningMode.pin,
    ),
    // Pinned to the right and bottom.
    rect(
      'pinnedRight',
      NodeBox(w - 236, h - 116, 220, 100),
      mode: PositioningMode.pin,
      pins: const EdgePinsModel(left: null, top: null, right: 16, bottom: 16),
    ),
    // Pinned to both sides.
    rect(
      'stretched',
      NodeBox(w * 0.5, 300, w * 0.5 - 24, 50),
      mode: PositioningMode.pin,
      pins: EdgePinsModel(left: w * 0.5, top: 300, right: 24, bottom: null),
    ),
    rect(
      'centered',
      NodeBox((w - 120) / 2, (h - 120) / 2, 120, 120),
      alignment: AlignmentModel.center,
    ),
    rect(
      'fill',
      NodeBox(0, 0, w, 8),
      horizontalFit: SizeFit.expanded,
      pins: const EdgePinsModel(left: 0, top: 0, right: 0, bottom: null),
    ),
  ];
  return (frame('frame', NodeBox(0, 0, w, h), children), children);
}

void main() {
  group('freeform children at the design size', () {
    for (final design in screens) {
      testWidgets('stay exactly where they were designed at $design', (
        tester,
      ) async {
        final (root, children) = freeformScreen(design);
        final rects = await pump(tester, root, children, screen: design);
        for (final child in children) {
          expect(
            rects[child.id],
            Rect.fromLTWH(
              child.basicBoxLocal.x,
              child.basicBoxLocal.y,
              child.basicBoxLocal.width,
              child.basicBoxLocal.height,
            ),
            reason: child.id,
          );
        }
      });
    }
  });

  group('freeform children at other sizes', () {
    for (final design in screens) {
      for (final screen in screens) {
        for (final host in [Host.tight, Host.loose]) {
          testWidgets(
            'designed at $design stay on screen at $screen (${host.name})',
            (tester) async {
              final (root, children) = freeformScreen(design);
              final rects = await pump(
                tester,
                root,
                children,
                screen: screen,
                host: host,
              );
              expect(rects['frame'], Offset.zero & screen);
              expectOnScreen(rects, screen, [for (final c in children) c.id]);

              // Pins keep their distances whenever they fit.
              expect(
                rects['pinnedRight']!.right,
                closeTo(screen.width - 16, 0.01),
              );
              expect(
                rects['pinnedRight']!.bottom,
                closeTo(screen.height - 16, 0.01),
              );
              expect(rects['fill']!.width, screen.width);
              expect(
                rects['centered']!.center.dx,
                closeTo(screen.width / 2, 0.01),
              );
              if (screen.width >= design.width) {
                expect(
                  rects['stretched']!.right,
                  closeTo(screen.width - 24, 0.01),
                );
                expect(
                  rects['stretched']!.left,
                  closeTo(design.width * 0.5, 0.01),
                );
              }
              if (screen.width > design.width) {
                // A dropped child keeps its share of the free space instead
                // of staying at its design x.
                final dropped = rects['dropped']!;
                expect(
                  dropped.left / (screen.width - 300),
                  closeTo((design.width - 340) / (design.width - 300), 0.001),
                );
                expect(rects['droppedLeft']!.left, 0);
              }
            },
          );
        }
      }
    }
  });

  testWidgets('a stretched child shrinks with its pins instead of vanishing', (
    tester,
  ) async {
    final child = rect(
      'card',
      NodeBox(1000, 10, 400, 40),
      mode: PositioningMode.pin,
      pins: const EdgePinsModel(left: 1000, top: 10, right: 40, bottom: null),
    );
    final root = frame('frame', NodeBox(0, 0, 1440, 900), [child]);
    final rects = await pump(tester, root, [
      child,
    ], screen: const Size(390, 844));
    final card = rects['card']!;
    // Its design share of the width: 400 / 1440.
    expect(card.width, closeTo(400 * 390 / 1440, 0.01));
    // The pins split what is left in their design ratio.
    expect(card.left / (390 - card.right), closeTo(1000 / 40, 0.01));
  });

  testWidgets('a left-pinned child wider than the screen is kept inside', (
    tester,
  ) async {
    final child = rect(
      'wide',
      NodeBox(300, 10, 900, 40),
      mode: PositioningMode.pin,
    );
    final root = frame('frame', NodeBox(0, 0, 1440, 900), [child]);
    final rects = await pump(tester, root, [
      child,
    ], screen: const Size(390, 844));
    expect(rects['wide'], const Rect.fromLTWH(0, 10, 390, 40));
  });

  testWidgets('padding offsets freeform children', (tester) async {
    final child = rect('a', NodeBox(30, 40, 50, 50));
    final root = frame(
      'frame',
      NodeBox(0, 0, 200, 300),
      [child],
      horizontalFit: SizeFit.fixed,
      verticalFit: SizeFit.fixed,
      padding: const EdgeInsetsModel.all(20),
    );
    final rects = await pump(tester, root, [
      child,
    ], screen: const Size(390, 844));
    final Offset origin = rects['frame']!.topLeft;
    expect(rects['a']!.shift(-origin), const Rect.fromLTWH(30, 40, 50, 50));
  });

  group('wrapping stacks', () {
    testWidgets('size to their children plus the pins', (tester) async {
      final a = rect('a', NodeBox(10, 20, 100, 40), parent: 'wrap');
      final b = rect('b', NodeBox(30, 5, 50, 30), parent: 'wrap');
      final c = rect(
        'c',
        NodeBox(55, 35, 30, 30),
        parent: 'wrap',
        alignment: AlignmentModel.bottomRight,
      );
      final wrap = frame(
        'wrap',
        NodeBox(0, 0, 110, 60),
        [a, b, c],
        horizontalFit: SizeFit.shrinkWrap,
        verticalFit: SizeFit.shrinkWrap,
      );
      for (final screen in screens) {
        final rects = await pump(
          tester,
          wrap,
          [a, b, c],
          screen: screen,
          host: Host.loose,
        );
        final Offset origin = rects['wrap']!.topLeft;
        expect(rects['wrap']!.size, const Size(110, 60));
        expect(
          rects['a']!.shift(-origin),
          const Rect.fromLTWH(10, 20, 100, 40),
        );
        expect(rects['b']!.shift(-origin), const Rect.fromLTWH(30, 5, 50, 30));
        // Aligned in the wrapped size, not frozen at design offsets.
        expect(rects['c']!.shift(-origin), const Rect.fromLTWH(80, 30, 30, 30));
      }
    });

    testWidgets('keep the size of their visible children when the largest '
        'collapses', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      FreeformAxisPlacement axis(double start, double extent) =>
          FreeformAxisPlacement(
            mode: FreeformAxisMode.start,
            start: start,
            extent: extent,
            parentExtent: 200,
          );
      const key = Key('layout');
      await tester.pumpWidget(
        Center(
          child: FreeformLayout(
            key: key,
            wrapsWidth: true,
            wrapsHeight: true,
            designSize: const Size(200, 200),
            children: [
              FreeformChild(
                placement: FreeformPlacement(
                  horizontal: axis(0, 200),
                  vertical: axis(0, 200),
                ),
                // A hidden child collapses to nothing.
                child: const SizedBox.shrink(),
              ),
              FreeformChild(
                placement: FreeformPlacement(
                  horizontal: axis(10, 50),
                  vertical: axis(10, 50),
                ),
                child: const SizedBox(width: 50, height: 50),
              ),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byKey(key)), const Size(60, 60));
    });
  });

  testWidgets('a freeform body under an unbounded height keeps its design '
      'height', (tester) async {
    final (root, children) = freeformScreen(const Size(390, 844));
    root.parentID = 'canvas';
    final canvas = CanvasNode(
      id: 'canvas',
      name: 'canvas',
      basicBoxLocal: NodeBox(0, 0, 390, 844),
      children: [root.id],
      properties: CanvasProperties(bodyId: root.id),
    )..parentID = kRootNode;
    for (final screen in screens) {
      final rects = await pump(
        tester,
        root,
        children,
        screen: screen,
        host: Host.scroll,
        extra: [canvas],
      );
      expect(rects['frame']!.size, Size(screen.width, 844));
      for (final child in children) {
        expect(rects[child.id]!.isEmpty, isFalse, reason: child.id);
        expect(rects[child.id]!.left, greaterThanOrEqualTo(0));
        expect(rects[child.id]!.right, lessThanOrEqualTo(screen.width + 0.01));
      }
    }
  });

  testWidgets('an empty shrink-wrapping frame takes only its padding', (
    tester,
  ) async {
    final root = frame(
      'frame',
      NodeBox(0, 0, 40, 40),
      [],
      horizontalFit: SizeFit.shrinkWrap,
      verticalFit: SizeFit.shrinkWrap,
      padding: const EdgeInsetsModel.all(8),
    );
    final rects = await pump(
      tester,
      root,
      [],
      screen: const Size(390, 844),
      host: Host.loose,
    );
    expect(rects['frame']!.size, const Size(16, 16));
  });
}
