// A row of copies an `each` repeats (`Row gap=5` / `each day in week` /
// `ChoiceChip …`) wraps where the screen is narrow: the notation gives the
// list a media rule that wraps it, and its item template one that makes each
// copy as tall as it is (on one line it is as tall as its row). The template
// is read at the screen's size: test 10's chips were 0 tall on a phone.
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart' as lists;

Map<String, Json> _nodes() => {
      'r': {
        'type': 'row',
        'layout': {'width': {'fill': 0}, 'height': {'hug': 0}},
        'children': ['list'],
      },
      'list': {
        'type': 'listView',
        'layout': {'width': {'hug': 0}, 'height': {'hug': 0}},
        'props': {'scrollable': false, 'scrollDirection': 'horizontal', 'spacing': 4},
        'bind': {'data': r'${days}'},
        'children': ['cell'],
        'media': [
          {
            'maxWidth': 1023,
            'patch': {
              'layout': {'width': {'hug': null, 'fill': 0}},
              'props': {'wrap': true, 'wrapSpacing': 4, 'runSpacing': 4},
            },
          },
        ],
      },
      'cell': {
        'type': 'column',
        'layout': {'width': {'hug': 0}, 'height': {'fill': 0}},
        'children': ['label'],
        'media': [
          {
            'maxWidth': 1023,
            'patch': {
              'layout': {'height': {'fill': null, 'hug': 0}},
            },
          },
        ],
      },
      'label': {
        'type': 'text',
        'layout': {'width': 60, 'height': 20},
        'props': {'text': r'${item}'},
      },
    };

void main() {
  testWidgets('on a phone the copies wrap onto lines of their own, each as tall as it is', (tester) async {
    // The window is 800 wide (the test's), the screen a phone's: 20 copies
    // of 60 do not fit on one line.
    final s = await lists.show(tester, _nodes(), root: 'r', variables: [
      lists.v('days', List.generate(20, (i) => 'D\$i'), api.VariableType.list),
    ]);
    s.tree.responsive = ResponsiveWidth(api.Breakpoints.defaults, 390);
    await tester.pump();
    tester.takeException();
    s.tree.responsive = ResponsiveWidth(api.Breakpoints.defaults, 390);
    await tester.pump();
    final view = tester.renderObject(find.byType(NodeView));
    final rects = <Rect>[];
    void visit(RenderObject o) {
      if (o is NodeBox && o.id == 'cell') rects.add(o.rectIn(view)!);
      o.visitChildren(visit);
    }

    visit(view);
    expect(rects, hasLength(20));
    expect(rects.every((r) => r.height == 20), isTrue, reason: '${rects.map((r) => r.size)}');
    expect(rects.map((r) => r.top).toSet().length, greaterThan(1), reason: 'the copies wrap: 20 × 60 is wider than the window');
    expect(tester.takeException(), isNull);
  });
}
