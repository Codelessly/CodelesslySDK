// A table view on a design canvas (not running) shows its bound data: one
// row per item, each cell in its own scope (${item.value}, ${item.label}),
// as the running table does.
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart' hide Node;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> paragraphs(WidgetTester tester) {
  final out = <String>[];
  void visit(RenderObject o) {
    if (o is RenderParagraph) out.add(o.text.toPlainText());
    o.visitChildren(visit);
  }

  visit(tester.renderObject(find.byType(NodeView)));
  return out;
}

void main() {
  testWidgets('bound rows and cell values show at rest', (tester) async {
    final doc = LayoutDocument.fromJson({
      'roots': ['t'],
      'nodes': {
        't': {
          'type': 'tableView',
          'layout': {'width': 300, 'height': 200},
          'props': {'rowHeight': 30, 'headerHeight': 30},
          'bind': {'data': r'${rows}', 'props.columns': r'${cols}'},
          'slots': {'cell': 'cell', 'columnHeader': 'head'},
        },
        'cell': {'type': 'text', 'props': {'text': r'${item.value}'}},
        'head': {'type': 'text', 'props': {'text': r'${item.label}'}},
      },
    });
    final scope = VariableScope([
      Variable(name: 'rows', type: api.VariableType.list, value: [
        {'x': '−3.0', 'l1': '0.4234'},
        {'x': '−2.5', 'l1': '1.4962'},
      ]),
      Variable(name: 'cols', type: api.VariableType.list, value: [
        {'key': 'x', 'label': 'x', 'width': 84},
        {'key': 'l1', 'label': 'y₁', 'width': 150},
      ]),
    ]);
    final tree = NodeTree(NodeValues(DocumentSource(doc)), binder: NodeBinder(scope: scope));
    addTearDown(tree.dispose);
    await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 't', interactive: false))));
    await tester.pump();
    final texts = paragraphs(tester);
    expect(texts, containsAll(['x', 'y₁', '−3.0', '0.4234', '−2.5', '1.4962']));
  });
}
