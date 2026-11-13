// A list of 500 items whose template is a 15-node component builds and
// scrolls like the same list with the nodes inlined: the same boxes, the
// same applies, a comparable time; a variable nothing in it reads re-applies
// none of its boxes.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const int items = 500;

/// The item's 15 nodes: a row of 7 columns of a text each, plus the row.
/// [read] is how a text reads its value: `props.x` in the component,
/// `item.x` inlined.
Map<String, Json> itemNodes(String root, String read) => {
      root: {
        'type': 'row',
        'children': [for (var i = 0; i < 7; i++) 'c$i'],
        'layout': {'width': 700, 'height': {'hug': 30}},
      },
      for (var i = 0; i < 7; i++) ...{
        'c$i': {'type': 'column', 'children': ['t$i'], 'layout': {'width': 100, 'height': {'hug': 30}}},
        't$i': {
          'type': 'text',
          'props': {'text': '\${$read.n} $i'},
          'layout': {'width': {'hug': 40}, 'height': {'hug': 16}},
        },
      },
    };

Json definition() => {
      'schema': 2,
      'roots': ['r'],
      'widget': {
        'type': 'Line',
        'props': [
          {'key': 'item', 'type': {'kind': 'json'}, 'default': {}},
        ],
      },
      'nodes': itemNodes('r', 'props.item'),
    };

Json page({required bool component}) => {
      'schema': 2,
      'roots': ['col'],
      'nodes': {
        'col': {'type': 'column', 'children': ['list', 'other'], 'layout': {'width': 800, 'height': 600}},
        'other': {'type': 'text', 'props': {'text': r'${other}'}, 'layout': {'width': 50, 'height': 20}},
        'list': {
          'type': 'listView',
          'children': ['item'],
          'bind': {'data': r'${rows}'},
          'layout': {'width': 800, 'height': {'fill': 560}},
        },
        if (component)
          'item': {'type': 'Line', 'bind': {'props.item': r'${item}'}, 'layout': {'width': 700, 'height': {'hug': 30}}}
        else
          ...itemNodes('item', 'item'),
      },
    };

class Run {
  Run(this.tree, this.scope, this.buildUs, this.scrollUs, this.applies, this.unrelated);
  final NodeTree tree;
  final VariableScope scope;
  final int buildUs, scrollUs;
  final int applies, unrelated;
}

Future<Run> run(WidgetTester tester, {required bool component}) async {
  final registry = ComponentRegistry([if (component) LayoutDocument.fromJson(definition())]);
  final doc = LayoutDocument.fromJson(page(component: component), catalog: standardCatalog + registry.catalog);
  final scope = VariableScope([
    Variable(name: 'rows', type: VariableType.list, value: [for (var i = 0; i < items; i++) {'n': i}]),
    const Variable(name: 'other', type: VariableType.integer, value: 0),
  ]);
  final binder = NodeBinder(scope: scope);
  final tree = NodeTree(DocumentSource(doc), binder: binder, components: component ? registry : null);
  NodeBox.debugApplyCounts.clear();
  NodeBox.debugCountApplies = true;
  final watch = Stopwatch()..start();
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'col', interactive: true))),
  ));
  final buildUs = watch.elapsedMicroseconds;
  final applies = NodeBox.debugApplyCounts.values.fold(0, (a, b) => a + b);
  watch
    ..reset()
    ..start();
  for (var i = 0; i < 10; i++) {
    await tester.drag(find.byType(NodeView), const Offset(0, -400));
    await tester.pump();
  }
  final scrollUs = watch.elapsedMicroseconds;
  NodeBox.debugApplyCounts.clear();
  scope.set('other', 1);
  await tester.pump();
  final unrelated = NodeBox.debugApplyCounts.entries.where((e) => e.key != 'other').fold(0, (a, e) => a + e.value);
  NodeBox.debugCountApplies = false;
  await tester.pumpWidget(const SizedBox());
  tree.dispose();
  binder.dispose();
  return Run(tree, scope, buildUs, scrollUs, applies, unrelated);
}

void main() {
  testWidgets('500 component items build and scroll like 500 inlined ones', (tester) async {
    // Warm both paths up once (compilation, fonts), then measure.
    await run(tester, component: true);
    await run(tester, component: false);
    final inlined = await run(tester, component: false);
    final components = await run(tester, component: true);
    // ignore: avoid_print
    print('inlined: build ${inlined.buildUs ~/ 1000} ms, scroll ${inlined.scrollUs ~/ 1000} ms, ${inlined.applies} applies; '
        'components: build ${components.buildUs ~/ 1000} ms, scroll ${components.scrollUs ~/ 1000} ms, ${components.applies} applies');
    expect(components.applies, inlined.applies, reason: 'one box per definition node per instance, applied as often');
    expect(components.unrelated, 0);
    expect(inlined.unrelated, 0);
    // The same order of time (loose: a shared, loaded machine).
    expect(components.buildUs, lessThan(inlined.buildUs * 3 + 200000));
    expect(components.scrollUs, lessThan(inlined.scrollUs * 3 + 200000));
  });
}
