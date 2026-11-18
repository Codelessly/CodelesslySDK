// A list as thick as its thickest item (a column of code lines inside a
// sideways scroll): an item that fills across is as thick as that item, so
// every line starts at the list's start, not centered in it.
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart' as lists;

Map<String, Json> _nodes() => {
      'sc': {
        'type': 'row',
        'layout': {'width': 600, 'height': {'hug': 0}},
        'props': {'scrollable': true, 'scrollDirection': 'horizontal'},
        'children': ['code'],
      },
      'code': {
        'type': 'column',
        'layout': {'width': {'hug': 0}, 'height': {'hug': 0}},
        'props': {'crossAxisAlignment': 'start'},
        'children': ['list'],
      },
      'list': {
        'type': 'listView',
        'layout': {'width': {'fill': 0}, 'height': {'hug': 0}},
        'props': {'scrollable': false},
        'bind': {'data': r'${lines}'},
        'children': ['line'],
      },
      'line': {
        'type': 'row',
        'layout': {'width': {'fill': 0}, 'height': {'hug': 0}},
        'children': ['tok'],
      },
      'tok': {
        'type': 'text',
        'layout': {'width': {'hug': 0}, 'height': {'hug': 0}},
        'props': {'text': r'${item}', 'style': {'fontSize': 13}},
      },
    };

void main() {
  testWidgets('every line starts at the list\'s start, as wide as the widest', (tester) async {
    await lists.show(tester, _nodes(), root: 'sc', variables: [
      lists.v('lines', ['a', 'a much longer line of code', 'bb'], api.VariableType.list),
    ]);
    final view = tester.renderObject(find.byType(NodeView));
    final rects = <Rect>[];
    void visit(RenderObject o) {
      if (o is NodeBox && o.id == 'line') rects.add(o.rectIn(view)!);
      o.visitChildren(visit);
    }

    visit(view);
    expect(rects, hasLength(3));
    expect(rects.map((r) => r.left).toSet(), hasLength(1));
    expect(rects.map((r) => r.width.round()).toSet(), hasLength(1));
  });
}
