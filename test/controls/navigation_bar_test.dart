// Navigation bars as render objects (render/controls/navigation_bar.dart):
// `navigationBar` and `bottomNavigationBar` with nothing styled are SSUI's
// tab bar (soft_saas_ui's bottom navigation); the selected item follows the
// bound `selectedIndex` and a pick fires `changed` (written back); the
// keyboard, labels centred, screen readers, the props over SSUI's, the
// bottom safe area read from the view (no MediaQuery), no Scaffold, and a
// pixel match to SSUI's own widget.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui' show Tristate;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/controls/kit_bars.dart';
import 'package:codelessly_sdk/src/render/controls/navigation_bar.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show GlobalKey, RepaintBoundary, Align, Alignment;
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

RenderNavigationBar _bar(RenderTree tree, String id) {
  RenderNavigationBar? found;
  void visit(RenderObject o) {
    if (o is RenderNavigationBar) found ??= o;
    o.visitChildren(visit);
  }

  visit(tree.boxOf(id)!);
  return found!;
}

const _home = {'source': 'icon', 'type': 'MATERIAL_ICON', 'name': 'home', 'codepoint': 0xe318, 'style': 'filled'};
const _search = {'source': 'icon', 'type': 'MATERIAL_ICON', 'name': 'search', 'codepoint': 0xe567, 'style': 'filled'};
const _person = {'source': 'icon', 'type': 'MATERIAL_ICON', 'name': 'person', 'codepoint': 0xe491, 'style': 'filled'};

const _three = [
  {'label': 'Home', 'icon': _home},
  {'label': 'Search', 'icon': _search},
  {'label': 'Profile', 'icon': _person},
];

Map<String, Object?> _nav(String type, Map<String, Object?> props, {Object width = 360, Object? height}) => {
      'type': type,
      'layout': {'width': width, 'height': height ?? {'hug': 0}},
      'props': {'destinations': _three, ...props},
    };

Future<(NodeTree, RecordedInteractions)> _show(WidgetTester tester, Map<String, Map<String, Object?>> nodes,
    {bool dark = false}) async {
  final (tree, recorded) = runningTree(columnDoc(nodes), dark: dark);
  addTearDown(tree.dispose);
  await tester.pumpWidget(NodeView(tree: tree, rootId: 'col', interactive: true));
  return (tree, recorded);
}

Future<void> _fonts() async {
  const dir = '/opt/flutter/bin/cache/artifacts/material_fonts';
  final roboto = FontLoader('Roboto');
  for (final f in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']) {
    roboto.addFont(Future.value(ByteData.sublistView(File('$dir/$f').readAsBytesSync())));
  }
  await roboto.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(File('$dir/MaterialIcons-Regular.otf').readAsBytesSync())));
  await icons.load();
}

void main() {
  setUpAll(_fonts);

  for (final type in ['navigationBar', 'bottomNavigationBar']) {
    group(type, () {
      testWidgets('with nothing styled it is SSUI\'s tab bar: the selected item primary on activeTint, the rest secondary',
          (tester) async {
        final (tree, _) = await _show(tester, {'nav': _nav(type, {})});
        final bar = _bar(tree, 'nav');
        expect(rectOf(tree, 'nav').height, closeTo(60.8, .01), reason: 'SSUI\'s 6 + 47.8 + 6 and the hairline');
        expect(bar.backgroundColor, const Color(0xFFFFFFFF));
        expect(bar.indicatorColor, const Color(0x242563EB));
        expect(bar.labelColorOf(0), const Color(0xFF2563EB));
        expect(bar.labelColorOf(1), const Color(0xFF4B5563));
        final items = bar.itemRects;
        expect(items[0].width, closeTo(items[2].width, .01), reason: 'equal shares');
        final labels = bar.labels;
        for (var i = 0; i < labels.length; i++) {
          final g = labels[i].glyphs;
          expect((g.first.left + g.last.right) / 2, closeTo(items[i].center.dx, 1), reason: '${labels[i].text} centred in its item');
        }
      });

      testWidgets('a tap picks an item: changed fires with its index and the pill moves there on the ticker', (tester) async {
        final (tree, recorded) = await _show(tester, {'nav': _nav(type, {})});
        final bar = _bar(tree, 'nav');
        await tester.tapAt(bar.localToGlobal(bar.itemRects[2].center));
        await tester.pump();
        expect(bar.selectedIndex, 2);
        expect(recorded.fired, ['nav changed']);
        await tester.pump(const Duration(milliseconds: 75));
        final mid = bar.indicatorRectNow!;
        expect(mid.left, greaterThan(bar.itemRects[0].left + 1));
        expect(mid.left, lessThan(bar.itemRects[2].left - 1));
        await tester.pump(const Duration(milliseconds: 100));
        expect(bar.indicatorRectNow, bar.itemRects[2]);
      });

      testWidgets('Tab, Left and Right move between items with SSUI\'s ring; Enter picks', (tester) async {
        final (tree, recorded) = await _show(tester, {'nav': _nav(type, {})});
        final bar = _bar(tree, 'nav');
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(bar.focusHighlight, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        expect(bar.focusedIndex, 1);
        expect(bar.labelColorOf(1), const Color(0xFF111827), reason: 'the keyboard\'s item reads as hovered');
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        expect(bar.selectedIndex, 1);
        expect(recorded.fired, ['nav changed']);
        await tester.pump(const Duration(milliseconds: 200));
      });
    });
  }

  testWidgets('a bound selectedIndex shows the item and is written back by a pick', (tester) async {
    final source = DocumentSource(LayoutDocument.fromJson(columnDoc({
      'nav': {
        ..._nav('navigationBar', {}),
        'bind': {'props.selectedIndex': r'${page}'},
      },
    })));
    final scope = VariableScope([const Variable(name: 'page', type: VariableType.integer, value: 2)]);
    final tree = NodeTree(source, binder: NodeBinder(scope: scope), environment: const IslandEnvironment(interactive: true));
    addTearDown(tree.dispose);
    tree.interactions = TreeReactions(runner: const CodelesslyActions(), context: RuntimeActionContext(scope: scope, tree: tree));
    await tester.pumpWidget(NodeView(tree: tree, rootId: 'col', interactive: true));
    expect(_bar(tree, 'nav').selectedIndex, 2);
    await tester.tapAt(_bar(tree, 'nav').localToGlobal(_bar(tree, 'nav').itemRects[0].center));
    await tester.pumpAndSettle();
    expect(scope.read('page'), 0);
    scope.set('page', 1);
    await tester.pumpAndSettle();
    expect(_bar(tree, 'nav').selectedIndex, 1);
  });

  testWidgets('screen readers see each item as a button, selected or not, which a tap picks', (tester) async {
    final handle = tester.ensureSemantics();
    final (tree, recorded) = await _show(tester, {'nav': _nav('bottomNavigationBar', {})});
    final bar = _bar(tree, 'nav');
    final items = <SemanticsNode>[];
    bar.debugSemantics!.visitChildren((c) {
      items.add(c);
      return true;
    });
    expect([for (final i in items) i.getSemanticsData().label], ['Home', 'Search', 'Profile']);
    expect(items[0].getSemanticsData().flagsCollection.isSelected, Tristate.isTrue);
    expect(items[1].getSemanticsData().flagsCollection.isSelected, Tristate.isFalse);
    expect(items[1].getSemanticsData().flagsCollection.isButton, isTrue);
    tester.binding.renderViews.first.owner!.semanticsOwner!.performAction(items[1].id, SemanticsAction.tap);
    await tester.pump(const Duration(milliseconds: 200));
    expect(bar.selectedIndex, 1);
    expect(recorded.fired, ['nav changed']);
    handle.dispose();
  });

  testWidgets('the node\'s props are over SSUI\'s: colours, sizes, label behaviour, a shifting bar\'s fill', (tester) async {
    final (tree, _) = await _show(tester, {
      'a': _nav('navigationBar', {
        'backgroundColor': '#FF101418',
        'indicatorColor': '#FF1F6F4A',
        'selectedIconColor': '#FFFFFFFF',
        'iconColor': '#FF999999',
        'labelBehavior': 'onlyShowSelected',
        'iconSize': 28,
      }),
      'b': _nav('bottomNavigationBar', {
        'type': 'shifting',
        'destinations': [
          {'label': 'Home', 'icon': _home, 'backgroundColor': '#FF0D47A1'},
          {'label': 'Search', 'icon': _search, 'backgroundColor': '#FF1B5E20'},
        ],
      }),
    });
    final a = _bar(tree, 'a');
    expect(a.backgroundColor, const Color(0xFF101418));
    expect(a.indicatorColor, const Color(0xFF1F6F4A));
    expect(a.iconColorOf(0), const Color(0xFFFFFFFF));
    expect(a.iconColorOf(1), const Color(0xFF999999));
    expect([for (final l in a.labels) l.text], ['Home'], reason: 'only the selected label');
    expect(a.glyphs.glyphs.first.size, const Size(28, 28));
    expect(_bar(tree, 'b').backgroundColor, const Color(0xFF0D47A1), reason: 'the selected destination\'s fill');
  });

  testWidgets('in a canvas\'s bottom slot the bar keeps the view\'s bottom safe area clear, read from the view', (tester) async {
    tester.view.padding = const FakeViewPadding(bottom: 34 * 3);
    addTearDown(tester.view.reset);
    final (tree, _) = runningTree({
      'schema': 3,
      'roots': ['screen'],
      'nodes': {
        'screen': {
          'type': 'canvas',
          'slots': {'body': 'body', 'bottomNavigationBar': 'nav'},
          'layout': {'width': 390, 'height': 700},
        },
        'body': {'type': 'box', 'layout': {'width': {'fill': 390}, 'height': {'fill': 600}}},
        'nav': _nav('navigationBar', {}, width: {'fill': 390}, height: 60),
      },
    });
    addTearDown(tree.dispose);
    await tester.pumpWidget(Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'screen', interactive: true)));
    final bar = _bar(tree, 'nav');
    expect(controlViewPadding(bar).bottom, 34);
    expect(rectOf(tree, 'nav').height, 60 + 34);
    expect(rectOf(tree, 'nav').bottom, rectOf(tree, 'screen').bottom, reason: 'Scaffold\'s place, with no Scaffold');
    for (final r in bar.itemRects) {
      expect(r.bottom, lessThanOrEqualTo(60), reason: 'the items stay above the safe area');
    }
  });

  testWidgets('a mouse over an item lays SSUI\'s hover overlay on it and darkens its ink', (tester) async {
    final (tree, _) = await _show(tester, {'nav': _nav('navigationBar', {})});
    final bar = _bar(tree, 'nav');
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(bar.localToGlobal(bar.itemRects[2].center));
    await tester.pump();
    expect(bar.hoveredIndex, 2);
    expect(bar.labelColorOf(2), const Color(0xFF111827));
  });

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    testWidgets('three destinations with nothing styled match SSUI\'s own tab bar: $mode', (tester) async {
      tester.view.physicalSize = const Size(360, 61);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({
        'schema': 3,
        'roots': ['nav'],
        'nodes': {'nav': _nav('navigationBar', {})},
      })))
        ..theme = ThemeTokens.fromJson({'fontFamily': 'Roboto'})
        ..dark = dark;
      addTearDown(tree.dispose);
      final key = GlobalKey();
      await tester.pumpWidget(Align(alignment: Alignment.topLeft, child: RepaintBoundary(key: key, child: NodeView(tree: tree, rootId: 'nav'))));
      await tester.pump();
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
      final image = (await tester.runAsync(() => boundary.toImage(pixelRatio: 1)))!;
      final dir = Platform.environment['CODELESSLY_M3_RENDERS'];
      if (dir != null && dir.isNotEmpty) {
        final png = await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
        File('$dir/navigation-$mode.png').writeAsBytesSync(png!.buffer.asUint8List());
      }
      final w = image.width, h = image.height;
      final ours = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawStraightRgba)))!.buffer.asUint8List();
      final bytes = File('design_systems/ssui/examples/renders/m3/navigation-ssui-$mode.png').readAsBytesSync();
      final (rw, ref) = (await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        return (frame.image.width, (await frame.image.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!.buffer.asUint8List());
      }))!;
      var differing = 0, total = 0;
      for (var y = 0; y < h && y < ref.length ~/ (rw * 4); y++) {
        for (var x = 0; x < w && x < rw; x++) {
          final i = (y * w + x) * 4, j = (y * rw + x) * 4;
          total++;
          for (var c = 0; c < 3; c++) {
            // Over the page (the last row is partly covered: 60.8 high).
            final page = dark ? 0x1C : 0xFF;
            int over(List<int> px, int k) => ((px[k + c] * px[k + 3] + page * (255 - px[k + 3])) / 255).round();
            if ((over(ours, i) - over(ref, j)).abs() > 40) {
              differing++;
              break;
            }
          }
        }
      }
      final share = differing / total;
      // ignore: avoid_print
      print('SSUI navigation $mode: ${(share * 100).toStringAsFixed(2)} % of the pixels differ');
      // What differs is the labels' letter spacing: the reference's Text
      // inherits Material's bodyMedium 0.25 under SSUI's theme; SSUI's
      // typography (and these labels) set none. With 0.25 the dark render
      // matches to 0.00 %.
      expect(share, lessThan(.02));
    });
  }
}
