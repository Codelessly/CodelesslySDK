// A text style without a height: schema 3 takes the font's own line height,
// as Flutter's `Text` does (`height: null`); a schema-2 document keeps 1.33
// through the migration (`defaultTextStyle` on its top-level nodes); the
// nearest `defaultTextStyle` (Flutter's `DefaultTextStyle`) is inherited.
import 'package:codelessly_api/codelessly_api.dart' show LayoutDocument;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _text(String t, Map<String, Object?> style, double y, {Map<String, Object?>? extra, List<Object?>? runs}) => {
      'type': 'text',
      'props': {'text': t, 'style': {'fontSize': 15, ...style}, 'runs': ?runs},
      'layout': {'width': {'hug': 40}, 'height': {'hug': 40}, 'y': {'start': y}},
      ...?extra,
    };

Future<(NodeTree, double)> _show(WidgetTester tester, Map<String, Object?> doc) async {
  final tree = NodeTree(DocumentSource(LayoutDocument.fromJson(doc)));
  addTearDown(tree.dispose);
  await tester.pumpWidget(MaterialApp(home: Column(children: [
    Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 's')),
    const Text('Flutter', key: Key('flutter'), style: TextStyle(fontSize: 15)),
  ])));
  await tester.pumpAndSettle();
  return (tree, tester.getSize(find.byKey(const Key('flutter'))).height);
}

void main() {
  testWidgets('a text without a height takes its font\'s own line height as Flutter\'s Text does, and a stated height wins', (tester) async {
    final (tree, flutter) = await _show(tester, {
      'schema': 3,
      'roots': ['s'],
      'nodes': {
        's': {'type': 'stack', 'layout': {'width': 300, 'height': 300}, 'children': ['base', 'stated', 'run']},
        'base': _text('Base', const {}, 0),
        'stated': _text('Stated', const {'height': 2}, 60),
        'run': _text('Run here', const {}, 120, runs: [
          {'start': 0, 'end': 3, 'style': {'fontWeight': 700}},
        ]),
      },
    });
    double h(String id) => tree.boxOf(id)!.size.height;
    expect(h('base'), flutter);
    expect(h('run'), flutter);
    expect(h('stated'), 30);
    expect(flutter, isNot(closeTo(15 * 1.33, 0.5)));
  });

  testWidgets('a schema-2 text keeps its 1.33 line height through the migration, and natural height becomes the font\'s own', (tester) async {
    final (tree, flutter) = await _show(tester, {
      'roots': ['s'],
      'nodes': {
        's': {'type': 'stack', 'layout': {'width': 300, 'height': 300}, 'children': ['base', 'natural', 'stated', 'run']},
        'base': _text('Base', const {}, 0),
        'natural': _text('Natural', const {'naturalHeight': true}, 60),
        'stated': _text('Stated', const {'naturalHeight': true, 'height': 2}, 120),
        'run': _text('Run here', const {'naturalHeight': true}, 180, runs: [
          {'start': 0, 'end': 3, 'style': {'fontWeight': 700}},
        ]),
      },
    });
    double h(String id) => tree.boxOf(id)!.size.height;
    expect(h('base'), closeTo(15 * 1.33, 0.5));
    expect(h('natural'), flutter);
    expect(h('run'), flutter);
    expect(h('stated'), 30);
  });

  testWidgets('a default text style is inherited by the text below it, the nearest one winning', (tester) async {
    final (tree, flutter) = await _show(tester, {
      'schema': 3,
      'roots': ['s'],
      'nodes': {
        's': {
          'type': 'stack',
          'layout': {'width': 300, 'height': 300},
          'children': ['inherits', 'own', 'reset', 'col'],
          'defaultTextStyle': {'height': 2, 'fontSize': 10},
        },
        'inherits': _text('A', const {}, 0),
        'own': _text('B', const {'height': 1}, 60),
        'reset': _text('C', const {}, 120, extra: {'defaultTextStyle': <String, Object?>{}}),
        'col': {
          'type': 'column',
          'layout': {'width': 100, 'height': {'hug': 10}, 'y': {'start': 180}},
          'children': ['deep'],
        },
        'deep': {'type': 'text', 'props': {'text': 'D'}, 'layout': {'width': {'hug': 40}, 'height': {'hug': 40}}},
      },
    });
    double h(String id) => tree.boxOf(id)!.size.height;
    expect(h('inherits'), 30, reason: 'its own fontSize 15 over the inherited height 2');
    expect(h('own'), 15);
    expect(h('reset'), flutter);
    expect(h('deep'), 20, reason: 'two levels down: fontSize 10, height 2');
  });
}
