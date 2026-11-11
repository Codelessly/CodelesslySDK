// A chip in a list nested in a list opens a picker (a modal) and, with its
// answer, updates the outer item: the chain resumes after the modal in the
// chip's item scope (item, parent).
import 'package:codelessly_api/codelessly_api.dart' as api show WidgetState;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

class PickerUi extends NoActionUi {
  const PickerUi();
  @override
  Future<Object?> openModal(OpenModalAction action, {Json params = const {}}) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return {'emoji': '🔥', 'for': params['kudos']};
  }
}

void main() {
  testWidgets('a nested chip\'s chain resumes after its modal with the result and the outer item', (tester) async {
    final s = await show(tester, {
      'col': {'type': 'column', 'children': ['cards'], 'layout': {'width': 400, 'height': 600}},
      'cards': {
        'type': 'listView',
        'children': ['card'],
        'layout': {'width': {'fill': 400}, 'height': {'hug': 10}},
        'props': {'scrollable': false},
        'bind': {'data': r'${kudos}'},
      },
      'card': {'type': 'column', 'children': ['chips'], 'layout': {'width': {'fill': 400}, 'height': {'hug': 10}}},
      'chips': {
        'type': 'listView',
        'children': ['chip'],
        'layout': {'width': {'fill': 400}, 'height': {'hug': 10}},
        'props': {'scrollable': false, 'scrollDirection': 'horizontal'},
        'bind': {'data': r"${= append(item.reactions, {emoji: '+', plus: true})}"},
      },
      'chip': {
        'type': 'box',
        'layout': {'width': 40, 'height': 30},
        'bind': {'opacity': r'${= pickerFor == parent.id ? 0.5 : 1}'},
        'actions': [
          reaction('click', [
            {'type': 'if', 'condition': {'left': r'${item.plus}', 'op': 'equalsTo', 'right': 'true'}, 'then': [
              {'type': 'setVariable', 'variable': 'pickerFor', 'value': r'${parent.id}'},
              {'type': 'openModal', 'to': 'picker', 'presentation': 'popover', 'params': {'kudos': r'${parent.id}'}},
              {'type': 'setVariable', 'variable': 'pickerFor', 'value': ''},
              {'type': 'setVariable', 'variable': 'picked', 'value': r'${result.emoji}'},
              {'type': 'setVariable', 'variable': 'kudos',
               'value': r"${= map(kudos, k => k.id == parent.id ? merge(k, {reactions: append(k.reactions, {emoji: result.emoji, by: ['maya']})}) : k)}"},
            ]},
          ]),
        ],
      },
    }, variables: [
      v('kudos', [
        {'id': 'k1', 'reactions': [{'emoji': '🎉', 'by': ['a']}]},
        {'id': 'k2', 'reactions': []},
      ], VariableType.list),
      v('pickerFor', ''),
      v('picked', ''),
    ], ui: const PickerUi());
    // Each card is a 30 px row of chips: the second card's only chip is its +.
    await tester.tapAt(const Offset(20, 45));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(s['picked'], '🔥');
    expect(s['pickerFor'], '');
    expect(((s['kudos'] as List)[1] as Map)['reactions'], [
      {'emoji': '🔥', 'by': ['maya']},
    ]);
  });

  testWidgets('with a real popover: the nested chip\'s chain resumes when the popover closes with a result', (tester) async {
    late BuildContext appContext;
    final ui = NavigatorActionUi(
      context: () => appContext,
      modal: (to, params) => SizedBox(key: ValueKey(to), width: 120, height: 40),
    );
    final s = await show(tester, {
      'col': {'type': 'column', 'children': ['cards'], 'layout': {'width': 400, 'height': 600}},
      'cards': {
        'type': 'listView',
        'children': ['card'],
        'layout': {'width': {'fill': 400}, 'height': {'hug': 10}},
        'props': {'scrollable': false},
        'bind': {'data': r'${kudos}'},
      },
      'card': {'type': 'column', 'children': ['chips'], 'layout': {'width': {'fill': 400}, 'height': {'hug': 10}}},
      'chips': {
        'type': 'listView',
        'children': ['chip'],
        'layout': {'width': {'fill': 400}, 'height': {'hug': 10}},
        'props': {'scrollable': false, 'scrollDirection': 'horizontal', 'wrap': true},
        'bind': {'data': r"${= append(item.reactions, {emoji: '+', plus: true})}"},
      },
      'chip': {
        'type': 'box',
        'layout': {'width': 40, 'height': 30},
        'actions': [
          reaction('click', [
            {'type': 'openModal', 'to': 'picker', 'presentation': 'popover', 'anchor': 'trigger', 'placement': 'belowStart'},
            {'type': 'setVariable', 'variable': 'picked', 'value': r'${result.emoji}:${parent.id}'},
          ]),
        ],
      },
    }, variables: [
      v('kudos', [
        {'id': 'k1', 'reactions': [{'emoji': '🎉', 'by': ['a']}]},
        {'id': 'k2', 'reactions': []},
      ], VariableType.list),
      v('picked', ''),
    ], ui: ui);
    appContext = tester.element(find.byType(NodeView));
    await tester.tapAt(const Offset(20, 45));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('picker')), findsOneWidget);
    Navigator.of(tester.element(find.byKey(const ValueKey('picker')))).pop({'emoji': '🔥'});
    await tester.pumpAndSettle();
    expect(s['picked'], '🔥:k2');
  });

  testWidgets('a hover style that adds a layer above the chip doesn\'t stop the chip\'s chain', (tester) async {
    late BuildContext appContext;
    final ui = NavigatorActionUi(
      context: () => appContext,
      modal: (to, params) => SizedBox(key: ValueKey(to), width: 120, height: 40),
    );
    final s = await show(tester, {
      'col': {'type': 'column', 'children': ['card'], 'layout': {'width': 400, 'height': 600}},
      'card': {
        'type': 'column',
        'children': ['chip'],
        'layout': {'width': {'fill': 400}, 'height': {'hug': 10}},
        // Hovered, the card lifts: a motion its box didn't have.
        'states': {
          'hovered': {'card': {'motion': {'translateX': -2, 'translateY': -2, 'duration': 180}}},
        },
      },
      'chip': {
        'type': 'box',
        'layout': {'width': 40, 'height': 30},
        'actions': [
          reaction('click', [
            {'type': 'openModal', 'to': 'picker', 'presentation': 'popover', 'anchor': 'trigger'},
            {'type': 'setVariable', 'variable': 'picked', 'value': r'${result.emoji}'},
          ]),
        ],
      },
    }, variables: [v('picked', '')], ui: ui);
    appContext = tester.element(find.byType(NodeView));
    await tester.tapAt(s.center('chip'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('picker')), findsOneWidget, reason: 'the popover opened');
    // The pointer leaves the card for the popover, and comes back.
    s.tree.setState('card', api.WidgetState.hovered, true);
    await tester.pump();
    s.tree.setState('card', api.WidgetState.hovered, false);
    await tester.pump();
    Navigator.of(tester.element(find.byKey(const ValueKey('picker')))).pop({'emoji': '🔥'});
    await tester.pumpAndSettle();
    expect(s['picked'], '🔥');
  });
}
