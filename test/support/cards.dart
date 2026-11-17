// A page written in the notation, shown with the Cards design system: what
// a behavior test of a Cards block starts from.
//
//   final session = await showCards(tester, 'Page\n  Section\n    Button#go "Go"');
//   await tester.tapAt(centerOf(tester, 'go'));
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/controls/kit.dart' show firstTextUnder;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shows [notation] (a whole page) at [size] and lets it settle.
Future<UiSession> showCards(
  WidgetTester tester,
  String notation, {
  Size size = const Size(1280, 800),
  bool dark = false,
  String designSystem = 'design_systems/cards',
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final problems = <String>[];
  final ds = await tester.runAsync(() => api.DesignSystem.load((ref) async {
        final file = File('$designSystem/$ref');
        return file.existsSync() ? file.readAsStringSync() : null;
      }, problems: problems));
  expect(problems, isEmpty);
  final session = UiSession(designSystem: ds);
  addTearDown(session.dispose);
  await tester.pumpWidget(
      MaterialApp(themeMode: dark ? ThemeMode.dark : ThemeMode.light, home: Scaffold(body: CodelesslyView(session: session))));
  final result = await session.applyNotation(Stream.value(notation.trimLeft()));
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(session.notationIssues, isEmpty);
  expect(result.errors, isEmpty, reason: '${result.errors}');
  return session;
}

/// Every attached box of node [id], in paint order.
List<NodeBox> boxesOf(WidgetTester tester, String id) {
  final found = <NodeBox>[];
  void visit(RenderObject o) {
    // A node by its id; a component's call by its id (its box is the
    // component's root) and a node inside one by its path (`card/title`).
    if (o is NodeBox && o.attached && (o.id == id || o.tree.pathOf(o.id, o.instance) == id)) found.add(o);
    o.visitChildren(visit);
  }

  for (final view in tester.binding.renderViews) {
    visit(view);
  }
  return found;
}

/// The (last) box of node [id]; fails when there is none.
NodeBox boxOf(WidgetTester tester, String id) {
  final all = boxesOf(tester, id);
  expect(all, isNotEmpty, reason: 'no node "$id" on screen');
  return all.last;
}

/// Whether node [id] is on screen.
bool shown(WidgetTester tester, String id) => boxesOf(tester, id).isNotEmpty;

Offset centerOf(WidgetTester tester, String id) {
  final b = boxOf(tester, id);
  return b.localToGlobal(b.size.center(Offset.zero));
}

Rect rectOf(WidgetTester tester, String id) {
  final b = boxOf(tester, id);
  return b.localToGlobal(Offset.zero) & b.size;
}

/// The text node [id] shows.
String textOf(WidgetTester tester, String id) => firstTextUnder(boxOf(tester, id)) ?? '';

/// Lets [ms] pass in frames.
Future<void> settle(WidgetTester tester, [int ms = 600]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
