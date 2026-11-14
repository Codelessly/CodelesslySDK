// List tiles, accordions and expansion tiles as render objects
// (render/controls/{tile,expansion}.dart): SSUI's ListRow and Accordion with
// nothing styled, the slots laid out by the tree, the whole header as the
// tap target, the keyboard, the open and close animation on the tree's
// ticker with the content clipped while it moves, and screen readers.
import 'dart:ui' show Tristate;

import 'package:codelessly_api/codelessly_api.dart' as api show WidgetState;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/controls/expansion.dart';
import 'package:codelessly_sdk/src/render/controls/tile.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

T _find<T extends RenderObject>(RenderTree tree, String id) {
  T? found;
  void visit(RenderObject o) {
    if (found != null) return;
    if (o is T) {
      found = o;
      return;
    }
    o.visitChildren(visit);
  }

  visit(tree.boxOf(id)!);
  return found!;
}

RenderListTile _tile(RenderTree tree, String id) => _find<RenderListTile>(tree, id);
RenderExpansion _expansion(RenderTree tree, String id) => _find<RenderExpansion>(tree, id);

Future<(NodeTree, RecordedInteractions)> _show(WidgetTester tester, Map<String, Map<String, Object?>> nodes,
    {Map<String, Object?>? theme, bool dark = false, Object? fill, double height = 600}) async {
  final doc = columnDoc({}, height: height, fill: fill);
  final col = (doc['nodes']! as Map)['col'] as Map<String, Object?>;
  // Only the nodes not placed in a slot or under another are the column's.
  final placed = <String>{};
  for (final n in nodes.values) {
    placed.addAll(((n['slots'] as Map?)?.values ?? const []).cast<String>());
    placed.addAll(((n['children'] as List?) ?? const []).cast<String>());
  }
  col['children'] = [for (final id in nodes.keys) if (!placed.contains(id)) id];
  (doc['nodes']! as Map).addAll(nodes);
  final (tree, recorded) = runningTree(doc, theme: theme == null ? null : ThemeTokens.fromJson(theme), dark: dark);
  addTearDown(tree.dispose);
  await tester.pumpWidget(NodeView(tree: tree, rootId: 'col', interactive: true));
  return (tree, recorded);
}

Map<String, Object?> _text(String text, {Object width = const {'hug': 0}}) => {
      'type': 'text',
      'layout': {'width': width, 'height': {'hug': 0}},
      'props': {
        'text': text,
        'style': {'fontSize': 13, 'color': '#FF111827'},
      },
    };

Map<String, Object?> _box(double w, double h) => {
      'type': 'box',
      'layout': {'width': w, 'height': h},
    };

const _click = [
  {
    'trigger': {'type': 'click'},
    'actions': <Object?>[],
  },
];

/// A list tile filling the column's width, with [slots].
Map<String, Object?> _listTile(Map<String, String> slots, {Map<String, Object?> props = const {}, bool click = false}) => {
      'type': 'listTile',
      'layout': {'width': 368, 'height': {'hug': 0}},
      'slots': slots,
      'props': props,
      if (click) 'actions': _click,
    };

/// An expansion tile filling the column's width: a header of [title] (and
/// [leading]) and [children].
Map<String, Object?> _expansionTile(List<String> children, {Map<String, Object?> props = const {}}) => {
      'type': 'expansionTile',
      'layout': {'width': 368, 'height': {'hug': 0}},
      'slots': {'tile': 'header'},
      'props': props,
      'children': children,
    };

void main() {
  group('list tile', () {
    testWidgets('with nothing styled it is SSUI\'s ListRow: 36 high, 12 in, 10 apart, a hairline under it', (tester) async {
      final (tree, _) = await _show(tester, {
        'row': _listTile({'leading': 'icon', 'title': 'title', 'trailing': 'end'}),
        'icon': _box(16, 16),
        'title': _text('Invoice #1042'),
        'end': _box(40, 20),
        'dense': _listTile({'title': 'dtitle'}, props: {'dense': true}),
        'dtitle': _text('Dense'),
      });
      final row = rectOf(tree, 'row');
      expect(row.height, 36);
      expect(row.width, 368, reason: 'its node\'s width');
      expect(rectOf(tree, 'icon').left - row.left, 12);
      expect(rectOf(tree, 'title').left - rectOf(tree, 'icon').right, 10);
      expect(row.right - rectOf(tree, 'end').right, 12);
      for (final id in ['icon', 'title', 'end']) {
        expect(rectOf(tree, id).center.dy, closeTo(row.center.dy, .01), reason: '$id centred on the row');
      }
      final tile = _tile(tree, 'row');
      expect(tile.dividerColor, const Color(0xFFE5E7EB), reason: 'SSUI\'s primaryBorder');
      expect(tile.fillColor, isNull);
      expect(rectOf(tree, 'dense').height, 28, reason: 'SSUI\'s dense row');
    });

    testWidgets('a subtitle goes under the title; the row grows to hold them; a hugging tile hugs', (tester) async {
      final (tree, _) = await _show(tester, {
        'row': _listTile({'title': 'title', 'subtitle': 'sub'}),
        'title': _text('Ada Lovelace'),
        'sub': _text('ada@example.com'),
        'hug': {
          'type': 'listTile',
          'layout': {'width': {'hug': 0}, 'height': {'hug': 0}},
          'slots': {'title': 'htitle'},
        },
        'htitle': _text('Short'),
        'empty': {'type': 'listTile', 'layout': {'width': {'hug': 0}, 'height': {'hug': 0}}},
      });
      final title = rectOf(tree, 'title'), sub = rectOf(tree, 'sub'), row = rectOf(tree, 'row');
      expect(sub.top, closeTo(title.bottom + 1, .01));
      expect(sub.left, title.left);
      expect(row.height, greaterThanOrEqualTo(title.height + sub.height + 12));
      expect(rectOf(tree, 'hug').width, closeTo(rectOf(tree, 'htitle').width + 24, .01));
      expect(rectOf(tree, 'empty').size, const Size(24, 36), reason: 'never 0 × 0');
    });

    testWidgets('selected takes SSUI\'s active tint and says so; disabled is half opacity with no tap or Tab stop',
        (tester) async {
      final handle = tester.ensureSemantics();
      final (tree, recorded) = await _show(tester, {
        'on': _listTile({'title': 't1'}, props: {'selected': true}, click: true),
        't1': _text('Selected'),
        'off': _listTile({'title': 't2'}, props: {'enabled': false}, click: true),
        't2': _text('Off'),
        'bound': _listTile({'title': 't3'}),
        't3': _text('Bound'),
      });
      final on = _tile(tree, 'on');
      expect(on.fillColor, const Color(0x242563EB));
      expect(on.debugSemantics!.getSemanticsData().flagsCollection.isSelected, Tristate.isTrue);
      expect(on.debugSemantics!.getSemanticsData().label, 'Selected');
      tree.setState('bound', api.WidgetState.selected, true);
      await tester.pump();
      expect(_tile(tree, 'bound').fillColor, const Color(0x242563EB), reason: 'a bound selected state, too');
      await tester.tapAt(centreOf(tree, 'off'));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      expect(_tile(tree, 'on').focusNode.hasFocus, isTrue, reason: 'Tab skips the disabled tile');
      expect(recorded.fired, isEmpty);
      expect(_tile(tree, 'off').paintedAlpha, 128);
      expect(_tile(tree, 'off').debugSemantics!.getSemanticsData().flagsCollection.isEnabled, Tristate.isFalse);
      handle.dispose();
    });

    testWidgets('the whole row is the tap target; hover and press lay SSUI\'s overlays; Tab, a ring, Enter', (tester) async {
      final (tree, recorded) = await _show(tester, {
        'row': _listTile({'title': 'title'}, click: true),
        'title': _text('Open'),
      });
      final row = rectOf(tree, 'row');
      await tester.tapAt(Offset(row.right - 4, row.top + 3));
      await tester.tapAt(centreOf(tree, 'title'));
      expect(recorded.fired, ['row click', 'row click']);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(row.centerRight - const Offset(8, 0));
      await tester.pump();
      expect(_tile(tree, 'row').stateOverlay, const Color(0x0A000000));
      await mouse.down(row.centerRight - const Offset(8, 0));
      await tester.pump();
      expect(_tile(tree, 'row').stateOverlay, const Color(0x14000000));
      await mouse.up();
      await mouse.moveTo(Offset.zero);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_tile(tree, 'row').focusHighlight, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(recorded.fired.last, 'row click');
      expect(recorded.fired, hasLength(4));
    });
  });

  testWidgets('on a touch screen a dense tile takes taps in a 44 px band around it', (tester) async {
    final (tree, recorded) = await _show(tester, {
      'row': _listTile({'title': 'title'}, props: {'dense': true}, click: true),
      'title': _text('Dense'),
    });
    final r = rectOf(tree, 'row');
    expect(r.height, 28);
    await tester.tapAt(Offset(r.center.dx, r.bottom + 6));
    expect(recorded.fired, ['row click']);
  });

  group('expansion tile', () {
    testWidgets('the whole header is the tap target: its edge, its title, the chevron', (tester) async {
      final (tree, recorded) = await _show(tester, {
        'more': _expansionTile(['body']),
        'header': {'type': 'listTile', 'slots': {'title': 'title'}},
        'title': _text('Shipping'),
        'body': _box(200, 80),
      });
      final x = _expansion(tree, 'more');
      expect(x.expanded, isFalse);
      final head = x.headerRect.shift(rectOf(tree, 'more').topLeft);
      expect(head.height, 36, reason: 'a ListRow header');
      expect(rectOf(tree, 'more').height, 36, reason: 'closed: the header only');
      for (final at in [head.centerLeft + const Offset(3, 0), centreOf(tree, 'title'), head.centerRight - const Offset(14, 0)]) {
        final before = x.expanded;
        await tester.tapAt(at);
        await tester.pumpAndSettle();
        expect(x.expanded, !before, reason: 'a tap at $at toggles');
      }
      expect(recorded.fired, ['more click', 'more changed', 'more click', 'more changed', 'more click', 'more changed']);
      expect(x.expanded, isTrue);
      expect(rectOf(tree, 'more').height, 36 + 80);
      // A tap in the content is the content's, not the header's.
      await tester.tapAt(centreOf(tree, 'body'));
      await tester.pumpAndSettle();
      expect(x.expanded, isTrue);
    });

    testWidgets('it opens on the tree\'s ticker over 150 ms, the content clipped while it moves', (tester) async {
      final (tree, _) = await _show(tester, {
        'more': _expansionTile(['body']),
        'header': {'type': 'listTile', 'slots': {'title': 'title'}},
        'title': _text('Shipping'),
        'body': _box(200, 80),
      });
      final x = _expansion(tree, 'more');
      await tester.tapAt(centreOf(tree, 'title'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 75));
      expect(x.animating, isTrue);
      expect(x.progress, inExclusiveRange(0, 1));
      final h = rectOf(tree, 'more').height;
      expect(h, inExclusiveRange(36, 116));
      expect(x.clipsContent, isTrue);
      await tester.pump(const Duration(milliseconds: 80));
      expect(x.animating, isFalse);
      expect(x.progress, 1);
      expect(rectOf(tree, 'more').height, 116);
      expect(x.clipsContent, isFalse);
      // The chevron: SSUI's tertiary text, turned to point down; hairlines
      // above and below while open.
      expect(x.chevronColor, const Color(0xFF9CA3AF));
      expect(x.dividerColor, const Color(0xFFE5E7EB));
    });

    testWidgets('Tab focuses the header with SSUI\'s ring; Enter and Space toggle it', (tester) async {
      final (tree, recorded) = await _show(tester, {
        'more': _expansionTile(['body']),
        'header': {'type': 'listTile', 'slots': {'title': 'title'}},
        'title': _text('Shipping'),
        'body': _box(200, 80),
      });
      final x = _expansion(tree, 'more');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(x.focusHighlight, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(x.expanded, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(x.expanded, isFalse);
      expect(recorded.fired, ['more click', 'more changed', 'more click', 'more changed']);
    });

    testWidgets('a screen reader hears a button named by its title, expanded or collapsed', (tester) async {
      final handle = tester.ensureSemantics();
      final (tree, _) = await _show(tester, {
        'more': _expansionTile(['body'], props: {'initiallyExpanded': true}),
        'header': {'type': 'listTile', 'slots': {'title': 'title'}},
        'title': _text('Shipping'),
        'body': _text('Free over 50'),
      });
      final x = _expansion(tree, 'more');
      var data = x.debugSemantics!.getSemanticsData();
      expect(data.label, 'Shipping');
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isExpanded, Tristate.isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      tester.binding.renderViews.first.owner!.semanticsOwner!.performAction(x.debugSemantics!.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      data = x.debugSemantics!.getSemanticsData();
      expect(data.flagsCollection.isExpanded, Tristate.isFalse);
      handle.dispose();
    });

    testWidgets('a leading control affinity puts the chevron first; a trailing slot takes the chevron\'s place',
        (tester) async {
      final (tree, _) = await _show(tester, {
        'lead': _expansionTile(['b1'], props: {'controlAffinity': 'leading'}),
        'header': {'type': 'listTile', 'slots': {'title': 't1'}},
        't1': _text('Leading'),
        'b1': _box(10, 10),
        'own': {..._expansionTile(['b2']), 'slots': {'tile': 'header2'}},
        'header2': {'type': 'listTile', 'slots': {'title': 't2', 'trailing': 'end'}},
        't2': _text('Own trailing'),
        'end': _box(24, 24),
        'b2': _box(10, 10),
      });
      final lead = rectOf(tree, 'lead');
      expect(rectOf(tree, 't1').left - lead.left, 12 + 16 + 10, reason: 'padding, the chevron, the gap');
      final own = rectOf(tree, 'own');
      expect(own.right - rectOf(tree, 'end').right, 12);
      expect(rectOf(tree, 't2').left - own.left, 12);
    });

    testWidgets('on a design canvas it is drawn open or closed as the node says, at rest', (tester) async {
      final doc = columnDoc({
        'more': _expansionTile(['body'], props: {'initiallyExpanded': true}),
      });
      (doc['nodes']! as Map).addAll(<String, Map<String, Object?>>{
        'header': {'type': 'listTile', 'slots': {'title': 'title'}},
        'title': _text('Shipping'),
        'body': _box(200, 80),
      });
      final tree = NodeTree(DocumentSource(LayoutDocument.fromJson(doc)));
      addTearDown(tree.dispose);
      await tester.pumpWidget(NodeView(tree: tree, rootId: 'col'));
      expect(rectOf(tree, 'more').height, 116);
      expect(_expansion(tree, 'more').stateOverlay, isNull);
    });
  });

  group('accordion', () {
    Map<String, Object?> accordion(String header, String content, {bool expanded = true}) => {
          'type': 'accordion',
          'layout': {'width': 368, 'height': {'hug': 0}},
          'props': {'expanded': expanded},
          'children': [header, content],
        };

    testWidgets('SSUI\'s Accordion: a tinted header panel with a chevron, the content in a panel under it', (tester) async {
      final (tree, _) = await _show(tester, {
        'faq': accordion('q', 'a'),
        'q': _text('What is included?'),
        'a': _text('Everything.', width: const {'fill': 300}),
      });
      final a = _expansion(tree, 'faq');
      expect(a.expanded, isTrue, reason: 'open by default, as before');
      expect(a.headerFill, const Color(0xFFF3F4F6), reason: 'SSUI\'s tertiaryBackground');
      expect(a.chevronColor, const Color(0xFF9CA3AF));
      final faq = rectOf(tree, 'faq');
      expect(rectOf(tree, 'q').left - faq.left, 17, reason: '16 inside a 1 px border');
      expect(rectOf(tree, 'q').center.dy - faq.top, closeTo(a.headerRect.height / 2, .01));
      expect(a.headerRect.height, 46, reason: '12 + the 20 px chevron + 12, in the border');
      expect(rectOf(tree, 'a').left - faq.left, 17);
      expect(rectOf(tree, 'a').top - faq.top, 46 + 17);
      expect(rectOf(tree, 'a').width, 368 - 34);
    });

    testWidgets('each opens and closes on its own (several may be open); a tap in the content does nothing',
        (tester) async {
      final (tree, recorded) = await _show(tester, {
        'one': accordion('q1', 'a1'),
        'q1': _text('One'),
        'a1': _box(100, 40),
        'two': accordion('q2', 'a2', expanded: false),
        'q2': _text('Two'),
        'a2': _box(100, 40),
      });
      expect(rectOf(tree, 'two').height, 46);
      await tester.tapAt(centreOf(tree, 'q2'));
      await tester.pumpAndSettle();
      expect(_expansion(tree, 'one').expanded, isTrue);
      expect(_expansion(tree, 'two').expanded, isTrue);
      await tester.tapAt(centreOf(tree, 'a1'));
      await tester.pumpAndSettle();
      expect(_expansion(tree, 'one').expanded, isTrue);
      await tester.tapAt(rectOf(tree, 'one').topRight + const Offset(-20, 23));
      await tester.pumpAndSettle();
      expect(_expansion(tree, 'one').expanded, isFalse, reason: 'the chevron end of the header');
      expect(rectOf(tree, 'one').height, 46);
      expect(recorded.fired, ['two click', 'two changed', 'one click', 'one changed']);
    });

    testWidgets('a change of the node\'s expanded opens it, animated',
        (tester) async {
      final (tree, _) = await _show(tester, {
        'faq': accordion('q', 'a', expanded: false),
        'q': _text('Q'),
        'a': _box(100, 40),
      });
      final a = _expansion(tree, 'faq');
      a.expandedFrom(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(a.progress, inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(a.progress, 1);
      expect(rectOf(tree, 'faq').height, 46 + 40 + 34);
    });

    testWidgets('single-open, as before: expanded bound to a variable its click sets closes the others', (tester) async {
      Map<String, Object?> item(int i) => {
            ...accordion('q$i', 'a$i', expanded: false),
            'bind': {'props.expanded': '\${= open == $i}'},
            'actions': [
              {
                'trigger': {'type': 'click'},
                'actions': [
                  {'type': 'setVariable', 'variable': 'open', 'value': '$i'},
                ],
              },
            ],
          };
      final doc = columnDoc({'one': item(1), 'two': item(2)}, height: 600);
      (doc['nodes']! as Map).addAll(<String, Map<String, Object?>>{
        'q1': _text('One'),
        'a1': _box(100, 40),
        'q2': _text('Two'),
        'a2': _box(100, 40),
      });
      final scope = VariableScope([const Variable(name: 'open', type: VariableType.integer, value: 1)]);
      final binder = NodeBinder(scope: scope, projectScope: scope);
      final tree = NodeTree(DocumentSource(LayoutDocument.fromJson(doc)),
          binder: binder, environment: const IslandEnvironment(interactive: true));
      final reactions = TreeReactions(
          runner: const CodelesslyActions(), context: RuntimeActionContext(scope: scope, tree: tree, services: Services()));
      tree.interactions = reactions;
      addTearDown(() {
        reactions.dispose();
        tree.dispose();
        binder.dispose();
      });
      await tester.pumpWidget(NodeView(tree: tree, rootId: 'col', interactive: true));
      expect(_expansion(tree, 'one').expanded, isTrue);
      expect(_expansion(tree, 'two').expanded, isFalse);
      await tester.tapAt(centreOf(tree, 'q2'));
      await tester.pumpAndSettle();
      expect(_expansion(tree, 'two').expanded, isTrue);
      expect(_expansion(tree, 'one').expanded, isFalse, reason: 'its bound expanded changed: it closes');
      expect(rectOf(tree, 'one').height, 46);
    });

    testWidgets('in dark mode it takes SSUI\'s dark panels', (tester) async {
      final (tree, _) = await _show(tester, {
        'faq': accordion('q', 'a'),
        'q': _text('Q'),
        'a': _box(100, 40),
      }, dark: true, fill: '#FF1C1C1C');
      final a = _expansion(tree, 'faq');
      expect(a.headerFill, const Color(0xFF383838));
      expect(a.chevronColor, const Color(0x66FFFFFF));
    });
  });
}
