import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/graph.dart' show GraphHit, RenderGraph;
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/screen.dart' as harness;

// The graph node: a document's `graph` drawn by the graph's render object,
// its selection reported to the page as the node's `changed`.

Iterable<RenderObject> _all(RenderObject o) sync* {
  yield o;
  final kids = <RenderObject>[];
  o.visitChildren(kids.add);
  for (final k in kids) {
    yield* _all(k);
  }
}

RenderGraph graphOf(harness.Screen s, String id) => _all(s.tree.boxOf(id)!).whereType<RenderGraph>().single;

const _still = {'dragPan': false, 'wheelZoom': false, 'pinchZoom': false, 'axisScale': false, 'doubleTapReset': false};

Map<String, Json> _page(Json graph) => {
      'col': {
        'type': 'column',
        'children': ['graph', 'label'],
        'layout': {'width': 440, 'height': {'hug': 300}},
      },
      'graph': graph,
      'label': {
        'type': 'text',
        'layout': {'width': 440, 'height': 20},
        'props': {'text': ''},
        'bind': {'props.text': r"${= sel.label == null ? 'nothing' : sel.label + ' ' + sel.row.web}"},
      },
    };

Json _bars({Json selection = const {'on': 'both'}, List<Json>? actions}) => {
      'type': 'graph',
      'layout': {'width': 440, 'height': 224},
      'props': {
        'rowKey': 'month',
        'data': [
          {'month': 'Jan', 'web': 30, 'store': 10},
          {'month': 'Feb', 'web': 50, 'store': 20},
          {'month': 'Mar', 'web': 20, 'store': 40},
          {'month': 'Apr', 'web': 10, 'store': 5},
        ],
        'x': {'label': 'month', 'fit': 'bars', 'axisHeight': 24},
        'y': {'width': 40, 'decimals': 0},
        'marks': [
          {'type': 'bar', 'y': 'web', 'name': 'Web', 'stack': 's'},
          {'type': 'bar', 'y': 'store', 'name': 'Store', 'stack': 's'},
        ],
        'selection': selection,
        'crosshair': {'enabled': false},
        'interactions': _still,
      },
      'actions': actions ??
          [
            harness.reaction('changed', [
              {'type': 'setVariable', 'variable': 'sel', 'value': r'${result.selection}'},
            ]),
          ],
    };

void main() {
  testWidgets('a graph node is drawn by the graph, with its one pane written on the node', (tester) async {
    final s = await harness.show(tester, _page(_bars()), variables: [harness.v('sel', null, VariableType.map)]);
    await tester.pump();
    final graph = graphOf(s, 'graph');
    expect(graph.size, const Size(440, 224));
    final e = graph.engine;
    expect(e.count, 4);
    expect(e.spec.key, 'month');
    expect(e.spec.panes.single.marks.map((m) => m.y), ['web', 'store']);
    expect(e.spec.selection.on, 'both');
    // On a page it has no ground of its own.
    expect(e.spec.style.background, const Color(0x00000000));
    expect(e.barGroups(0), [
      [0, 1],
    ]);
  });

  testWidgets('hovering a bar reports the selection, and the page shows it', (tester) async {
    final s = await harness.show(tester, _page(_bars()), variables: [harness.v('sel', null, VariableType.map)]);
    await tester.pump();
    final graph = graphOf(s, 'graph');
    expect(harness.textOf(s.tree, 'label'), 'nothing');
    final origin = graph.localToGlobal(Offset.zero);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: const Offset(700, 550));
    await mouse.moveTo(origin + Offset(graph.engine.xOf(1), 100));
    await tester.pumpAndSettle();
    expect(graph.engine.selection, const GraphHit(pane: 0, index: 1));
    expect((s['sel'] as Map?)?['label'], 'Feb');
    expect(harness.textOf(s.tree, 'label'), 'Feb 50');
    await mouse.moveTo(const Offset(700, 550));
    await tester.pumpAndSettle();
    expect((s['sel'] as Map?)?['label'], isNull);
    expect(harness.textOf(s.tree, 'label'), 'nothing');
  });

  testWidgets('a tap pins the selection, and the page can set it', (tester) async {
    final graphNode = _bars()..['bind'] = {'props.selected': r'${pick}'};
    final s = await harness.show(tester, _page(graphNode),
        variables: [harness.v('sel', null, VariableType.map), harness.v('pick', null, VariableType.map)]);
    await tester.pump();
    final graph = graphOf(s, 'graph');
    final origin = graph.localToGlobal(Offset.zero);
    await tester.tapAt(origin + Offset(graph.engine.xOf(2), 100));
    await tester.pumpAndSettle();
    expect(graph.engine.selection?.index, 2);
    expect(harness.textOf(s.tree, 'label'), 'Mar 20');

    s.scope.set('pick', {'index': 0});
    await tester.pumpAndSettle();
    expect(graph.engine.selection?.index, 0);
    expect(harness.textOf(s.tree, 'label'), 'Jan 30');
  });

  testWidgets('a donut is a polar graph: a slice under the pointer is the selection', (tester) async {
    final s = await harness.show(
        tester,
        _page({
          'type': 'graph',
          'layout': {'width': 200, 'height': 200},
          'props': {
            'rowKey': 'label',
            'coord': 'polar',
            'data': [
              {'label': 'Rent', 'web': 60},
              {'label': 'Food', 'web': 25},
              {'label': 'Other', 'web': 15},
            ],
            'x': {'label': 'label', 'axisHeight': 0},
            'y': {'width': 0},
            'marks': [
              {'type': 'arc', 'y': 'web', 'inner': 0.6, 'colors': ['#FF2563EB', '#FF719AF2', '#FFA8C1F7']},
            ],
            'selection': {'on': 'hover', 'by': 'mark'},
            'crosshair': {'enabled': false},
          },
          'actions': [
            harness.reaction('changed', [
              {'type': 'setVariable', 'variable': 'sel', 'value': r'${result.selection}'},
            ]),
          ],
        }),
        variables: [harness.v('sel', null, VariableType.map)]);
    await tester.pump();
    final graph = graphOf(s, 'graph');
    final origin = graph.localToGlobal(Offset.zero);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: const Offset(700, 550));
    await mouse.moveTo(origin + const Offset(22, 90));
    await tester.pumpAndSettle();
    expect(harness.textOf(s.tree, 'label'), 'Food 25');
    expect((s['sel'] as Map?)?['value'], 25);
  });

  testWidgets('on a design canvas a graph is at rest: pointers select nothing', (tester) async {
    final s = await harness.show(tester, _page(_bars()),
        variables: [harness.v('sel', null, VariableType.map)], interactive: false);
    await tester.pump();
    final graph = graphOf(s, 'graph');
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: const Offset(700, 550));
    await mouse.moveTo(graph.localToGlobal(Offset.zero) + const Offset(150, 100));
    await tester.pump();
    expect(graph.engine.selection, isNull);
  });
}
