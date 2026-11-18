// The notation's words with their further parameters, rendered with Cards:
// a block's mark= marks what a search matched, and a row's menu reads the
// row that was pressed.
import 'package:flutter/gestures.dart' show kSecondaryMouseButton, PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/cards.dart';

/// The parts of the paragraphs under [box] drawn bold.
List<String> _bold(RenderObject box) {
  final out = <String>[];
  void visit(RenderObject o) {
    if (o is RenderParagraph) {
      o.text.visitChildren((span) {
        if (span is TextSpan && span.style?.fontWeight == FontWeight.w700 && (span.text ?? '').isNotEmpty) out.add(span.text!);
        return true;
      });
    }
    o.visitChildren(visit);
  }

  visit(box);
  return out;
}

/// A mouse's secondary button pressed and released at [at].
Future<void> _rightClick(WidgetTester tester, Offset at) async {
  final mouse = TestPointer(93, PointerDeviceKind.mouse, 93, kSecondaryMouseButton);
  await tester.sendEventToBinding(mouse.hover(at));
  await tester.sendEventToBinding(mouse.down(at));
  await tester.pump(const Duration(milliseconds: 40));
  await tester.sendEventToBinding(mouse.up());
  await tester.pump();
  await tester.sendEventToBinding(mouse.removePointer(location: at));
}

void main() {
  testWidgets('mark= on a ListRow, a ConversationRow and a PostCard marks what fuzzy matched in their texts', (tester) async {
    await showCards(tester, '''
state q="adamens"
state people=[{"name":"Grace Hopper","note":"Navy"},{"name":"Ada Mensah","note":"Accra"}]
Page
  Section
    each p in fuzzy(people,q,x=>x.name)
      ListRow#lr "{p.name}" subtitle="{p.note}" mark={q}
      ConversationRow#cr name="{p.name}" subject="Lunch with {p.name}" mark={q}
      PostCard#pc title="{p.name} on queues" author="Priya Raman" mark={q}
''');
    for (final id in ['lr', 'cr', 'pc']) {
      expect(_bold(boxOf(tester, id)), containsAll(['Ada', 'Mens']), reason: id);
    }
  });

  testWidgets('a row\x27s menu reads the row pressed by its loop name, whichever row was pressed last', (tester) async {
    await showCards(tester, '''
state clips=[{"id":"a","name":"Alpha"},{"id":"b","name":"Beta"}]
state copied=""
Page
  Section
    each c in clips
      Row#row gap=8 menu=rowMenu
        Text "{c.name}"
    Text#out "copied={copied}"
Menu#rowMenu
  MenuItem#copyIt "Copy" onTap={copied=c.name}
''');
    Future<void> copyFrom(int row) async {
      final box = boxesOf(tester, 'row')[row];
      await _rightClick(tester, box.localToGlobal(box.size.center(Offset.zero)));
      await settle(tester);
      expect(shown(tester, 'copyIt'), isTrue, reason: 'the menu is open');
      await tester.tapAt(centerOf(tester, 'copyIt'));
      await settle(tester);
    }

    await copyFrom(1);
    expect(textOf(tester, 'out'), 'copied=Beta');
    await copyFrom(0);
    expect(textOf(tester, 'out'), 'copied=Alpha');
  });
}
