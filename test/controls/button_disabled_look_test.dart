// A button written off (`enabled=false`) with its own disabled look
// (`disabled.fill=#FFC7C9F8 disabled.color=#FFFFFFFF`): it draws that look,
// as written. (Its state style was never applied: it drew its enabled fill
// faded to half, a darker violet than the one written.)
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

Map<String, Object?> _button0({required bool enabled, bool ownLook = true}) => {
      'type': 'filledButton',
      'layout': {'width': 300, 'height': 48},
      'props': {
        'label': 'Next',
        'enabled': enabled,
        'style': {'backgroundColor': '#FF545CEA'},
      },
      if (ownLook)
        'states': {
          'disabled': {
            'b': {
              'props': {
                'style': {'backgroundColor': '#FFC7C9F8', 'foregroundColor': '#FFFFFFFF'},
              },
            },
          },
        },
    };

Future<NodeTree> _show(WidgetTester tester, Map<String, Object?> button) async {
  final (tree, _) = runningTree(columnDoc({'b': button}));
  addTearDown(tree.dispose);
  await tester.pumpWidget(NodeView(tree: tree, rootId: 'col', interactive: true));
  await tester.pumpAndSettle();
  return tree;
}

void main() {
  testWidgets('written off, it draws its disabled look as written, not faded', (tester) async {
    final tree = await _show(tester, _button0(enabled: false));
    final b = _button(tree, 'b');
    expect(b.fillColor, const Color(0xFFC7C9F8));
    expect(b.labelColor, const Color(0xFFFFFFFF));
    expect(b.paintedAlpha, 255);
    expect(b.enabled, isFalse);
  });

  testWidgets('on, it draws its own fill', (tester) async {
    final tree = await _show(tester, _button0(enabled: true));
    expect(_button(tree, 'b').fillColor, const Color(0xFF545CEA));
    expect(_button(tree, 'b').enabled, isTrue);
  });

  testWidgets('off with no disabled look of its own: its fill, faded', (tester) async {
    final tree = await _show(tester, _button0(enabled: false, ownLook: false));
    final b = _button(tree, 'b');
    expect(b.fillColor, const Color(0xFF545CEA));
    expect(b.paintedAlpha, 128);
  });
}
