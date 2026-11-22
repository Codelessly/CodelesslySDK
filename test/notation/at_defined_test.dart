// A defined word's own design at a width (codelessly_api docs/design/24-a-
// design-at-a-width.md, section 13): `at phone` in a definition, read where
// the word is used. Each use holds the part's own lines and the block's,
// one drawn at a time by the width it is shown at, whatever width the page
// was written at; the word's state is one for both.
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/cards.dart' show boxesOf, rectOf, settle, textOf;

const _page = '''
define Product "title" "price"
  state saved=false
  Column gap=8 w=fill
    Box#photo w=fill h=120 fill=#FFE5E7EB radius=8
    Column#words gap=2
      Text.strong#name "{title}"
      Text#cost "{saved ? 'Saved' : price}"
    Button#save "Save" onTap={saved=!saved}
    at phone
      Row gap=12 middle w=fill
        Box w=56 h=56 fill=#FFE5E7EB radius=8
        ...#words
        ...#save
define Shelf
  Row gap=16 w=fill
    ...
    at phone
      Column gap=12 w=fill
        ...
Column#page w=fill pad=16 gap=16
  Shelf
    Product#kettle "Kettle" "48"
    Product#mug "Mug" "14"
''';

Future<UiSession> _show(WidgetTester tester, Size size, {required double writtenAt}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final session = UiSession();
  addTearDown(session.dispose);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: CodelesslyView(session: session))));
  final result = await session.applyNotation(Stream.value(_page), options: api.NotationOptions(width: writtenAt));
  await settle(tester, 800);
  expect(session.notationIssues, isEmpty);
  expect(result.errors, isEmpty, reason: '${result.errors}');
  return session;
}

bool _drawn(WidgetTester tester, String id) => boxesOf(tester, id).any((b) => b.drawn);

void main() {
  for (final writtenAt in [390.0, 1440.0]) {
    testWidgets('a word\'s design at a width follows the width shown, written at ${writtenAt.toInt()}', (tester) async {
      await _show(tester, const Size(1440, 900), writtenAt: writtenAt);
      // On a desktop: the products side by side, each its own lines (photo over words).
      expect(_drawn(tester, 'photo_kettle'), isTrue);
      expect(_drawn(tester, 'words_kettle'), isTrue);
      expect(_drawn(tester, 'kettle_phone'), isFalse);
      expect(rectOf(tester, 'mug').left, greaterThan(rectOf(tester, 'kettle').right - 1));
      expect(rectOf(tester, 'words_kettle').top, greaterThan(rectOf(tester, 'photo_kettle').bottom - 1));
      await tester.tapAt(rectOf(tester, 'save_kettle').center);
      await settle(tester);
      expect(textOf(tester, 'cost_kettle'), 'Saved');
      expect(textOf(tester, 'cost_mug'), '14');

      // On a phone: the shelf is a column of the products read again, each a row (the word's own block).
      tester.view.physicalSize = const Size(390, 844);
      await settle(tester);
      expect(_drawn(tester, 'kettle'), isFalse);
      expect(_drawn(tester, 'kettle_phone'), isTrue);
      expect(_drawn(tester, 'mug_phone'), isTrue);
      expect(rectOf(tester, 'mug_phone').top, greaterThan(rectOf(tester, 'kettle_phone').bottom - 1));
      final words = boxesOf(tester, 'words_kettle_phone_2_phone').where((b) => b.drawn);
      expect(words, hasLength(1), reason: 'the copy\'s words, read again by its own block');
      // The word's state is one for both designs.
      expect(textOf(tester, 'cost_kettle_phone_2_phone'), 'Saved');
      expect(textOf(tester, 'cost_mug_phone_2_phone'), '14');
    });
  }
}
