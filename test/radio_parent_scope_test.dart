// A radio in an option list nested in a field list: its group value comes
// from the outer item (`parent.item`), so the chosen option shows its dot.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'actions/wiring_test.dart' show show, v;

void main() {
  for (final interactive in [true, false]) {
    testWidgets('a nested radio reads its group from parent.item (interactive: $interactive)', (tester) async {
      await show(
        tester,
        {
          'col': {'type': 'column', 'children': ['fields'], 'layout': {'width': 300, 'height': 300}},
          'fields': {
            'type': 'listView',
            'children': ['field'],
            'layout': {'width': 300, 'height': {'hug': 0}},
            'props': {'scrollable': false},
            'bind': {'data': r'${fields}'},
          },
          'field': {
            'type': 'listView',
            'children': ['option'],
            'layout': {'width': 300, 'height': {'hug': 0}},
            'props': {'scrollable': false},
            'bind': {'data': r'${item.optionItems}'},
          },
          'option': {
            'type': 'radio',
            'layout': {'width': 18, 'height': 18},
            'props': {'value': ''},
            'bind': {'props.value': r'${item.text}', 'props.groupValue': r'${parent.item.textValue}'},
          },
        },
        variables: [
          v('fields', [
            {
              'textValue': 'Team',
              'optionItems': [
                {'text': 'Solo'},
                {'text': 'Team'},
              ],
            },
          ], VariableType.list),
        ],
        interactive: interactive,
      );
      await tester.pumpAndSettle();
      final radios = tester.widgetList<Radio<String>>(find.byType(Radio<String>)).toList();
      expect(radios.map((r) => r.value), ['Solo', 'Team']);
      final groups = tester.widgetList<RadioGroup<String>>(find.byType(RadioGroup<String>)).toList();
      expect(groups.map((g) => g.groupValue), ['Team', 'Team']);
    });
  }
}
