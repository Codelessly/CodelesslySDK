// A sideways list that doesn't clip (clipBehavior: none) in a padded
// scrolling column draws its overflowing items into the column's padding,
// as Flutter's ListView in a padded SingleChildScrollView does (the send
// sheet's people row: the fifth tile peeks in at the screen's edge).
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  testWidgets('a list with clipBehavior none is not clipped at its own box', (tester) async {
    final s = await show(tester, {
      'col': {
        'type': 'column',
        'children': ['tiles'],
        'layout': {'width': 300, 'height': 400, 'padding': [16, 8, 16, 8]},
        'props': {'scrollable': true},
      },
      'tiles': {
        'type': 'listView',
        'children': ['tile'],
        'layout': {'width': {'fill': 268}, 'height': 90},
        'props': {'scrollDirection': 'horizontal', 'separator': 'space', 'spacing': 8, 'clipBehavior': 'none'},
        'bind': {'data': r'${items}'},
      },
      'tile': {'type': 'box', 'layout': {'width': 80, 'height': 90}},
    }, variables: [v('items', [1, 2, 3, 4, 5], VariableType.list)]);
    await tester.pumpAndSettle();
    final boxes = s.tree.boxesOf('tile').where((b) => b.attached && b.hasSize).toList()
      ..sort((a, b) => a.localToGlobal(Offset.zero).dx.compareTo(b.localToGlobal(Offset.zero).dx));
    // The fourth tile (x 280–360) overflows the list (16–284) into the padding.
    final tile = boxes[3];
    final clips = <String>[];
    RenderObject child = tile;
    for (var p = tile.parent; p != null; child = p, p = p.parent) {
      final clip = p.describeApproximatePaintClip(child);
      if (clip != null && p is RenderBox) {
        final global = MatrixUtils.transformRect(p.getTransformTo(null), clip);
        if (global.right < 300) clips.add('${p.runtimeType} ${global.right}');
      }
    }
    expect(clips, isEmpty);
  });
}
