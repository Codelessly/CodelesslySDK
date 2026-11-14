// Chips and badges as render objects (render/controls/chips.dart): SSUI's
// look with nothing styled, the check mark's room kept so selecting never
// resizes a chip, the delete icon, selection by prop and by tap (written
// back), the label centred, the keyboard, screen readers, and the badge
// alone and over a child.
import 'dart:ui' show Tristate;

import 'package:codelessly_api/codelessly_api.dart' as api show WidgetState;
import 'package:codelessly_api/validate.dart' show validateDocument;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/controls/chips.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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

RenderChip _chip(RenderTree tree, String id) => _find<RenderChip>(tree, id);

Future<(NodeTree, RecordedInteractions)> _show(WidgetTester tester, Map<String, Map<String, Object?>> nodes,
    {bool dark = false, Object? fill, Map<String, Object?>? theme}) async {
  final doc = columnDoc(nodes, fill: fill);
  // A node in another's slot is not the column's child.
  final slotted = {for (final n in nodes.values) ...((n['slots'] as Map?)?.values ?? const [])};
  ((doc['nodes'] as Map)['col'] as Map)['children'] = [for (final id in nodes.keys) if (!slotted.contains(id)) id];
  final (tree, recorded) = runningTree(doc, dark: dark, theme: theme == null ? null : ThemeTokens.fromJson(theme));
  addTearDown(tree.dispose);
  await tester.pumpWidget(NodeView(tree: tree, rootId: 'col', interactive: true));
  return (tree, recorded);
}

/// Each label glyph's centre, minus the chip's centre (x, y).
Offset _labelOffCentre(RenderTree tree, String id) {
  final c = _chip(tree, id);
  final glyphs = c.labels.single.glyphs;
  final left = glyphs.map((g) => g.left).reduce((a, b) => a < b ? a : b);
  final right = glyphs.map((g) => g.right).reduce((a, b) => a > b ? a : b);
  final top = glyphs.map((g) => g.top).reduce((a, b) => a < b ? a : b);
  final bottom = glyphs.map((g) => g.bottom).reduce((a, b) => a > b ? a : b);
  return Offset((left + right) / 2 - c.size.width / 2, (top + bottom) / 2 - c.size.height / 2);
}

void main() {
  group('with nothing styled', () {
    testWidgets('each chip is SSUI\'s: a 24 px pill as wide as its content, tinted fill, hairline, label centred',
        (tester) async {
      final (tree, _) = await _show(tester, {
        for (final type in ['chip', 'actionChip', 'choiceChip', 'filterChip', 'inputChip']) type: {'type': type, 'props': {'label': 'Design'}},
      });
      for (final type in ['chip', 'actionChip', 'choiceChip', 'filterChip', 'inputChip']) {
        final c = _chip(tree, type);
        expect(rectOf(tree, type).height, 24, reason: type);
        expect(c.shape, isA<StadiumBorder>(), reason: '$type is a pill');
        expect(c.fillColor, const Color(0xFFF3F4F6), reason: '$type: SSUI\'s tertiaryBackground');
        expect(c.borderSide.color, const Color(0xFFE5E7EB), reason: '$type: SSUI\'s primaryBorder');
        expect(c.labelColor, const Color(0xFF111827));
        // An input chip centres its label and x together.
        expect(_labelOffCentre(tree, type).dx.abs(), lessThan(type == 'inputChip' ? 9.5 : .75), reason: '$type: label centred');
        expect(_labelOffCentre(tree, type).dy.abs(), lessThan(.75), reason: '$type: label centred');
      }
      // A plain chip and an action chip are the label in SSUI's padding.
      final plain = rectOf(tree, 'chip').width;
      expect(rectOf(tree, 'actionChip').width, plain);
      expect(plain, closeTo(_chip(tree, 'chip').labelWidths.whole + 22, .01), reason: '10 px inside a 1 px hairline');
      // A selectable chip keeps its check mark's room; an input chip its x.
      expect(rectOf(tree, 'filterChip').width, closeTo(plain + 12 + 6, .01));
      expect(rectOf(tree, 'inputChip').width, closeTo(plain + 12 + 6 + 12 + 6, .01));
      final validation = validateDocument(columnDoc({'c': {'type': 'filterChip', 'props': {'label': 'A'}}}));
      expect(validation.where((d) => d.code.name == 'zero_size'), isEmpty, reason: 'a chip with no layout hugs');
    });

    testWidgets('dark mode takes SSUI\'s dark tokens', (tester) async {
      final (tree, _) = await _show(tester, {
        'c': {'type': 'filterChip', 'props': {'label': 'On', 'selected': true}},
      }, dark: true, fill: '#FF1C1C1C');
      final c = _chip(tree, 'c');
      expect(c.labelColor, const Color(0xFF3B82F6), reason: 'SSUI\'s dark primary');
    });
  });

  testWidgets('selecting never resizes a chip: the check mark\'s room is kept, and what shows stays centred', (tester) async {
    final (tree, _) = await _show(tester, {
      'off': {'type': 'filterChip', 'props': {'label': 'Engineering'}},
      'on': {'type': 'filterChip', 'props': {'label': 'Engineering', 'selected': true}},
      'choice': {'type': 'choiceChip', 'props': {'label': 'Engineering', 'selected': true}},
    });
    expect(rectOf(tree, 'on').size, rectOf(tree, 'off').size);
    expect(rectOf(tree, 'choice').size, rectOf(tree, 'off').size);
    final on = _chip(tree, 'on'), off = _chip(tree, 'off');
    expect(on.showsCheck, isTrue);
    expect(off.showsCheck, isFalse);
    expect(_labelOffCentre(tree, 'off').dx.abs(), lessThan(.75), reason: 'unselected: the label alone, centred');
    // Selected: the check and the label together, centred.
    final glyphs = on.labels.single.glyphs;
    final right = glyphs.map((g) => g.right).reduce((a, b) => a > b ? a : b);
    final left = on.leadRect.left;
    expect((left - (on.size.width - right)).abs(), lessThan(1.5));
    expect(on.labelWidths.laidOut, closeTo(on.labelWidths.whole, .5), reason: 'the label is never cut');
    expect(on.fillColor, const Color(0x242563EB), reason: 'SSUI\'s activeTint');
    expect(on.labelColor, const Color(0xFF2563EB));
    expect(on.borderSide.color, const Color(0x472563EB), reason: 'SSUI\'s primaryTintBorder');
  });

  testWidgets('a chip narrower than its content draws it whole from its start', (tester) async {
    final (tree, _) = await _show(tester, {
      'narrow': {'type': 'filterChip', 'layout': {'width': 72, 'height': 32}, 'props': {'label': 'Engineering', 'selected': true}},
    });
    final c = _chip(tree, 'narrow');
    expect(rectOf(tree, 'narrow').size, const Size(72, 32), reason: 'the node keeps its box');
    expect(c.pillRect.width, greaterThan(72));
    expect(c.labelWidths.laidOut, closeTo(c.labelWidths.whole, .5));
  });

  testWidgets('a tap on a filter chip toggles it, writes back (changed before click), and eases the tint in', (tester) async {
    final (tree, recorded) = await _show(tester, {
      'f': {'type': 'filterChip', 'props': {'label': 'North'}},
    });
    final c = _chip(tree, 'f');
    await tester.tapAt(centreOf(tree, 'f'));
    await tester.pump();
    expect(c.selected, isTrue, reason: 'an unbound chip toggles itself');
    expect(recorded.fired, ['f changed', 'f click']);
    expect(c.stateValue(api.WidgetState.selected), lessThan(1), reason: 'easing in');
    await tester.pump(const Duration(milliseconds: 200));
    expect(c.stateValue(api.WidgetState.selected), 1);
    await tester.tapAt(centreOf(tree, 'f'));
    await tester.pump();
    expect(c.selected, isFalse);
  });

  testWidgets('an action chip fires click; a plain chip takes no tap or focus without a click reaction', (tester) async {
    final (tree, recorded) = await _show(tester, {
      'label': {'type': 'chip', 'props': {'label': 'Tag'}},
      'act': {'type': 'actionChip', 'props': {'label': 'Run'}},
    });
    await tester.tapAt(centreOf(tree, 'label'));
    await tester.tapAt(centreOf(tree, 'act'));
    expect(recorded.fired, ['act click']);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_chip(tree, 'act').focusHighlight, isTrue, reason: 'Tab skips the label chip');
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(recorded.fired, ['act click', 'act click']);
  });

  testWidgets('an input chip\'s delete icon fires deleted (a tap, or Delete when focused); the rest of it fires click',
      (tester) async {
    final (tree, recorded) = await _show(tester, {
      'in': {'type': 'inputChip', 'props': {'label': 'ada@example.com'}},
    });
    final c = _chip(tree, 'in');
    final origin = rectOf(tree, 'in').topLeft;
    await tester.tapAt(origin + c.deleteRect.center);
    await tester.pump();
    expect(recorded.fired, ['in deleted']);
    await tester.tapAt(origin + Offset(c.size.width / 3, c.size.height / 2));
    expect(recorded.fired, ['in deleted', 'in click']);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    expect(recorded.fired.last, 'in deleted');
    expect(c.deleteRect.left, greaterThan(c.labels.single.glyphs.last.right), reason: 'after the label');
  });

  testWidgets('a disabled chip draws at half opacity and takes no tap', (tester) async {
    final (tree, recorded) = await _show(tester, {
      'f': {'type': 'filterChip', 'props': {'label': 'Off', 'isEnabled': false}},
    });
    await tester.tapAt(centreOf(tree, 'f'));
    expect(recorded.fired, isEmpty);
    expect(_chip(tree, 'f').paintedAlpha, 128);
  });

  testWidgets('hover lays SSUI\'s overlay over the pill; nothing changes size', (tester) async {
    final (tree, _) = await _show(tester, {
      'a': {'type': 'actionChip', 'props': {'label': 'Run'}},
    });
    final before = rectOf(tree, 'a');
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(centreOf(tree, 'a'));
    await tester.pump();
    expect(_chip(tree, 'a').stateOverlay, const Color(0x0A000000));
    expect(rectOf(tree, 'a'), before);
  });

  testWidgets('own colours, side and shape apply over SSUI\'s', (tester) async {
    final (tree, _) = await _show(tester, {
      'c': {
        'type': 'choiceChip',
        'props': {
          'label': 'Go',
          'selected': true,
          'selectedColor': '#FF1F6F4A',
          'side': {'color': '#FFE4572E', 'width': 2},
          'shape': {'type': 'roundedRectangle', 'borderRadius': 4},
        },
      },
    });
    final c = _chip(tree, 'c');
    expect(c.fillColor, const Color(0xFF1F6F4A));
    expect(c.labelColor.computeLuminance(), greaterThan(.5), reason: 'reads on its own dark fill');
    expect(c.borderSide, const BorderSide(color: Color(0xFFE4572E), width: 2));
    expect(c.shape, isA<RoundedRectangleBorder>());
  });

  testWidgets('screen readers: a selectable chip is a button with its selected state', (tester) async {
    final handle = tester.ensureSemantics();
    final (tree, _) = await _show(tester, {
      'f': {'type': 'filterChip', 'props': {'label': 'North', 'selected': true}},
    });
    final data = _chip(tree, 'f').debugSemantics!.getSemanticsData();
    expect(data.label, 'North');
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.flagsCollection.isSelected, Tristate.isTrue);
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    handle.dispose();
  });

  group('badge', () {
    testWidgets('alone it is SSUI\'s badge: 20 high, tinted, a hairline, radius 5; a count is a pill', (tester) async {
      final (tree, _) = await _show(tester, {
        'label': {'type': 'badge', 'props': {'label': 'Draft'}},
        'count': {'type': 'badge', 'props': {'count': 1200}},
      });
      final b = _find<RenderBadge>(tree, 'label');
      expect(rectOf(tree, 'label').height, 20);
      expect(b.backgroundColor, const Color(0xFFF3F4F6));
      expect(b.borderColor, const Color(0xFFE5E7EB));
      expect(b.textStyle.color, const Color(0xFF4B5563));
      expect(b.labels.single.text, 'Draft');
      expect(_find<RenderBadge>(tree, 'count').label, '999+');
      final glyphs = b.labels.single.glyphs;
      final mid = (glyphs.first.left + glyphs.last.right) / 2;
      expect((mid - b.size.width / 2).abs(), lessThan(.75), reason: 'label centred');
    });

    testWidgets('over a child it is Flutter\'s: a count or a dot in the error colour at the corner', (tester) async {
      final (tree, _) = await _show(tester, {
        'b': {'type': 'badge', 'slots': {'child': 'box'}, 'props': {'count': 3}},
        'box': {'type': 'box', 'layout': {'width': 32, 'height': 24}},
        'dot': {'type': 'badge', 'slots': {'child': 'box2'}},
        'box2': {'type': 'box', 'layout': {'width': 32, 'height': 24}},
      });
      expect(rectOf(tree, 'b').size, const Size(32, 24));
      final b = _find<RenderBadge>(tree, 'b');
      expect(b.backgroundColor, const Color(0xFFDC2626));
      expect(b.textStyle.color, const Color(0xFFFFFFFF));
      expect(b.badgeRect.right, greaterThan(32), reason: 'past the child\'s corner');
      expect(_find<RenderBadge>(tree, 'dot').badgeRect.size, const Size(6, 6));
    });
  });
}
