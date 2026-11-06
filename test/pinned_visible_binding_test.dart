import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// A status dot pinned to the top right of a 44×26 chip, shown by a
// `visible` binding, with the transition every palette-bound fill of the
// app has: it shows exactly where the same dot without a binding shows, at
// runtime and where tickers are muted (the design canvas, its captures).

RectangleNode dot({
  Map<String, String> variables = const {},
  int transitionMs = 0,
  double size = 8,
}) =>
    RectangleNode(
        id: 'dot',
        name: 'Dot',
        basicBoxLocal: NodeBox(36 - size, 0, size, size),
        positioningMode: PositioningMode.pin,
        edgePins: const EdgePinsModel(
          left: null,
          right: 8,
          top: 0,
          bottom: null,
        ),
        fills: [PaintModel.solid(id: 'f', color: ColorRGB.fromHex('#FF0000'))],
      )
      ..parentID = 'chip'
      ..variables.addAll(variables)
      ..transitionMs = transitionMs;

FrameNode chip() => FrameNode(
  id: 'chip',
  name: 'Chip',
  basicBoxLocal: NodeBox(0, 0, 44, 26),
  children: ['dot'],
  fills: [PaintModel.solid(id: 'c', color: ColorRGB.fromHex('#FFFFFF'))],
)..parentID = kRootNode;

Observable<VariableData> flag(bool value) => Observable(
  VariableData(id: 'on', name: 'on', type: VariableType.boolean, value: value),
);

Future<void> pump(
  WidgetTester tester,
  RectangleNode child, {
  bool ticking = true,
  CodelesslyContext? context,
}) async {
  final FrameNode root = chip();
  final registry = NodeRegistry()..setNodes({root.id: root, child.id: child});
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  await tester.pumpWidget(
    TickerMode(
      enabled: ticking,
      child: ChangeNotifierProvider<CodelesslyContext>.value(
        value: context ?? CodelesslyContext.empty(),
        child: MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: Builder(
              builder: (context) => manager.buildWidgetFromNode(
                root,
                context,
                settings: const WidgetBuildSettings(debugLabel: 'test'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The dot's painted box, or null when nothing of it shows: not built,
/// sized to nothing, or faded out entirely.
Rect? shownDot(WidgetTester tester) {
  final Finder dot = find.byKey(
    const ValueKey('Rectangle Transformer of Dot [dot]'),
  );
  if (dot.evaluate().isEmpty) return null;
  final Rect rect = tester.getRect(dot);
  if (rect.isEmpty) return null;
  for (final Widget w in tester.widgetList(
    find.ancestor(of: dot, matching: find.byWidgetPredicate((_) => true)),
  )) {
    if (w is Opacity && w.opacity == 0) return null;
    if (w is FadeTransition && w.opacity.value == 0) return null;
    if (w is Visibility && !w.visible) return null;
  }
  return rect;
}

const Rect pinned = Rect.fromLTWH(28, 0, 8, 8);

void main() {
  for (final bool ticking in const [true, false]) {
    final String where = ticking ? 'at runtime' : 'under muted tickers';
    for (final (String label, Map<String, String> variables, int ms) in [
      ('no binding', const <String, String>{}, 0),
      ('a formula', const {'visible': r'${= true}'}, 0),
      ('a formula and a transition', const {'visible': r'${= true}'}, 900),
    ]) {
      testWidgets('$where a pinned child with $label shows at its pins', (
        tester,
      ) async {
        await pump(
          tester,
          dot(variables: variables, transitionMs: ms),
          ticking: ticking,
        );
        await tester.pumpAndSettle();
        expect(shownDot(tester), pinned);
      });
    }

    testWidgets('$where a pinned child a binding shows again shows at its '
        'pins', (tester) async {
      final Observable<VariableData> on = flag(false);
      final context = CodelesslyContext.empty()..variables['on'] = on;
      final RectangleNode node = dot(
        variables: {'visible': r'${on}'},
        transitionMs: 900,
      );
      await pump(tester, node, ticking: ticking, context: context);
      await tester.pumpAndSettle();
      expect(shownDot(tester), isNull);
      on.value = on.value.copyWith(value: true);
      await tester.pumpAndSettle();
      expect(shownDot(tester), pinned);
    });

    // The canvas keeps a node's widget as the layout solver resizes it (an
    // inserted node gets its box after its first build).
    testWidgets('$where a pinned child with a visible formula that is '
        'resized shows at its new size', (tester) async {
      await pump(
        tester,
        dot(variables: {'visible': r'${= true}'}, transitionMs: 900, size: 2),
        ticking: ticking,
      );
      await tester.pumpAndSettle();
      await pump(
        tester,
        dot(variables: {'visible': r'${= true}'}, transitionMs: 900),
        ticking: ticking,
      );
      await tester.pumpAndSettle();
      expect(shownDot(tester), pinned);
    });
  }
}
