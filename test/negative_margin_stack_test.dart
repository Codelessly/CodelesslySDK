// A child pinned to a padded stack's edges with a negative margin reaches
// past the padding (a modal's scrim covering the whole screen).
import 'package:flutter/rendering.dart';
import 'package:codelessly_sdk/src/render/layout/margin_box.dart';
import 'package:flutter_test/flutter_test.dart';
import 'actions/wiring_test.dart' as support;

void main() {
  testWidgets('a negative margin takes a pinned child past its stack\'s padding', (tester) async {
    final s = await support.show(
      tester,
      {
        'stack': {
          'type': 'stack',
          'layout': {'width': 300, 'height': 400, 'padding': [20, 20, 20, 20]},
          'children': ['scrim', 'card'],
        },
        'scrim': {
          'type': 'box',
          'layout': {
            'width': {'fill': 1},
            'height': {'fill': 1},
            'x': {'start': 0, 'end': 0},
            'y': {'start': 0, 'end': 0},
            'margin': [-20, -20, -20, -20],
          },
          'decoration': {'fills': [{'color': '#A6080503'}]},
        },
        'card': {'type': 'box', 'layout': {'width': 100, 'height': 100}},
      },
      root: 'stack',
    );
    // The scrim's box (inside its margin) covers the whole stack.
    final stack = s.tree.boxOf('stack')!;
    RenderBox? painted;
    void find(RenderObject o) {
      if (o is RenderMargin) painted ??= o.child;
      o.visitChildren(find);
    }

    find(stack);
    expect(painted, isNotNull, reason: 'a negative margin uses RenderMargin');
    expect(painted!.size, const Size(300, 400));
    expect(painted!.localToGlobal(Offset.zero) - stack.localToGlobal(Offset.zero), Offset.zero);
    expect(s.tree.boxOf('scrim')!.size, const Size(260, 360), reason: 'its place in the stack stays inside the padding');
  });
}
