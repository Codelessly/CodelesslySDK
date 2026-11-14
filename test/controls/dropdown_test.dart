// The dropdown as a render object (render/controls/dropdown.dart) and its
// menu (render/controls/menu.dart): SSUI's Select with nothing styled, the
// menu as an entry of the root's overlay layer anchored under the field
// (flipping above, at least its width, scrolling when long), dismissal and
// focus, the keyboard, value write-back, semantics, and the props it keeps
// from Flutter's DropdownButton.
import 'dart:ui' show Tristate;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/controls/dropdown.dart';
import 'package:codelessly_sdk/src/render/controls/field_frame.dart';
import 'package:codelessly_sdk/src/render/controls/menu.dart';
import 'package:codelessly_sdk/src/render/controls/root.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

RenderDropdown _dropdown(RenderTree tree, String id) {
  RenderDropdown? found;
  void visit(RenderObject o) {
    if (o is RenderDropdown) found ??= o;
    o.visitChildren(visit);
  }

  visit(tree.boxOf(id)!);
  return found!;
}

const _fruit = ['Apple', 'Banana', 'Cherry', 'Date', 'Elderberry'];

Map<String, Object?> _select({Object? value, List<String> items = _fruit, Map<String, Object?> props = const {}, Object? width, Object? height}) => {
      'type': 'dropdown',
      'layout': {'width': width ?? 200, 'height': height ?? {'hug': 0}},
      'props': {'items': items, 'value': ?value, ...props},
    };

Future<(NodeTree, RecordedInteractions)> _show(WidgetTester tester, Map<String, Map<String, Object?>> nodes,
    {Map<String, Object?>? theme, bool dark = false, Object? fill, double height = 300}) async {
  final (tree, recorded) =
      runningTree(columnDoc(nodes, fill: fill, height: height), theme: theme == null ? null : ThemeTokens.fromJson(theme), dark: dark);
  addTearDown(tree.dispose);
  await tester.pumpWidget(NodeView(tree: tree, rootId: 'col', interactive: true));
  return (tree, recorded);
}

RenderControlRoot _root(WidgetTester tester) => tester.renderObject<RenderControlRoot>(find.byType(NodeView));

Rect _global(RenderBox b, [Rect? local]) => MatrixUtils.transformRect(b.getTransformTo(null), local ?? Offset.zero & b.size);

void main() {
  group('with nothing styled', () {
    testWidgets('it is SSUI\'s Select: 28 high, primaryBackground, a hairline, radius 7, the value in primaryText', (tester) async {
      final (tree, _) = await _show(tester, {'s': _select(value: 'Banana')});
      final d = _dropdown(tree, 's');
      expect(rectOf(tree, 's').height, 28);
      expect(d.fillNow, const Color(0xFFFFFFFF));
      expect(d.currentBorder.side.color, const Color(0xFFE5E7EB));
      expect(d.currentBorder.side.width, 1);
      expect(d.boxShape.tlRadiusX, 7);
      expect(d.selectedLabel, 'Banana');
      expect(d.spec.valueStyle.color, const Color(0xFF111827));
      expect(d.spec.valueStyle.fontSize, 12);
      expect(d.chevronColor, const Color(0xFF9CA3AF), reason: 'SSUI\'s tertiaryText chevron');
      expect(d.chevronRect.width, 14);
      // The chevron sits at the right padding (8) of the box.
      expect(d.boxRect.right - d.chevronRect.right, 8);
      expect(d.icon, isNull, reason: 'no Material arrow glyph');
    });

    testWidgets('with no value it shows the hint in tertiaryText; a hugging one fits its widest item', (tester) async {
      final (tree, _) = await _show(tester, {
        's': _select(props: {'hint': 'Pick a fruit'}),
        'hug': _select(width: {'hug': 0}, items: ['A', 'Much longer item']),
      });
      final d = _dropdown(tree, 's');
      expect(d.hintShown, isTrue);
      expect(d.hintStyle.color, const Color(0xFF9CA3AF));
      expect(d.labels.map((l) => l.text), ['Pick a fruit']);
      final hug = rectOf(tree, 'hug');
      final p = TextPainter(text: TextSpan(text: 'Much longer item', style: _dropdown(tree, 'hug').spec.valueStyle), textDirection: TextDirection.ltr)..layout();
      expect(hug.width, greaterThan(p.width + 14));
      expect(hug.width, lessThan(p.width + 50));
      p.dispose();
    });

    testWidgets('in dark mode it takes SSUI\'s dark tokens', (tester) async {
      final (tree, _) = await _show(tester, {'s': _select(value: 'Apple')}, dark: true, fill: '#FF1C1C1C');
      final d = _dropdown(tree, 's');
      expect(d.fillNow, const Color(0xFF141414));
      expect(d.currentBorder.side.color, const Color(0xFF383838));
      expect(d.spec.valueStyle.color, const Color(0xFFFFFFFF));
    });
  });

  group('the menu', () {
    testWidgets('a tap opens it in the root\'s overlay layer, under the field, its width, SSUI\'s surface; the selected row marked',
        (tester) async {
      final (tree, _) = await _show(tester, {'s': _select(value: 'Cherry')});
      final root = _root(tester);
      expect(root.overlayEntries, isEmpty);
      await tester.tapAt(centreOf(tree, 's'));
      await tester.pump();
      final d = _dropdown(tree, 's');
      expect(d.isOpen, isTrue);
      final layer = root.overlayEntries.single as RenderPopupLayer;
      final menu = layer.child! as RenderMenu;
      final field = _global(d, d.boxRect);
      final box = _global(menu);
      expect(box.top, field.bottom + 4, reason: 'SSUI\'s 4 px gap under the field');
      expect(box.left, field.left);
      expect(box.width, field.width);
      expect(menu.look.fill, const Color(0xFFFFFFFF));
      expect(menu.look.radius, 7);
      expect(menu.look.border?.color, const Color(0xFFE5E7EB));
      expect(menu.look.shadows, isNotEmpty, reason: 'SSUI\'s level3 for floating surfaces');
      expect(menu.rows.length, 5);
      expect(menu.rows.first.size.height, 28);
      expect(menu.rows[2].item.selected, isTrue);
      expect(menu.look.selectedFill, const Color(0x242563EB), reason: 'activeTint');
      expect(menu.look.selectedTextStyle.color, const Color(0xFF2563EB));
      expect(menu.active, 2, reason: 'the chosen item is where the keyboard starts');
      expect(d.currentBorder.side.color, const Color(0x802563EB), reason: 'the focus border while open');
      // No Material: the menu is ours, no route or card.
      expect(find.byWidgetPredicate((w) => w.runtimeType.toString().contains('Dropdown')), findsNothing);
    });

    testWidgets('it flips above the field when there is no room below, and is at least 120 wide', (tester) async {
      final (tree, _) = await _show(tester, {
        'gap': {'type': 'box', 'layout': {'width': 10, 'height': 520}},
        's': _select(value: 'Apple', width: 80),
      }, height: 600);
      await tester.tapAt(centreOf(tree, 's'));
      await tester.pump();
      final d = _dropdown(tree, 's');
      final menu = (_root(tester).overlayEntries.single as RenderPopupLayer).child!;
      final box = _global(menu), field = _global(d, d.boxRect);
      expect(box.bottom, field.top - 4);
      expect(box.width, 120);
    });

    testWidgets('a long menu scrolls: 240 high at most, the chosen row revealed, the wheel scrolls it', (tester) async {
      final items = [for (var i = 0; i < 30; i++) 'Item $i'];
      final (tree, _) = await _show(tester, {'s': _select(value: 'Item 20', items: items)}, height: 600);
      await tester.tapAt(centreOf(tree, 's'));
      await tester.pump();
      final menu = (_root(tester).overlayEntries.single as RenderPopupLayer).child! as RenderMenu;
      expect(menu.size.height, 240);
      expect(menu.maxScrollOffset, greaterThan(0));
      expect(menu.scrollOffset, greaterThan(0), reason: 'Item 20 is in view');
      final before = menu.scrollOffset;
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(_global(menu).center));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, -60)));
      await tester.pump();
      expect(menu.scrollOffset, before - 60);
    });

    testWidgets('a tap on a row chooses it: the field shows it, `changed` fires, the menu closes, focus stays', (tester) async {
      final (tree, recorded) = await _show(tester, {'s': _select(value: 'Apple')});
      await tester.tapAt(centreOf(tree, 's'));
      await tester.pump();
      final menu = (_root(tester).overlayEntries.single as RenderPopupLayer).child! as RenderMenu;
      await tester.tapAt(_global(menu.rows[3]).center);
      await tester.pump();
      final d = _dropdown(tree, 's');
      expect(d.isOpen, isFalse);
      expect(_root(tester).overlayEntries, isEmpty);
      expect(d.selectedLabel, 'Date');
      expect(recorded.fired, ['s changed']);
      expect(d.focusNode.hasFocus, isTrue);
    });

    testWidgets('a press outside closes it without choosing, and nothing under it takes the press; focus returns to the field',
        (tester) async {
      final (tree, recorded) = await _show(tester, {
        's': _select(value: 'Apple'),
        'b': hugging('filledButton', {'label': 'Below'}),
      });
      await tester.tapAt(centreOf(tree, 's'));
      await tester.pump();
      await tester.tapAt(const Offset(390, 290));
      await tester.pump();
      final d = _dropdown(tree, 's');
      expect(d.isOpen, isFalse);
      expect(d.selectedLabel, 'Apple');
      expect(d.focusNode.hasFocus, isTrue);
      expect(recorded.fired, isEmpty);
    });
  });

  group('the keyboard', () {
    testWidgets('Tab, then Enter opens; arrows move; Enter chooses', (tester) async {
      final (tree, recorded) = await _show(tester, {'s': _select(value: 'Apple')});
      final d = _dropdown(tree, 's');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(d.focusNode.hasFocus, isTrue);
      expect(d.currentBorder.side.width, 1.5, reason: 'keyboard focus shows SSUI\'s focus border');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(d.isOpen, isTrue);
      expect(d.menu.active, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      expect(d.menu.active, 2);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      expect(d.menu.active, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(d.isOpen, isFalse);
      expect(d.selectedLabel, 'Banana');
      expect(recorded.fired, ['s changed']);
      expect(d.focusNode.hasFocus, isTrue);
    });

    testWidgets('Space and Arrow Down open it; Home/End jump; type-ahead finds a row; Escape closes and keeps the focus',
        (tester) async {
      final (tree, recorded) = await _show(tester, {'s': _select()});
      final d = _dropdown(tree, 's');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(d.isOpen, isTrue);
      expect(d.menu.active, isNull, reason: 'nothing chosen yet');
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      expect(d.menu.active, 4);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      expect(d.menu.active, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      expect(d.menu.active, 2, reason: 'C: Cherry');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(d.isOpen, isFalse);
      expect(d.focusNode.hasFocus, isTrue, reason: 'Escape closes the menu, not the focus');
      expect(recorded.fired, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(d.isOpen, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(d.isOpen, isFalse, reason: 'Tab closes it and moves on');
    });
  });

  testWidgets('a bound value is written back by `changed` and a new value from the node replaces the shown one', (tester) async {
    final (tree, _) = await _show(tester, {'s': _select(value: 'Apple')});
    final d = _dropdown(tree, 's');
    d.spec = DropdownSpec(tokens: d.spec.tokens, scale: d.spec.scale, items: d.spec.items, labels: d.spec.labels, value: 'Elderberry', menu: d.spec.menu);
    await tester.pump();
    expect(d.selectedLabel, 'Elderberry');
    expect(d.menu.items[4].selected, isTrue);
  });

  testWidgets('disabled: half opacity, no menu, no Tab stop', (tester) async {
    final (tree, _) = await _show(tester, {'s': _select(value: 'Apple', props: {'enabled': false})});
    final d = _dropdown(tree, 's');
    expect(d.paintedAlpha, 128);
    await tester.tapAt(centreOf(tree, 's'));
    await tester.pump();
    expect(d.isOpen, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    expect(d.focusNode.hasFocus, isFalse);
  });

  testWidgets('screen readers: a button with its value, expanded while open, the menu rows as buttons with the selected one',
      (tester) async {
    final handle = tester.ensureSemantics();
    final (tree, _) = await _show(tester, {'s': _select(value: 'Banana')});
    final d = _dropdown(tree, 's');
    var data = d.debugSemantics!.getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.value, 'Banana');
    expect(data.flagsCollection.isExpanded, Tristate.isFalse);
    tester.binding.renderViews.first.owner!.semanticsOwner!.performAction(d.debugSemantics!.id, SemanticsAction.tap);
    await tester.pump();
    data = d.debugSemantics!.getSemanticsData();
    expect(data.flagsCollection.isExpanded, Tristate.isTrue);
    final rows = d.menu.rows;
    final second = rows[1].debugSemantics!.getSemanticsData();
    expect(second.label, 'Banana');
    expect(second.flagsCollection.isButton, isTrue);
    expect(second.flagsCollection.isSelected, Tristate.isTrue);
    expect(rows[0].debugSemantics!.getSemanticsData().flagsCollection.isSelected, Tristate.isFalse);
    handle.dispose();
  });

  testWidgets('the node\'s props: dropdownColor, borderRadius, item style, alignment, icon colour, no underline', (tester) async {
    final (tree, _) = await _show(tester, {
      's': _select(value: 'Apple', props: {
        'dropdownColor': '#FFFEF3C7',
        'borderRadius': 12,
        'style': {'fontSize': 15},
        'iconEnabledColor': '#FF16A34A',
        'alignment': 'centerRight',
        'underline': false,
      }),
    });
    final d = _dropdown(tree, 's');
    expect(d.chevronColor, const Color(0xFF16A34A));
    expect(d.currentBorder.kind, FieldBorderKind.none);
    expect(d.fillNow, isNull);
    final glyphs = d.labels.single.glyphs;
    expect(glyphs.last.right, closeTo(d.chevronRect.left - 6, 2), reason: 'aligned to the end, the gap before the chevron');
    expect(d.menu.look.fill, const Color(0xFFFEF3C7));
    expect(d.menu.look.radius, 12);
    expect(d.menu.look.textStyle.fontSize, 15);
  });

  testWidgets('the value\'s label is centred in the field at every step of the scale', (tester) async {
    final (tree, _) = await _show(tester, {
      for (final h in [24.0, 28.0, 32.0, 36.0, 44.0]) 's$h': _select(value: 'Banana', height: h),
    }, height: 400);
    for (final h in [24.0, 28.0, 32.0, 36.0, 44.0]) {
      final d = _dropdown(tree, 's$h');
      final g = d.labels.single.glyphs;
      final mid = (g.first.top + g.first.bottom) / 2;
      expect(mid, closeTo(d.boxRect.center.dy, .75), reason: '$h');
    }
  });
}
