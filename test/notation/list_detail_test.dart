// A list beside its detail, written once for a desktop (codelessly_api
// docs/design/13-compact-notation.md section 14), on a phone: the list fills
// the screen, a tap on a row (or Enter or Space on it) shows the detail with
// a back button, and the back button, Escape and the system back show the
// list again where it was. On a desktop the two stay side by side.
import 'dart:async';
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/cards.dart';
import '../support/keyboard.dart';

final _rows = [
  for (var i = 1; i <= 24; i++) '{"id":$i,"from":"Sender $i","subject":"Subject $i"}',
].join(',');

final _inbox = '''
state sel=1
state msgs=[$_rows]
App
  Sidebar
    Text.strong "Postbox"
    Row w=fill gap=10 middle pad=[10,7,10,7] radius=6
      Icon "inbox" size=18
      Text "Inbox"
  Pane#list w=320 pad=0 gap=0
    each m in msgs
      Row#msg pad=[16,12,16,12] gap=12 border-bottom=#FFE5E7EB fill={sel==m.id?"#142563EB":"#00000000"} onTap={sel=m.id}
        Column grow gap=2
          Text.strong "{m.from}"
          Text.muted "{m.subject}"
  Main#detail
    Nav
      Text.heading3#title "{find(msgs,x=>x.id==sel).subject}"
      Button "Reply"
    Column pad=24
      Text "{find(msgs,x=>x.id==sel).from}"
''';

/// [notation], written for a page 1280 wide, shown with the Cards design
/// system on a screen [size].
Future<UiSession> _show(WidgetTester tester, String notation, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final problems = <String>[];
  final ds = await tester.runAsync(() => api.DesignSystem.load((ref) async {
        final file = File('design_systems/cards/$ref');
        return file.existsSync() ? file.readAsStringSync() : null;
      }, problems: problems));
  expect(problems, isEmpty);
  final session = UiSession(designSystem: ds);
  addTearDown(session.dispose);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: CodelesslyView(session: session))));
  final result = await session.applyNotation(Stream.value(notation), options: NotationOptions.fromDesignSystem(ds!, width: 1280, named: true));
  await settle(tester, 800);
  expect(session.notationIssues, isEmpty);
  expect(result.errors, isEmpty, reason: '${result.errors}');
  return session;
}

/// Whether node [id] is drawn (a hidden one keeps its box, collapsed).
bool _drawn(WidgetTester tester, String id) => boxesOf(tester, id).any((b) => b.drawn);

/// The clock of the animation a pane plays as it shows in another's place.
AnimationClock _clock(WidgetTester tester, String id) {
  AnimationClock? found;
  void visit(RenderObject o) {
    if (found != null) return;
    if (o is RenderAnimations && o.clockOf('pane') != null) {
      found = o.clockOf('pane');
      return;
    }
    o.visitChildren(visit);
  }

  visit(boxOf(tester, id));
  expect(found, isNotNull, reason: 'no animation on "$id"');
  return found!;
}

/// The title the detail shows.
String _title(WidgetTester tester) => textOf(tester, 'title');

void main() {
  testWidgets('on a phone: the list fills the screen; a tap shows the detail; back shows the list where it was', (tester) async {
    await _show(tester, _inbox, const Size(390, 844));
    expect(_drawn(tester, 'list'), isTrue);
    expect(_drawn(tester, 'detail'), isFalse);
    expect(rectOf(tester, 'list').width, 390);
    expect(rectOf(tester, 'list').height, 844);

    // Scroll the list down, then open a row further on.
    await tester.drag(find.byType(CodelesslyView), const Offset(0, -500));
    await settle(tester);
    final rows = boxesOf(tester, 'msg');
    final row = rows.firstWhere((b) => b.localToGlobal(Offset.zero).dy > 300);
    final before = row.localToGlobal(Offset.zero);
    await tester.tapAt(row.localToGlobal(row.size.center(Offset.zero)));
    // The detail fades and slides in as it takes the list's place.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final clock = _clock(tester, 'detail');
    expect(clock.isAnimating, isTrue);
    expect(clock.value, inExclusiveRange(0, 1));
    await settle(tester);
    expect(clock.isAnimating, isFalse);
    expect(_drawn(tester, 'list'), isFalse);
    expect(_drawn(tester, 'detail'), isTrue);
    expect(rectOf(tester, 'detail').width, 390);
    final subject = _title(tester);
    expect(subject, startsWith('Subject '));
    expect(int.parse(subject.split(' ').last), greaterThan(5), reason: 'the row tapped, not the first');

    // The back button, at the top left of the detail.
    final back = rectOf(tester, 'screen_paneBack1');
    expect(back.left, lessThan(60));
    expect(back.top, lessThan(60));
    await tester.tapAt(back.center);
    await settle(tester);
    expect(_drawn(tester, 'detail'), isFalse);
    expect(_drawn(tester, 'list'), isTrue);
    // The list is where it was left, the row chosen marked.
    expect(row.attached, isTrue);
    expect(row.localToGlobal(Offset.zero), before);
  });

  testWidgets('on a phone by keyboard: Enter on a row shows the detail, Escape the list, Space the detail again', (tester) async {
    final semantics = tester.ensureSemantics();
    await _show(tester, _inbox, const Size(390, 844));
    final keys = Keyboard(tester);
    // The first stop is the bar's button that opens the sidebar's drawer; the rows follow.
    for (var i = 0; i < 6 && keys.focusedId != 'msg'; i++) {
      await keys.tab();
    }
    expect(keys.focusedId, 'msg');
    await keys.tab();
    expect(keys.focusedText, 'Sender 2');
    await keys.enter();
    await settle(tester);
    expect(_drawn(tester, 'detail'), isTrue);
    expect(_drawn(tester, 'list'), isFalse);
    expect(_title(tester), 'Subject 2');
    // The back button is a stop, named Back.
    for (var i = 0; i < 4 && keys.focusedId != 'screen_paneBack1'; i++) {
      await keys.tab();
    }
    expect(keys.focusedId, 'screen_paneBack1');
    expect(keys.semantics!.label, contains('Back'));
    await keys.escape();
    await settle(tester);
    expect(_drawn(tester, 'list'), isTrue);
    expect(_drawn(tester, 'detail'), isFalse);

    for (var i = 0; i < 8 && keys.focusedText != 'Sender 3'; i++) {
      await keys.tab();
    }
    expect(keys.focusedText, 'Sender 3');
    await keys.space();
    await settle(tester);
    expect(_title(tester), 'Subject 3');
    expect(_drawn(tester, 'list'), isFalse);
    semantics.dispose();
  });

  testWidgets('in a published app on a phone, the system back shows the list, and leaves from the list', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    // The page as a published layout (the notation's own words, no design system).
    final r = parseNotation(_inbox, catalog: api.standardCatalog, options: const NotationOptions(width: 1280));
    expect(r.issues, isEmpty);
    final home = PublishLayout.fromJson({'id': 'home', ...r.document});
    final other = PublishLayout.fromJson({
      'schema': 3,
      'id': 'other',
      'roots': ['o'],
      'nodes': {
        'o': {'type': 'canvas', 'slots': {'body': 'ob'}, 'layout': {'width': 390, 'height': 844}},
        'ob': {'type': 'box', 'layout': {'width': {'fill': 390}, 'height': {'fill': 844}}},
      },
    });
    final app = Codelessly.fromBundle(PublishBundle(
      model: PublishModel(
        projectId: 'p',
        entryLayoutId: 'other',
        layouts: {'home': PublishLayoutInfo.of(home), 'other': PublishLayoutInfo.of(other)},
      ),
      layouts: {'home': home, 'other': other},
    ));
    addTearDown(app.dispose);
    final first = CodelesslyWidgetController();
    final inbox = CodelesslyWidgetController(layoutId: 'home');
    addTearDown(first.dispose);
    addTearDown(inbox.dispose);
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(navigatorKey: navigator, home: CodelesslyWidget(codelessly: app, controller: first)));
    await settle(tester);
    // The inbox is a screen pushed over another, so a back that is not held leaves it.
    unawaited(navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => CodelesslyWidget(codelessly: app, controller: inbox))));
    await settle(tester, 1000);
    expect(_drawn(tester, 'list'), isTrue);
    expect(_drawn(tester, 'detail'), isFalse);
    await tester.tapAt(boxesOf(tester, 'msg')[2].localToGlobal(const Offset(40, 20)));
    await settle(tester);
    expect(_drawn(tester, 'detail'), isTrue);
    expect(inbox.read('screen_pane'), 1);

    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(navigator.currentState!.canPop(), isTrue, reason: 'back shows the list, on the same screen');
    expect(_drawn(tester, 'list'), isTrue);
    expect(_drawn(tester, 'detail'), isFalse);

    await tester.binding.handlePopRoute();
    await settle(tester, 1000);
    expect(navigator.currentState!.canPop(), isFalse, reason: 'back from the list leaves the screen');
  });

  testWidgets('on a desktop the list and its detail stay side by side, with no back button', (tester) async {
    await _show(tester, _inbox, const Size(1440, 900));
    expect(_drawn(tester, 'list'), isTrue);
    expect(_drawn(tester, 'detail'), isTrue);
    expect(rectOf(tester, 'list').width, 320);
    expect(_drawn(tester, 'screen_paneBack1'), isFalse);
    await tester.tapAt(centerOf(tester, 'msg'));
    await settle(tester);
    expect(_drawn(tester, 'list'), isTrue);
    expect(_drawn(tester, 'detail'), isTrue);
    await Keyboard(tester).escape();
    expect(_drawn(tester, 'detail'), isTrue);
  });
}
