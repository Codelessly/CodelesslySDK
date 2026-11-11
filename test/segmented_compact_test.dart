import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _show(WidgetTester tester, Map<String, Object?> props, {double width = 96, double height = 28}) async {
  final source = DocumentSource(LayoutDocument.fromJson({
    'roots': ['seg'],
    'nodes': {
      'seg': {
        'type': 'segmentedButton',
        'layout': {'width': width, 'height': height},
        'props': {
          'segments': [
            {'value': '1', 'label': '1×'},
            {'value': '2', 'label': '2×'},
            {'value': '4', 'label': '4×'},
          ],
          'selected': ['1'],
          'showSelectedIcon': false,
          ...props,
        },
      },
    },
  }));
  final scope = VariableScope(const []);
  final tree = NodeTree(source, binder: NodeBinder(scope: scope));
  await tester.pumpWidget(MaterialApp(home: Center(child: NodeView(tree: tree, rootId: 'seg', interactive: true))));
  await tester.pumpAndSettle();
  addTearDown(() {
    tree.dispose();
    scope.dispose();
  });
}

void main() {
  testWidgets('a compact segmented button fits a 96 × 28 box', (tester) async {
    await _show(tester, {
      'expanded': true,
      'segmentHeight': 28,
      'shrinkTapTarget': true,
      'padding': [0, 0, 0, 0],
      'backgroundColor': '#00000000',
    });
    expect(tester.takeException(), isNull);
    final size = tester.getSize(find.byType(SegmentedButton<String>));
    expect(size.width, closeTo(96, 0.5));
    expect(size.height, closeTo(28, 0.5));
    final b = tester.widget<SegmentedButton<String>>(find.byType(SegmentedButton<String>));
    expect(b.expandedInsets, EdgeInsets.zero);
  });

  testWidgets('without the new props it is Flutter\'s segmented button', (tester) async {
    await _show(tester, {}, width: 200, height: 48);
    final b = tester.widget<SegmentedButton<String>>(find.byType(SegmentedButton<String>));
    expect(b.expandedInsets, isNull);
    expect(b.style?.minimumSize, isNull);
  });
}
