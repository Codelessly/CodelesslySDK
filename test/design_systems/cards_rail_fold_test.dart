// Cards' sidebar words fold to their icons where their sidebar is a rail, and only there. An app's sidebar whose
// lines all fold is a rail of 64 on a tablet; one with a line written by hand stays as wide as written, and its
// words then keep their labels (they folded by the window's width alone: icons in a sidebar of 248). With a list
// between the sidebar and the main pane, no button for the drawer shows beside a rail.
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/cards.dart' show boxesOf, rectOf, settle;

const _folding = '''
    Brand#brand "Northstar" "Admin console" icon="hub"
    NavSection#group "People"
    NavItem#members "Members" icon="group" badge="50" selected
    NavItem#billing "Billing" icon="payments"
    Footer
      Account#me "Amara Okafor" "Workspace owner"''';

String _app(String sidebar, {String pane = ''}) => '''
App
  Sidebar#side
$sidebar
$pane  Main#main
    Text#hello "Hello"
''';

/// Shows [notation], written for a desktop (expanded at 1440), in a window of [size].
Future<void> _show(WidgetTester tester, String notation, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final ds = await tester.runAsync(() => api.DesignSystem.load((ref) async {
        final file = File('design_systems/cards/$ref');
        return file.existsSync() ? file.readAsStringSync() : null;
      }));
  final session = UiSession(designSystem: ds);
  addTearDown(session.dispose);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: CodelesslyView(session: session))));
  final result = await session.applyNotation(Stream.value(notation), options: api.NotationOptions.fromDesignSystem(ds!, width: 1440));
  await settle(tester, 800);
  expect(session.notationIssues, isEmpty);
  expect(result.errors, isEmpty, reason: '${result.errors}');
  tester.takeException();
}

/// Whether the node at [path] is drawn (it and what is above it).
bool _drawn(WidgetTester tester, String path) => boxesOf(tester, path).any((b) => b.drawn && b.size.width > 0);

void main() {
  testWidgets('a sidebar of folding words is a rail on a tablet: icons alone, the labels gone', (tester) async {
    await _show(tester, _app(_folding), const Size(834, 1112));
    expect(rectOf(tester, 'side').width, 64);
    expect(_drawn(tester, 'members/name'), isFalse);
    expect(_drawn(tester, 'members/count'), isFalse);
    expect(_drawn(tester, 'brand/words'), isFalse);
    expect(_drawn(tester, 'group/label'), isFalse);
    expect(_drawn(tester, 'group/rule'), isTrue);
    expect(_drawn(tester, 'me/accountWords'), isFalse);
    expect(rectOf(tester, 'members').right, lessThanOrEqualTo(64));
  });

  testWidgets('the same sidebar on a desktop is whole', (tester) async {
    await _show(tester, _app(_folding), const Size(1440, 900));
    expect(rectOf(tester, 'side').width, 248);
    for (final path in ['members/name', 'members/count', 'brand/words', 'group/label', 'me/accountWords']) {
      expect(_drawn(tester, path), isTrue, reason: path);
    }
    expect(_drawn(tester, 'group/rule'), isFalse);
  });

  testWidgets('with a line written by hand it stays as wide as written on a tablet, and its words keep their labels', (tester) async {
    await _show(tester, _app('$_folding\n    Row#hand gap=10 middle pad=[12,8,12,8]\n      Icon "bolt"\n      Text "Upgrade plan"'), const Size(834, 1112));
    expect(rectOf(tester, 'side').width, 248);
    for (final path in ['members/name', 'members/count', 'brand/words', 'group/label', 'me/accountWords']) {
      expect(_drawn(tester, path), isTrue, reason: path);
    }
    expect(_drawn(tester, 'group/rule'), isFalse);
    expect(rectOf(tester, 'members/name').width, greaterThan(60));
  });

  testWidgets("a writer's own rail folds them too, and rail on a line folds that line anywhere", (tester) async {
    await _show(
        tester,
        _app('    NavItem#members "Members" icon="group"\n    NavItem#billing "Billing" icon="payments"').replaceFirst('Sidebar#side', 'Sidebar#side tablet.w=72 hide=phone'),
        const Size(834, 1112));
    expect(rectOf(tester, 'side').width, 72);
    expect(_drawn(tester, 'members/name'), isFalse);

    await _show(tester, 'Column#page w=300\n  NavItem#whole "Members" icon="group"\n  NavItem#folded "Billing" icon="payments" rail\n', const Size(834, 1112));
    expect(_drawn(tester, 'whole/name'), isTrue);
    expect(_drawn(tester, 'folded/name'), isFalse);
  });

  testWidgets('with a list between the rail and the main pane, a tablet shows no button for the drawer', (tester) async {
    const pane = '  Pane#list w=400\n    Text "Inbox"\n';
    await _show(tester, _app(_folding, pane: pane), const Size(834, 1112));
    expect(rectOf(tester, 'side').width, 64);
    // The main pane starts with what the page wrote: nothing is put above it.
    expect(rectOf(tester, 'hello').top, rectOf(tester, 'main').top);

    // A sidebar the tablet drops (a line written by hand keeps it wide) gets the button there.
    await _show(tester, _app('$_folding\n    Row#hand gap=10\n      Icon "bolt"\n      Text "Upgrade"', pane: pane), const Size(834, 1112));
    expect(rectOf(tester, 'hello').top, greaterThan(rectOf(tester, 'main').top + 20));
  });
}
