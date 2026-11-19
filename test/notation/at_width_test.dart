// A design at a width (codelessly_api docs/design/24-a-design-at-a-width.md):
// a part's `at phone` block, its own lines brought again by `...#id`, is two
// nodes for each such line, one shown at a time. What a window that crosses
// the bound keeps: the text typed (a variable both bind), and per node, the
// focus, the caret and the scroll position, which the other node does not
// have. Measured here, as the renderer does it today (no change for it).
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/controls/text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/cards.dart' show boxesOf, rectOf, settle;
import '../support/fields.dart';

final _items = [for (var i = 1; i <= 40; i++) '"Item $i"'].join(',');

final _page = '''
state q=""
state items=[$_items]
Column#page w=fill h=fill
  Row#bar w=fill pad=16 gap=16 middle
    Text#brand "Acme"
    Input#search "Search" @q w=280
    at phone
      Column w=fill gap=8
        ...#search
        ...#brand
  Column#main w=fill grow
    Column#list w=fill h=400 scroll
      each it in items
        Text "{it}" h=40
    at phone
      Column w=fill h=fill
        ...#list
''';

Future<UiSession> _show(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final session = UiSession();
  addTearDown(session.dispose);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: CodelesslyView(session: session))));
  final result = await session.applyNotation(Stream.value(_page), options: const api.NotationOptions(width: 1440));
  await settle(tester, 800);
  expect(session.notationIssues, isEmpty);
  expect(result.errors, isEmpty, reason: '${result.errors}');
  return session;
}

Future<void> _resize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  await settle(tester);
}

/// The text field of node [id] (its box drawn or not).
RenderTextField _field(WidgetTester tester, String id) {
  RenderTextField? found;
  void visit(RenderObject o) {
    if (found != null) return;
    if (o is RenderTextField) {
      found = o;
      return;
    }
    o.visitChildren(visit);
  }

  for (final b in boxesOf(tester, id)) {
    visit(b);
  }
  expect(found, isNotNull, reason: 'no text field in "$id"');
  return found!;
}

bool _drawn(WidgetTester tester, String id) => boxesOf(tester, id).any((b) => b.drawn);

/// Where the first copy of the list's text is drawn (it moves up as the list scrolls).
double _firstRowTop(WidgetTester tester, String list) => rectOf(tester, list).top - _rowsTop(tester, list);

double _rowsTop(WidgetTester tester, String list) {
  RenderParagraph? first;
  void visit(RenderObject o) {
    if (first != null) return;
    if (o is RenderParagraph && o.text.toPlainText() == 'Item 1') {
      first = o;
      return;
    }
    o.visitChildren(visit);
  }

  for (final b in boxesOf(tester, list)) {
    visit(b);
  }
  return first!.localToGlobal(Offset.zero).dy;
}

void main() {
  testWidgets('across the phone bound: the text is kept; the focus, the caret and the scroll are each node\'s own', (tester) async {
    await _show(tester, const Size(1440, 900));
    expect(_drawn(tester, 'search'), isTrue);
    expect(_drawn(tester, 'search_phone'), isFalse);

    // On a desktop: type into the search, put the caret after "he", scroll the list.
    final wide = _field(tester, 'search');
    await typeInto(tester, 'hello', field: wide);
    wide.editor.value = wide.editor.value.copyWith(selection: const TextSelection.collapsed(offset: 2));
    await tester.pump();
    await tester.dragFrom(rectOf(tester, 'list').center, const Offset(0, -300));
    await settle(tester);
    final scrolled = _firstRowTop(tester, 'list');
    expect(scrolled, greaterThan(0), reason: 'the desktop list scrolled');
    expect(wide.focusNode.hasFocus, isTrue);

    // Narrowed to a phone: the copy shows, with the text typed (the variable
    // both bind) and none of the rest.
    await _resize(tester, const Size(390, 844));
    expect(_drawn(tester, 'search'), isFalse);
    expect(_drawn(tester, 'search_phone'), isTrue);
    final narrow = _field(tester, 'search_phone');
    expect(narrow.editor.text, 'hello', reason: 'the text is the variable q');
    final facts = <String, Object?>{
      'phone copy focused': narrow.focusNode.hasFocus,
      'phone copy caret': narrow.editor.selection.baseOffset,
      'hidden desktop field still focused': wide.focusNode.hasFocus,
      'phone list scrolled by': _firstRowTop(tester, 'list_phone'),
    };

    // Typed on the phone: the desktop field reads it back through q.
    await typeInto(tester, 'hello world', field: narrow);
    facts['desktop field focused after typing on the phone'] = wide.focusNode.hasFocus;

    // Widened again: the desktop's own field and list, as they were left?
    await _resize(tester, const Size(1440, 900));
    expect(_drawn(tester, 'search'), isTrue);
    facts['back on the desktop: its field shows'] = wide.editor.text;
    facts['back on the desktop: its field focused'] = wide.focusNode.hasFocus;
    facts['back on the desktop: its caret'] = wide.editor.selection.baseOffset;
    facts['back on the desktop: its list scrolled by'] = _firstRowTop(tester, 'list');
    facts['desktop list scrolled by before'] = scrolled;
    // ignore: avoid_print
    print('AT-WIDTH FACTS ${facts.entries.map((e) => '${e.key}=${e.value}').join('; ')}');

    // What holds, as measured: the text is shared; the phone's copy starts
    // with no focus and its list at the top; the desktop's list keeps where
    // it was scrolled to (its hidden node keeps its state).
    expect(wide.editor.text, 'hello world');
    expect(facts['phone copy focused'], isFalse);
    expect(facts['phone list scrolled by'], 0);
    expect(facts['back on the desktop: its list scrolled by'], scrolled);
  });
}
