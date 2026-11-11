import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

LayoutDocument doc(double width, Object sliderWidth) =>
    LayoutDocument.fromJson({
      'roots': ['row'],
      'nodes': {
        'row': {
          'type': 'column',
          'layout': {'width': width, 'height': 60},
          'props': {'crossAxisAlignment': 'start'},
          'children': ['slider'],
        },
        'slider': {
          'type': 'slider',
          'layout': {'width': sliderWidth, 'height': 48},
          'props': {'value': 0},
        },
      },
    });
Slider slider(NodeTree tree) {
  Slider? result;
  void visit(Element e) {
    if (e.widget is Slider) result = e.widget as Slider;
    e.visitChildren(visit);
  }

  for (final host in tree.islands.hosts) {
    if (host.element case final e?) visit(e);
  }
  return result!;
}

void main() {
  testWidgets(
    'fill slider uses the runtime width and accepts taps beyond its fallback',
    (tester) async {
      final source = DocumentSource(doc(600, {'fill': 200}));
      final tree = NodeTree(source);
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: NodeView(tree: tree, rootId: 'row', interactive: true),
          ),
        ),
      );
      expect(tree.islands.hosts.single.size.width, 600);
      final host = tree.islands.hosts.single;
      await tester.tapAt(host.localToGlobal(const Offset(550, 24)));
      await tester.pump();
      expect(slider(tree).value, greaterThan(.8));
      source.document = doc(450, {'fill': 200});
      await tester.pump();
      expect(tree.islands.hosts.single.size.width, 450);
      await tester.pumpWidget(const SizedBox());
      tree.dispose();
    },
  );
  testWidgets('hug slider keeps its chosen design width', (tester) async {
    final tree = NodeTree(DocumentSource(doc(600, {'hug': 200})));
    await tester.pumpWidget(
      MaterialApp(
        home: NodeView(tree: tree, rootId: 'row'),
      ),
    );
    expect(tree.islands.hosts.single.size.width, 200);
    await tester.pumpWidget(const SizedBox());
    tree.dispose();
  });
}
