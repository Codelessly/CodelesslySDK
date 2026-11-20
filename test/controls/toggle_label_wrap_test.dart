// A checkbox's long label (a consent line) wraps onto the lines its width
// needs, the control growing taller with the box beside the first line; it
// was cut to one line with an ellipsis. And a checkbox or radio given a box
// smaller than its touch target (18 × 18) is that box, not an 8 px mark in it.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/controls/toggles.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';
import 'toggles_support.dart';

const _consent = 'I agree to receive transactional messages about my appointments and account by text and email';

void main() {
  testWidgets('a long label wraps; the box sits beside its first line', (tester) async {
    final (tree, _) = runningTree(columnDoc({
      'cb': {
        'type': 'checkbox',
        'layout': {'width': {'fill': 0}, 'height': {'hug': 0}},
        'props': {'label': _consent},
      },
      'one': hugging('checkbox', {'label': 'Remember me'}),
    }, width: 300, height: 400));
    addTearDown(tree.dispose);
    await tester.pumpWidget(NodeView(tree: tree, rootId: 'col', interactive: true));
    final cb = controlIn<RenderToggle>(tree, 'cb');
    final glyphs = cb.labels.single.glyphs;
    final lines = {for (final g in glyphs) g.top.round()};
    expect(lines.length, greaterThan(1), reason: 'the label takes more than one line');
    expect(glyphs.every((g) => g.right <= cb.size.width + .5), isTrue, reason: 'nothing past its width');
    expect(cb.size.height, greaterThan(30), reason: 'the control is as tall as its lines');
    expect(cb.markRect.top, lessThan(glyphs.first.bottom), reason: 'the box beside the first line');
    // A short label is one line, centred on the box as before.
    final one = controlIn<RenderToggle>(tree, 'one');
    expect(one.labels.single.glyphs.map((g) => g.top.round()).toSet().length, 1);
    expect(one.markRect.center.dy, closeTo(one.size.height / 2, .5));
  });

  testWidgets('an 18 × 18 checkbox or radio is an 18 px mark; at 40 it is Flutter\'s 18 in its target', (tester) async {
    final (tree, _) = runningTree(columnDoc({
      'small': {'type': 'checkbox', 'layout': {'width': 18, 'height': 18}},
      'ring': {'type': 'radio', 'layout': {'width': 18, 'height': 18}, 'props': {'value': 'a'}},
      'target': {'type': 'checkbox', 'layout': {'width': 40, 'height': 40}},
      'big': {'type': 'checkbox', 'layout': {'width': 80, 'height': 80}},
    }));
    addTearDown(tree.dispose);
    await tester.pumpWidget(NodeView(tree: tree, rootId: 'col', interactive: true));
    expect(controlIn<RenderToggle>(tree, 'small').markRect.size, const Size(18, 18));
    expect(controlIn<RenderToggle>(tree, 'ring').markRect.size, const Size(18, 18));
    expect(controlIn<RenderToggle>(tree, 'target').markRect.size, const Size(18, 18));
    expect(controlIn<RenderToggle>(tree, 'big').markRect.size, const Size(36, 36));
  });
}
