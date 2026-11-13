// What the guide states about runtime behaviour (index.md sections 10 and 13),
// checked: `${result}` along a chain, a tap on a control inside a tappable
// row, and item/index/parent in nested lists.
import 'package:codelessly_sdk/codelessly_sdk.dart' show VariableType;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support.dart';

void main() {
  testWidgets('\${result} after a setVariable is still the trigger\'s (a text field\'s text)', (tester) async {
    final s = await show(tester, {
      'col': {'type': 'column', 'children': ['f'], 'layout': {'width': 300, 'height': {'hug': 100}}},
      'f': {'type': 'textField', 'layout': {'width': 300, 'height': 50},
        'actions': [reaction('changed', [
          {'type': 'setVariable', 'variable': 'a', 'value': r'${result}'},
          {'type': 'setVariable', 'variable': 'b', 'value': r'${result}'},
        ])]},
    }, variables: [v('a', ''), v('b', '')]);
    await tester.enterText(find.byType(EditableText), 'hey');
    await tester.pumpAndSettle();
    expect([s['a'], s['b']], ['hey', 'hey'], reason: 'setVariable gives no result: the next action still reads the text');
  });
  testWidgets('a checkbox inside a tappable row: each tap runs one handler', (tester) async {
    final s = await show(tester, {
      'col': {'type': 'row', 'children': ['cb'], 'layout': {'width': 300, 'height': 50},
        'actions': [reaction('click', [{'type': 'setVariable', 'variable': 'row', 'op': 'add', 'value': '1'}])]},
      'cb': {'type': 'checkbox', 'layout': {'width': 40, 'height': 40},
        'actions': [reaction('changed', [{'type': 'setVariable', 'variable': 'cb', 'op': 'add', 'value': '1'}])]},
    }, variables: [v('row', 0, VariableType.integer), v('cb', 0, VariableType.integer)]);
    await tester.tapAt(s.center('cb'));
    await tester.pumpAndSettle();
    expect([s['row'], s['cb']], [0, 1], reason: 'the control takes its own tap (the innermost gesture wins)');
    await tester.tapAt(const Offset(250, 25));
    await tester.pumpAndSettle();
    expect([s['row'], s['cb']], [1, 1], reason: 'the row takes a tap beside the control');
  });
  testWidgets('nested lists: item and index are the innermost; parent is the item around it', (tester) async {
    final s = await show(tester, {
      'col': {'type': 'column', 'children': ['outer'], 'layout': {'width': 300, 'height': {'hug': 100}}},
      'outer': {'type': 'listView', 'children': ['sec'], 'layout': {'width': {'fill': 300}, 'height': {'hug': 100}}, 'props': {'scrollable': false},
        'bind': {'data': r'${sections}'}},
      'sec': {'type': 'column', 'children': ['inner'], 'layout': {'width': {'fill': 300}, 'height': {'hug': 50}}},
      'inner': {'type': 'listView', 'children': ['t'], 'layout': {'width': {'fill': 300}, 'height': {'hug': 50}}, 'props': {'scrollable': false},
        'bind': {'data': r'${item.dishes}'}},
      't': {'type': 'text', 'layout': {'width': {'hug': 50}, 'height': {'hug': 20}}, 'props': {'text': r'${parent.item.name}/${parent.index}/${parent.name}:${item}#${index}', 'style': {'color': '#FF000000'}}},
    }, variables: [v('sections', [{'name': 'A', 'dishes': ['x', 'y']}, {'name': 'B', 'dishes': ['z']}], VariableType.list)]);
    await tester.pumpAndSettle();
    expect(textsUnder(s.tree.boxOf('col')!), ['A/0/A:x#0', 'A/0/A:y#1', 'B/1/B:z#0']);
  });
}
