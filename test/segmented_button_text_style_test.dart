import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

SegmentedButton<String> control(NodeTree tree) {
  SegmentedButton<String>? found;
  void visit(Element e) {
    if (e.widget is SegmentedButton<String>)
      found = e.widget as SegmentedButton<String>;
    e.visitChildren(visit);
  }

  for (final host in tree.islands.hosts) {
    final e = host.element;
    if (e != null) visit(e);
  }
  return found!;
}

void main() {
  testWidgets(
    'segmented typography reaches native ButtonStyle and updates live',
    (tester) async {
      final source = DocumentSource(
        LayoutDocument.fromJson({
          'roots': ['tabs'],
          'nodes': {
            'tabs': {
              'type': 'segmentedButton',
              'layout': {'width': 320, 'height': 48},
              'props': {
                'segments': [
                  {'value': 'Results', 'label': 'Results'},
                  {'value': 'Swing', 'label': 'Swing'},
                ],
                'selected': ['Results'],
                'textStyle': {
                  'fontFamily': 'Alegreya',
                  'fontSize': 13,
                  'fontWeight': 700,
                },
              },
            },
          },
        }),
      );
      final tree = NodeTree(source);
      await tester.pumpWidget(
        MaterialApp(
          home: NodeView(tree: tree, rootId: 'tabs', interactive: true),
        ),
      );
      final style = control(tree).style!.textStyle!.resolve({});
      expect(style!.fontFamily, 'Alegreya');
      expect(style.fontSize, 13);
      expect(style.fontWeight, FontWeight.w700);
      source.document = source.document.copyWith(
        nodes: {
          'tabs': source.document['tabs']!.withProp(
            api.SegmentedButtonProps.textStyle,
            const api.TextStyle(fontFamily: 'Alegreya', fontSize: 18),
          ),
        },
      );
      await tester.pump();
      expect(control(tree).style!.textStyle!.resolve({})!.fontSize, 18);
      await tester.pumpWidget(const SizedBox());
      tree.dispose();
    },
  );
  testWidgets('unconfigured segmented typography inherits the host theme', (
    tester,
  ) async {
    final source = DocumentSource(
      LayoutDocument.fromJson({
        'roots': ['tabs'],
        'nodes': {
          'tabs': {
            'type': 'segmentedButton',
            'layout': {'width': 320, 'height': 48},
            'props': {
              'segments': [
                {'value': 'Results', 'label': 'Results'},
              ],
              'selected': ['Results'],
            },
          },
        },
      }),
    );
    final tree = NodeTree(source);
    await tester.pumpWidget(
      MaterialApp(
        home: NodeView(tree: tree, rootId: 'tabs'),
      ),
    );
    expect(control(tree).style!.textStyle, isNull);
    await tester.pumpWidget(const SizedBox());
    tree.dispose();
  });
}
