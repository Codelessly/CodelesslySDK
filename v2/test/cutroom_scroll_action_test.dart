import 'package:codelessly_sdk_v2/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'lists/support.dart' as support;

void main() {
  testWidgets('axis-specific scrollTo reveals a node in a generic runtime column', (tester) async {
    final nodes = <String, Json>{
      'col': {
        'type': 'column',
        'layout': {'width': 200, 'height': 200},
        'props': {'scrollable': true},
        'children': ['a', 'b', 'c', 'd'],
      },
      for (final id in ['a', 'b', 'c', 'd'])
        id: {
          'type': 'box',
          'layout': {'width': 200, 'height': 100},
          'decoration': {
            'fills': [
              {'color': '#FF203638'},
            ],
          },
        },
    };
    nodes['a']!['actions'] = [
      support.reaction('click', [
        {'type': 'scrollTo', 'node': 'd', 'axis': 'vertical', 'alignment': 0, 'durationMs': 0},
      ]),
    ];
    final screen = await support.show(tester, nodes);
    RenderDesignScroll? viewport;
    void visit(RenderObject o) {
      if (o is RenderDesignScroll) viewport ??= o;
      o.visitChildren(visit);
    }

    visit(screen.tree.boxOf('col')!);
    await tester.tapAt(screen.center('a'));
    await tester.pump();
    expect(viewport!.pixels, 200);
    await tester.pumpWidget(const SizedBox());
  });
}
