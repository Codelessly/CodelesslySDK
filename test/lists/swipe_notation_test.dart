// A list row's SwipeAction is written in the notation, while a visible
// Actions button offers the same command to pointer and keyboard users.
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/controls/kit.dart'
    show firstTextUnder;
import 'package:codelessly_sdk/src/widgets/collections_swipe.dart'
    show SwipeActionsBox;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/keyboard.dart';

const _page = '''
state picked=""
state rows=[{"name":"Lift"}]
Page
  Section narrow
    Column
      each row in rows
        SwipeAction "Book" id:book side:end -> picked=result.item.name
        Row
          Text#className "{row.name}"
          Button#more "Actions" -> open rowMenu
    Text#picked "Chosen: {picked}"
Menu#rowMenu
  MenuItem#book "Book" -> picked="Lift"
''';

Future<UiSession> _show(
  WidgetTester tester, {
  double width = 800,
  TextDirection direction = TextDirection.ltr,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 700);
  addTearDown(tester.view.reset);
  final problems = <String>[];
  final ds = await tester.runAsync(
    () => api.DesignSystem.load((ref) async {
      final f = File('design_systems/cards/$ref');
      return f.existsSync() ? f.readAsStringSync() : null;
    }, problems: problems),
  );
  expect(problems, isEmpty);
  final session = UiSession(designSystem: ds);
  addTearDown(session.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: direction,
        child: Scaffold(body: CodelesslyView(session: session)),
      ),
    ),
  );
  final result = await session.applyNotation(Stream.value(_page.trimLeft()));
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(session.notationIssues, isEmpty);
  expect(result.errors, isEmpty, reason: '${result.errors}');
  return session;
}

NodeBox _box(WidgetTester tester, String id) {
  NodeBox? found;
  void visit(RenderObject o) {
    if (o is NodeBox && o.id == id) found = o;
    o.visitChildren(visit);
  }

  for (final v in tester.binding.renderViews) {
    visit(v);
  }
  expect(found, isNotNull, reason: id);
  return found!;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('pointer swipe and semantic action choose the row action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _show(tester);
    final box = _box(tester, 'className');
    await tester.dragFrom(
      box.localToGlobal(box.size.center(Offset.zero)),
      const Offset(-360, 0),
    );
    await _settle(tester);
    expect(firstTextUnder(_box(tester, 'picked')), 'Chosen: Lift');
    // The list exposes the same named action to assistive technology.
    final swipe = find.byType(SwipeActionsBox);
    expect(swipe, findsOneWidget);
    final data = tester.getSemantics(swipe);
    expect(data.getSemanticsData().customSemanticsActionIds, isNotEmpty);
    expect([
      for (final id in data.getSemanticsData().customSemanticsActionIds!)
        CustomSemanticsAction.getAction(id)!.label,
    ], contains('Book'));
    semantics.dispose();
  });

  testWidgets('keyboard opens the row menu and chooses the same Book command', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _show(tester);
    final keys = Keyboard(tester);
    for (var i = 0; i < 12 && keys.focusedText != 'Actions'; i++) {
      await keys.tab();
    }
    expect(keys.focusedText, 'Actions');
    expect(keys.ringShown, isTrue);
    expect(keys.semantics!.isButton, isTrue);
    expect(keys.semantics!.isFocused, isTrue);
    await keys.enter();
    await _settle(tester);
    expect(keys.inOverlay, isTrue);
    expect(keys.focusedText, 'Book');
    await keys.enter();
    await _settle(tester);
    expect(keys.inOverlay, isFalse);
    expect(keys.focusedText, 'Actions');
    expect(firstTextUnder(_box(tester, 'picked')), 'Chosen: Lift');
    semantics.dispose();
  });

  testWidgets(
    'at phone width the end action mirrors under right-to-left text',
    (tester) async {
      await _show(tester, width: 390, direction: TextDirection.rtl);
      final box = _box(tester, 'className');
      await tester.dragFrom(
        box.localToGlobal(box.size.center(Offset.zero)),
        const Offset(260, 0),
      );
      await _settle(tester);
      expect(firstTextUnder(_box(tester, 'picked')), 'Chosen: Lift');
    },
  );
}
