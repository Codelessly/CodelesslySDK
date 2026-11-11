// scrollTo with `item`: reveal one copy of a list's item template (Strata
// v2: the timeline and glossary jump to one layer among the wall's eleven).
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'actions/wiring_test.dart' as wiring show show;
import 'interactive_scroll_test.dart' show viewport;

Map<String, Json> page(String item) => {
      'col': {
        'type': 'column',
        'props': {'scrollable': true},
        'layout': {'width': 200, 'height': 200},
        'children': ['go', 'list'],
      },
      'go': {
        'type': 'box',
        'layout': {'width': 200, 'height': 40},
        'actions': [
          {
            'trigger': {'type': 'click'},
            'actions': [
              {'type': 'scrollTo', 'node': 'row', 'item': item, 'durationMs': 0},
            ],
          },
        ],
      },
      'list': {
        'type': 'listView',
        'props': {'scrollable': false},
        'layout': {'width': 200, 'height': {'hug': 500}},
        'bind': {'data': r'${rows}'},
        'children': ['row'],
      },
      'row': {
        'type': 'box',
        'layout': {'width': 200, 'height': 100},
      },
    };

const rows = Variable(name: 'rows', type: VariableType.list, value: [
  {'id': 'a'},
  {'id': 'b'},
  {'id': 'c'},
  {'id': 'd'},
  {'id': 'e'},
]);

void main() {
  for (final (item, expected) in [('c', 240.0), (r'${= "d"}', 340.0), ('1', 140.0)]) {
    testWidgets('scrollTo reveals the copy for item $item', (tester) async {
      final screen = await wiring.show(tester, page(item), variables: [rows]);
      final view = viewport(screen.tree);
      await tester.tapAt(view.localToGlobal(const Offset(100, 20)));
      await tester.pump();
      await tester.pump();
      expect(view.pixels, expected);
    });
  }

  testWidgets('without item, the first copy (unchanged behavior)', (tester) async {
    final screen = await wiring.show(tester, page(''), variables: [rows]);
    final view = viewport(screen.tree);
    await tester.tapAt(view.localToGlobal(const Offset(100, 20)));
    await tester.pump();
    expect(view.pixels, 40);
  });
}
