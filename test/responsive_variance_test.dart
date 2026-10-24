import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/ui/codelessly_dialog_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const List<Size> screens = [Size(390, 844), Size(834, 1194), Size(1440, 900)];

Finder rectOf(BaseNode node) =>
    find.byKey(ValueKey('Rectangle Transformer of ${node.debugLabel}'));

/// The variants' nodes (roots and their rectangles) that were built.
Set<String> builtRectangles(Map<String, BaseNode> nodes) => {
  for (final node in nodes.values)
    if (ScreenBreakpoint.values.any((b) => node.id.startsWith('${b.name}-')) &&
        rectOf(node).evaluate().isNotEmpty)
      node.id,
};

/// A responsive layout: canvas > body column > variance with a column per
/// breakpoint. Each variant's column holds [counts] rectangles, so the built
/// widgets tell which variant was built.
Map<String, BaseNode> responsivePage({
  double canvasWidth = 390,
  Map<ScreenBreakpoint, int> counts = const {
    ScreenBreakpoint.mobile: 2,
    ScreenBreakpoint.tablet: 3,
    ScreenBreakpoint.desktop: 4,
  },
  ScaleMode scaleMode = ScaleMode.responsive,
}) {
  final nodes = <String, BaseNode>{};
  void add(BaseNode node) => nodes[node.id] = node;

  add(
    CanvasNode(
      id: 'canvas',
      name: 'canvas',
      basicBoxLocal: NodeBox(0, 0, canvasWidth, 844),
      children: ['body'],
      scaleMode: scaleMode,
      properties: CanvasProperties(
        bodyId: 'body',
        safeArea: const SafeAreaModel.all(false),
      ),
    )..parentID = kRootNode,
  );
  add(
    AutoPlaceholderNode(
      id: 'body',
      name: 'body',
      basicBoxLocal: NodeBox(0, 0, canvasWidth, 844),
      children: ['layout'],
      mainAxisAlignment: MainAxisAlignmentC.start,
      horizontalFit: SizeFit.expanded,
      verticalFit: SizeFit.expanded,
    )..parentID = 'canvas',
  );
  final variants = <Variant>[];
  for (final MapEntry(key: breakpoint, value: count) in counts.entries) {
    final String root = '${breakpoint.name}-root';
    variants.add(
      Variant(
        id: breakpoint.name,
        name: breakpoint.label,
        children: [root],
        breakpoint: breakpoint,
      ),
    );
    add(
      RowColumnNode(
        id: root,
        name: root,
        basicBoxLocal: NodeBox(0, 0, canvasWidth, 844),
        rowColumnType: RowColumnType.column,
        mainAxisAlignment: MainAxisAlignmentC.start,
        crossAxisAlignment: CrossAxisAlignmentC.stretch,
        horizontalFit: SizeFit.expanded,
        verticalFit: SizeFit.expanded,
        alignment: AlignmentModel.center,
        children: [for (int i = 0; i < count; i++) '${breakpoint.name}-$i'],
      )..parentID = 'layout',
    );
    for (int i = 0; i < count; i++) {
      add(
        RectangleNode(
          id: '${breakpoint.name}-$i',
          name: '${breakpoint.name}-$i',
          basicBoxLocal: NodeBox(0, i * 60.0, 100, 50),
          horizontalFit: SizeFit.expanded,
        )..parentID = root,
      );
    }
  }
  add(
    VarianceNode(
      id: 'layout',
      name: 'Responsive layout',
      basicBoxLocal: NodeBox(0, 0, canvasWidth, 844),
      horizontalFit: SizeFit.expanded,
      verticalFit: SizeFit.expanded,
      // The editor last showed mobile; the runtime must not care.
      currentVariantId: variants.first.id,
      variants: variants,
    )..parentID = 'body',
  );
  return nodes;
}

Future<void> pumpPage(
  WidgetTester tester,
  Map<String, BaseNode> nodes, {
  required Size screen,
  String rootId = 'canvas',
  Widget Function(Widget child)? wrap,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = screen;
  addTearDown(tester.view.reset);
  final registry = NodeRegistry()..setNodes(nodes);
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  Widget layout = Builder(
    builder: (context) => manager.buildWidgetFromNode(
      nodes[rootId]!,
      context,
      settings: const WidgetBuildSettings(debugLabel: 'test'),
    ),
  );
  layout = wrap?.call(layout) ?? layout;
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: CodelesslyContext.empty(),
      child: MaterialApp(home: layout),
    ),
  );
  await tester.pump();
}

/// Shows [nodes]' canvas the way the SDK's show-dialog action does: a
/// [CodelesslyDialogWidget] in a dismissible dialog, on a screen of [screen].
Future<void> showPageInDialog(
  WidgetTester tester,
  Map<String, BaseNode> nodes, {
  required Size screen,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = screen;
  addTearDown(tester.view.reset);
  final registry = NodeRegistry()..setNodes(nodes);
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  // A fresh app, without a dialog left open by an earlier call.
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: CodelesslyContext.empty(),
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog(
                context: context,
                useRootNavigator: false,
                builder: (context) => CodelesslyDialogWidget(
                  showCloseButton: false,
                  builder: (context) => manager.buildWidgetFromNode(
                    nodes['canvas']!,
                    context,
                    settings: const WidgetBuildSettings(debugLabel: 'test'),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// [responsivePage] as a sheet: full screen on mobile, a centered 560 wide
/// card on tablet and desktop.
Map<String, BaseNode> responsiveSheet() {
  final nodes = responsivePage();
  // No background: the barrier shows around the card.
  (nodes['canvas']! as CanvasNode).fills = [];
  for (final breakpoint in [
    ScreenBreakpoint.tablet,
    ScreenBreakpoint.desktop,
  ]) {
    final root = nodes['${breakpoint.name}-root']! as RowColumnNode;
    nodes[root.id] = RowColumnNode(
      id: root.id,
      name: root.name,
      basicBoxLocal: NodeBox(0, 0, 560, 400),
      rowColumnType: RowColumnType.column,
      mainAxisAlignment: MainAxisAlignmentC.start,
      crossAxisAlignment: CrossAxisAlignmentC.stretch,
      alignment: AlignmentModel.center,
      fills: [PaintModel.whitePaint],
      children: root.children,
    )..parentID = root.parentID;
  }
  return nodes;
}

/// A variant's root and its rectangles.
Set<String> idsOf(ScreenBreakpoint breakpoint, int count) => {
  '${breakpoint.name}-root',
  for (int i = 0; i < count; i++) '${breakpoint.name}-$i',
};

void main() {
  test('the screen variable and responsive variances share one rule', () {
    for (final double width in [0, 390, 599, 600, 834, 1023, 1024, 1440]) {
      expect(
        screenVariableValue(Size(width, 800))['breakpoint'],
        ScreenBreakpoint.forWidth(width).name,
      );
    }
    expect(kTabletMinWidth, ScreenBreakpoint.tablet.minWidth);
    expect(kDesktopMinWidth, ScreenBreakpoint.desktop.minWidth);
  });

  group('a responsive variance builds only the variant for the width', () {
    final expected = {
      390.0: (ScreenBreakpoint.mobile, 2),
      834.0: (ScreenBreakpoint.tablet, 3),
      1440.0: (ScreenBreakpoint.desktop, 4),
    };
    for (final screen in screens) {
      testWidgets('${screen.width.toInt()}', (tester) async {
        final nodes = responsivePage();
        await pumpPage(tester, nodes, screen: screen);

        expect(tester.takeException(), isNull);
        final (breakpoint, count) = expected[screen.width]!;
        expect(builtRectangles(nodes), idsOf(breakpoint, count));
        // The other variants' roots are not in the tree at all.
        for (final other in ScreenBreakpoint.values) {
          if (other == breakpoint) continue;
          expect(
            find.byKey(
              ValueKey(
                'Rectangle Transformer of '
                '${nodes['${other.name}-root']!.debugLabel}',
              ),
            ),
            findsNothing,
          );
        }
        for (int i = 0; i < count; i++) {
          final String id = '${breakpoint.name}-$i';
          final Rect rect = tester.getRect(rectOf(nodes[id]!));
          expect(rect.width, screen.width);
          expect(rect.height, 50);
          expect(rect.left, 0);
          expect(rect.bottom, lessThanOrEqualTo(screen.height));
        }
      });
    }
  });

  testWidgets('switches variant when the width crosses a breakpoint', (
    tester,
  ) async {
    final nodes = responsivePage();
    await pumpPage(tester, nodes, screen: const Size(390, 844));
    expect(builtRectangles(nodes), idsOf(ScreenBreakpoint.mobile, 2));

    tester.view.physicalSize = const Size(1440, 900);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(builtRectangles(nodes), idsOf(ScreenBreakpoint.desktop, 4));

    tester.view.physicalSize = const Size(834, 1194);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(builtRectangles(nodes), idsOf(ScreenBreakpoint.tablet, 3));
  });

  testWidgets('follows the canvas width, not the screen width', (tester) async {
    final nodes = responsivePage();
    // A 390 wide frame inside a 1440 window.
    await pumpPage(
      tester,
      nodes,
      screen: const Size(1440, 900),
      wrap: (child) => Center(child: SizedBox(width: 390, child: child)),
    );
    expect(tester.takeException(), isNull);
    expect(builtRectangles(nodes), idsOf(ScreenBreakpoint.mobile, 2));
  });

  testWidgets('an autoScale canvas picks by its design width', (tester) async {
    final nodes = responsivePage(
      canvasWidth: 1440,
      scaleMode: ScaleMode.autoScale,
    );
    await pumpPage(tester, nodes, screen: const Size(390, 844));
    expect(tester.takeException(), isNull);
    expect(builtRectangles(nodes), idsOf(ScreenBreakpoint.desktop, 4));
  });

  group('a missing breakpoint falls back to the nearest variant', () {
    for (final screen in screens) {
      testWidgets('${screen.width.toInt()}', (tester) async {
        final nodes = responsivePage(
          counts: const {
            ScreenBreakpoint.mobile: 2,
            ScreenBreakpoint.desktop: 4,
          },
        );
        await pumpPage(tester, nodes, screen: screen);
        expect(tester.takeException(), isNull);
        final shown = screen.width >= 1024
            ? idsOf(ScreenBreakpoint.desktop, 4)
            : idsOf(ScreenBreakpoint.mobile, 2);
        expect(builtRectangles(nodes), shown);
      });
    }
  });

  testWidgets('outside a canvas it uses the width it is given', (tester) async {
    final nodes = responsivePage();
    nodes['layout']!.parentID = kRootNode;
    await pumpPage(
      tester,
      nodes,
      rootId: 'layout',
      screen: const Size(1440, 900),
      wrap: (child) => Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 834, height: 900, child: child),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(builtRectangles(nodes), idsOf(ScreenBreakpoint.tablet, 3));
  });

  testWidgets('an ordinary variance still shows its current variant', (
    tester,
  ) async {
    final nodes = responsivePage();
    final layout = nodes['layout']! as VarianceNode;
    for (final variant in layout.variants) {
      variant.breakpoint = null;
    }
    layout.currentVariantId = 'tablet';
    await pumpPage(tester, nodes, screen: const Size(390, 844));
    expect(tester.takeException(), isNull);
    expect(builtRectangles(nodes), idsOf(ScreenBreakpoint.tablet, 3));
  });

  testWidgets('a dialog with a responsive layout follows the screen', (
    tester,
  ) async {
    for (final screen in screens) {
      final nodes = responsiveSheet();
      await showPageInDialog(tester, nodes, screen: screen);

      expect(tester.takeException(), isNull);
      final ScreenBreakpoint breakpoint = ScreenBreakpoint.forWidth(
        screen.width,
      );
      final int count = switch (breakpoint) {
        ScreenBreakpoint.mobile => 2,
        ScreenBreakpoint.tablet => 3,
        ScreenBreakpoint.desktop => 4,
      };
      expect(builtRectangles(nodes), idsOf(breakpoint, count));
      // The canvas fills the screen; each variant places itself in it: the
      // mobile sheet fills it, the card is centered.
      expect(tester.getSize(rectOf(nodes['canvas']!)), screen);
      final Rect root = tester.getRect(
        rectOf(nodes['${breakpoint.name}-root']!),
      );
      if (breakpoint == ScreenBreakpoint.mobile) {
        expect(root, Offset.zero & screen);
      } else {
        expect(root.size, const Size(560, 400));
        expect(root.center, screen.center(Offset.zero));
      }
    }
  });

  testWidgets('a dialog with a responsive layout closes on a barrier tap', (
    tester,
  ) async {
    final nodes = responsiveSheet();
    await showPageInDialog(tester, nodes, screen: const Size(1440, 900));
    expect(builtRectangles(nodes), idsOf(ScreenBreakpoint.desktop, 4));

    // Inside the card, below its rectangles, the dialog stays open.
    await tester.tapAt(const Offset(720, 600));
    await tester.pumpAndSettle();
    expect(builtRectangles(nodes), idsOf(ScreenBreakpoint.desktop, 4));

    // Outside of it, the empty canvas lets the tap through to the barrier.
    await tester.tapAt(const Offset(100, 100));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(builtRectangles(nodes), isEmpty);
  });
}
