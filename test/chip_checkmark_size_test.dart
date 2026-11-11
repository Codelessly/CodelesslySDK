// A selectable chip's checkmark is drawn in its avatar box: avatarSize sizes
// it, with or without an avatar. The plain variant is exactly its padding
// around the check, a gap and the label (no Material spacing).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:codelessly_sdk/codelessly_sdk.dart';

import 'lists/support.dart';

void main() {
  testWidgets('avatarSize sets a filter chip\'s checkmark box', (tester) async {
    await show(tester, {
      'col': {'type': 'column', 'children': ['c'], 'layout': {'width': 300, 'height': 100}},
      'c': {
        'type': 'filterChip',
        'layout': {'width': {'hug': 0}, 'height': {'hug': 0}},
        'props': {'label': 'Slack', 'selected': true, 'avatarSize': 13},
      },
    });
    await tester.pumpAndSettle();
    expect(tester.widget<RawChip>(find.byType(RawChip)).avatarBoxConstraints, BoxConstraints.tight(const Size.square(13)));
  });

  testWidgets('without avatarSize the checkmark keeps Material\'s box', (tester) async {
    await show(tester, {
      'col': {'type': 'column', 'children': ['c'], 'layout': {'width': 300, 'height': 100}},
      'c': {
        'type': 'filterChip',
        'layout': {'width': {'hug': 0}, 'height': {'hug': 0}},
        'props': {'label': 'Slack', 'selected': true},
      },
    });
    await tester.pumpAndSettle();
    expect(tester.widget<RawChip>(find.byType(RawChip)).avatarBoxConstraints, isNull);
  });

  testWidgets('plain: exactly its padding around the check, the gap and the label', (tester) async {
    final s = await show(tester, {
      'col': {'type': 'column', 'children': ['c'], 'layout': {'width': 300, 'height': 100}, 'props': {'crossAxisAlignment': 'start'}},
      'c': {
        'type': 'filterChip',
        'layout': {'width': {'hug': 0}, 'height': {'hug': 0}},
        'props': {
          'variant': 'plain', 'label': 'Slack', 'avatarSize': 13, 'spacing': 4, 'padding': [10, 4, 10, 4],
          'labelStyle': {'fontSize': 12.5, 'height': 1.4286}, 'side': {'color': '#FF0B5CAD', 'width': 1},
          'shape': {'type': 'roundedRectangle', 'borderRadius': 3},
          'selectedColor': '#FF0B5CAD', 'backgroundColor': '#FFFFFFFF', 'checkmarkColor': '#FFFFFFFF',
        },
        'bind': {'props.selected': r'${on}'},
      },
    }, variables: [v('on', true, VariableType.boolean)]);
    await tester.pumpAndSettle();
    expect(find.byType(RawChip), findsNothing);
    final label = tester.getRect(find.text('Slack'));
    final check = tester.getRect(find.byIcon(Icons.check_rounded));
    expect(check.size, const Size(13, 13));
    expect(label.left - check.right, closeTo(4, 0.01));
    // The side adds to the padding (as a Flutter Container's border does):
    // 1 + 10 before the check, 10 + 1 after the label.
    final chip = tester.getRect(find.ancestor(of: find.text('Slack'), matching: find.byType(Container)).first);
    expect(check.left - chip.left, closeTo(11, 0.01));
    expect(chip.right - label.right, closeTo(11, 0.01));
    expect(chip.height, closeTo(1 + 4 + 12.5 * 1.4286 + 4 + 1, 0.5));
    // A tap toggles it (written back to the bound variable): no check when off.
    await tester.tap(find.text('Slack'));
    await tester.pumpAndSettle();
    expect(s['on'], isFalse);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
  });
}
