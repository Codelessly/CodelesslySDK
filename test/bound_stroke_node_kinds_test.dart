import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A bound `stroke` colour (and `strokeWeight`) applies to every kind of
/// node that draws a stroke: a plain rectangle, a rectangle stroking its
/// `path`, a row and a column with a one-side stroke (`strokeSide`), a
/// frame and a path node. The hex pill of the Apiary generator (ap.py
/// `hex_pill` / `hex_chip(error=...)`) is built of exactly these parts:
/// caps 'L' and 'R' (rectangles with a path), 'Mid' (a column with a top
/// stroke) and 'Inner' (a row with a bottom stroke), each bound with
/// `variables.stroke`.

const String danger = '#B23A2B';
const String waxEdge = '#E3CFA3';
const String strokeFormula =
    "\${= ((showErrors ? errSigns : '') != '') "
    "? '$danger' : '$waxEdge'}";
const String weightFormula = r'${= showErrors ? 2 : 1}';

Map paint(String id, String hex) =>
    PaintModel.solid(id: id, color: ColorRGB.fromHex(hex)).toJson();

Map<String, dynamic> bound(Map<String, dynamic> json) => {
  ...json,
  'strokes': [paint('${json['id']}-stroke', waxEdge)],
  'strokeWeight': 1,
  'variables': {'stroke': strokeFormula, 'strokeWeight': weightFormula},
};

/// The hex pill of ap.py, plus a path node, a plain rectangle and a frame
/// stroked on every side, all under a freeform frame.
Map<String, BaseNode> nodeTree() {
  final Map<String, Map<String, dynamic>> json = {
    'root': {
      'type': 'frame',
      'id': 'root',
      'name': 'Root',
      'basicBoxLocal': {'x': 0, 'y': 0, 'width': 400, 'height': 200},
      'children': ['pill', 'path', 'box', 'frame'],
    },
    'pill': {
      'type': 'frame',
      'id': 'pill',
      'name': 'Chip face',
      'basicBoxLocal': {'x': 0, 'y': 0, 'width': 130, 'height': 36},
      'children': ['Mid', 'L', 'R'],
      'interactionStates': {
        'hovered': {
          'L': {
            'fills': [paint('hover', '#FFF3D6')],
          },
        },
      },
    },
    'Mid': bound({
      'type': 'column',
      'id': 'Mid',
      'name': 'Mid',
      'rowColumnType': 'column',
      'basicBoxLocal': {'x': 14, 'y': 0, 'width': 102, 'height': 36},
      'fills': [paint('mid-fill', '#FFF8E7')],
      'strokeSide': 'top',
      'strokeAlign': 'inside',
      'children': ['Inner'],
    }),
    'Inner': bound({
      'type': 'row',
      'id': 'Inner',
      'name': 'Inner',
      'rowColumnType': 'row',
      'basicBoxLocal': {'x': 0, 'y': 0, 'width': 102, 'height': 36},
      'strokeSide': 'bottom',
      'strokeAlign': 'inside',
      'children': [],
    }),
    'L': bound({
      'type': 'rectangle',
      'id': 'L',
      'name': 'L',
      'basicBoxLocal': {'x': 0, 'y': 0, 'width': 15, 'height': 36},
      'path':
          'M15 0.5 L12.8 0.5 Q10.6 0.5 8.6 4 L2.5 14.5 Q0.5 18 2.5 21.5 '
          'L8.6 32 Q10.6 35.5 12.8 35.5 L15 35.5',
      'fills': [paint('l-fill', '#FFF8E7')],
      'strokeJoin': 'round',
    }),
    'R': bound({
      'type': 'rectangle',
      'id': 'R',
      'name': 'R',
      'basicBoxLocal': {'x': 115, 'y': 0, 'width': 15, 'height': 36},
      'path':
          'M0 0.5 L2.2 0.5 Q4.4 0.5 6.4 4 L12.5 14.5 Q14.5 18 12.5 21.5 '
          'L6.4 32 Q4.4 35.5 2.2 35.5 L0 35.5',
      'fills': [paint('r-fill', '#FFF8E7')],
      'strokeJoin': 'round',
    }),
    'path': bound({
      'type': 'path',
      'id': 'path',
      'name': 'Line',
      'basicBoxLocal': {'x': 0, 'y': 60, 'width': 100, 'height': 20},
      'pathData': 'M0 10 L100 10',
    }),
    'box': bound({
      'type': 'rectangle',
      'id': 'box',
      'name': 'Box',
      'basicBoxLocal': {'x': 0, 'y': 100, 'width': 80, 'height': 30},
    }),
    'frame': bound({
      'type': 'frame',
      'id': 'frame',
      'name': 'Frame',
      'basicBoxLocal': {'x': 200, 'y': 100, 'width': 80, 'height': 30},
      'children': [],
    }),
  };
  final Map<String, BaseNode> nodes = {
    for (final MapEntry(:key, :value) in json.entries)
      key: NodeJsonConverter().fromJson(value)!,
  };
  for (final BaseNode node in nodes.values) {
    for (final String child in node.childrenOrEmpty) {
      nodes[child]!.parentID = node.id;
    }
  }
  nodes['root']!.parentID = kRootNode;
  return nodes;
}

VariableData variable(String name, VariableType type, Object? value) =>
    VariableData(id: name, name: name, type: type, value: value);

/// The variables of the Inspection form the formula reads: `errSigns` is
/// computed and holds while disease is ticked and no sign is picked.
Map<String, Observable<VariableData>> formVariables({
  required bool showErrors,
}) => {
  for (final VariableData v in [
    variable('showErrors', VariableType.boolean, showErrors),
    variable('cDisease', VariableType.boolean, true),
    variable('fSigns', VariableType.list, const []),
    variable(
      'errSigns',
      VariableType.text,
      r"${= cDisease && length(fSigns) == 0 ? 'Pick one.' : ''}",
    ),
  ])
    v.id: Observable(v),
};

/// The stroke each part paints: its colour and width, by the painter or
/// border that draws it.
class Painted {
  Painted(this.kind, this.color, this.width);

  final String kind;
  final Color color;
  final double width;

  @override
  String toString() => '$kind ${color.toARGB32().toRadixString(16)} $width';
}

List<Painted> paintedStrokes(WidgetTester tester) => [
  for (final CustomPaint w in tester.allWidgets.whereType<CustomPaint>())
    ...switch (w.painter) {
      final StrokePainter p => [
        Painted('side ${p.strokeSide.name}', p.color, p.strokeWidth),
      ],
      final SvgPathStrokePainter p => [
        Painted('svg path', p.color, p.strokeWidth),
      ],
      final PathNodePainter p => [
        for (final PathFill stroke in p.strokes)
          Painted('path node', stroke.color!, p.strokeWeight),
      ],
      _ => const <Painted>[],
    },
  for (final DecoratedBox w in tester.allWidgets.whereType<DecoratedBox>())
    if (w.decoration case BoxDecoration(border: final Border border))
      Painted('border', border.top.color, border.top.width),
];

Future<void> pumpTree(
  WidgetTester tester, {
  required CodelesslyContext context,
  bool withReactions = true,
}) async {
  final Map<String, BaseNode> nodes = nodeTree();
  final NodeRegistry registry = NodeRegistry()..setNodes(nodes);
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: context,
      child: MaterialApp(
        home: Material(
          child: Align(
            alignment: Alignment.topLeft,
            child: Builder(
              builder: (c) => manager.buildWidgetFromNode(
                nodes['root']!,
                c,
                settings: WidgetBuildSettings(
                  debugLabel: 'test',
                  withReactions: withReactions,
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

const Color dangerColor = Color(0xFFB23A2B);
const Color waxEdgeColor = Color(0xFFE3CFA3);

/// Every node kind that strokes, as [paintedStrokes] names it.
const List<String> kinds = [
  'side top', // Mid
  'side bottom', // Inner
  'svg path', // L
  'svg path', // R
  'path node',
  'border', // box
  'border', // frame
];

void expectAll(WidgetTester tester, Color color, double width) {
  final List<Painted> painted = paintedStrokes(tester);
  expect(
    painted.map((p) => p.kind).toList()..sort(),
    [...kinds]..sort(),
    reason: '$painted',
  );
  for (final Painted p in painted) {
    expect(p.color, color, reason: '$p');
    expect(p.width, width, reason: '$p');
  }
}

void main() {
  testWidgets('a bound stroke colour and weight apply to every node kind '
      'that strokes, and follow the variables', (tester) async {
    final Map<String, Observable<VariableData>> variables = formVariables(
      showErrors: false,
    );
    final CodelesslyContext context = CodelesslyContext.empty()
      ..variables.addAll(variables);
    await pumpTree(tester, context: context);
    expectAll(tester, waxEdgeColor, 1);

    // The first Save shows the errors: every part turns red and thickens.
    final Observable<VariableData> show = variables['showErrors']!;
    show.set(show.value.copyWith(value: true));
    await tester.pump();
    expectAll(tester, dangerColor, 2);

    // Picking a sign clears the error (through the computed errSigns).
    final Observable<VariableData> signs = variables['fSigns']!;
    signs.set(signs.value.copyWith(value: ['chalkbrood']));
    await tester.pump();
    expectAll(tester, waxEdgeColor, 2);
  });

  testWidgets('a hovered state patch keeps the bound stroke', (tester) async {
    final CodelesslyContext context = CodelesslyContext.empty()
      ..variables.addAll(formVariables(showErrors: true));
    await pumpTree(tester, context: context);
    final TestGesture mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await mouse.addPointer(location: const Offset(60, 18));
    addTearDown(mouse.removePointer);
    await tester.pump();
    expectAll(tester, dangerColor, 2);
  });

  testWidgets('on the design canvas the bindings read the preview values, '
      'path nodes included', (tester) async {
    // The live value says no errors; the editor previews them shown.
    final CodelesslyContext context = CodelesslyContext.empty()
      ..variables.addAll(formVariables(showErrors: false));
    VariablePreview.scopeResolver = (_) => ScopedValues.preview(
      variables: {
        for (final Observable<VariableData> v in formVariables(
          showErrors: true,
        ).values)
          v.value.name: v.value,
      },
      codelesslyContext: CodelesslyContext.empty(),
    );
    addTearDown(() => VariablePreview.scopeResolver = null);
    await pumpTree(tester, context: context, withReactions: false);
    expectAll(tester, dangerColor, 2);
  });

  testWidgets('a path node reads stroke-paint-<id> from the preview values '
      'on the design canvas', (tester) async {
    final PathNode node =
        PathNode(
            id: 'line',
            name: 'Line',
            basicBoxLocal: NodeBox(0, 0, 100, 20),
            pathData: 'M0 10 L100 10',
            strokes: [
              PaintModel.solid(id: 'ink', color: ColorRGB.fromHex(waxEdge)),
            ],
          )
          ..variables['stroke-paint-ink'] =
              "\${= showErrors ? '$danger' : '$waxEdge'}"
          ..parentID = kRootNode;
    final CodelesslyContext context = CodelesslyContext.empty()
      ..variables.addAll(formVariables(showErrors: false));
    VariablePreview.scopeResolver = (_) => ScopedValues.preview(
      variables: {
        for (final Observable<VariableData> v in formVariables(
          showErrors: true,
        ).values)
          v.value.name: v.value,
      },
      codelesslyContext: CodelesslyContext.empty(),
    );
    addTearDown(() => VariablePreview.scopeResolver = null);
    final NodeRegistry registry = NodeRegistry()..setNodes({node.id: node});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    Future<void> pump({required bool withReactions}) => tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: context,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (c) => manager.buildWidgetFromNode(
              node,
              c,
              settings: WidgetBuildSettings(
                debugLabel: 'test',
                withReactions: withReactions,
              ),
            ),
          ),
        ),
      ),
    );
    await pump(withReactions: false);
    expect(paintedStrokes(tester).single.color, dangerColor);
    // At runtime the live value wins.
    await pump(withReactions: true);
    expect(paintedStrokes(tester).single.color, waxEdgeColor);
  });
}
