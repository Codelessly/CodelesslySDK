// Buttons as render objects (render/controls/buttons.dart): SSUI's look with
// nothing styled, the document's theme over it, their states (hover, press,
// focus, disabled, selected), the keyboard, screen readers, tooltips, and
// the props they keep from Flutter's buttons.
import 'dart:ui' show Tristate;

import 'package:codelessly_api/codelessly_api.dart' as api show WidgetState;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/controls/buttons.dart';
import 'package:codelessly_sdk/src/render/controls/overlay.dart';
import 'package:codelessly_sdk/src/render/controls/root.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

RenderButton _button(RenderTree tree, String id) {
  RenderButton? found;
  void visit(RenderObject o) {
    if (o is RenderButton) found ??= o;
    o.visitChildren(visit);
  }

  visit(tree.boxOf(id)!);
  return found!;
}

Future<(NodeTree, RecordedInteractions)> _show(WidgetTester tester, Map<String, Map<String, Object?>> buttons,
    {Map<String, Object?>? theme, bool dark = false, Object? fill}) async {
  final (tree, recorded) = runningTree(columnDoc(buttons, fill: fill),
      theme: theme == null ? null : ThemeTokens.fromJson(theme), dark: dark);
  addTearDown(tree.dispose);
  await tester.pumpWidget(NodeView(tree: tree, rootId: 'col', interactive: true));
  return (tree, recorded);
}

const _ssuiPrimary = Color(0xFF2563EB);

void main() {
  group('with nothing styled', () {
    testWidgets('each kind is its SSUI variant, 28 px high when it hugs', (tester) async {
      final (tree, _) = await _show(tester, {
        'filled': hugging('filledButton', {'label': 'Save'}),
        'tonal': hugging('filledButton', {'label': 'Tonal', 'tonal': true}),
        'elevated': hugging('elevatedButton', {'label': 'Raised'}),
        'outlined': hugging('outlinedButton', {'label': 'Cancel'}),
        'text': hugging('textButton', {'label': 'Skip'}),
        'icon': hugging('iconButton', {'icon': 'close'}),
      });
      for (final id in ['filled', 'tonal', 'elevated', 'outlined', 'text', 'icon']) {
        expect(rectOf(tree, id).height, 28, reason: id);
      }
      expect(rectOf(tree, 'icon').width, 28, reason: 'an icon button is a square of its height');
      expect(_button(tree, 'filled').fillColor, _ssuiPrimary);
      expect(_button(tree, 'filled').labelColor, const Color(0xFFFFFFFF));
      expect(_button(tree, 'tonal').fillColor, const Color(0xFFF3F4F6));
      expect(_button(tree, 'elevated').borderSide?.color, const Color(0xFFE5E7EB));
      expect(_button(tree, 'outlined').fillColor, isNull);
      expect(_button(tree, 'outlined').borderSide?.color, const Color(0xFFE5E7EB));
      expect(_button(tree, 'outlined').labelColor, const Color(0xFF111827));
      expect(_button(tree, 'text').borderSide, isNull);
      expect(_button(tree, 'icon').labelColor, const Color(0xFF4B5563), reason: 'SSUI\'s secondary text');
      for (final id in ['filled', 'outlined']) {
        final shape = _button(tree, id).shape as RoundedRectangleBorder;
        expect(shape.borderRadius.resolve(TextDirection.ltr).topLeft.x, 7, reason: '$id: SSUI\'s control radius');
      }
    });

    testWidgets('a button\'s height picks its step of the control scale: padding, font and radius', (tester) async {
      final (tree, _) = await _show(tester, {
        'xs': {'type': 'filledButton', 'layout': {'width': {'hug': 0}, 'height': 24}, 'props': {'label': 'Go'}},
        'large': {'type': 'filledButton', 'layout': {'width': {'hug': 0}, 'height': 44}, 'props': {'label': 'Go'}},
      });
      final xs = _button(tree, 'xs'), large = _button(tree, 'large');
      expect((xs.shape as RoundedRectangleBorder).borderRadius.resolve(TextDirection.ltr).topLeft.x, 5);
      expect(rectOf(tree, 'large').width, greaterThan(rectOf(tree, 'xs').width));
      expect(large.labels.single.glyphs.single.height, greaterThan(xs.labels.single.glyphs.single.height));
    });

    testWidgets('in dark mode the buttons take SSUI\'s dark tokens', (tester) async {
      final (tree, _) = await _show(tester, {
        'filled': hugging('filledButton', {'label': 'Save'}),
        'outlined': hugging('outlinedButton', {'label': 'Cancel'}),
      }, dark: true, fill: '#FF1C1C1C');
      expect(_button(tree, 'filled').fillColor, const Color(0xFF3B82F6));
      expect(_button(tree, 'outlined').labelColor, const Color(0xFFFFFFFF));
      expect(_button(tree, 'outlined').borderSide?.color, const Color(0xFF383838));
    });
  });

  group('the document\'s theme', () {
    testWidgets('its primary and onPrimary reach a filled button, its font every label', (tester) async {
      final (tree, _) = await _show(tester, {'go': hugging('filledButton', {'label': 'Go'})},
          theme: {'primary': '#FF1F6F4A', 'onPrimary': '#FFFFF8E7', 'fontFamily': 'Barlow'});
      expect(_button(tree, 'go').fillColor, const Color(0xFF1F6F4A));
      expect(_button(tree, 'go').labelColor, const Color(0xFFFFF8E7));
      expect(_button(tree, 'go').fontFamily, 'Barlow');
    });

    testWidgets('a role that names a theme colour reaches the button (it drew black before)', (tester) async {
      final (tree, _) = await _show(tester, {'go': hugging('filledButton', {'label': 'Go'})},
          theme: {
            'primary': 'forest',
            'onPrimary': 'cream',
            'colors': {'forest': '#FF1F6F4A', 'cream': '#FFFFF8E7'},
          });
      expect(_button(tree, 'go').fillColor, const Color(0xFF1F6F4A));
      expect(_button(tree, 'go').labelColor, const Color(0xFFFFF8E7));
    });

    testWidgets('a role written inside colors is not a role: the button keeps the default primary', (tester) async {
      final (tree, _) = await _show(tester, {'go': hugging('filledButton', {'label': 'Go'})},
          theme: {
            'colors': {'primary': '#FF1F6F4A'},
          });
      // Validation reports it (theme_role_in_colors); never black or white.
      expect(_button(tree, 'go').fillColor, _ssuiPrimary);
    });

    testWidgets('a node\'s style is over everything: fill, label colour, side and shape', (tester) async {
      final (tree, _) = await _show(tester, {
        'go': hugging('outlinedButton', {
          'label': 'Go',
          'style': {
            'backgroundColor': '#FF101418',
            'side': {'color': '#FFE4572E', 'width': 2},
            'shape': {'type': 'stadium'},
          },
        }),
      });
      final b = _button(tree, 'go');
      expect(b.fillColor, const Color(0xFF101418));
      expect(b.labelColor.computeLuminance(), greaterThan(.5), reason: 'a label that reads on its own dark fill');
      expect(b.borderSide, const BorderSide(color: Color(0xFFE4572E), width: 2));
      expect(b.shape, isA<StadiumBorder>());
    });
  });

  group('states', () {
    testWidgets('hover and press lay SSUI\'s faint overlays over the fill; nothing changes size', (tester) async {
      final (tree, recorded) = await _show(tester, {
        'filled': hugging('filledButton', {'label': 'Save'}),
        'outlined': hugging('outlinedButton', {'label': 'Cancel'}),
      });
      final before = rectOf(tree, 'outlined');
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(centreOf(tree, 'outlined'));
      await tester.pump();
      final outlined = _button(tree, 'outlined');
      expect(outlined.hovered, isTrue);
      expect(outlined.stateOverlay, const Color(0x0A000000));
      expect(outlined.borderSide?.color, const Color(0xFFD1D5DB), reason: 'the hairline darkens under the pointer');
      await mouse.down(centreOf(tree, 'outlined'));
      await tester.pump();
      expect(outlined.stateOverlay, const Color(0x14000000));
      expect(rectOf(tree, 'outlined'), before);
      await mouse.up();
      await tester.pump();
      expect(recorded.fired, ['outlined click']);
      await mouse.moveTo(centreOf(tree, 'filled'));
      await tester.pump();
      expect(_button(tree, 'filled').stateOverlay, const Color(0x14000000), reason: 'a filled button darkens by SSUI\'s 8 %');
      expect(outlined.hovered, isFalse);
    });

    testWidgets('a state comes and goes over SSUI\'s 150 ms, eased on the tree\'s ticker', (tester) async {
      final (tree, _) = await _show(tester, {'outlined': hugging('outlinedButton', {'label': 'Cancel'})});
      final b = _button(tree, 'outlined');
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(centreOf(tree, 'outlined'));
      await tester.pump();
      expect(b.stateOverlay, const Color(0x0A000000), reason: 'the state itself is at once');
      expect(b.transitioning, isTrue);
      await tester.pump(const Duration(milliseconds: 50));
      final part = b.paintedOverlay!.a;
      expect(part, greaterThan(0));
      expect(part, lessThan(const Color(0x0A000000).a));
      expect(b.stateValue(api.WidgetState.hovered), greaterThan(50 / 150), reason: 'ease-out: ahead of linear');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      expect(b.paintedOverlay, const Color(0x0A000000));
      expect(b.transitioning, isFalse);
      await mouse.moveTo(const Offset(390, 290));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 75));
      expect(b.paintedOverlay!.a, greaterThan(0), reason: 'and eases out');
      await tester.pump(const Duration(milliseconds: 80));
      expect(b.paintedOverlay, isNull);
    });

    testWidgets('a theme\'s durations.control sets the ease; 0 shows each state at once', (tester) async {
      final (tree, _) = await _show(tester, {'go': hugging('textButton', {'label': 'Go'})}, theme: {
        'durations': {'control': 0},
      });
      final b = _button(tree, 'go');
      tree.setState('go', api.WidgetState.selected, true);
      await tester.pump();
      expect(_button(tree, 'go').stateValue(api.WidgetState.selected), 1);
      expect(b.transitioning, isFalse);
    });

    testWidgets('a disabled button draws at half opacity, takes no tap and no Tab stop, and says so to screen readers',
        (tester) async {
      final handle = tester.ensureSemantics();
      final (tree, recorded) = await _show(tester, {
        'off': hugging('filledButton', {'label': 'Off', 'enabled': false}),
        'on': hugging('filledButton', {'label': 'On'}),
      });
      await tester.tapAt(centreOf(tree, 'off'));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(recorded.fired, ['on click'], reason: 'Tab skips the disabled button');
      final off = _button(tree, 'off');
      expect(off.enabled, isFalse);
      expect(off.paintedAlpha, 128, reason: 'SSUI\'s 50 %');
      expect(_button(tree, 'on').paintedAlpha, 255);
      expect(tester.getSemantics(find.byType(NodeView)), isNotNull);
      final data = off.debugSemantics!.getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isEnabled, Tristate.isFalse);
      expect(data.hasAction(SemanticsAction.tap), isFalse);
      handle.dispose();
    });

    testWidgets('Tab shows SSUI\'s focus ring; Enter and Space press; the focused state reaches the node\'s state styles',
        (tester) async {
      final (tree, recorded) = await _show(tester, {
        'save': hugging('filledButton', {'label': 'Save'}, {
          'states': {
            'focused': {
              'save': {'props': {'label': 'Save now'}},
            },
          },
        }),
      });
      final save = _button(tree, 'save');
      expect(save.focusHighlight, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_button(tree, 'save').focusHighlight, isTrue);
      expect(tree.statesOf('save'), contains(api.WidgetState.focused));
      expect(_button(tree, 'save').spec.label, 'Save now', reason: 'the node\'s states.focused patch applies');
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
      expect(recorded.fired, ['save click', 'save click']);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(_button(tree, 'save').focusHighlight, isFalse);
    });

    testWidgets('autofocus takes the keyboard when the button appears', (tester) async {
      final (tree, recorded) = await _show(tester, {
        'first': hugging('outlinedButton', {'label': 'First'}),
        'second': hugging('filledButton', {'label': 'Second', 'autofocus': true}),
      });
      await tester.pump();
      expect(_button(tree, 'second').focusNode.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(recorded.fired, ['second click']);
    });

    testWidgets('a selected button (a tab, a toggle) is tinted with the primary colour as its ink', (tester) async {
      final (tree, _) = await _show(tester, {
        'day': hugging('textButton', {'label': 'Day'}),
        'week': hugging('outlinedButton', {'label': 'Week'}),
      });
      tree.setState('day', api.WidgetState.selected, true);
      tree.setState('week', api.WidgetState.selected, true);
      await tester.pump();
      final day = _button(tree, 'day'), week = _button(tree, 'week');
      expect(day.selected, isTrue);
      expect(day.fillColor, const Color(0x242563EB), reason: 'SSUI\'s activeTint');
      expect(day.labelColor, _ssuiPrimary);
      expect(week.borderSide?.color, const Color(0x472563EB), reason: 'SSUI\'s primaryTintBorder');
      expect(day.debugSemantics!.getSemanticsData().flagsCollection.isSelected, Tristate.isTrue);
    });
  });

  testWidgets('screen readers see a button named by its label, which a tap and focus act on', (tester) async {
    final handle = tester.ensureSemantics();
    final (tree, recorded) = await _show(tester, {'save': hugging('filledButton', {'label': 'Save'})});
    final node = _button(tree, 'save').debugSemantics!;
    final data = node.getSemanticsData();
    expect(data.label, 'Save');
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.flagsCollection.isEnabled, Tristate.isTrue);
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    expect(data.hasAction(SemanticsAction.focus), isTrue);
    tester.binding.renderViews.first.owner!.semanticsOwner!.performAction(node.id, SemanticsAction.tap);
    await tester.pump();
    expect(recorded.fired, ['save click']);
    handle.dispose();
  });

  testWidgets('a tooltip shows in the root\'s overlay layer after hovering, above the button, and goes when the pointer leaves',
      (tester) async {
    final (tree, _) = await _show(tester, {
      'above': {'type': 'box', 'layout': {'width': 10, 'height': 60}},
      'more': hugging('iconButton', {'icon': 'more_horiz'}, {'tooltip': 'More actions'}),
    });
    final root = tester.renderObject<RenderControlRoot>(find.byType(NodeView));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(centreOf(tree, 'more'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(root.overlayEntries, isEmpty, reason: 'not before SSUI\'s 400 ms');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    final bubble = root.overlayEntries.single as RenderTooltipBubble;
    expect(bubble.message, 'More actions');
    final at = bubble.localToGlobal(Offset.zero) & bubble.size;
    final button = rectOf(tree, 'more');
    expect(at.bottom, lessThanOrEqualTo(button.top), reason: 'above the button');
    // Centred on the button, kept 8 px inside the root.
    expect(at.left, closeTo(button.center.dx - at.width / 2 < 8 ? 8 : button.center.dx - at.width / 2, 1));
    await mouse.moveTo(const Offset(390, 290));
    await tester.pump();
    expect(root.overlayEntries, isEmpty);
  });

  testWidgets('on a touch screen a small button takes taps in a 44 × 44 target around it', (tester) async {
    final (tree, recorded) = await _show(tester, {
      'xs': {'type': 'textButton', 'layout': {'width': {'hug': 0}, 'height': 24}, 'props': {'label': 'Edit'}},
    });
    final r = rectOf(tree, 'xs');
    await tester.tapAt(Offset(r.center.dx, r.bottom + 8));
    await tester.pump();
    expect(recorded.fired, ['xs click']);
  });

  testWidgets('an icon and a label: the icon before (or after) the label, the pair centred', (tester) async {
    final (tree, _) = await _show(tester, {
      'start': hugging('filledButton', {'label': 'New', 'icon': 'add'}),
      'end': hugging('filledButton', {'label': 'Next', 'icon': 'arrow_forward', 'iconAlignment': 'end'}),
    });
    for (final (id, iconFirst) in [('start', true), ('end', false)]) {
      final b = _button(tree, id);
      final glyph = b.icon!;
      final iconX = glyph.localToGlobal(Offset.zero).dx - rectOf(tree, id).left;
      final label = b.labels.single.glyphs.first;
      expect(iconX < label.left, iconFirst, reason: id);
      final left = iconFirst ? iconX : label.left;
      final right = iconFirst ? label.right : iconX + glyph.size.width;
      expect((left - (b.size.width - right)).abs(), lessThan(1.5), reason: '$id: centred');
    }
  });
}
