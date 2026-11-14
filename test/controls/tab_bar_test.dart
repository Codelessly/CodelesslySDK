// Tab bars as render objects (render/controls/tab_bar.dart): SSUI's Tabs
// with nothing styled, the selected indicator moving between tabs on the
// bar's ticker, the keyboard (Left/Right, Home/End, Enter/Space, the focus
// ring), labels centred, scrolling when the tabs overflow, screen readers
// (a tab bar of tabs, each selected or not), `changed` and its write-back,
// `tabs` switching its child, and a pixel match to SSUI's own Tabs.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui' show Tristate;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/controls/tab_bar.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show GlobalKey, RepaintBoundary, Align, Alignment, Directionality, TextDirection;
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

T _find<T extends RenderObject>(RenderTree tree, String id) {
  T? found;
  void visit(RenderObject o) {
    if (o is T) found ??= o;
    o.visitChildren(visit);
  }

  visit(tree.boxOf(id)!);
  return found!;
}

RenderTabBar _bar(RenderTree tree, String id) => _find<RenderTabBar>(tree, id);

const _three = [
  {'id': 'o', 'label': 'Overview'},
  {'id': 'a', 'label': 'Activity'},
  {'id': 's', 'label': 'Settings'},
];

Future<(NodeTree, RecordedInteractions)> _show(WidgetTester tester, Map<String, Map<String, Object?>> nodes,
    {Map<String, Object?>? theme, bool dark = false, double width = 400, Map<String, Map<String, Object?>> extra = const {}}) async {
  final doc = columnDoc(nodes, width: width);
  (doc['nodes']! as Map).addAll(extra);
  final (tree, recorded) = runningTree(doc, theme: theme == null ? null : ThemeTokens.fromJson(theme), dark: dark);
  addTearDown(tree.dispose);
  await tester.pumpWidget(NodeView(tree: tree, rootId: 'col', interactive: true));
  return (tree, recorded);
}

/// A tab bar [width] wide (hugging its height) with [props].
Map<String, Object?> _tabBar(Map<String, Object?> props, {Object width = 360}) => {
      'type': 'tabBar',
      'layout': {'width': width, 'height': {'hug': 0}},
      'props': props,
    };

void main() {
  group('with nothing styled', () {
    testWidgets('it is SSUI\'s Tabs: 36 high, labels from the start 16 apart, a hairline and a 2 px primary underline',
        (tester) async {
      final (tree, _) = await _show(tester, {'bar': _tabBar({'tabs': _three})});
      final bar = _bar(tree, 'bar');
      expect(rectOf(tree, 'bar').height, 36);
      final tabs = bar.itemRects;
      expect(tabs.first.left, 12, reason: 'SSUI\'s 12 px side padding');
      expect(tabs[1].left - tabs[0].right, 16);
      expect(bar.labelColorOf(0), const Color(0xFF111827), reason: 'selected: primaryText');
      expect(bar.labelColorOf(1), const Color(0xFF4B5563), reason: 'unselected: secondaryText');
      expect(bar.divider, (color: const Color(0xFFE5E7EB), height: 1.0));
      expect(bar.indicatorColor, const Color(0xFF2563EB));
      final ind = bar.indicatorRect!;
      expect(ind.height, 2);
      expect(ind.bottom, 36);
      // The underline is the label's width.
      final label = bar.labels.first.glyphs;
      expect(ind.left, closeTo(label.first.left, 1.5));
      expect(ind.right, closeTo(label.last.right, 1.5));
    });

    testWidgets('a tab bar with no layout hugs its tabs (never 0 × 0); in dark mode it takes SSUI\'s dark tokens',
        (tester) async {
      final (tree, _) = await _show(tester, {
        'bar': {'type': 'tabBar', 'props': {'tabs': _three}},
      }, dark: true, theme: null);
      final r = rectOf(tree, 'bar');
      expect(r.height, 36);
      expect(r.width, greaterThan(150));
      final bar = _bar(tree, 'bar');
      expect(bar.labelColorOf(0), const Color(0xFFFFFFFF));
      expect(bar.divider!.color, const Color(0xFF383838));
      expect(bar.indicatorColor, const Color(0xFF3B82F6));
    });

    testWidgets('every label is centred in the bar, at 36 and at 48 high, with icons too', (tester) async {
      final (tree, _) = await _show(tester, {
        'a': _tabBar({'tabs': _three}),
        'b': {
          'type': 'tabBar',
          'layout': {'width': 360, 'height': 48},
          'props': {
            'tabs': [
              {'id': 'h', 'label': 'Home', 'icon': 'home'},
              {'id': 's', 'label': 'Search', 'icon': 'search'},
            ],
          },
        },
      });
      for (final id in ['a', 'b']) {
        final bar = _bar(tree, id);
        for (final l in bar.labels) {
          final top = l.glyphs.map((g) => g.top).reduce((a, b) => a < b ? a : b);
          final bottom = l.glyphs.map((g) => g.bottom).reduce((a, b) => a > b ? a : b);
          expect((top + bottom) / 2, closeTo(bar.size.height / 2, .75), reason: '$id ${l.text}');
        }
      }
      // An icon beside its label, the pair centred in the tab.
      final b = _bar(tree, 'b');
      final glyph = b.glyphs.glyphs.first;
      final icon = glyph.localToGlobal(Offset.zero) - b.localToGlobal(Offset.zero) & glyph.size;
      expect(icon.center.dy, closeTo(24, .5));
      expect(icon.right, lessThan(b.labels.first.glyphs.first.left));
    });
  });

  group('picking a tab', () {
    testWidgets('a tap selects it, fires changed with its index, and the indicator glides there in 150 ms',
        (tester) async {
      final (tree, recorded) = await _show(tester, {'bar': _tabBar({'tabs': _three})});
      final bar = _bar(tree, 'bar');
      final from = bar.indicatorRect!;
      final to = bar.itemRects[2];
      await tester.tapAt(bar.localToGlobal(to.center));
      await tester.pump();
      expect(bar.selectedIndex, 2);
      expect(recorded.fired, ['bar changed']);
      await tester.pump(const Duration(milliseconds: 75));
      final mid = bar.indicatorRect!;
      expect(mid.left, greaterThan(from.left + 1));
      expect(mid.left, lessThan(bar.itemRects[2].left - 1), reason: 'on its way, not there yet');
      await tester.pump(const Duration(milliseconds: 100));
      final end = bar.indicatorRect!;
      expect(end.left, closeTo(bar.labels[2].glyphs.first.left, 1.5));
      expect(bar.labelColorOf(2), const Color(0xFF111827));
      expect(bar.labelColorOf(0), const Color(0xFF4B5563));
    });

    testWidgets('a mouse over an unselected tab darkens its label (SSUI\'s hovered tab)', (tester) async {
      final (tree, _) = await _show(tester, {'bar': _tabBar({'tabs': _three})});
      final bar = _bar(tree, 'bar');
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(bar.localToGlobal(bar.itemRects[1].center));
      await tester.pump();
      expect(bar.hoveredIndex, 1);
      expect(bar.labelColorOf(1), const Color(0xFF111827));
      expect(bar.labelColorOf(2), const Color(0xFF4B5563));
    });

    testWidgets('Tab focuses the bar with SSUI\'s ring; Left and Right move between tabs, Enter and Space pick', (tester) async {
      final (tree, recorded) = await _show(tester, {'bar': _tabBar({'tabs': _three})});
      final bar = _bar(tree, 'bar');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(bar.focusHighlight, isTrue);
      expect(bar.focusedIndex, 0, reason: 'the keyboard starts on the selected tab');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(bar.focusedIndex, 1);
      expect(bar.selectedIndex, 0, reason: 'arrows move, Enter and Space pick');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(bar.selectedIndex, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      expect(bar.focusedIndex, 2, reason: 'wrapping');
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      expect(bar.focusedIndex, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(bar.selectedIndex, 2);
      expect(recorded.fired, ['bar changed', 'bar changed']);
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('a bound initialIndex picks the tab and is written back when the user picks another', (tester) async {
      final source = DocumentSource(LayoutDocument.fromJson(columnDoc({
        'bar': {
          ..._tabBar({'tabs': _three}),
          'bind': {'props.initialIndex': r'${tab}'},
        },
      })));
      final scope = VariableScope([const Variable(name: 'tab', type: VariableType.integer, value: 1)]);
      final tree = NodeTree(source, binder: NodeBinder(scope: scope), environment: const IslandEnvironment(interactive: true));
      addTearDown(tree.dispose);
      tree.interactions = TreeReactions(runner: const CodelesslyActions(), context: RuntimeActionContext(scope: scope, tree: tree));
      await tester.pumpWidget(NodeView(tree: tree, rootId: 'col', interactive: true));
      final bar = _bar(tree, 'bar');
      expect(bar.selectedIndex, 1);
      await tester.tapAt(bar.localToGlobal(bar.itemRects[2].center));
      await tester.pumpAndSettle();
      expect(scope.read('tab'), 2);
      scope.set('tab', 0);
      await tester.pumpAndSettle();
      expect(_bar(tree, 'bar').selectedIndex, 0, reason: 'the variable picks the tab');
    });
  });

  testWidgets('tabs that overflow the bar scroll: a drag, and to the tab the keyboard picks', (tester) async {
    final (tree, _) = await _show(tester, {
      'bar': _tabBar({
        'tabs': [for (var i = 0; i < 10; i++) {'id': '$i', 'label': 'Section $i'}],
      }, width: 300),
    });
    final bar = _bar(tree, 'bar');
    expect(bar.scrolls, isTrue);
    expect(bar.scrollOffset, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    expect(bar.scrollOffset, greaterThan(0));
    final last = bar.itemRects.last;
    expect(last.right, lessThanOrEqualTo(300 + .5), reason: 'the last tab is in view');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    final before = bar.scrollOffset;
    await tester.dragFrom(bar.localToGlobal(const Offset(100, 18)), const Offset(120, 0));
    await tester.pump();
    expect(bar.scrollOffset, lessThan(before));
    // A bar that fits doesn't scroll.
    final (tree2, _) = await _show(tester, {'bar': _tabBar({'tabs': _three})});
    expect(_bar(tree2, 'bar').scrolls, isFalse);
  });

  testWidgets('screen readers see a tab bar of tabs, each selected or not, which a tap picks', (tester) async {
    final handle = tester.ensureSemantics();
    final (tree, recorded) = await _show(tester, {'bar': _tabBar({'tabs': _three})});
    final bar = _bar(tree, 'bar');
    final node = bar.debugSemantics!;
    expect(node.getSemanticsData().role, SemanticsRole.tabBar);
    final tabs = <SemanticsNode>[];
    node.visitChildren((c) {
      tabs.add(c);
      return true;
    });
    expect([for (final t in tabs) t.getSemanticsData().label], ['Overview', 'Activity', 'Settings']);
    expect([for (final t in tabs) t.getSemanticsData().role], everyElement(SemanticsRole.tab));
    expect(tabs[0].getSemanticsData().flagsCollection.isSelected, Tristate.isTrue);
    expect(tabs[1].getSemanticsData().flagsCollection.isSelected, Tristate.isFalse);
    tester.binding.renderViews.first.owner!.semanticsOwner!.performAction(tabs[1].id, SemanticsAction.tap);
    await tester.pump();
    expect(bar.selectedIndex, 1);
    expect(recorded.fired, ['bar changed']);
    await tester.pump(const Duration(milliseconds: 200));
    handle.dispose();
  });

  testWidgets('the node\'s props are over SSUI\'s: colours, a filled indicator, a tab-wide one, fill alignment', (tester) async {
    final (tree, _) = await _show(tester, {
      'bar': _tabBar({
        'tabs': _three,
        'labelColor': '#FFE4572E',
        'unselectedLabelColor': '#FF777777',
        'indicatorColor': '#FF1F6F4A',
        'indicatorStyle': 'filled',
        'indicatorSize': 'tab',
        'tabAlignment': 'fill',
        'dividerColor': '#FF000000',
        'dividerHeight': 2,
      }),
    });
    final bar = _bar(tree, 'bar');
    expect(bar.labelColorOf(0), const Color(0xFFE4572E));
    expect(bar.labelColorOf(1), const Color(0xFF777777));
    expect(bar.indicatorColor, const Color(0xFF1F6F4A));
    expect(bar.divider, (color: const Color(0xFF000000), height: 2.0));
    final tabs = bar.itemRects;
    expect(tabs[0].width, closeTo(tabs[1].width, .01), reason: 'fill: equal shares');
    expect(bar.indicatorRect, tabs[0], reason: 'a filled indicator the tab\'s size');
  });

  testWidgets('tabs show the selected child below the bar and switch it when a tab is picked', (tester) async {
    final (tree, recorded) = await _show(tester, {
      'tabs': {
        'type': 'tabs',
        'layout': {'width': 360, 'height': 200},
        'props': {'titles': ['One', 'Two']},
        'children': ['p1', 'p2'],
      },
    }, extra: {
      'p1': {'type': 'box', 'layout': {'width': {'fill': 360}, 'height': {'fill': 100}}},
      'p2': {'type': 'box', 'layout': {'width': {'fill': 360}, 'height': {'fill': 100}}},
    });
    final tabs = _find<RenderTabs>(tree, 'tabs');
    expect(identical(tabs.shown, tree.boxOf('p1')), isTrue);
    expect(rectOf(tree, 'p1').top - rectOf(tree, 'tabs').top, 36, reason: 'below the bar');
    expect(rectOf(tree, 'p1').height, 200 - 36);
    await tester.tapAt(tabs.bar.localToGlobal(tabs.bar.itemRects[1].center));
    await tester.pump();
    expect(identical(tabs.shown, tree.boxOf('p2')), isTrue);
    expect(rectOf(tree, 'p2').top - rectOf(tree, 'tabs').top, 36);
    expect(recorded.fired, ['tabs changed']);
    await tester.pump(const Duration(milliseconds: 200));
  });

  group('SSUI\'s own Tabs', () {
    Future<void> fonts() async {
      const dir = '/opt/flutter/bin/cache/artifacts/material_fonts';
      final roboto = FontLoader('Roboto');
      for (final f in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']) {
        roboto.addFont(Future.value(ByteData.sublistView(File('$dir/$f').readAsBytesSync())));
      }
      await roboto.load();
    }

    setUpAll(fonts);

    for (final dark in [false, true]) {
      final mode = dark ? 'dark' : 'light';
      testWidgets('a tab bar of three tabs with nothing styled matches SSUI\'s Tabs component render: $mode', (tester) async {
        tester.view.physicalSize = const Size(360, 36);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({
          'schema': 3,
          'roots': ['bar'],
          'nodes': {
            'bar': {
              'type': 'tabBar',
              'layout': {'width': 360, 'height': 36},
              'props': {'tabs': _three},
            },
          },
        })))
          ..theme = ThemeTokens.fromJson({'fontFamily': 'Roboto'})
          ..dark = dark;
        addTearDown(tree.dispose);
        final key = GlobalKey();
        await tester.pumpWidget(Directionality(
          textDirection: TextDirection.ltr,
          child: Align(alignment: Alignment.topLeft, child: RepaintBoundary(key: key, child: NodeView(tree: tree, rootId: 'bar'))),
        ));
        final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
        final image = (await tester.runAsync(() => boundary.toImage(pixelRatio: 1)))!;
        final dir = Platform.environment['CODELESSLY_M3_RENDERS'];
        if (dir != null && dir.isNotEmpty) {
          final png = await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
          File('$dir/tabs-$mode.png').writeAsBytesSync(png!.buffer.asUint8List());
        }
        final ours = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawStraightRgba)))!.buffer.asUint8List();
        final bytes = File('design_systems/ssui/examples/renders/m3/tabs-ssui-$mode.png').readAsBytesSync();
        final ref = (await tester.runAsync(() async {
          final codec = await ui.instantiateImageCodec(bytes);
          final frame = await codec.getNextFrame();
          return (await frame.image.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!.buffer.asUint8List();
        }))!;
        // Both on the same page colour (SSUI's component has no fill).
        final page = dark ? const [0x1C, 0x1C, 0x1C] : const [0xF9, 0xFA, 0xFB];
        int over(List<int> px, int i, int c) => ((px[i + c] * px[i + 3] + page[c] * (255 - px[i + 3])) / 255).round();
        var differing = 0;
        const total = 360 * 36;
        for (var i = 0; i < total * 4; i += 4) {
          for (var c = 0; c < 3; c++) {
            if ((over(ours, i, c) - over(ref, i, c)).abs() > 40) {
              differing++;
              break;
            }
          }
        }
        final share = differing / total;
        // ignore: avoid_print
        print('SSUI Tabs $mode: ${(share * 100).toStringAsFixed(2)} % of the pixels differ');
        expect(share, lessThan(.005));
      });
    }
  });
}
