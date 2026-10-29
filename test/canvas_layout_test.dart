import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/ui/codelessly_dialog_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// The screen sizes every layout is checked at.
const List<Size> screens = [Size(390, 844), Size(834, 1194), Size(1440, 900)];

Finder rectOf(BaseNode node) =>
    find.byKey(ValueKey('Rectangle Transformer of ${node.debugLabel}'));

/// How the host app hands its space to the layout.
enum Host {
  /// The layout is the whole screen: tight constraints.
  tight,

  /// A Scaffold body around a Center: loose constraints.
  loose,

  /// A Column: unbounded height.
  column,
}

Widget host(Host host, Widget child) => switch (host) {
  Host.tight => child,
  Host.loose => Scaffold(body: Center(child: child)),
  Host.column => Scaffold(
    body: SingleChildScrollView(child: Column(children: [child])),
  ),
};

Future<void> setScreen(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}

/// Pumps [root] (built from [nodes]) in [hostKind] on a screen of [size].
Future<void> pumpNodes(
  WidgetTester tester,
  BaseNode root,
  List<BaseNode> nodes, {
  required Size size,
  Host hostKind = Host.tight,
  Widget Function(Widget child)? wrap,
}) async {
  await setScreen(tester, size);
  final registry = NodeRegistry()
    ..setNodes({for (final node in nodes) node.id: node});
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  Widget layout = Builder(
    builder: (context) => manager.buildWidgetFromNode(
      root,
      context,
      settings: const WidgetBuildSettings(debugLabel: 'test'),
    ),
  );
  layout = wrap?.call(layout) ?? layout;
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: CodelesslyContext.empty(),
      child: MaterialApp(home: host(hostKind, layout)),
    ),
  );
  await tester.pump();
}

CanvasNode canvas({
  ScaleMode scaleMode = ScaleMode.responsive,
  double width = 390,
  double height = 844,
  bool isScrollable = false,
  SizeFit verticalFit = SizeFit.fixed,
}) => CanvasNode(
  id: 'canvas',
  name: 'canvas',
  basicBoxLocal: NodeBox(0, 0, width, height),
  children: ['body'],
  scaleMode: scaleMode,
  isScrollable: isScrollable,
  verticalFit: verticalFit,
  properties: CanvasProperties(
    bodyId: 'body',
    safeArea: const SafeAreaModel.all(false),
  ),
)..parentID = kRootNode;

AutoPlaceholderNode columnBody(List<String> children, {Size? size}) =>
    AutoPlaceholderNode(
      id: 'body',
      name: 'body',
      basicBoxLocal: NodeBox(0, 0, size?.width ?? 390, size?.height ?? 844),
      children: children,
      mainAxisAlignment: MainAxisAlignmentC.start,
      horizontalFit: SizeFit.expanded,
      verticalFit: SizeFit.expanded,
    )..parentID = 'canvas';

FreeformPlaceholderNode freeformBody(List<String> children, {Size? size}) =>
    FreeformPlaceholderNode(
      id: 'body',
      name: 'body',
      basicBoxLocal: NodeBox(0, 0, size?.width ?? 390, size?.height ?? 844),
      children: children,
      horizontalFit: SizeFit.expanded,
      verticalFit: SizeFit.expanded,
    )..parentID = 'canvas';

RectangleNode box(String id, double x, double y, double w, double h) =>
    RectangleNode(id: id, name: id, basicBoxLocal: NodeBox(x, y, w, h))
      ..parentID = 'body';

const String longText =
    'This sentence is long enough to wrap onto several lines once the box '
    'it sits in is narrow, which the editor did not measure.';

void main() {
  group('a responsive canvas fills the space it is given', () {
    for (final size in screens) {
      for (final hostKind in [Host.tight, Host.loose]) {
        testWidgets('${size.width.toInt()} ${hostKind.name}', (tester) async {
          final c = canvas();
          final body = columnBody(['a']);
          final a = box('a', 0, 0, 100, 50);
          await pumpNodes(
            tester,
            c,
            [c, body, a],
            size: size,
            hostKind: hostKind,
          );

          expect(tester.takeException(), isNull);
          expect(tester.getSize(rectOf(c)), size);
          final Rect child = tester.getRect(rectOf(a));
          expect(child.size, const Size(100, 50));
          expect((Offset.zero & size).contains(child.center), isTrue);
        });
      }
    }

    testWidgets('takes its design height where height is unbounded', (
      tester,
    ) async {
      final c = canvas();
      final body = columnBody(['a']);
      final a = box('a', 0, 0, 100, 50);
      await pumpNodes(
        tester,
        c,
        [c, body, a],
        size: const Size(1440, 900),
        hostKind: Host.column,
      );

      expect(tester.takeException(), isNull);
      expect(tester.getSize(rectOf(c)), const Size(1440, 844));
    });

    // The SDK's show-dialog action: showDialog with a CodelesslyDialogWidget
    // around the layout, which the dialog route centers in the screen.
    Future<void> showInDialog(
      WidgetTester tester,
      CanvasNode c,
      List<BaseNode> nodes,
      Size size,
    ) async {
      await setScreen(tester, size);
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
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showDialog(
                    context: context,
                    useRootNavigator: false,
                    builder: (context) => CodelesslyDialogWidget(
                      showCloseButton: false,
                      builder: (context) => manager.buildWidgetFromNode(
                        c,
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

    for (final size in screens) {
      testWidgets('a dialog with a fixed height keeps its design size at '
          '${size.width.toInt()}', (tester) async {
        final c = canvas(width: 300, height: 200);
        final body = columnBody(['a'], size: const Size(300, 200));
        final a = box('a', 0, 0, 100, 50);
        await showInDialog(tester, c, [c, body, a], size);

        expect(tester.takeException(), isNull);
        final Rect card = tester.getRect(rectOf(c));
        expect(card.size, const Size(300, 200));
        expect(card.center, size.center(Offset.zero));
      });

      testWidgets('a dialog with a shrink-wrapped height hugs its content at '
          '${size.width.toInt()}', (tester) async {
        final c = canvas(
          width: 300,
          height: 600,
          verticalFit: SizeFit.shrinkWrap,
        );
        final body = columnBody(['a', 'b'], size: const Size(300, 600));
        final a = box('a', 0, 0, 100, 50);
        final b = box('b', 0, 50, 100, 70);
        await showInDialog(tester, c, [c, body, a, b], size);

        expect(tester.takeException(), isNull);
        final Rect card = tester.getRect(rectOf(c));
        expect(card.size, const Size(300, 120));
        expect(card.center, size.center(Offset.zero));
        expect(card.contains(tester.getRect(rectOf(b)).center), isTrue);
      });
    }
  });

  group('a scrollable responsive canvas', () {
    for (final size in screens) {
      testWidgets('shares the viewport with an expanded body child at '
          '${size.width.toInt()}', (tester) async {
        final c = canvas(isScrollable: true);
        final body = columnBody(['top', 'fill']);
        final top = box('top', 0, 0, 100, 100);
        final fill = box('fill', 0, 100, 390, 744)
          ..horizontalFit = SizeFit.expanded
          ..verticalFit = SizeFit.expanded;
        await pumpNodes(tester, c, [c, body, top, fill], size: size);

        expect(tester.takeException(), isNull);
        expect(tester.getSize(rectOf(c)), size);
        expect(
          tester.getSize(rectOf(fill)),
          Size(size.width, size.height - 100),
        );
      });

      testWidgets('scrolls a freeform body at ${size.width.toInt()}', (
        tester,
      ) async {
        final c = canvas(isScrollable: true);
        final body = freeformBody(['a']);
        final a = box('a', 0, 2000, 100, 100)
          ..edgePins = EdgePinsModel.standard;
        await pumpNodes(tester, c, [c, body, a], size: size);

        expect(tester.takeException(), isNull);
        expect(tester.getSize(rectOf(a)), const Size(100, 100));
        // The body scrolls as long as its content needs.
        expect(tester.getSize(rectOf(body)).height, greaterThanOrEqualTo(2100));
        expect(find.byType(SingleChildScrollView), findsOneWidget);
      });
    }
  });

  group('an autoScale canvas', () {
    for (final size in screens) {
      for (final hostKind in Host.values) {
        testWidgets('fills the width at ${size.width.toInt()} '
            '${hostKind.name}', (tester) async {
          final c = canvas(scaleMode: ScaleMode.autoScale);
          final body = freeformBody(['a', 'bottom']);
          final a = box('a', 0, 0, 390, 100)..edgePins = EdgePinsModel.standard;
          final bottom = box('bottom', 0, 794, 390, 50)
            ..edgePins = EdgePinsModel.standard;
          await pumpNodes(
            tester,
            c,
            [c, body, a, bottom],
            size: size,
            hostKind: hostKind,
          );

          expect(tester.takeException(), isNull);
          expect(tester.getSize(rectOf(c)).width, size.width);
          // Painted width is the design width scaled to the screen.
          final RenderBox aBox = tester.renderObject(rectOf(a));
          final Rect painted = MatrixUtils.transformRect(
            aBox.getTransformTo(null),
            Offset.zero & aBox.size,
          );
          expect(painted.width, moreOrLessEquals(size.width));
          expect(painted.left, moreOrLessEquals(0));
        });
      }
    }

    testWidgets('scrolls when scaled taller than the screen', (tester) async {
      final c = canvas(scaleMode: ScaleMode.autoScale);
      final body = freeformBody(['bottom']);
      final bottom = box('bottom', 0, 794, 390, 50)
        ..edgePins = EdgePinsModel.standard;
      await pumpNodes(tester, c, [
        c,
        body,
        bottom,
      ], size: const Size(1440, 900));

      expect(tester.takeException(), isNull);
      // 844 scaled by 1440 / 390 is about 3116: below the 900 high screen.
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -5000),
      );
      await tester.pumpAndSettle();
      final RenderBox bottomBox = tester.renderObject(rectOf(bottom));
      final Rect painted = MatrixUtils.transformRect(
        bottomBox.getTransformTo(null),
        Offset.zero & bottomBox.size,
      );
      expect(painted.bottom, moreOrLessEquals(900, epsilon: 1));
    });

    testWidgets('does not scroll while it fits', (tester) async {
      final c = canvas(scaleMode: ScaleMode.autoScale);
      final body = freeformBody([]);
      await pumpNodes(tester, c, [c, body], size: const Size(390, 844));

      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsNothing);
    });
  });

  group('breakpoints follow the width the layout gets', () {
    testWidgets('bounded width wins over the screen width', (tester) async {
      await setScreen(tester, const Size(1440, 900));
      late double inFrame;
      late double unbounded;
      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              SizedBox(
                width: 390,
                height: 10,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    inFrame = CodelesslyWidget.breakpointWidth(
                      context,
                      constraints,
                    );
                    return const SizedBox();
                  },
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    unbounded = CodelesslyWidget.breakpointWidth(
                      context,
                      constraints,
                    );
                    return const SizedBox(width: 10, height: 10);
                  },
                ),
              ),
            ],
          ),
        ),
      );
      expect(inFrame, 390);
      expect(unbounded, 1440);
    });

    test('canvas for a width', () {
      final layout = SDKPublishLayout(
        id: 'layout',
        pageId: 'page',
        projectId: 'project',
        canvases: {'phone': {}, 'tablet': {}, 'desktop': {}},
        lastUpdated: DateTime(2026),
        owner: 'owner',
        teams: const {},
        users: const {},
        roles: const {},
        public: false,
        breakpoints: const [
          Breakpoint(nodeId: 'phone', upperBound: 599),
          Breakpoint(nodeId: 'tablet', lowerBound: 600, upperBound: 1199),
          Breakpoint(nodeId: 'desktop', lowerBound: 1200),
        ],
      );
      final model = SDKPublishModel(
        projectId: 'project',
        owner: 'owner',
        teams: const {},
        users: const {},
        roles: const {},
        public: false,
        layouts: LookupMap((lookupMap: {}, dataMap: {'layout': layout})),
      );
      String? at(double width) =>
          CodelesslyWidget.canvasIDForWidth('layout', model, width);
      expect(at(390), 'phone');
      expect(at(834), 'tablet');
      expect(at(1440), 'desktop');
      expect(CodelesslyWidget.canvasIDForWidth('none', model, 390), isNull);
    });
  });

  group('text', () {
    TextNode text({
      required double width,
      required double height,
      SizeFit horizontalFit = SizeFit.fixed,
      SizeFit verticalFit = SizeFit.fixed,
      String characters = longText,
      TextAlignHorizontalEnum h = TextAlignHorizontalEnum.left,
      TextAlignVerticalEnum v = TextAlignVerticalEnum.top,
      EdgePinsModel edgePins = EdgePinsModel.standard,
    }) => TextNode(
      id: 'text',
      name: 'text',
      basicBoxLocal: NodeBox(0, 0, width, height),
      horizontalFit: horizontalFit,
      verticalFit: verticalFit,
      edgePins: edgePins,
      data: characters,
      textMixedProps: [
        StartEndProp(start: 0, end: characters.length, fontSize: 16),
      ],
      textAlignHorizontal: h,
      textAlignVertical: v,
    )..parentID = 'body';

    Rect paragraphRect(WidgetTester tester) =>
        tester.getRect(find.byType(RichText).first);

    for (final size in screens) {
      testWidgets('a fixed height grows to fit reflowed lines at '
          '${size.width.toInt()}', (tester) async {
        final c = canvas(isScrollable: true);
        final body = columnBody(['text']);
        // Measured as one 20 px line by the editor; at 120 wide it wraps.
        final t = text(width: 120, height: 20);
        await pumpNodes(tester, c, [c, body, t], size: size);

        expect(tester.takeException(), isNull);
        final Size textBox = tester.getSize(find.byType(TextNodeBox));
        expect(textBox.width, 120);
        expect(textBox.height, greaterThan(20));
        // Every line is inside the box: nothing is clipped.
        expect(paragraphRect(tester).height, lessThanOrEqualTo(textBox.height));
      });
    }

    testWidgets('its minimum intrinsic height is its text alone', (
      tester,
    ) async {
      final c = canvas();
      final body = columnBody(['text']);
      final t = text(width: 200, height: 60, characters: 'Hi');
      await pumpNodes(tester, c, [c, body, t], size: const Size(390, 844));

      final RenderBox minHeight = tester.renderObject(
        find.byType(TextMinHeight),
      );
      final RenderBox paragraph = tester.renderObject(
        find.byType(RichText).first,
      );
      expect(minHeight.size.height, 60);
      expect(
        minHeight.getMinIntrinsicHeight(200),
        paragraph.getMinIntrinsicHeight(200),
      );
      expect(minHeight.getMaxIntrinsicHeight(200), 60);
    });

    testWidgets('a fixed height stays the minimum for short text', (
      tester,
    ) async {
      final c = canvas();
      final body = columnBody(['text']);
      final t = text(width: 200, height: 60, characters: 'Hi');
      await pumpNodes(tester, c, [c, body, t], size: const Size(390, 844));

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(TextNodeBox)), const Size(200, 60));
    });

    for (final size in screens) {
      testWidgets('pinned on all edges and centered sits in the middle at '
          '${size.width.toInt()}', (tester) async {
        final c = canvas();
        final body = freeformBody(['text']);
        final t = text(
          width: 390,
          height: 844,
          characters: 'Centered',
          h: TextAlignHorizontalEnum.center,
          v: TextAlignVerticalEnum.center,
          edgePins: const EdgePinsModel(left: 0, top: 0, right: 0, bottom: 0),
        );
        await pumpNodes(tester, c, [c, body, t], size: size);

        expect(tester.takeException(), isNull);
        final Rect line = paragraphRect(tester);
        expect(line.center.dx, moreOrLessEquals(size.width / 2, epsilon: 1));
        expect(line.center.dy, moreOrLessEquals(size.height / 2, epsilon: 1));
      });
    }

    testWidgets('a fixed box aligns its text at the bottom right', (
      tester,
    ) async {
      final c = canvas();
      final body = freeformBody(['text']);
      final t = text(
        width: 300,
        height: 200,
        characters: 'End',
        h: TextAlignHorizontalEnum.right,
        v: TextAlignVerticalEnum.bottom,
      );
      await pumpNodes(tester, c, [c, body, t], size: const Size(390, 844));

      expect(tester.takeException(), isNull);
      final Rect boxRect = tester.getRect(find.byType(TextNodeBox));
      final Rect line = paragraphRect(tester);
      expect(line.right, moreOrLessEquals(boxRect.right, epsilon: 1));
      expect(line.bottom, moreOrLessEquals(boxRect.bottom, epsilon: 1));
    });
  });

  group('scroll content grows to its laid-out children', () {
    Future<Size> stackSize(
      WidgetTester tester, {
      required double minExtent,
      required List<Widget> children,
      Axis axis = Axis.vertical,
    }) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SingleChildScrollView(
            scrollDirection: axis,
            child: ScrollContentStack(
              key: const ValueKey('content'),
              axis: axis,
              minExtent: minExtent,
              children: children,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      return tester.getSize(find.byKey(const ValueKey('content')));
    }

    testWidgets('keeps the design extent when children fit', (tester) async {
      final size = await stackSize(
        tester,
        minExtent: 900,
        children: const [
          Positioned(top: 10, left: 0, child: SizedBox(width: 10, height: 10)),
        ],
      );
      expect(size.height, 900);
    });

    testWidgets('grows past it when a child ends farther', (tester) async {
      final size = await stackSize(
        tester,
        minExtent: 300,
        children: const [
          Positioned(
            top: 250,
            left: 0,
            child: SizedBox(width: 10, height: 200),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            child: SizedBox(width: 10, height: 10),
          ),
        ],
      );
      expect(size.height, 450);
      // A bottom-pinned child follows the grown end.
      expect(
        tester.getRect(find.byType(SizedBox).last).bottom,
        moreOrLessEquals(450),
      );
    });

    testWidgets('a child that sizes itself sets the length', (tester) async {
      final size = await stackSize(
        tester,
        minExtent: 300,
        children: const [SizedBox(width: 10, height: 700)],
      );
      expect(size.height, 700);
    });

    testWidgets('grows horizontally too', (tester) async {
      final size = await stackSize(
        tester,
        axis: Axis.horizontal,
        minExtent: 300,
        children: const [
          Positioned(
            top: 0,
            left: 280,
            child: SizedBox(width: 100, height: 10),
          ),
        ],
      );
      expect(size.width, 380);
    });
  });
}
