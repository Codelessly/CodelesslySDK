// A list that sticks to its end (ListViewProps.stickToEnd), as a chat or a
// log needs: it opens at the end, follows new items only while at the end,
// and keeps its place when older items are put in front.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

List<Object?> messages(int from, int to) => [for (var i = from; i < to; i++) {'id': i, 'text': 'M$i'}];

Map<String, Json> chat() => {
      'col': {
        'type': 'column',
        'children': ['list'],
        'layout': {'width': 300, 'height': 400},
      },
      'list': {
        'type': 'listView',
        'children': ['row'],
        'layout': {'width': 300, 'height': 400},
        'bind': {'data': r'${messages}'},
        'props': {'stickToEnd': true},
      },
      'row': {
        'type': 'text',
        'layout': {'width': 300, 'height': 40},
        'props': {'text': r'${item.text}'},
      },
    };

void main() {
  ScrollPosition position(WidgetTester tester) => tester
      .state<ScrollableState>(find.descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable)))
      .position;

  /// The message at the top of the list's 400-high viewport.
  String topRow(WidgetTester tester, Screen s) {
    final list = s.tree.boxOf('list')!;
    final top = list.localToGlobal(Offset.zero).dy;
    final hit = tester.renderObjectList<RenderBox>(find.byType(NodeView)).first;
    String? found;
    double best = double.infinity;
    void visit(RenderObject o) {
      if (o is RenderParagraph && o.attached && o.hasSize) {
        final y = o.localToGlobal(Offset.zero).dy;
        if (y >= top - 1 && y < best) {
          best = y;
          found = o.text.toPlainText();
        }
      }
      o.visitChildren(visit);
    }

    visit(hit);
    return found!;
  }

  testWidgets('opens at the end and follows new messages while there', (tester) async {
    final s = await show(tester, chat(), variables: [v('messages', messages(0, 30), VariableType.list)]);
    await tester.pumpAndSettle();
    final p = position(tester);
    expect(p.pixels, p.maxScrollExtent);
    expect(p.maxScrollExtent, 30 * 40 - 400);
    expect(topRow(tester, s), 'M20');

    s.scope.set('messages', messages(0, 31));
    await tester.pumpAndSettle();
    expect(p.pixels, p.maxScrollExtent);
    expect(topRow(tester, s), 'M21');
  });

  testWidgets('scrolled up, a new message does not move it; older ones put in front keep its place', (tester) async {
    final s = await show(tester, chat(), variables: [v('messages', messages(10, 40), VariableType.list)]);
    await tester.pumpAndSettle();
    final p = position(tester);
    p.jumpTo(p.maxScrollExtent - 200);
    await tester.pumpAndSettle();
    final reading = topRow(tester, s);
    expect(reading, 'M25');

    s.scope.set('messages', messages(10, 41));
    await tester.pumpAndSettle();
    expect(topRow(tester, s), reading, reason: 'a new message while scrolled up');

    // Older messages loaded in front.
    s.scope.set('messages', messages(0, 41));
    await tester.pumpAndSettle();
    expect(topRow(tester, s), reading, reason: 'older messages put in front');
    // And they are there above it.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 4000));
    await tester.pumpAndSettle();
    expect(topRow(tester, s), 'M0');

    // Back at the end, it follows again.
    p.jumpTo(p.maxScrollExtent);
    await tester.pumpAndSettle();
    s.scope.set('messages', messages(0, 42));
    await tester.pumpAndSettle();
    expect(p.pixels, p.maxScrollExtent);
    expect(topRow(tester, s), 'M32');
  });
}
