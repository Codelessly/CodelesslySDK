// A button given a width narrower than its scale's padding and its label:
// the scale's padding gives way before the label is cut (a 64 wide button
// 44 high drew "D…" for "Done", its 24 px sides leaving the word 16).
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/controls/buttons.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

RenderButton _button(NodeTree tree, String id) {
  RenderButton? found;
  void visit(RenderObject o) {
    if (o is RenderButton) found ??= o;
    o.visitChildren(visit);
  }

  visit(tree.boxOf(id)!);
  return found!;
}

Map<String, Object?> _sized(String type, String label, double w, double h, [Map<String, Object?> layout = const {}]) => {
      'type': type,
      'layout': {'width': w, 'height': h, ...layout},
      'props': {'label': label},
    };

void main() {
  testWidgets('the label shows whole where the box has room for it, less the scale\'s padding', (tester) async {
    final (tree, _) = runningTree(columnDoc({
      'done': _sized('textButton', 'Done', 64, 44),
      'post': _sized('filledButton', 'Post', 64, 44),
      'roomy': _sized('textButton', 'Done', 160, 44),
    }));
    addTearDown(tree.dispose);
    await tester.pumpWidget(NodeView(tree: tree, rootId: 'col', interactive: true));
    for (final id in ['done', 'post', 'roomy']) {
      expect(_button(tree, id).debugLabelCut, isFalse, reason: id);
    }
  });

  testWidgets('a padding the node writes is kept: the label is cut', (tester) async {
    final (tree, _) = runningTree(columnDoc({
      'padded': _sized('textButton', 'Done', 64, 44, {'padding': [24, 0, 24, 0]}),
    }));
    addTearDown(tree.dispose);
    await tester.pumpWidget(NodeView(tree: tree, rootId: 'col', interactive: true));
    expect(_button(tree, 'padded').debugLabelCut, isTrue);
  });
}
