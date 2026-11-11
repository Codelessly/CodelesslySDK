// A table at rest (a design canvas) shows what the running one does: cells
// inset from its edges, the line under its header and its selected row.
import 'package:codelessly_sdk/codelessly_sdk.dart' hide captureImage;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  testWidgets('edge inset, header border and selected row at rest', (tester) async {
    await show(
      tester,
      {
        'table': {
          'type': 'tableView',
          'layout': {'width': 400, 'height': 300},
          'bind': {'data': r'${rows}'},
          'slots': {'cell': 'cell', 'columnHeader': 'head'},
          'props': {
            'columns': [
              {'key': 'name', 'label': 'Name', 'width': 200},
              {'key': 'code', 'label': 'Code', 'width': 200},
            ],
            'rowHeight': 50,
            'headerHeight': 50,
            'horizontalPadding': 18,
            'headerBorderColor': '#FFFF0000',
            'headerBorderWidth': 2,
            'selectedRow': 1,
            'selectedRowColor': '#FF00FF00',
            'selectedRowEdgeColor': '#FF0000FF',
          },
        },
        'cell': {'type': 'text', 'layout': {'width': {'hug': 80}, 'height': {'hug': 20}}, 'props': {'text': r'${item.value}'}},
        'head': {'type': 'text', 'layout': {'width': {'hug': 80}, 'height': {'hug': 20}}, 'props': {'text': r'${item.label}'}},
      },
      root: 'table',
      variables: [
        v('rows', [
          for (var r = 0; r < 4; r++) {'name': 'N$r', 'code': 'C$r'},
        ], VariableType.list),
      ],
      interactive: false,
    );
    await tester.pumpAndSettle();
    final at = <String, Offset>{};
    final heights = <String, double>{};
    void visit(RenderObject o) {
      if (o is RenderParagraph) {
        at[o.text.toPlainText()] = o.localToGlobal(Offset.zero);
        heights[o.text.toPlainText()] = o.size.height;
      }
      o.visitChildren(visit);
    }

    final root = tester.renderObject(find.byType(NodeView));
    visit(root);
    final origin = (root as RenderBox).localToGlobal(Offset.zero);
    expect(at['N0']!.dx - origin.dx, closeTo(18, 0.5));
    // The header's 2 px line takes room: its label centres in the 48 above it.
    expect(at['Name']!.dy - origin.dy, closeTo((48 - heights['Name']!) / 2, 0.01));

    final image = await tester.runAsync(() => captureImage(tester.element(find.byType(NodeView))));
    final bytes = (await tester.runAsync(() => image!.toByteData()))!;
    Color at2(int x, int y) {
      final i = (y * image!.width + x) * 4;
      return Color.fromARGB(bytes.getUint8(i + 3), bytes.getUint8(i), bytes.getUint8(i + 1), bytes.getUint8(i + 2));
    }

    // Header border: the last row of the 50 px header is red.
    expect(at2(300, 49), const Color(0xFFFF0000));
    // Selected row (the second body row, y 100..150): green, a blue bar first.
    expect(at2(300, 125), const Color(0xFF00FF00));
    expect(at2(1, 125), const Color(0xFF0000FF));
  });
}
