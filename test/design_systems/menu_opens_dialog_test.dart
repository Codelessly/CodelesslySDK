// A menu item that opens a dialog closes its menu first: the menu is not
// left drawn under the dialog, and closing the dialog closes only it.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/cards.dart';
import '../support/keyboard.dart';

const _page = '''
state items=["Milk","Tea"]
state note=""
Page
  Section
    Text#count "{length(items)} items {note}"
    Row#line between
      Text "Milk"
      Button#more "More" onTap={open rowMenu}
Menu#rowMenu
  MenuItem#rename "Rename" icon="edit" onTap={note="renamed"}
  MenuItem#del "Delete" icon="delete" onTap={open confirmDelete}
Dialog#confirmDelete "Delete item?" "This removes it."
  Row gap=8
    Button.outline#cancel "Cancel" onTap={close}
    Button.destructive#yes "Delete" onTap={items=[]; close}
''';

void main() {
  for (final size in const [Size(1280, 800), Size(390, 844)]) {
    testWidgets('by pointer at ${size.width.round()}: the menu closes as its item opens the dialog', (tester) async {
      await showCards(tester, _page, size: size);
      await tester.tapAt(centerOf(tester, 'more'));
      await settle(tester);
      expect(shown(tester, 'rename'), isTrue);
      await tester.tapAt(centerOf(tester, 'del'));
      await settle(tester);
      expect(shown(tester, 'cancel'), isTrue, reason: 'the dialog is open');
      expect(shown(tester, 'rename'), isFalse, reason: 'the menu is not left under the dialog');
      await tester.tapAt(centerOf(tester, 'cancel'));
      await settle(tester);
      expect(shown(tester, 'cancel'), isFalse);
      expect(textOf(tester, 'count'), '2 items');
      // And again, this time confirming.
      await tester.tapAt(centerOf(tester, 'more'));
      await settle(tester);
      await tester.tapAt(centerOf(tester, 'del'));
      await settle(tester);
      await tester.tapAt(centerOf(tester, 'yes'));
      await settle(tester);
      expect(shown(tester, 'yes'), isFalse);
      expect(shown(tester, 'rename'), isFalse);
      expect(textOf(tester, 'count'), '0 items');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('by keyboard: Enter on the item opens the dialog over the page, Escape closes only it', (tester) async {
    await showCards(tester, _page);
    final keys = Keyboard(tester);
    for (var i = 0; i < 12 && keys.focusedId != 'more'; i++) {
      await keys.tab();
    }
    expect(keys.focusedId, 'more');
    await keys.enter();
    await settle(tester);
    expect(shown(tester, 'rename'), isTrue);
    await keys.down();
    await keys.enter();
    await settle(tester);
    expect(shown(tester, 'cancel'), isTrue);
    expect(shown(tester, 'rename'), isFalse);
    await keys.press(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(shown(tester, 'cancel'), isFalse);
    expect(shown(tester, 'more'), isTrue);
  });

  testWidgets('an item that does not open anything still closes its menu', (tester) async {
    await showCards(tester, _page);
    await tester.tapAt(centerOf(tester, 'more'));
    await settle(tester);
    await tester.tapAt(centerOf(tester, 'rename'));
    await settle(tester);
    expect(shown(tester, 'rename'), isFalse);
    expect(textOf(tester, 'count'), '2 items renamed');
  });
}
