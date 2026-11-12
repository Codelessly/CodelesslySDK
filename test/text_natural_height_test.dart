import 'package:codelessly_api/codelessly_api.dart' show LayoutDocument;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('naturalHeight gives a text the font\'s own line height, as Flutter\'s height: null', (tester) async {
    Map<String, Object?> text(String t, Map<String, Object?> style, double y) => {
          'type': 'text',
          'props': {'text': t, 'style': {'fontSize': 15, ...style}},
          'layout': {'width': {'hug': 40}, 'height': {'hug': 40}, 'y': {'start': y}},
        };
    final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({
      'roots': ['s'],
      'nodes': {
        's': {'type': 'stack', 'layout': {'width': 300, 'height': 300}, 'children': ['base', 'natural', 'stated', 'run']},
        'base': text('Base', const {}, 0),
        'natural': text('Natural', const {'naturalHeight': true}, 60),
        'stated': text('Stated', const {'naturalHeight': true, 'height': 2}, 120),
        'run': {
          'type': 'text',
          'props': {
            'text': 'Run here',
            'style': {'fontSize': 15, 'naturalHeight': true},
            'runs': [
              {'start': 0, 'end': 3, 'style': {'fontWeight': 700}},
            ],
          },
          'layout': {'width': {'hug': 40}, 'height': {'hug': 40}, 'y': {'start': 180}},
        },
      },
    })));
    await tester.pumpWidget(MaterialApp(home: Column(children: [
      Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 's')),
      const Text('Flutter', key: Key('flutter'), style: TextStyle(fontSize: 15)),
    ])));
    await tester.pumpAndSettle();
    final flutter = tester.getSize(find.byKey(const Key('flutter'))).height;
    double h(String id) => tree.boxOf(id)!.size.height;
    expect(h('natural'), flutter);
    expect(h('run'), flutter);
    expect(h('base'), closeTo(15 * 1.33, 0.5));
    expect(h('stated'), 30);
  });

  testWidgets('a project with natural line height (ThemeTokens.naturalLineHeight): text without a height takes the font\'s', (tester) async {
    Map<String, Object?> text(String t, Map<String, Object?> style, double y, {List<Object?> runs = const []}) => {
          'type': 'text',
          'props': {'text': t, 'style': {'fontSize': 15, ...style}, 'runs': runs},
          'layout': {'width': {'hug': 40}, 'height': {'hug': 40}, 'y': {'start': y}},
        };
    final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({
      'roots': ['s'],
      'nodes': {
        's': {'type': 'stack', 'layout': {'width': 300, 'height': 300}, 'children': ['base', 'run', 'stated', 'optOut']},
        'base': text('Base', const {}, 0),
        // A run without a height (Tack's runs style weight and color only).
        'run': text('Run here', const {}, 60, runs: [
          {'start': 0, 'end': 8, 'style': {'fontWeight': 600}},
        ]),
        'stated': text('Stated', const {'height': 2}, 120),
        'optOut': text('Material', const {'naturalHeight': false}, 180),
      },
    })));
    await tester.pumpWidget(MaterialApp(home: Column(children: [
      Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 's')),
      const Text('Flutter', key: Key('flutter'), style: TextStyle(fontSize: 15)),
    ])));
    await tester.pumpAndSettle();
    final flutter = tester.getSize(find.byKey(const Key('flutter'))).height;
    double h(String id) => tree.boxOf(id)!.size.height;
    expect(h('base'), closeTo(15 * 1.33, 0.5), reason: 'off by default');
    tree.naturalLineHeight = true;
    await tester.pumpAndSettle();
    expect(h('base'), flutter);
    expect(h('run'), flutter);
    expect(h('stated'), 30, reason: 'a stated height wins');
    expect(h('optOut'), closeTo(15 * 1.33, 0.5), reason: 'a run that opts out keeps 1.33');
    tree.naturalLineHeight = false;
    await tester.pumpAndSettle();
    expect(h('base'), closeTo(15 * 1.33, 0.5));
  });
}
