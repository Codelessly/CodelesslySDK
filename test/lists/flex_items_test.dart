// A non-scrolling list's items that fill along it share its length by
// their flex, as a Row's Expanded children: a bar of segments sized by data.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  testWidgets('fill items of a list that keeps its width share it by their bound flex', (tester) async {
    final s = await show(tester, {
      'col': {'type': 'column', 'children': ['bar'], 'layout': {'width': 300, 'height': 400}},
      'bar': {
        'type': 'listView',
        'children': ['seg'],
        'layout': {'width': 300, 'height': 18},
        'props': {'scrollable': false, 'scrollDirection': 'horizontal'},
        'bind': {'data': r'${counts}'},
      },
      'seg': {
        'type': 'box',
        'layout': {'width': {'fill': 10}, 'height': {'fill': 18}},
        'bind': {'layout.flex': r'${item}'},
      },
    }, variables: [v('counts', [1, 2, 3], VariableType.list)]);
    final segs = <NodeBox>[];
    void visit(RenderObject o) {
      if (o is NodeBox && o.id == 'seg') segs.add(o);
      o.visitChildren(visit);
    }

    visit(s.tree.boxOf('bar')!);
    expect([for (final b in segs) b.size.width], [50, 100, 150]);
  });
}
