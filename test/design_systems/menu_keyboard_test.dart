// A menu written in the notation (`Menu#id` after the page, opened with
// `-> open id`; under Cards its rows are MenuItem instances in a
// MenuPopover) is driven from the keyboard as the kit's dropdown menu is:
// the focus starts on its first item, Up and Down move through the enabled
// items, Home and End jump, a typed letter finds an item, Enter and Space
// choose, Escape closes and the focus returns to the button.
//
// Nothing here is written for menus: the rows are press targets (a click
// reaction), the popover a modal overlay, and MenuPopover's root has
// `focusGroup` (one Tab stop, the arrows move inside).
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/controls/focus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/keyboard.dart';

Future<api.DesignSystem> _cards() async {
  final problems = <String>[];
  final ds = await api.DesignSystem.load((ref) async {
    final f = File('design_systems/cards/$ref');
    return f.existsSync() ? f.readAsStringSync() : null;
  }, problems: problems);
  expect(problems, isEmpty);
  return ds;
}

const _page = '''
state sort="Newest"
Page
  Section
    Row gap:12 middle
      Button.outline#sortBtn "Sort" icon:"sort" -> open sortMenu
      Text#sorted "Sorted by {sort}"
      Button#other "Other"

Menu#sortMenu
  MenuItem#byNewest "Newest" icon:"schedule" -> sort="Newest"
  MenuItem#byPrice "Price" icon:"sell" -> sort="Price"
  MenuItem#byName "Name" enabled:false -> sort="Name"
  MenuItem#byRating "Rating" -> sort="Rating"
  MenuItem#byPopular "Popular" -> sort="Popular"
''';

String _texts(WidgetTester tester) {
  final out = StringBuffer();
  void visit(RenderObject o) {
    if (o is RenderParagraph) out.writeln(o.text.toPlainText());
    o.visitChildren(visit);
  }

  for (final v in tester.binding.renderViews) {
    visit(v);
  }
  return out.toString();
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<UiSession> _show(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1280, 800);
  addTearDown(tester.view.reset);
  final ds = await tester.runAsync(_cards);
  final session = UiSession(designSystem: ds);
  addTearDown(session.dispose);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: CodelesslyView(session: session))));
  final result = await session.applyNotation(Stream.value(_page.trimLeft()));
  await _settle(tester);
  expect(session.notationIssues, isEmpty);
  expect(result.errors, isEmpty, reason: '${result.errors}');
  return session;
}

Future<void> _tabToText(Keyboard keys, String text) async {
  for (var i = 0; i < 12 && keys.focusedText != text; i++) {
    await keys.tab();
  }
  expect(keys.focusedText, text);
}

/// Whether an overlay (the menu) holds the keyboard.
bool get _menuOpen => ControlFocusLayer.top != null;

void main() {
  testWidgets('opened from the keyboard: the first item has the focus; arrows, Home, End and letters move; Enter chooses', (tester) async {
    final handle = tester.ensureSemantics();
    await _show(tester);
    final keys = Keyboard(tester);
    await _tabToText(keys, 'Sort');
    await keys.enter();
    await _settle(tester);
    expect(_menuOpen, isTrue);
    expect(keys.inOverlay, isTrue);
    expect(keys.focusedText, 'Newest');
    expect(keys.ringShown, isTrue);
    // A menu is named after the button that opened it.
    expect(keys.routeName, 'Sort');
    // Down through the enabled items (Name is disabled), wrapping.
    await keys.down();
    expect(keys.focusedText, 'Price');
    await keys.down();
    expect(keys.focusedText, 'Rating');
    await keys.down();
    expect(keys.focusedText, 'Popular');
    await keys.down();
    expect(keys.focusedText, 'Newest');
    await keys.up();
    expect(keys.focusedText, 'Popular');
    await keys.home();
    expect(keys.focusedText, 'Newest');
    await keys.end();
    expect(keys.focusedText, 'Popular');
    // Type-ahead: a letter jumps to the next item that starts with it; the
    // same letter again goes on to the next.
    await keys.letter('p');
    expect(keys.focusedText, 'Price');
    await keys.letter('p');
    expect(keys.focusedText, 'Popular');
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 800)));
    await keys.letter('r');
    expect(keys.focusedText, 'Rating');
    // Left and Right are not a vertical menu's.
    await keys.right();
    expect(keys.focusedText, 'Rating');
    // The whole menu is one Tab stop: Tab stays in the overlay, on it.
    await keys.tab();
    expect(keys.focusedText, 'Rating');
    expect(keys.inOverlay, isTrue);
    // What a screen reader is told about the row with the focus.
    final row = keys.semantics!;
    expect(row.isButton, isTrue);
    expect(row.label, contains('Rating'));
    expect(row.isFocused, isTrue);
    expect(row.isEnabled, isTrue);
    await keys.enter();
    await _settle(tester);
    expect(_menuOpen, isFalse);
    expect(_texts(tester), contains('Sorted by Rating'));
    // The focus is back on the button, with its ring.
    expect(keys.focusedText, 'Sort');
    expect(keys.ringShown, isTrue);
    expect(keys.inOverlay, isFalse);
    handle.dispose();
  });

  testWidgets('Space chooses, Escape closes without choosing, and the focus returns to the button each time', (tester) async {
    await _show(tester);
    final keys = Keyboard(tester);
    await _tabToText(keys, 'Sort');
    await keys.space();
    await _settle(tester);
    expect(keys.focusedText, 'Newest');
    await keys.down();
    await keys.escape();
    await _settle(tester);
    expect(_menuOpen, isFalse);
    expect(_texts(tester), contains('Sorted by Newest'));
    expect(keys.focusedText, 'Sort');
    await keys.enter();
    await _settle(tester);
    expect(keys.focusedText, 'Newest');
    await keys.down();
    await keys.space();
    await _settle(tester);
    expect(_menuOpen, isFalse);
    expect(_texts(tester), contains('Sorted by Price'));
    expect(keys.focusedText, 'Sort');
    // The page's own order is as before: Tab goes on to the next button.
    await keys.tab();
    expect(keys.focusedText, 'Other');
  });

  testWidgets('opened by a pointer no row has a ring; an arrow starts the highlight, End goes to the last', (tester) async {
    await _show(tester);
    final keys = Keyboard(tester);
    // The button draws its own label: tap it by its box.
    await _tabToText(keys, 'Sort');
    final box = keys.focused!.owner;
    await keys.escape();
    expect(keys.focused, isNull);
    await tester.tapAt(box.localToGlobal(box.size.center(Offset.zero)));
    await _settle(tester);
    expect(_menuOpen, isTrue);
    expect(keys.focused, isNull);
    await keys.down();
    expect(keys.focusedText, 'Newest');
    expect(keys.ringShown, isTrue);
    await keys.escape();
    await _settle(tester);
    await tester.tapAt(box.localToGlobal(box.size.center(Offset.zero)));
    await _settle(tester);
    expect(keys.focused, isNull);
    await keys.end();
    expect(keys.focusedText, 'Popular');
  });
}
