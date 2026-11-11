// A table at rest (a design canvas) that fills its parent: its flex columns
// take the width it's laid out at and rows run past its design height.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  testWidgets('a filling table at rest widens its flex columns and shows more rows', (tester) async {
    await show(
      tester,
      {
        'col': {
          'type': 'column',
          'children': ['table'],
          'layout': {'width': 1000, 'height': 700},
        },
        'table': {
          'type': 'tableView',
          'layout': {
            'width': {'fill': 400},
            'height': {'fill': 200},
          },
          'bind': {'data': r'${rows}'},
          'slots': {'cell': 'cell', 'columnHeader': 'head'},
          'props': {
            'columns': [
              {'key': 'name', 'label': 'Name', 'flex': 1},
              {'key': 'code', 'label': 'Code', 'width': 100},
            ],
            'rowHeight': 50,
            'headerHeight': 50,
          },
        },
        'cell': {'type': 'text', 'layout': {'width': {'hug': 80}, 'height': {'hug': 20}}, 'props': {'text': r'${item.value}'}},
        'head': {'type': 'text', 'layout': {'width': {'hug': 80}, 'height': {'hug': 20}}, 'props': {'text': r'${item.label}'}},
      },
      variables: [
        v('rows', [
          for (var r = 0; r < 30; r++) {'name': 'N$r', 'code': 'C$r'},
        ], VariableType.list),
      ],
      interactive: false,
    );
    await tester.pumpAndSettle();
    final at = <String, Offset>{};
    void visit(RenderObject o) {
      if (o is RenderParagraph) at[o.text.toPlainText()] = o.localToGlobal(Offset.zero);
      o.visitChildren(visit);
    }

    visit(tester.renderObject(find.byType(NodeView)));
    // Laid out 800 wide (the test screen): the flex column takes 800 - 100,
    // so the code column starts at 700 (300 at the 400 design width).
    expect(at['Code']!.dx, closeTo(700, 1));
    // 600 tall: rows past the 200 design height show.
    expect(at.keys, containsAll(['N0', 'N9']));
  });
}
