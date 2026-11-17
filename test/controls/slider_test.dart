// The slider as a render object (render/controls/slider.dart): SSUI's look
// with nothing styled and no thumb shadow, drag and tap, divisions, the
// keys (arrows, Page Up / Page Down, Home / End), the value indicator in the
// root's overlay, screen readers with increase and decrease, the custom
// paint between its parts, and a pixel match to soft_saas_ui's slider.
import 'package:codelessly_api/codelessly_api.dart' as api show WidgetState;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/controls/root.dart';
import 'package:codelessly_sdk/src/render/controls/slider.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';
import 'toggles_support.dart';
import '../support/keyboard.dart';

Future<(NodeTree, RecordedInteractions)> _show(WidgetTester tester, Map<String, Map<String, Object?>> nodes,
    {bool dark = false, Object? fill}) async {
  final (tree, recorded) = runningTree(columnDoc(nodes, fill: fill), dark: dark);
  addTearDown(tree.dispose);
  await tester.pumpWidget(NodeView(tree: tree, rootId: 'col', interactive: true));
  return (tree, recorded);
}

RenderSlider _slider(RenderTree tree, [String id = 's']) => controlIn<RenderSlider>(tree, id);

Map<String, Object?> _node(Map<String, Object?> props, {Object width = 200, Object? height}) => {
      'type': 'slider',
      'layout': {'width': width, 'height': height ?? {'hug': 0}},
      'props': props,
    };

void main() {
  for (final dark in [false, true]) {
    testWidgets('range slider: pointer, one keyboard stop, both values and semantics (dark: $dark)', (tester) async {
      final handle = tester.ensureSemantics();
      final (tree, recorded) = await _show(tester, {
        'price': _node({'value': 20, 'rangeEnd': 80, 'min': 0, 'max': 100, 'label': 'Price range'})
      }, dark: dark);
      final slider = _slider(tree, 'price');
      final keys = Keyboard(tester);
      expect(slider.size.height, 44);
      await keys.tab();
      expect(keys.focusedId, 'price');
      expect(keys.stopIds(slider), ['price']);
      expect(keys.ringShown, isTrue);
      expect(keys.semantics!.label, 'Price range');
      expect(keys.semantics!.data.hint, contains('Space'));
      expect(keys.semantics!.data.flagsCollection.isSlider, isTrue);
      expect(keys.semantics!.value, '20 to 80; lower thumb');
      await keys.right();
      expect(slider.value, 21);
      await keys.space();
      expect(keys.semantics!.value, '21 to 80; upper thumb');
      await keys.press(LogicalKeyboardKey.pageUp);
      expect(slider.rangeEnd, 90);
      await keys.press(LogicalKeyboardKey.pageDown);
      expect(slider.rangeEnd, 80);
      await keys.end();
      expect(slider.rangeEnd, 100);
      final high = slider.localToGlobal(slider.highThumbCenter);
      await tester.tapAt(high);
      await tester.pump();
      expect(slider.highActive, isTrue);
      expect(keys.ringShown, isFalse, reason: 'a pointer does not leave a keyboard ring');
      await tester.dragFrom(slider.localToGlobal(slider.highThumbCenter), const Offset(-40, 0));
      await tester.pump();
      expect(slider.rangeEnd, lessThan(100));
      expect(slider.rangeEnd, greaterThan(slider.value));
      await keys.home();
      expect(slider.rangeEnd, 21, reason: 'the thumbs cannot cross');
      await keys.enter();
      expect(slider.highActive, isFalse);
      await tester.dragFrom(slider.localToGlobal(slider.thumbCenter), const Offset(40, 0));
      await tester.pump();
      expect(slider.rangeEnd, greaterThan(slider.value), reason: 'a collapsed range can open again by dragging');
      expect(recorded.fired, contains('price changed'));
      handle.dispose();
    });
  }

  testWidgets('range slider: Tab goes from the lower thumb to the upper one, Shift+Tab back, each named and ringed', (tester) async {
    final (tree, _) = await _show(tester, {
      'price': _node({'value': 20, 'rangeEnd': 80, 'min': 0, 'max': 100, 'label': 'Price range'}),
      'after': _node({'value': 5, 'min': 0, 'max': 10}),
    });
    final slider = _slider(tree, 'price');
    final keys = Keyboard(tester);
    await keys.tab();
    expect(keys.focusedId, 'price');
    expect(slider.highActive, isFalse);
    expect(slider.focusNode.label!(), 'Price range, lower thumb');
    await keys.tab();
    expect(keys.focusedId, 'price');
    expect(slider.highActive, isTrue);
    expect(slider.focusNode.label!(), 'Price range, upper thumb');
    expect(keys.ringShown, isTrue);
    await keys.right();
    expect(slider.rangeEnd, 81);
    expect(slider.value, 20);
    await keys.tab();
    expect(keys.focusedId, 'after');
    // Back from after it: onto the upper thumb, then the lower one.
    await keys.shiftTab();
    expect(keys.focusedId, 'price');
    expect(slider.highActive, isTrue);
    await keys.shiftTab();
    expect(keys.focusedId, 'price');
    expect(slider.highActive, isFalse);
    await keys.left();
    expect(slider.value, 19);
  });

  testWidgets('between whole-number ends an arrow moves by at least 1', (tester) async {
    final (tree, _) = await _show(tester, {
      'heat': _node({'value': 18, 'rangeEnd': 24, 'min': 16, 'max': 30}),
      'level': _node({'value': 0.5, 'min': 0, 'max': 1}),
    });
    final keys = Keyboard(tester);
    await keys.tab();
    await keys.right();
    expect(_slider(tree, 'heat').value, 19);
    await keys.tab();
    await keys.tab();
    await keys.right();
    expect(_slider(tree, 'level').value, closeTo(0.51, 1e-9));
  });

  testWidgets('range slider mirrors its track and horizontal keys in right-to-left text', (tester) async {
    final (tree, _) = await _show(tester, {
      'price': {..._node({'value': 20, 'rangeEnd': 80, 'min': 0, 'max': 100}), 'textDirection': 'rtl'}
    });
    final slider = _slider(tree, 'price');
    expect(slider.thumbCenter.dx, greaterThan(slider.highThumbCenter.dx));
    final keys = Keyboard(tester);
    await keys.tab();
    await keys.right();
    expect(slider.value, 19);
    await keys.left();
    expect(slider.value, 20);
  });

  testWidgets('star rating takes a tap, half-step keys, and announces its score', (tester) async {
    final handle = tester.ensureSemantics();
    final (tree, _) = await _show(tester, {'s': _node({
      'value': 0, 'min': 0, 'max': 5, 'divisions': 10, 'trackShape': 'stars',
      'showThumb': false, 'label': 'Your rating',
    }, height: 44)});
    final s = _slider(tree);
    await tester.tapAt(s.localToGlobal(const Offset(120, 22)));
    await tester.pump();
    expect(s.value, 3);
    expect(s.focusHighlight, isFalse, reason: 'a pointer must not show the keyboard ring');
    s.focusNode.unfocus();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(s.focusNode.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(s.value, 3.5);
    expect(s.focusHighlight, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    expect(s.value, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    expect(s.value, 5);
    final data = s.debugSemantics!.getSemanticsData();
    expect(data.flagsCollection.isSlider, isTrue);
    expect(data.label, 'Your rating');
    expect(data.value, '5 of 5');
    handle.dispose();
  });

  testWidgets('read-only star rating remains full color and has no change actions', (tester) async {
    final handle = tester.ensureSemantics();
    final (tree, recorded) = await _show(tester, {'s': _node({
      'value': 4.5, 'min': 0, 'max': 5, 'trackShape': 'stars',
      'readOnly': true, 'showThumb': false, 'label': 'Course score',
    }, height: 44)}, dark: true);
    final s = _slider(tree);
    await tester.tapAt(s.localToGlobal(const Offset(20, 22)));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(s.value, 4.5);
    expect(s.paintedAlpha, 255);
    expect(s.focusNode.hasFocus, isFalse);
    expect(recorded.fired, isEmpty);
    final data = s.debugSemantics!.getSemanticsData();
    expect(data.value, '4.5 of 5');
    expect(data.hint, 'Read only');
    expect(data.hasAction(SemanticsAction.increase), isFalse);
    handle.dispose();
  });

  testWidgets('star rating in right-to-left text fills and steps from the right', (tester) async {
    final n = _node({'value': 0, 'max': 5, 'divisions': 5, 'trackShape': 'stars',
      'showThumb': false}, height: 44);
    n['textDirection'] = 'rtl';
    final (tree, _) = await _show(tester, {'s': n});
    final s = _slider(tree);
    await tester.tapAt(s.localToGlobal(const Offset(175, 22)));
    await tester.pump();
    expect(s.value, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(s.value, 2);
  });

  testWidgets('with nothing styled it is SSUI\'s slider: 28 high, a 6 px rail, a ringed 14 px thumb and no shadow',
      (tester) async {
    final (tree, _) = await _show(tester, {'s': hugging('slider', {'value': 0.5})});
    final s = _slider(tree);
    expect(s.size, const Size(200, 28));
    expect(s.trackRect, const Rect.fromLTWH(0, 11, 200, 6));
    expect(s.thumbSize, const Size(14, 14));
    expect(s.thumbCenter, const Offset(100, 14));
    expect(s.activeTrackColor, const Color(0xFF2563EB));
    expect(s.inactiveTrackColor, const Color(0xFFD1D5DB));
    expect(s.thumbShadows, isEmpty, reason: 'no thumb shadow');
    expect(
        s,
        paints
          ..rrect(color: const Color(0xFFD1D5DB))
          ..rrect(color: const Color(0xFF2563EB))
          ..circle(x: 100, y: 14, radius: 7, color: const Color(0xFFFFFFFF))
          ..circle(x: 100, y: 14, radius: 6.5, style: PaintingStyle.stroke, color: const Color(0xFFD1D5DB)));
  });

  testWidgets('a drag moves the value with the pointer, snapping to divisions; changed then changeEnd', (tester) async {
    final (tree, recorded) = await _show(tester, {'s': _node({'value': 0, 'max': 10, 'divisions': 10})});
    final s = _slider(tree);
    final start = s.localToGlobal(s.thumbCenter);
    // The thumb travels 186 px for 10: 18.6 px a division.
    await tester.dragFrom(start, const Offset(60, 0));
    await tester.pump();
    expect(s.value, 3);
    expect(recorded.fired.first, 's changed');
    expect(recorded.fired.last, 's changeEnd');
    recorded.fired.clear();
    await tester.tapAt(s.localToGlobal(Offset(7 + 186 * .8, 14)));
    await tester.pump();
    expect(s.value, 8);
    expect(recorded.fired, ['s changed', 's changeEnd']);
  });

  testWidgets('keys: arrows a step, Page Up / Down ten, Home / End the ends; each reports changed', (tester) async {
    final (tree, recorded) = await _show(tester, {'s': _node({'value': 50, 'max': 100})});
    final s = _slider(tree);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(s.focusNode.hasFocus, isTrue);
    expect(s.haloShown, isTrue, reason: 'SSUI\'s halo shows the keyboard focus');
    Future<double> key(LogicalKeyboardKey k) async {
      await tester.sendKeyEvent(k);
      await tester.pump();
      return s.value;
    }

    expect(await key(LogicalKeyboardKey.arrowRight), 51);
    expect(await key(LogicalKeyboardKey.arrowUp), 52);
    expect(await key(LogicalKeyboardKey.arrowLeft), 51);
    expect(await key(LogicalKeyboardKey.arrowDown), 50);
    expect(await key(LogicalKeyboardKey.pageUp), 60);
    expect(await key(LogicalKeyboardKey.pageDown), 50);
    expect(await key(LogicalKeyboardKey.end), 100);
    expect(await key(LogicalKeyboardKey.home), 0);
    expect(recorded.fired.where((f) => f == 's changed'), hasLength(8));
  });

  testWidgets('a discrete slider steps a division; a selectable range keeps the value inside it', (tester) async {
    final (tree, _) = await _show(tester, {'s': _node({'value': 4, 'max': 10, 'divisions': 5, 'selectableMax': 6})});
    final s = _slider(tree);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(s.value, 6);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(s.value, 6, reason: 'selectableMax');
  });

  testWidgets('a vertical slider runs bottom (min) to top; inverted runs the other way', (tester) async {
    final (tree, _) = await _show(tester, {
      'v': _node({'value': 0.25, 'orientation': 'vertical'}, width: 28, height: 200),
      'i': _node({'value': 0.25, 'inverted': true}),
    });
    final v = _slider(tree, 'v'), i = _slider(tree, 'i');
    await tester.tapAt(v.localToGlobal(const Offset(14, 7 + 186 * .25)));
    await tester.pump();
    expect(v.value, closeTo(.75, .01), reason: 'a quarter down is three quarters up');
    expect(i.thumbCenter.dx, closeTo(7 + 186 * .75, .01));
  });

  testWidgets('hovering shows SSUI\'s primary halo round the thumb', (tester) async {
    final (tree, _) = await _show(tester, {'s': _node({'value': 0.5})});
    final s = _slider(tree);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(s.localToGlobal(s.thumbCenter));
    await tester.pump();
    expect(s.haloShown, isTrue);
    expect(s, paints..rrect()..rrect()..circle(radius: 12, color: const Color(0x1F2563EB)));
  });

  testWidgets('its label shows in a bubble above the thumb in the root\'s overlay while dragged', (tester) async {
    final (tree, _) = await _show(tester, {
      'gap': {'type': 'box', 'layout': {'width': 10, 'height': 40}},
      's': _node({'value': 2, 'max': 10, 'divisions': 10, 'label': r'${value} km'}),
    });
    final s = _slider(tree);
    final root = tester.renderObject<RenderControlRoot>(find.byType(NodeView));
    final gesture = await tester.startGesture(s.localToGlobal(s.thumbCenter));
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    await tester.pump();
    final bubble = root.overlayEntries.single as RenderSliderValueIndicator;
    expect(bubble.text, '${s.value.round()} km');
    final at = bubble.localToGlobal(Offset.zero) & bubble.size;
    expect(at.bottom, lessThanOrEqualTo(s.localToGlobal(Offset.zero).dy + 7), reason: 'above the thumb');
    await gesture.up();
    await tester.pump();
    await tester.pump();
    expect(root.overlayEntries, isEmpty);
  });

  testWidgets('screen readers see a slider with its value, which they increase and decrease', (tester) async {
    final handle = tester.ensureSemantics();
    final (tree, recorded) = await _show(tester, {'s': _node({'value': 50, 'max': 100})});
    final s = _slider(tree);
    final data = s.debugSemantics!.getSemanticsData();
    expect(data.flagsCollection.isSlider, isTrue);
    expect(data.value, '50%');
    expect(data.increasedValue, '51%');
    expect(data.decreasedValue, '49%');
    expect(data.hasAction(SemanticsAction.increase), isTrue);
    tester.binding.renderViews.first.owner!.semanticsOwner!.performAction(s.debugSemantics!.id, SemanticsAction.increase);
    await tester.pump();
    expect(s.value, 51);
    expect(recorded.fired, ['s changed', 's changeEnd']);
    handle.dispose();
  });

  testWidgets('disabled by its state it draws at half and takes no drag', (tester) async {
    final (tree, recorded) = await _show(tester, {'s': _node({'value': 0.5})});
    tree.setState('s', api.WidgetState.disabled, true);
    await tester.pump();
    final s = _slider(tree);
    await tester.dragFrom(s.localToGlobal(s.thumbCenter), const Offset(40, 0));
    await tester.pump();
    expect(recorded.fired, isEmpty);
    expect(s.paintedAlpha, 128);
  });
}
