import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A scanner viewfinder's top-left corner bracket: an L of two strokes
/// with a rounded corner and round ends, as hand-written node JSON.
RectangleNode _bracket({Map<String, String> variables = const {}}) =>
    RectangleNode.fromJson({
      'id': 'bracket',
      'name': 'bracket',
      'type': 'rectangle',
      'basicBoxLocal': [0, 0, 30, 30],
      'path': 'M2 30 V10 Q2 2 10 2 H30',
      'fills': <Object>[],
      'strokes': [
        {'id': 's1', 'type': 'solid', 'color': '#FFFFFF'},
      ],
      'strokeWeight': 4,
      'strokeCap': 'round',
      'strokeJoin': 'round',
      'variables': variables,
    })..parentID = kRootNode;

Future<void> _pump(
  WidgetTester tester,
  BaseNode node, {
  CodelesslyContext? codelesslyContext,
}) async {
  final registry = NodeRegistry()..setNodes({node.id: node});
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: codelesslyContext ?? CodelesslyContext.empty(),
      child: MaterialApp(
        home: Center(
          child: Builder(
            builder: (context) => manager.buildWidgetFromNode(
              node,
              context,
              settings: const WidgetBuildSettings(debugLabel: 'test'),
            ),
          ),
        ),
      ),
    ),
  );
  expect(tester.takeException(), isNull);
}

SvgPathStrokePainter _painter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((paint) => paint.painter)
    .whereType<SvgPathStrokePainter>()
    .single;

void main() {
  group('parseSvgPath', () {
    test('reads an open corner bracket', () {
      final Path path = parseSvgPath('M0 30 V8 Q0 0 8 0 H30')!;
      expect(path.getBounds(), const Rect.fromLTRB(0, 0, 30, 30));
      // Open: the far corner is not inside a closed shape.
      expect(path.computeMetrics().single.isClosed, isFalse);
    });

    test('reads relative commands, implicit linetos and close', () {
      final Path path = parseSvgPath('m10 10 20 0 0 20z')!;
      expect(path.getBounds(), const Rect.fromLTRB(10, 10, 30, 30));
      expect(path.computeMetrics().single.isClosed, isTrue);
    });

    test('reads compact numbers, curves and arcs', () {
      expect(
        parseSvgPath('M0,0L10-5l.5.5')!.getBounds(),
        const Rect.fromLTRB(0, -5, 10.5, 0),
      );
      final Rect arc = parseSvgPath('M0 10 A10 10 0 0 1 20 10')!.getBounds();
      expect(arc.left, moreOrLessEquals(0));
      expect(arc.right, moreOrLessEquals(20));
      expect(arc.top, moreOrLessEquals(0, epsilon: 0.01));
      final Rect curve = parseSvgPath(
        'M0 0 C0 10 10 10 10 0 S20 -10 20 0 T30 0',
      )!.getBounds();
      expect(curve.right, moreOrLessEquals(30));
    });

    test('returns null for empty or invalid data', () {
      expect(parseSvgPath(null), isNull);
      expect(parseSvgPath('  '), isNull);
      expect(parseSvgPath('M0 0 X 4'), isNull);
      expect(parseSvgPath('M0 0 Z 4'), isNull);
      expect(parseSvgPath('10 10'), isNull);
    });
  });

  test('path and strokeJoin round-trip through JSON', () {
    final RectangleNode node = _bracket();
    expect(node.hasPath, isTrue);
    expect(node.strokeJoin, StrokeJoinEnum.round);
    final Map json = node.toJson();
    expect(json['path'], 'M2 30 V10 Q2 2 10 2 H30');
    expect(json['strokeJoin'], 'round');
    final RectangleNode copy = RectangleNode.fromJson(json);
    expect(copy.path, node.path);
    expect(copy.strokeJoin, StrokeJoinEnum.round);

    final Map plain = RectangleNode(
      id: 'r',
      name: 'r',
      basicBoxLocal: NodeBox(0, 0, 10, 10),
    ).toJson();
    expect(plain.containsKey('path'), isFalse);
    expect(plain.containsKey('strokeJoin'), isFalse);
  });

  testWidgets('a rectangle with a path strokes the path, round and '
      'unclipped', (tester) async {
    await _pump(tester, _bracket());
    final SvgPathStrokePainter painter = _painter(tester);
    expect(painter.path.getBounds(), const Rect.fromLTRB(2, 2, 30, 30));
    expect(painter.color, const Color(0xFFFFFFFF));
    expect(painter.strokeWidth, 4);
    expect(painter.strokeCap, StrokeCapEnum.round);
    expect(painter.strokeJoin, StrokeJoinEnum.round);
    // No box border is drawn, and nothing clips the round ends at the box.
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).border != null,
      ),
      findsNothing,
    );
    final RenderObject box = tester.renderObject(
      find.byKey(const ValueKey('Rectangle Transformer of bracket [bracket]')),
    );
    void noClips(RenderObject o) {
      expect(
        o is RenderClipRect || o is RenderClipRRect || o is RenderClipPath,
        isFalse,
        reason: '$o clips the path',
      );
      o.visitChildren(noClips);
    }

    noClips(box);
    expect(
      tester.getSize(
        find.byKey(
          const ValueKey('Rectangle Transformer of bracket [bracket]'),
        ),
      ),
      const Size(30, 30),
    );
  });

  testWidgets('a path stroke colour follows its binding', (tester) async {
    final CodelesslyContext codelesslyContext = CodelesslyContext.empty()
      ..variables['scanColor'] = Observable(
        VariableData(
          id: 'scanColor',
          name: 'scanColor',
          type: VariableType.color,
          value: '#FF3366',
        ),
      );
    await _pump(
      tester,
      _bracket(variables: {'stroke-paint-s1': r'${scanColor}'}),
      codelesslyContext: codelesslyContext,
    );
    expect(_painter(tester).color, const Color(0xFFFF3366));
  });

  testWidgets('a path fill is clipped to the path', (tester) async {
    final RectangleNode node = RectangleNode.fromJson({
      ..._bracket().toJson(),
      'path': 'M0 0 H30 V30 Z',
      'fills': [
        {'id': 'f1', 'type': 'solid', 'color': '#00FF00'},
      ],
      'strokes': <Object>[],
    })..parentID = kRootNode;
    await _pump(tester, node);
    final ClipPath clip = tester.widget<ClipPath>(find.byType(ClipPath));
    expect(clip.clipper, isA<SvgPathClipper>());
    expect(
      (clip.clipper! as SvgPathClipper).getClip(const Size(30, 30)).getBounds(),
      const Rect.fromLTRB(0, 0, 30, 30),
    );
  });
}
