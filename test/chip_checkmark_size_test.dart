// A selectable chip's checkmark is drawn in its avatar box: avatarSize sizes
// it, with or without an avatar.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
