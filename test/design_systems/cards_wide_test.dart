// Cards on a wide canvas (design_systems/cards/TO-DESKTOP.md): a card written once keeps a card's measure and
// stands in the middle of a tablet's and a desktop's window, its blocks take their wide form there, a block that
// stands alone on a wide page is no wider than a card, and under 700 px of shown width (a phone, or a card laid
// out in a narrow column of a wide window) everything is the phone form.
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/cards.dart' show rectOf, settle;

const _card = '''
state range="30 days"
state pick=1
Column#page h=fill scroll fill=page
  ChatCard#c "Coffee near you" "Five shops within a 12 minute walk" icon="local_cafe_rounded" status="5 shops"
    Paragraph#p "I am about to permanently delete old files from your shared drive. Nothing is removed until you approve."
    Segments#seg @range options=["7 days","30 days","90 days"]
    Grid#figures cols=2 gap=10 min700.cols=4
      StatTile#s1 "Revenue" value="\$78.9k" delta="+8.5%" icon="payments_rounded"
      StatTile#s2 "Sign-ups" value="1,340" delta="+11.2%" icon="person_add_rounded"
      StatTile#s3 "Churn" value="3.1%" delta="+0.4%" invert=true icon="logout_rounded"
      StatTile#s4 "Active users" value="14,260" delta="+6.3%" icon="groups_rounded"
    ChartCard "Sign-ups by channel" value="1,340" values=[540,372,218,134,76] labels=["Organic","Paid","Referral","Social","Email"] kind="bars"
    MapPanel#map @pick count=5
    DayHeader#day "Day 1" "Higashiyama and Gion" kind="temple"
    ComparisonTable#cmp names=["Lite","Max"] prices=["\$25/mo","\$45/mo"] rows=[["Data","10 GB","Unlimited",2],["Calls","500 min","Unlimited",2]] pick="Max"
    Details#facts rows=[["Folder","Shared Drive / Archive"],["Files","214"]]
    Row gap=10
      ActionButton#deny "Deny" tone="quiet" grow
      ActionButton#ok "Approve" grow=2
    TotalBar#bar "Total" amount="\$30.94" cta="Confirm order"
''';

const _tabs = '''
state range="30 days"
state view="List"
state kind="All"
Column#page h=fill scroll fill=page
  ChatCard#c "Views" "Every switch a card has"
    Segments#seg @range options=["7 days","30 days","90 days"]
    TabToggle#toggle @view options=["List","Grid"]
    SegmentedControl#small @view options=["List","Grid"] size="xs"
    ChipTabs#chips @kind tabs=["All","Open","Closed"]
    BrowserTabs#open @kind tabs=["All","Open","Closed"]
''';

const _bare = '''
Column#page h=fill scroll pad=24 gap=14 fill=page
  Paragraph#p "I am about to permanently delete old files from your shared drive. Nothing is removed until you approve."
  Details#facts rows=[["Folder","Shared Drive / Archive"],["Files","214"]]
  OptionList#opt "Delivery" options=["Standard","Express"] details=["3 to 5 days","Next day"]
  TotalBar#bar "Total" amount="\$30.94" cta="Confirm order"
  ChartCard#chart "Sign-ups by channel" value="1,340" values=[540,372,218] labels=["Organic","Paid","Referral"] kind="bars"
''';

const _held = '''
state pick="Standard"
Column#page h=fill scroll pad=24 gap=14 fill=page center
  Column#col w=fill maxw=860 gap=14
    ProgressLine#line "Modules finished" "0 of 4" value=0.25
    Panel#pn "Delivery" "How it reaches you."
      OptionList#opt "Delivery" @pick options=["Standard","Express"] details=["3 to 5 days","Next day"]
      Details#facts rows=[["Folder","Shared Drive / Archive"],["Files","214"]]
    Callout#co "Day one" "Arrive at 7:30 for a tour." tone="success"
''';

/// Shows [notation], written for a phone (expanded at 390), in a window of [size]; with [host] the card is laid
/// out in a column that wide at the window's start, as a chat column embeds it.
Future<void> _show(WidgetTester tester, String notation, Size size, {double? host}) async {
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
  final Widget view = CodelesslyView(session: session);
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: host == null ? view : Align(alignment: Alignment.topLeft, child: SizedBox(width: host, child: view)))));
  final result = await session.applyNotation(Stream.value(notation.trimLeft()),
      options: api.NotationOptions.fromDesignSystem(ds!, width: 390));
  await settle(tester, 800);
  expect(session.notationIssues, isEmpty);
  expect(result.errors, isEmpty, reason: '${result.errors}');
  // (No fonts are loaded here, so a text is wider than drawn: overflow is the render tool's to report.)
  tester.takeException();
}

void main() {
  for (final size in const [Size(834, 1112), Size(1440, 900)]) {
    testWidgets('a card shown ${size.width.toInt()} wide keeps a card\'s measure, its blocks in their wide form', (tester) async {
      await _show(tester, _card, size);
      final card = rectOf(tester, 'c/card');
      expect(card.width, 720);
      expect(card.center.dx, moreOrLessEquals(size.width / 2, epsilon: 0.6));
      // The switch spans the card; four figures are on one line; the pictures are taller than a phone's.
      expect(rectOf(tester, 'seg/track').width, moreOrLessEquals(684, epsilon: 0.6));
      expect(rectOf(tester, 'figures').height, lessThan(160));
      expect(rectOf(tester, 'map').height, 280);
      expect(rectOf(tester, 'day/head').height, 132);
      // Two plans share the card beside the labels.
      expect(rectOf(tester, 'cmp/k1').right, moreOrLessEquals(card.right - 18, epsilon: 1));
      // A card closes on buttons and a bar as wide as it is.
      expect(rectOf(tester, 'ok').right, moreOrLessEquals(card.right - 18, epsilon: 0.6));
      expect(rectOf(tester, 'bar').width, moreOrLessEquals(684, epsilon: 0.6));
    });
  }

  testWidgets('on a phone the card is the phone form', (tester) async {
    await _show(tester, _card, const Size(390, 844));
    final card = rectOf(tester, 'c/card');
    expect(card.left, 10);
    expect(card.width, 370);
    expect(rectOf(tester, 'map').height, 178);
    expect(rectOf(tester, 'day/head').height, 92);
    expect(rectOf(tester, 'figures').height, greaterThan(200));
    expect(rectOf(tester, 'cmp/k1').width, 140);
  });

  testWidgets('a card laid out in a narrow column of a wide window is the phone form', (tester) async {
    await _show(tester, _card, const Size(1440, 900), host: 400);
    final card = rectOf(tester, 'c/card');
    expect(card.left, 10);
    expect(card.width, 380);
    expect(rectOf(tester, 'map').height, 178);
    expect(rectOf(tester, 'day/head').height, 92);
    expect(rectOf(tester, 'figures').height, greaterThan(200));
    expect(rectOf(tester, 'cmp/k1').width, 140);
  });

  // The tab-like controls have a phone's 44 high tap areas by the shown width too: they read the window's width
  // once (screen.width), so in a narrow column of a wide window they were a desktop's.
  for (final (name, size, host, phone) in const [
    ('on a phone', Size(390, 844), null, true),
    ('in a narrow column of a wide window', Size(1440, 900), 400.0, true),
    ('in a wide window', Size(1440, 900), null, false),
  ]) {
    testWidgets('the tap areas of the tab-like controls $name are ${phone ? "a phone's 44" : 'as written'}', (tester) async {
      await _show(tester, _tabs, size, host: host);
      expect(rectOf(tester, 'seg/cell0').height, phone ? 44 : 40);
      expect(rectOf(tester, 'toggle/list').height, phone ? 44 : 36);
      expect(rectOf(tester, 'small/list').height, phone ? 44 : 28);
      expect(rectOf(tester, 'chips/list').height, phone ? 44 : 36);
      expect(rectOf(tester, 'open/list').height, phone ? 44 : 36);
    });
  }

  test('no card block reads the window where the shown width is meant', () {
    for (final name in File('design_systems/cards/BLOCKS.txt').readAsStringSync().trim().split(',')) {
      final json = File('design_systems/cards/components/$name.json').readAsStringSync();
      expect(RegExp(r'screen\.width\s*[<>]=?\s*\d').hasMatch(json), isFalse, reason: '$name compares screen.width: write a width rule (kit.wide, kit.phone)');
    }
  });

  testWidgets('on a wide page a block fills its place; running text keeps a reading measure', (tester) async {
    await _show(tester, _bare, const Size(1440, 900));
    expect(rectOf(tester, 'p').width, 720);
    for (final id in ['facts', 'opt', 'bar', 'chart']) {
      expect(rectOf(tester, id).width, 1440 - 48, reason: id);
      expect(rectOf(tester, id).left, 24, reason: id);
    }
  });

  testWidgets('a block is as wide as the column or the panel that holds it', (tester) async {
    await _show(tester, _held, const Size(1440, 900));
    final panel = rectOf(tester, 'pn');
    expect(panel.width, 860);
    expect(rectOf(tester, 'co').width, 860);
    expect(rectOf(tester, 'line').width, 860);
    for (final id in ['opt', 'facts']) {
      final r = rectOf(tester, id);
      expect(r.width, greaterThan(720), reason: id);
      expect(r.left - panel.left, closeTo(panel.right - r.right, 0.5), reason: '$id has the same space at both sides');
    }
  });

  test('every width rule of a card block holds from 700 up, or up to 699 or 1023: none changes a phone', () {
    final blocks = File('design_systems/cards/BLOCKS.txt').readAsStringSync().trim().split(',');
    var wide = 0;
    for (final name in blocks) {
      final doc = (jsonDecode(File('design_systems/cards/components/$name.json').readAsStringSync()) as Map).cast<String, Object?>();
      for (final node in (doc['nodes'] as Map).values) {
        for (final rule in ((node as Map)['media'] as List? ?? const [])) {
          final min = (rule as Map)['minWidth'];
          if (min == null) continue;
          expect(min, greaterThanOrEqualTo(700), reason: '$name: a rule from $min px would change the block on a phone');
          wide++;
        }
      }
    }
    expect(wide, greaterThan(12));
  });
}
