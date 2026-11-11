// An input node with its own fill, border and padding draws them around its
// widget (the node's shell), the widget filling the padded box.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:codelessly_sdk/src/render/node_tree.dart' show RenderNodeDecoration;

import 'actions/wiring_test.dart' show show;

Iterable<RenderObject> _below(RenderObject r) sync* {
  final kids = <RenderObject>[];
  r.visitChildren(kids.add);
  for (final k in kids) {
    yield k;
    yield* _below(k);
  }
}

void main() {
  testWidgets('a decorated, padded dropdown draws its box around the widget', (tester) async {
    final s = await show(tester, {
      'col': {'type': 'column', 'children': ['d'], 'layout': {'width': 400, 'height': 100}},
      'd': {
        'type': 'dropdown',
        'layout': {'width': 220, 'height': 34, 'padding': [10, 0, 8, 0]},
        'decoration': {
          'fills': [{'color': '#FFFFFFFF'}],
          'strokes': [{'color': '#FFB8C2CE'}],
          'strokeWidth': 1,
          'radius': 4,
        },
        'props': {
          'items': ['Plan', 'Use'],
          'value': 'Plan',
          'isDense': true,
          'isExpanded': true,
          'underline': false,
        },
      },
    });
    await tester.pumpAndSettle();
    final box = s.tree.boxOf('d')!;
    expect(box.size, const Size(220, 34));
    final decorations = _below(box).whereType<RenderNodeDecoration>().toList();
    expect(decorations, isNotEmpty);
    expect((decorations.first.decoration as BoxDecoration).borderRadius, BorderRadius.circular(4));
    // The dropdown widget sits in the padded box: 220 less 10 + 8.
    final dropdown = tester.getRect(find.byType(DropdownButton<Object>));
    expect(dropdown.width, 202);
    expect(dropdown.left - tester.getTopLeft(find.byType(NodeView)).dx - box.localToGlobal(Offset.zero).dx, closeTo(10, 0.5));
  });

  testWidgets('an undecorated input keeps its bare widget', (tester) async {
    final s = await show(tester, {
      'col': {'type': 'column', 'children': ['d'], 'layout': {'width': 400, 'height': 100}},
      'd': {
        'type': 'dropdown',
        'layout': {'width': 220, 'height': 34},
        'props': {'items': ['Plan'], 'value': 'Plan', 'isExpanded': true},
      },
    });
    await tester.pumpAndSettle();
    expect(_below(s.tree.boxOf('d')!).whereType<RenderNodeDecoration>(), isEmpty);
    expect(tester.getRect(find.byType(DropdownButton<Object>)).width, 220);
  });
}
