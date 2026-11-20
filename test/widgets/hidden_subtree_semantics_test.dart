// A subtree hidden by a condition leaves the render tree and comes back when
// the condition holds again. What changed in it while it was away (a row's
// check mark shown for the option just chosen) must reach the semantics
// tree: Flutter's semantics pass asserted `!semantics.parentDataDirty` on
// reopening a picker (NOCD 09, 28) and on a retry that swapped a list in
// (NOCD 12, 18).
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart' show Offset;
import 'package:flutter_test/flutter_test.dart';

import '../support/screen.dart' as harness;

void main() {
  testWidgets('a picker chosen, closed and opened again: its list, changed while hidden, is read without an assertion',
      (tester) async {
    final handle = tester.ensureSemantics();
    final s = await harness.show(
      tester,
      root: 'stack',
      {
        'stack': {
          'type': 'stack',
          'layout': {'width': 390, 'height': 500},
          'children': ['sheet', 'reopen'],
        },
        'sheet': {
          'type': 'column',
          'layout': {'width': {'fill': 0}, 'height': {'fill': 0}},
          'bind': {'visible': r'${= pickerVisible}'},
          'children': ['list'],
        },
        'list': {
          'type': 'listView',
          'layout': {'width': {'fill': 0}, 'height': {'fill': 0}},
          'bind': {'data': r'${items}'},
          'children': ['item'],
        },
        'item': {
          'type': 'row',
          'layout': {'width': {'fill': 0}, 'height': 48},
          'props': {'crossAxisAlignment': 'center'},
          'actions': [
            harness.reaction('click', [
              {'type': 'setVariable', 'variable': 'picked', 'value': r'${item}'},
              {'type': 'setVariable', 'variable': 'pickerVisible', 'value': r'${= false}'},
            ]),
          ],
          'children': ['label', 'check'],
        },
        'label': {
          'type': 'text',
          'layout': {'flex': 1, 'width': {'fill': 0}, 'height': {'hug': 0}},
          'props': {'text': r'${item}'},
        },
        'check': {
          'type': 'icon',
          'layout': {'width': {'hug': 0}, 'height': {'hug': 0}},
          'props': {'icon': 'check', 'size': 17},
          'bind': {'visible': r'${= item==picked}'},
        },
        'reopen': {
          'type': 'box',
          'layout': {'width': 120, 'height': 40},
          'bind': {'visible': r'${= !(pickerVisible)}'},
          'actions': [
            harness.reaction('click', [
              {'type': 'setVariable', 'variable': 'pickerVisible', 'value': r'${= true}'},
            ]),
          ],
        },
      },
      variables: [
        harness.v('picked', ''),
        harness.v('pickerVisible', true, VariableType.boolean),
        harness.v('items', ['Aetna', 'Ambetter', 'Cigna'], VariableType.list),
      ],
    );
    await tester.pump();
    final first = (s.tree.boxesOf('item').toList()..sort((a, b) => a.localToGlobal(Offset.zero).dy.compareTo(b.localToGlobal(Offset.zero).dy))).first;
    await tester.tapAt(first.localToGlobal(first.size.center(Offset.zero)));
    await tester.pump(const Duration(milliseconds: 350));
    expect(s['pickerVisible'], false);
    await tester.tapAt(s.center('reopen'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(s['pickerVisible'], true);
    expect(tester.takeException(), isNull);
    handle.dispose();
  });
}
