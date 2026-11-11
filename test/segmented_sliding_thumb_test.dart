import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a track with a sliding thumb moves one thumb between equal segments', (tester) async {
    final vars = VariableScope([const Variable(id: 's', name: 's', type: VariableType.text, value: 'a')]);
    final doc = LayoutDocument.fromJson({
      'roots': ['root'],
      'nodes': {
        'root': {'type': 'column', 'children': ['seg'], 'layout': {'width': 400, 'height': 60}},
        'seg': {
          'type': 'segmentedButton',
          'layout': {'width': 304, 'height': 32},
          'props': {
            'variant': 'track',
            'slidingThumb': true,
            'trackPadding': 2,
            'segments': [
              {'value': 'a', 'label': 'A'},
              {'value': 'b', 'label': 'B'},
              {'value': 'c', 'label': 'C'},
            ],
            'selected': ['a'],
            'backgroundColor': '#00000000',
            'selectedBackgroundColor': '#FF1A1714',
            'foregroundColor': '#FF1A1714',
            'selectedForegroundColor': '#FFF4EFE6',
            'padding': [0, 0, 0, 0],
          },
          'bind': {'props.selected': r'${= [s]}'},
        },
      },
    });
    final tree = NodeTree(DocumentSource(doc), binder: NodeBinder(scope: vars));
    await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'root'))));
    await tester.pumpAndSettle();
    // The thumb: the one decorated box filled with the selected colour.
    double thumbLeft() {
      double? left;
      void visit(RenderObject o) {
        if (o is RenderDecoratedBox && (o.decoration as BoxDecoration).color == const Color(0xFF1A1714)) {
          left = o.localToGlobal(Offset.zero).dx;
        }
        o.visitChildren(visit);
      }
      visit(tree.boxOf('seg')!);
      return left!;
    }

    final origin = tree.boxOf('seg')!.localToGlobal(Offset.zero).dx;
    expect(thumbLeft() - origin, closeTo(2, 0.5));
    vars.set('s', 'c');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final mid = thumbLeft() - origin;
    expect(mid, greaterThan(10), reason: 'sliding');
    expect(mid, lessThan(2 + 200 - 1));
    await tester.pumpAndSettle();
    expect(thumbLeft() - origin, closeTo(2 + 200, 0.5)); // (304 - 4) / 3 * 2
    await tester.pumpWidget(const SizedBox());
    tree.dispose();
    vars.dispose();
  });
}
