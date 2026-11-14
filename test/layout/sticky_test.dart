// Sticky section headers and view progress in a scrolling column (Strata
// v2 benchmark: a canyon wall's layer headers pin while their layer
// scrolls, and figures draw themselves as they scroll up the screen).
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/screen.dart' as wiring show show;
import '../gestures/sliders_and_knobs_test.dart' show textOf;
import 'scroll_test.dart' show viewport;

Json _click(String v) => {
      'trigger': {'type': 'click'},
      'actions': [
        {'type': 'setVariable', 'variable': 'clicked', 'value': v},
      ],
    };

/// A 200×200 scrolling column of two sections, each a 40 px sticky header
/// over a 300 px body; the bodies measure a line 40 px down the view
/// passing over them, writing it to `progress.<section>`.
Map<String, Json> sections({bool stickyStyle = false}) => {
      'col': {
        'type': 'column',
        'props': {'scrollable': true},
        'layout': {'width': 200, 'height': 200},
        'children': ['secA', 'secB', 'tail'],
      },
      for (final s in ['A', 'B']) ...{
        'sec$s': {
          'type': 'column',
          'layout': {'width': 200, 'height': {'hug': 340}},
          'children': ['head$s', 'body$s'],
        },
        'head$s': {
          'type': 'box',
          'layout': {'width': 200, 'height': 40},
          'sticky': true,
          'decoration': {
            'fills': [
              {'color': '#FFAA0000'},
            ],
          },
          'actions': [_click('head$s')],
          if (stickyStyle) 'bind': {'opacity': r'${= sticky.stuck ? 0.5 : 1}'},
        },
        'body$s': {
          'type': 'column',
          'layout': {'width': 200, 'height': 300},
          'viewProgress': {'mode': 'pass', 'from': 0, 'offset': 40, 'variable': 'progress', 'key': s},
          'children': ['label$s'],
          'actions': [_click('body$s')],
        },
        'label$s': {
          'type': 'text',
          'layout': {'width': 200, 'height': 20},
          'props': {'text': r'${view.progress}'},
        },
      },
      'tail': {
        'type': 'box',
        'layout': {'width': 200, 'height': 400},
      },
    };

double _top(NodeTree tree, String id) => tree.boxOf(id)!.contentBox!.localToGlobal(Offset.zero).dy;

void main() {
  testWidgets('a sticky header stays at the top while its section scrolls, then is pushed away by the next', (tester) async {
    final screen = await wiring.show(tester, sections(), variables: [const Variable(name: 'clicked', value: '')]);
    final view = viewport(screen.tree);
    final top = view.localToGlobal(Offset.zero).dy;
    expect(_top(screen.tree, 'headA') - top, closeTo(0, .01));

    await view.scrollTo(100);
    await tester.pump();
    await tester.pump();
    expect(_top(screen.tree, 'headA') - top, closeTo(0, .01), reason: 'pinned');
    expect(_top(screen.tree, 'bodyA') - top, closeTo(-60, .01));
    // the pinned header takes the tap, not the body scrolling under it
    await tester.tapAt(view.localToGlobal(const Offset(100, 20)));
    await tester.pump();
    expect(screen['clicked'], 'headA');

    await view.scrollTo(330);
    await tester.pump();
    await tester.pump();
    // section A ends 10 px down the view: its header is pushed up with it
    expect(_top(screen.tree, 'headA') - top, closeTo(-30, .01));

    await view.scrollTo(400);
    await tester.pump();
    await tester.pump();
    expect(_top(screen.tree, 'headB') - top, closeTo(0, .01));
    await tester.tapAt(view.localToGlobal(const Offset(100, 20)));
    await tester.pump();
    expect(screen['clicked'], 'headB');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a sticky node can style itself while it is stuck', (tester) async {
    final screen = await wiring.show(tester, sections(stickyStyle: true));
    final view = viewport(screen.tree);
    expect(screen.tree.boxOf('headA')!.node!.opacity, 1);
    await view.scrollTo(100);
    await tester.pump();
    await tester.pump();
    expect(screen.tree.boxOf('headA')!.node!.opacity, .5);
    await view.scrollTo(0);
    await tester.pump();
    await tester.pump();
    expect(screen.tree.boxOf('headA')!.node!.opacity, 1);
  });

  testWidgets('scroll progress follows a node through the view and writes it to a variable', (tester) async {
    final screen = await wiring.show(tester, sections(), variables: [
      const Variable(name: 'progress', type: VariableType.map, value: <String, Object?>{}),
    ]);
    final view = viewport(screen.tree);
    await tester.pump();
    expect((screen['progress'] as Map)['A'], 0);
    expect((screen['progress'] as Map)['B'], 0);

    await view.scrollTo(100);
    await tester.pump();
    await tester.pump();
    // the line (40 px down) is 100 px into body A's 300
    expect((screen['progress'] as Map)['A'], closeTo(.333, .001));
    expect(textOf(screen.tree, 'labelA'), '0.333');

    await view.scrollTo(500);
    await tester.pump();
    await tester.pump();
    expect((screen['progress'] as Map)['A'], 1);
    // body B starts at 380: the line is at 540, 160 into it
    expect((screen['progress'] as Map)['B'], closeTo(.533, .001));
  });

  testWidgets('on the design canvas scroll progress shows its finished state and nothing sticks', (tester) async {
    final screen = await wiring.show(tester, sections(), interactive: false);
    await tester.pump();
    expect(textOf(screen.tree, 'labelA'), '1');
    expect(textOf(screen.tree, 'labelB'), '1');
    expect(_top(screen.tree, 'headA'), closeTo(screen.tree.boxOf('secA')!.localToGlobal(Offset.zero).dy, .01));
  });
}
