// Switchboard's mobile drawer: a column slid off-screen by a bound
// motion.translateX, eased by a transition on `motion`, opened by a click
// that sets the variable it reads.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/screen.dart';

void main() {
  testWidgets('a click slides a drawer in under a see-through scrim, and the scrim closes it', (tester) async {
    final s = await show(
      tester,
      {
        'col': {
          'type': 'stack',
          'children': ['btn', 'scrim', 'drawer'],
          'layout': {'width': 400, 'height': 400},
        },
        'btn': {
          'type': 'row',
          'layout': {
            'width': 40,
            'height': 40,
            'x': {'align': 1},
            'y': {'align': 1},
          },
          'actions': [
            reaction('click', [
              {'type': 'setVariable', 'variable': 'drawerOpen', 'value': 'true'},
            ]),
          ],
        },
        // Full-screen and see-through until the drawer opens: a tap on it
        // closes the drawer, so while hidden it must not take taps.
        'scrim': {
          'type': 'row',
          'layout': {
            'width': {'fill': 400},
            'height': {'fill': 400},
            'x': {'align': 0},
            'y': {'align': 0},
          },
          'decoration': {
            'fills': [
              {'opacity': 0.6, 'color': '#FF000000'},
            ],
          },
          'bind': {'opacity': r'${= drawerOpen ? 1 : 0}'},
          'opacity': 0,
          'transitions': [
            {'property': 'opacity', 'duration': 200, 'curve': 'easeOut'},
          ],
          'actions': [
            reaction('click', [
              {'type': 'setVariable', 'variable': 'drawerOpen', 'value': 'false'},
            ]),
          ],
        },
        'drawer': {
          'type': 'column',
          'layout': {
            'width': 280,
            'height': {'fill': 400},
            'x': {'align': -1},
            'y': {'align': 0},
          },
          'bind': {'motion.translateX': r'${= drawerOpen ? 0 : -290}'},
          'motion': {'translateX': -290},
          'transitions': [
            {'property': 'motion', 'duration': 240, 'curve': 'easeOutCubic'},
          ],
        },
      },
      variables: [v('drawerOpen', false, VariableType.boolean)],
    );
    await tester.pumpAndSettle();
    Rect drawer() => _rect(s, 'drawer');
    expect(drawer().left, -290);
    await tester.tapAt(s.center('btn'));
    await tester.pumpAndSettle();
    expect(s['drawerOpen'], true);
    expect(drawer().left, 0);
    await tester.tapAt(const Offset(390, 200));
    await tester.pumpAndSettle();
    expect(s['drawerOpen'], false);
    expect(drawer().left, -290);
  });

  testWidgets('a node at opacity 0 lets taps through to what is under it; seen again, it takes them', (tester) async {
    final s = await show(
      tester,
      {
        'col': {
          'type': 'stack',
          'children': ['under', 'over'],
          'layout': {'width': 200, 'height': 200},
        },
        'under': {
          'type': 'row',
          'layout': {
            'width': {'fill': 200},
            'height': {'fill': 200},
          },
          'actions': [
            reaction('click', [add('under')]),
          ],
        },
        'over': {
          'type': 'row',
          'layout': {
            'width': {'fill': 200},
            'height': {'fill': 200},
          },
          'bind': {'opacity': r'${shown ? 1 : 0}'},
          'opacity': 0,
          'actions': [
            reaction('click', [add('over')]),
          ],
        },
      },
      variables: [
        v('under', 0, VariableType.integer),
        v('over', 0, VariableType.integer),
        v('shown', false, VariableType.boolean),
      ],
    );
    await tester.tapAt(const Offset(100, 100));
    await tester.pumpAndSettle();
    expect((s['under'], s['over']), (1, 0));
    s.scope.set('shown', true);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(100, 100));
    await tester.pumpAndSettle();
    expect((s['under'], s['over']), (1, 1));
  });
}

Rect _rect(Screen s, String id) {
  final box = s.tree.boxOf(id)!;
  final content = box.contentBox ?? box;
  return content.localToGlobal(Offset.zero) & content.size;
}
