// The app bar as a render object (render/controls/app_bar.dart): no
// Material widget and no Scaffold; SSUI's top bar with nothing styled; its
// slots (leading, title, actions) laid out as Flutter's NavigationToolbar
// does; placed by the canvas's slots (render/layout/scaffold_slots.dart);
// the top safe area read from the view, never MediaQuery; the props over
// SSUI's; the title centered (the label guard's measure) and announced as a
// header.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/controls/app_bar.dart';
import 'package:codelessly_sdk/src/render/controls/kit_bars.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' show Align, Alignment;
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

RenderAppBar _bar(RenderTree tree, String id) {
  RenderAppBar? found;
  void visit(RenderObject o) {
    if (o is RenderAppBar) found ??= o;
    o.visitChildren(visit);
  }

  visit(tree.boxOf(id)!);
  return found!;
}

bool _hasIsland(RenderObject o) {
  var found = false;
  void visit(RenderObject c) {
    if (c is IslandHost) found = true;
    c.visitChildren(visit);
  }

  visit(o);
  return found;
}

const _menu = {'icon': {'source': 'icon', 'type': 'MATERIAL_ICON', 'name': 'menu', 'codepoint': 0xe3dc}};
const _search = {'icon': {'source': 'icon', 'type': 'MATERIAL_ICON', 'name': 'search', 'codepoint': 0xe567}};
const _more = {'icon': {'source': 'icon', 'type': 'MATERIAL_ICON', 'name': 'more_vert', 'codepoint': 0xe404}};

Map<String, Object?> _appBar(Map<String, Object?> props, {Object width = 360, Object? height}) => {
      'type': 'appBar',
      'layout': {'width': width, 'height': height ?? {'hug': 0}},
      'props': props,
    };

Future<NodeTree> _show(WidgetTester tester, Map<String, Map<String, Object?>> nodes, {bool dark = false}) async {
  final (tree, _) = runningTree(columnDoc(nodes), dark: dark);
  addTearDown(tree.dispose);
  await tester.pumpWidget(NodeView(tree: tree, rootId: 'col', interactive: true));
  return tree;
}

double _center(List<Rect> glyphs) =>
    (glyphs.map((g) => g.top).reduce((a, b) => a < b ? a : b) + glyphs.map((g) => g.bottom).reduce((a, b) => a > b ? a : b)) / 2;

void main() {
  testWidgets('with nothing styled it is SSUI\'s top bar: 44 high, surface, a hairline, the title as sectionTitle', (tester) async {
    final tree = await _show(tester, {'bar': _appBar({'title': 'Inbox'})});
    final bar = _bar(tree, 'bar');
    expect(rectOf(tree, 'bar').height, 44);
    expect(bar.backgroundColor, const Color(0xFFFFFFFF));
    expect(bar.titleColor, const Color(0xFF111827));
    expect(bar.slots.title.left, 12, reason: 'SSUI\'s 12 px from the start');
    expect(_center(bar.labels.single.glyphs), closeTo(22, .75), reason: 'the title centered in the bar');
    expect(_hasIsland(tree.boxOf('bar')!), isFalse, reason: 'no AppBar island');
  });

  testWidgets('a bar with no layout hugs (never 0 × 0); in dark mode it takes SSUI\'s dark tokens', (tester) async {
    final tree = await _show(tester, {'bar': {'type': 'appBar', 'props': {'title': 'Inbox'}}}, dark: true);
    expect(rectOf(tree, 'bar').height, 44);
    expect(rectOf(tree, 'bar').width, greaterThan(40));
    final bar = _bar(tree, 'bar');
    expect(bar.backgroundColor, const Color(0xFF141414));
    expect(bar.titleColor, const Color(0xFFFFFFFF));
  });

  testWidgets('its slots: the leading icon at the start, the title after it, the actions at the end 4 apart', (tester) async {
    final tree = await _show(tester, {
      'bar': _appBar({'title': 'Inbox', 'leading': _menu, 'actions': [_search, _more]}, height: 56),
    });
    final bar = _bar(tree, 'bar');
    final s = bar.slots;
    expect(s.leading, const Rect.fromLTWH(8, 14, 28, 28));
    expect(s.title.left, 8 + 28 + 8);
    expect(s.actions, hasLength(2));
    expect(s.actions.last.right, 360 - 8);
    expect(s.actions.last.left - s.actions.first.right, 4);
    expect(_center(bar.labels.single.glyphs), closeTo(28, .75), reason: 'centered in a 56 bar too');
    // The glyphs are SSUI's secondary ink, 16 px, centered in their buttons.
    final glyphs = <RenderBox>[];
    bar.visitChildren((c) => glyphs.add(c as RenderBox));
    expect(glyphs, hasLength(3));
    final lead = glyphs.first.localToGlobal(Offset.zero) - bar.localToGlobal(Offset.zero) & glyphs.first.size;
    expect(lead.size, const Size(16, 16));
    expect(lead.center, s.leading!.center);
    expect(bar.iconColorOf(const BarIcon({})), const Color(0xFF4B5563));
  });

  testWidgets('centerTitle centers the title on the bar, kept between its slots', (tester) async {
    final tree = await _show(tester, {'bar': _appBar({'title': 'Inbox', 'centerTitle': true, 'leading': _menu})});
    final t = _bar(tree, 'bar').slots.title;
    expect(t.center.dx, closeTo(180, .5));
  });

  testWidgets('the node\'s props are over SSUI\'s: fill, ink, an elevation for the hairline, title style', (tester) async {
    final tree = await _show(tester, {
      'bar': _appBar({
        'title': 'Inbox',
        'backgroundColor': '#FF101418',
        'foregroundColor': '#FFFFF8E7',
        'elevation': 2,
        'titleTextStyle': {'fontSize': 20, 'fontWeight': 700},
        'actions': [_search],
      }),
    });
    final bar = _bar(tree, 'bar');
    expect(bar.backgroundColor, const Color(0xFF101418));
    expect(bar.titleColor, const Color(0xFFFFF8E7));
    expect(bar.iconColorOf(bar.spec.actions.single), const Color(0xFFFFF8E7));
    final g = bar.labels.single.glyphs.first;
    expect(g.height, greaterThan(16), reason: 'the 20 px title');
  });

  testWidgets('in a canvas\'s appBar slot it spans the top, the body below, no Scaffold; the view\'s top safe area is kept clear',
      (tester) async {
    tester.view.padding = const FakeViewPadding(top: 47 * 3);
    addTearDown(tester.view.reset);
    final (tree, _) = runningTree({
      'schema': 3,
      'roots': ['screen'],
      'nodes': {
        'screen': {
          'type': 'canvas',
          'slots': {'body': 'body', 'appBar': 'bar'},
          'layout': {'width': 390, 'height': 600},
        },
        'body': {'type': 'box', 'layout': {'width': {'fill': 390}, 'height': {'fill': 500}}},
        'bar': _appBar({'title': 'Inbox'}, width: {'fill': 390}, height: 56),
      },
    });
    addTearDown(tree.dispose);
    await tester.pumpWidget(Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'screen', interactive: true)));
    final bar = _bar(tree, 'bar');
    expect(controlViewPadding(bar).top, 47, reason: 'from the view, not MediaQuery');
    expect(rectOf(tree, 'bar'), const Rect.fromLTWH(0, 0, 390, 56 + 47));
    expect(rectOf(tree, 'body').top, 56 + 47, reason: 'the body below the bar');
    expect(_center(bar.labels.single.glyphs), closeTo(47 + 28, .75), reason: 'the title in the toolbar below the safe area');
    expect(_hasIsland(tree.boxOf('screen')!), isFalse);
  });

  testWidgets('screen readers hear the title as a header', (tester) async {
    final handle = tester.ensureSemantics();
    final tree = await _show(tester, {'bar': _appBar({'title': 'Inbox'})});
    final data = _bar(tree, 'bar').debugSemantics!.getSemanticsData();
    expect(data.label, 'Inbox');
    expect(data.flagsCollection.isHeader, isTrue);
    handle.dispose();
  });
}
