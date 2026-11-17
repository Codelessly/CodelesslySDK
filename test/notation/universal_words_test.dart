// Universal words (codelessly_api docs/design/21-universal-words.md) as they
// run: a list chosen from by pointer and by keyboard (`selectable`), a row's
// and a chip's x (`removable`), a box written `disabled`, a list reordered
// with no handle (`reorder`). Each is the notation's line expanded and run.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_api/notation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lists/support.dart';
import '../support/keyboard.dart';

/// [text] expanded (open vocabulary, 390 wide) and shown running.
Future<Screen> run(WidgetTester tester, String text) async {
  final r = parseNotation(text, catalog: standardCatalog, options: const NotationOptions().open());
  expect(r.issues, isEmpty, reason: '${r.issues}');
  final doc = r.document;
  final nodes = {
    for (final e in (doc['nodes'] as Map).entries)
      if ((e.value as Map)['type'] != 'canvas') e.key as String: (e.value as Map).cast<String, Object?>(),
  };
  final root = ((doc['nodes'] as Map)['screen'] as Map)['children'] as List? ?? [((doc['nodes'] as Map)['screen'] as Map)['slots']?['body']];
  final variables = Variable.listFromJson((doc['variables'] as Map?)?['screen']);
  final s = await show(tester, nodes, variables: variables, root: '${root.first}');
  await tester.pumpAndSettle();
  return s;
}

const items = 'state items=[{"id":"a","name":"Alpha"},{"id":"b","name":"Beta"},{"id":"c","name":"Gamma"},{"id":"d","name":"Delta"}]\n';

void main() {
  group('selectable', () {
    const page = '${items}state said=""\nColumn selectable bind=sel onSelect={said="{length(result)} chosen"}\n  each it in items\n    Row pad=8\n      Text "{it.name}"\n';

    // A row of a list that is not reordered is told apart by its index (the
    // first is the item's own node).
    Object? at(int i) => i == 0 ? null : ('item', null, 'listView1', i);
    Offset rowOf(Screen s, String id) => s.center('listView1Item', instance: at('abcd'.indexOf(id)));

    Future<void> tapWith(WidgetTester tester, Offset at, [LogicalKeyboardKey? held]) async {
      if (held != null) await tester.sendKeyDownEvent(held);
      await tester.tapAt(at);
      if (held != null) await tester.sendKeyUpEvent(held);
      await tester.pumpAndSettle();
    }

    testWidgets('by pointer: a tap selects alone, Ctrl adds and removes, Shift takes a range, onSelect follows', (tester) async {
      final s = await run(tester, page);
      await tapWith(tester, rowOf(s, 'b'));
      expect(s['sel'], ['b']);
      expect(s['said'], '1 chosen');
      await tapWith(tester, rowOf(s, 'd'), LogicalKeyboardKey.controlLeft);
      expect(s['sel'], ['b', 'd']);
      await tapWith(tester, rowOf(s, 'b'), LogicalKeyboardKey.controlLeft);
      expect(s['sel'], ['d']);
      // Shift: from the last row chosen (d) to this one.
      // Shift: from the last row tapped (b, taken out with Ctrl) to this one.
      await tapWith(tester, rowOf(s, 'a'), LogicalKeyboardKey.shiftLeft);
      expect(s['sel'], ['a', 'b']);
      await tapWith(tester, rowOf(s, 'd'));
      await tapWith(tester, rowOf(s, 'b'), LogicalKeyboardKey.shiftLeft);
      expect(s['sel'], ['b', 'c', 'd']);
      await tapWith(tester, rowOf(s, 'c'));
      expect(s['sel'], ['c']);
      expect(s['said'], '1 chosen');
      // A row in the selection is in its selected state.
      expect(s.tree.statesOf('listView1Item', instance: at(2)), contains(api.WidgetState.selected));
      expect(s.tree.statesOf('listView1Item', instance: at(0)), isNot(contains(api.WidgetState.selected)));
    });

    testWidgets('by keyboard: Tab reaches the rows, arrows move, Space selects, Shift+Space a range, Ctrl+A all; announced selected', (tester) async {
      final semantics = tester.ensureSemantics();
      final s = await run(tester, page);
      final keys = Keyboard(tester);
      await keys.tab();
      expect(keys.focusedText, 'Alpha');
      await keys.space();
      expect(s['sel'], ['a']);
      expect(keys.semantics?.isSelected, isTrue);
      await keys.down();
      await keys.down();
      expect(keys.focusedText, 'Gamma');
      await keys.press(LogicalKeyboardKey.space, shift: true, character: ' ');
      expect(s['sel'], ['a', 'b', 'c']);
      expect(keys.semantics?.isSelected, isTrue);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA, character: 'a');
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(s['sel'], ['a', 'b', 'c', 'd']);
      expect(s['said'], '4 chosen');
      semantics.dispose();
    });
  });

  group('removable', () {
    testWidgets('a chip\'s x and a row\'s x fire onRemove', (tester) async {
      final s = await run(tester, 'state tags=["red","blue"]\nstate rows=2\nColumn\n  Row\n    each t in tags\n      Chip "{t}" onDelete={tags=without(tags,t)}\n  Row removable onRemove={rows=rows-1}\n    Text "A row"\n');
      // The input chip's x: Delete on the focused chip.
      await Keyboard(tester).tab();
      await Keyboard(tester).press(LogicalKeyboardKey.delete);
      expect(s['tags'], ['blue']);
      await tester.tapAt(s.center('row2Remove'));
      await tester.pumpAndSettle();
      expect(s['rows'], 1);
    });
  });

  group('disabled', () {
    testWidgets('a box written disabled takes no tap, and neither does what is in it', (tester) async {
      final s = await run(tester, 'state n=0\nstate off=true\nColumn\n  Card disabled={off} onTap={n=n+1}\n    Button "Inside" onTap={n=n+10}\n  Button "Enable" onTap={off=false}\n');
      await tester.tapAt(s.center('column2'));
      await tester.tapAt(s.center('filledButton1'));
      await tester.pumpAndSettle();
      expect(s['n'], 0);
      await tester.tapAt(s.center('filledButton2'));
      await tester.pumpAndSettle();
      await tester.tapAt(s.center('filledButton1'));
      await tester.pumpAndSettle();
      expect(s['n'], 10);
    });
  });

  group('reorder', () {
    testWidgets('a list written reorder with no handle is reordered by a long press, and onReorder has the new order', (tester) async {
      final s = await run(tester, '${items}state first=""\nColumn reorder onReorder={first=result[0].name}\n  each it in items\n    Row h=48\n      Text "{it.name}"\n');
      final from = s.center('listView1Item', instance: ('row', null, 'listView1', ('id', 'a')));
      final drag = await tester.startGesture(from, kind: PointerDeviceKind.touch);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      await drag.moveBy(const Offset(0, 20));
      await tester.pump();
      await drag.moveBy(const Offset(0, 90));
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();
      final order = [for (final i in s['items'] as List) (i as Map)['id']];
      expect(order.first, isNot('a'));
      expect(s['first'], (s['items'] as List).first['name']);
    });
  });
}
