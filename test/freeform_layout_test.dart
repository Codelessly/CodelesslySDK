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
  testWidgets('invalid fractional values retain the legacy axis placement', (
    tester,
  ) async {
    final pin = rect('pin', NodeBox(40, 60, 28, 36), mode: PositioningMode.pin);
    final root = frame('frame', NodeBox(0, 0, 400, 300), [pin]);
    for (final value in <String>[
      r'${= -0.1}',
      r'${= 1.1}',
      r'${= 0 / 0}',
      r'${= "bad"}',
    ]) {
      pin.variables['positionX'] = value;
      pin.variables['positionY'] = value;
      final boxes = await pump(tester, root, [
        pin,
      ], screen: const Size(400, 300));
      expect(boxes['pin']!.topLeft, const Offset(40, 60), reason: value);
    }
  });

  testWidgets(
    'typed formula fractions respond to parent resize; no binding stays legacy',
    (tester) async {
      final pin =
          rect(
              'pin',
              NodeBox(40, 60, 28, 36),
              alignment: AlignmentModel.bottomCenter,
            )
            ..variables['positionX'] = r'${= 1 / 4}'
            ..variables['positionY'] = r'${= 3 / 4}';
      final legacy = rect(
        'legacy',
        NodeBox(40, 60, 28, 36),
        mode: PositioningMode.pin,
      );
      final root = frame('frame', NodeBox(0, 0, 400, 300), [pin, legacy]);
      for (final size in <Size>[const Size(400, 300), const Size(800, 600)]) {
        final boxes = await pump(tester, root, [pin, legacy], screen: size);
        expect(boxes['pin']!.center.dx, closeTo(size.width / 4, 0.1));
        expect(boxes['pin']!.bottom, closeTo(size.height * 3 / 4, 0.1));
        expect(boxes['legacy']!.topLeft, const Offset(40, 60));
      }
    },
  );

  testWidgets('mounted position binding updates its freeform parent slot', (
    tester,
  ) async {
    const size = Size(400, 300);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final pin = rect('pin', NodeBox(40, 60, 28, 36))
      ..variables['positionX'] = r'${= pinX}'
      ..variables['positionY'] = r'${= 1 / 2}';
    final root = frame('frame', NodeBox(0, 0, 400, 300), [pin]);
    final registry = NodeRegistry()..setNodes({root.id: root, pin.id: pin});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    final x = Observable(
      VariableData(
        id: 'pinX',
        name: 'pinX',
        type: VariableType.decimal,
        value: .2,
      ),
    );
    final scope = CodelesslyContext.empty()..variables['pinX'] = x;
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: scope,
        child: MaterialApp(
          home: Builder(
            builder: (context) => manager.buildWidgetFromNode(
              root,
              context,
              settings: const WidgetBuildSettings(debugLabel: 'test'),
            ),
          ),
        ),
      ),
    );
    Rect current() => tester.getRect(rectOf(pin));
    expect(current().center.dx, closeTo(80, .1));
    expect(current().center.dy, closeTo(150, .1));
    x.set(x.value.copyWith(value: .8));
    await tester.pump();
    expect(current().center.dx, closeTo(320, .1));
    expect(current().center.dy, closeTo(150, .1));
    x.set(x.value.copyWith(value: 1.5));
    await tester.pump();
    expect(current().topLeft, const Offset(40, 132));
  });

  testWidgets('mounted fractional parent slot follows a changed variable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final pin = rect('pin', NodeBox(40, 60, 28, 36))
      ..variables['positionX'] = r'${= pinX}'
      ..variables['positionY'] = r'${= 0.5}';
    final root = frame('frame', NodeBox(0, 0, 400, 300), [pin]);
    final registry = NodeRegistry()..setNodes({root.id: root, pin.id: pin});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    final position = Observable(
      VariableData(
        id: 'pinX',
        name: 'pinX',
        type: VariableType.decimal,
        value: 0.25,
      ),
    );
    final context = CodelesslyContext.empty()..variables['pinX'] = position;
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: context,
        child: MaterialApp(
          home: Builder(
            builder: (scope) => manager.buildWidgetFromNode(
              root,
              scope,
              settings: const WidgetBuildSettings(debugLabel: 'test'),
            ),
          ),
        ),
      ),
    );
    Rect box() => tester.getRect(rectOf(pin));
    expect(box().center.dx, closeTo(100, 0.1));
    position.set(position.value.copyWith(value: 0.75));
    await tester.pump();
    expect(box().center.dx, closeTo(300, 0.1));
    expect(box().center.dy, closeTo(150, 0.1));
  });

  testWidgets('five hero pins with identical saved boxes use bound positions', (
    tester,
  ) async {
    const positions = <(double, double)>[
      (0.18, 0.30),
      (0.47, 0.62),
      (0.70, 0.24),
      (0.86, 0.78),
      (0.32, 0.86),
    ];
    final children = <RectangleNode>[
      for (int i = 0; i < positions.length; i++)
        rect(
            'pin$i',
            NodeBox(325.06, 415.92, 27.88, 36.08),
            alignment: AlignmentModel.bottomCenter,
          )
          ..variables['positionX'] = '\${= ${positions[i].$1}}'
          ..variables['positionY'] = '\${= ${positions[i].$2}}',
    ];
    final root = frame('frame', NodeBox(0, 0, 600, 400), children);
    final rects = await pump(
      tester,
      root,
      children,
      screen: const Size(600, 400),
    );
    for (int i = 0; i < positions.length; i++) {
      final pin = rects['pin$i']!;
      expect(pin.center.dx, closeTo(600 * positions[i].$1, 0.1));
      expect(pin.bottom, closeTo(400 * positions[i].$2, 0.1));
    }
    expect(rects.values.map((r) => r.topLeft).toSet(), hasLength(6));
  });

  testWidgets('fractional pin positions follow responsive parent size', (
    tester,
  ) async {
    final pin = rect('pin', NodeBox(325.06, 415.92, 27.88, 36.08))
      ..variables['positionX'] = r'${= .18}'
      ..variables['positionY'] = r'${= .3}';
    final root = frame('frame', NodeBox(0, 0, 600, 400), [pin]);
    for (final size in [const Size(600, 400), const Size(900, 700)]) {
      final result = await pump(tester, root, [pin], screen: size);
      expect(result['pin']!.center.dx, closeTo(size.width * .18, .1));
      expect(result['pin']!.center.dy, closeTo(size.height * .3, .1));
    }
  });

  testWidgets('bad fractional bindings leave legacy placement unchanged', (
    tester,
  ) async {
    final baseline = rect('baseline', NodeBox(80, 90, 28, 36));
    final children = <RectangleNode>[
      baseline,
      for (final (index, binding) in [
        r'${= -0.1}',
        r'${= 1.2}',
        r'${= "oops"}',
        r'${= 0 / 0}',
      ].indexed)
        rect('bad$index', NodeBox(80, 90, 28, 36))
          ..variables['positionX'] = binding,
    ];
    final root = frame('frame', NodeBox(0, 0, 390, 844), children);
    final result = await pump(
      tester,
      root,
      children,
      screen: const Size(390, 844),
    );
    for (final child in children.skip(1)) {
      expect(result[child.id]!.topLeft, result['baseline']!.topLeft);
    }
  });

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

  for (final screen in screens) {
    testWidgets('children pinned top and bottom reach both pins at $screen, '
        'whatever their stored height', (tester) async {
      // A shell designed taller than any screen; the stored heights do not
      // satisfy the pins (1173 and 1000 instead of 1319 and 1303).
      final drawer = rect(
        'drawer',
        NodeBox(0, 0, 300, 1173),
        mode: PositioningMode.pin,
        pins: const EdgePinsModel(left: 0, top: 0, right: null, bottom: 0),
      );
      final sheet = rect(
        'sheet',
        NodeBox(82, 8, 300, 1000),
        mode: PositioningMode.pin,
        pins: const EdgePinsModel(left: null, top: 8, right: 8, bottom: 8),
      );
      final root = frame('frame', NodeBox(0, 0, 390, 1319), [drawer, sheet]);
      final rects = await pump(tester, root, [drawer, sheet], screen: screen);
      expect(rects['drawer'], Rect.fromLTWH(0, 0, 300, screen.height));
      expect(
        rects['sheet'],
        Rect.fromLTRB(
          screen.width - 308,
          8,
          screen.width - 8,
          screen.height - 8,
        ),
      );
    });
  }

  for (final screen in screens) {
    testWidgets('pinned axes ignore a stale stored rect at $screen', (
      tester,
    ) async {
      // Stored rects left behind by a canvas resize the editor did not
      // re-solve: none of them agrees with its pins.
      final bottomSheet = RectangleNode(
        id: 'bottomSheet',
        name: 'bottomSheet',
        basicBoxLocal: NodeBox(0, 759.333, 1193.324, 560),
        edgePins: const EdgePinsModel(left: 0, top: null, right: 0, bottom: 0),
      )..parentID = 'frame';
      final sideSheet = RectangleNode(
        id: 'sideSheet',
        name: 'sideSheet',
        basicBoxLocal: NodeBox(745.324, 8, 440, 1157.333),
        edgePins: const EdgePinsModel(left: null, top: 8, right: 8, bottom: 8),
      )..parentID = 'frame';
      final badge = RectangleNode(
        id: 'badge',
        name: 'badge',
        basicBoxLocal: NodeBox(500, 700, 40, 40),
        edgePins: const EdgePinsModel(
          left: 16,
          top: 24,
          right: null,
          bottom: null,
        ),
        positioningMode: PositioningMode.pin,
      )..parentID = 'frame';
      final root = frame('frame', NodeBox(0, 0, 834, 1194), [
        bottomSheet,
        sideSheet,
        badge,
      ]);
      final rects = await pump(tester, root, [
        bottomSheet,
        sideSheet,
        badge,
      ], screen: screen);
      final Size s = screen;
      expect(
        rects['bottomSheet'],
        Rect.fromLTWH(0, s.height - 560, s.width, 560),
      );
      expect(
        rects['sideSheet'],
        s.width >= 456
            ? Rect.fromLTRB(s.width - 8 - 440, 8, s.width - 8, s.height - 8)
            // Too wide for the phone: kept inside, as wide as the screen.
            : Rect.fromLTRB(0, 8, s.width, s.height - 8),
      );
      expect(rects['badge'], const Rect.fromLTWH(16, 24, 40, 40));
      expectOnScreen(rects, s, ['bottomSheet', 'sideSheet', 'badge']);
    });
  }

  testWidgets('pinned axes measure the pins from the padded box', (
    tester,
  ) async {
    final child = RectangleNode(
      id: 'pinned',
      name: 'pinned',
      basicBoxLocal: NodeBox(3, 3, 50, 50),
      positioningMode: PositioningMode.pin,
      edgePins: const EdgePinsModel(
        left: null,
        top: 30,
        right: 30,
        bottom: null,
      ),
    )..parentID = 'frame';
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
    // 30 from the frame's right and top edges, as in the editor.
    expect(
      rects['pinned']!.shift(-origin),
      const Rect.fromLTWH(120, 30, 50, 50),
    );
  });

  testWidgets('pins give way to a min constraint, in proportion', (
    tester,
  ) async {
    final child = RectangleNode(
      id: 'min',
      name: 'min',
      basicBoxLocal: NodeBox(100, 0, 200, 50),
      edgePins: const EdgePinsModel(
        left: 100,
        top: 0,
        right: 300,
        bottom: null,
      ),
      positioningMode: PositioningMode.pin,
      constraints: const BoxConstraintsModel(minWidth: 150),
    )..parentID = 'frame';
    final root = frame('frame', NodeBox(0, 0, 600, 300), [child]);
    final rects = await pump(tester, root, [
      child,
    ], screen: const Size(390, 844));
    // 390 - 400 of pins leaves nothing: the child keeps its 150 minimum and
    // the pins split the other 240 as 100:300.
    expect(rects['min'], const Rect.fromLTWH(60, 0, 150, 50));
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
    // What the editor's solver settles on (run through the real solver in
    // the editor's position_manager tests): a wrapping frame is as large as
    // its largest child, and children are clamped inside it.
    testWidgets('size to their largest child, as the editor solves them', (
      tester,
    ) async {
      final a = rect('a', NodeBox(0, 0, 100, 40), parent: 'wrap');
      final b = rect('b', NodeBox(30, 5, 50, 30), parent: 'wrap');
      final c = rect(
        'c',
        NodeBox(70, 10, 30, 30),
        parent: 'wrap',
        alignment: AlignmentModel.bottomRight,
      );
      final wrap = frame(
        'wrap',
        NodeBox(0, 0, 100, 40),
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
        expect(rects['wrap']!.size, const Size(100, 40));
        expect(rects['a']!.shift(-origin), const Rect.fromLTWH(0, 0, 100, 40));
        expect(rects['b']!.shift(-origin), const Rect.fromLTWH(30, 5, 50, 30));
        expect(rects['c']!.shift(-origin), const Rect.fromLTWH(70, 10, 30, 30));
      }
    });

    testWidgets(
      'clamp a child whose offset would leak out, as the editor does',
      (tester) async {
        // The solver sizes this frame to 60x40 and moves the child from 10,10
        // to 0,0 (FreeFormPositionEditor clamps children of wrapping frames).
        final a = rect('a', NodeBox(10, 10, 60, 40), parent: 'wrap');
        final wrap = frame(
          'wrap',
          NodeBox(0, 0, 200, 200),
          [a],
          horizontalFit: SizeFit.shrinkWrap,
          verticalFit: SizeFit.shrinkWrap,
        );
        for (final screen in screens) {
          final rects = await pump(
            tester,
            wrap,
            [a],
            screen: screen,
            host: Host.loose,
          );
          final Offset origin = rects['wrap']!.topLeft;
          expect(rects['wrap']!.size, const Size(60, 40));
          expect(rects['a']!.shift(-origin), const Rect.fromLTWH(0, 0, 60, 40));
        }
      },
    );

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
      expect(tester.getSize(find.byKey(key)), const Size(50, 50));
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

  group('a scrolling canvas with a freeform body', () {
    CanvasNode scrollingCanvas(List<String> body) => CanvasNode(
      id: 'canvas',
      name: 'canvas',
      basicBoxLocal: NodeBox(0, 0, 390, 844),
      children: ['body'],
      scaleMode: ScaleMode.responsive,
      isScrollable: true,
      properties: CanvasProperties(
        bodyId: 'body',
        safeArea: const SafeAreaModel.all(false),
      ),
    )..parentID = kRootNode;

    FreeformPlaceholderNode body(List<String> children) =>
        FreeformPlaceholderNode(
          id: 'body',
          name: 'body',
          basicBoxLocal: NodeBox(0, 0, 390, 844),
          children: children,
          horizontalFit: SizeFit.expanded,
          verticalFit: SizeFit.expanded,
        )..parentID = 'canvas';

    TextNode text(
      String id,
      NodeBox box, {
      String characters =
          'This sentence is long enough to wrap onto several lines once '
          'the box it sits in is narrow.',
      SizeFit fit = SizeFit.fixed,
      EdgePinsModel? pins,
      String parent = 'body',
    }) => TextNode(
      id: id,
      name: id,
      basicBoxLocal: box,
      horizontalFit: fit,
      verticalFit: fit,
      edgePins:
          pins ??
          EdgePinsModel(left: box.x, top: box.y, right: null, bottom: null),
      data: characters,
      textMixedProps: [
        StartEndProp(start: 0, end: characters.length, fontSize: 16),
      ],
    )..parentID = parent;

    Future<void> pumpCanvas(
      WidgetTester tester,
      List<BaseNode> nodes,
      Size screen,
    ) async {
      tester.view.physicalSize = screen;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final registry = NodeRegistry()
        ..setNodes({for (final node in nodes) node.id: node});
      final manager = PassiveNodeTransformerManager(
        registry.getNodeByID,
        (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
      );
      await tester.pumpWidget(
        ChangeNotifierProvider<CodelesslyContext>.value(
          value: CodelesslyContext.empty(),
          child: MaterialApp(
            home: Builder(
              builder: (context) => manager.buildWidgetFromNode(
                nodes.first,
                context,
                settings: const WidgetBuildSettings(debugLabel: 'test'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    }

    for (final screen in screens) {
      testWidgets('keeps a child far down reachable at $screen', (
        tester,
      ) async {
        final far = rect('far', NodeBox(20, 2000, 100, 100), parent: 'body');
        final nodes = [
          scrollingCanvas(['body']),
          body(['far']),
          far,
        ];
        await pumpCanvas(tester, nodes, screen);

        final Offset bodyOrigin = tester.getTopLeft(rectOf(nodes[1]));
        expect(tester.getTopLeft(rectOf(far)).dy - bodyOrigin.dy, 2000);

        await tester.drag(
          find.byType(Scrollable).first,
          const Offset(0, -4000),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expectOnScreen({'far': tester.getRect(rectOf(far))}, screen, ['far']);
      });

      testWidgets('pushes content below text that grew at $screen', (
        tester,
      ) async {
        // The editor measured the text as one 20 px line; at 120 wide it
        // wraps to several.
        final t = text('text', NodeBox(10, 10, 120, 20));
        final below = rect('below', NodeBox(0, 40, 100, 50), parent: 'body');
        final beside = rect(
          'beside',
          NodeBox(200, 40, 100, 50),
          parent: 'body',
        );
        final nodes = [
          scrollingCanvas(['body']),
          body(['text', 'below', 'beside']),
          t,
          below,
          beside,
        ];
        await pumpCanvas(tester, nodes, screen);

        final Rect textBox = tester.getRect(find.byType(TextNodeBox));
        expect(textBox.height, greaterThan(20));
        final Rect belowRect = tester.getRect(rectOf(below));
        expect(belowRect.top, closeTo(textBox.bottom + 10, 0.01));
        final Offset bodyOrigin = tester.getTopLeft(rectOf(nodes[1]));
        expect(tester.getTopLeft(rectOf(beside)).dy - bodyOrigin.dy, 40);
      });
    }
  });

  group('shrink-wrapping text pinned to all edges', () {
    for (final screen in screens) {
      testWidgets('stays centred between its pins at $screen', (tester) async {
        const String characters = 'Hi';
        // Measure the text as the test font lays it out.
        final painter = TextPainter(
          text: const TextSpan(
            text: characters,
            style: TextStyle(fontSize: 16),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final Size natural = painter.size;
        painter.dispose();
        final double x = (390 - natural.width) / 2;
        final double y = (844 - natural.height) / 2;
        final t = TextNode(
          id: 'text',
          name: 'text',
          basicBoxLocal: NodeBox(x, y, natural.width, natural.height),
          horizontalFit: SizeFit.shrinkWrap,
          verticalFit: SizeFit.shrinkWrap,
          edgePins: EdgePinsModel(left: x, top: y, right: x, bottom: y),
          positioningMode: PositioningMode.pin,
          data: characters,
          textMixedProps: [
            StartEndProp(start: 0, end: characters.length, fontSize: 16),
          ],
        )..parentID = 'frame';
        final root = frame('frame', NodeBox(0, 0, 390, 844), [t]);
        await pump(tester, root, const [], screen: screen, extra: [t]);
        final Rect r = tester.getRect(find.byType(TextNodeBox));
        expect(r.center.dx, closeTo(screen.width / 2, 0.01));
        // Centred between equal pins on both axes, whatever size the font
        // gives it.
        expect(r.center.dy, closeTo(screen.height / 2, 0.01));
      });
    }
  });
}
