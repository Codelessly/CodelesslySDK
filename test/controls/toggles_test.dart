// Checkboxes, switches and radios as render objects
// (render/controls/toggles.dart): SSUI's look with nothing styled, value
// write-back, the switch's eased thumb on the tree's ticker, the checkbox's
// tristate, radio groups, the keyboard, screen readers, the touch target,
// and a pixel match to soft_saas_ui's own toggles.
import 'dart:ui' show CheckedState, Tristate;

import 'package:codelessly_api/codelessly_api.dart' as api show WidgetState;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/controls/toggles.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ssui_toggles_page.dart';
import 'support.dart';
import 'toggles_support.dart';

Future<(NodeTree, RecordedInteractions)> _show(WidgetTester tester, Map<String, Map<String, Object?>> nodes,
    {Map<String, Object?>? theme, bool dark = false, Object? fill}) async {
  final (tree, recorded) = runningTree(columnDoc(nodes, fill: fill),
      theme: theme == null ? null : ThemeTokens.fromJson(theme), dark: dark);
  addTearDown(tree.dispose);
  await tester.pumpWidget(NodeView(tree: tree, rootId: 'col', interactive: true));
  return (tree, recorded);
}

RenderToggle _toggle(RenderTree tree, String id) => controlIn<RenderToggle>(tree, id);

const _primary = Color(0xFF2563EB);

void main() {
  group('with nothing styled', () {
    testWidgets('each is SSUI\'s control at its own size: 16 px box and ring, a 36 × 20 switch', (tester) async {
      final (tree, _) = await _show(tester, {
        'box': hugging('checkbox'),
        'ring': hugging('radio', {'value': 'a'}),
        'sw': hugging('switch'),
      });
      expect(rectOf(tree, 'box').size, const Size(16, 16));
      expect(rectOf(tree, 'ring').size, const Size(16, 16));
      expect(rectOf(tree, 'sw').size, const Size(36, 20));
      final box = _toggle(tree, 'box'), ring = _toggle(tree, 'ring'), sw = _toggle(tree, 'sw');
      expect(box.markFill, const Color(0xFFFFFFFF), reason: 'SSUI\'s primaryBackground');
      expect(box.markSide?.color, const Color(0xFFD1D5DB), reason: 'SSUI\'s secondaryBorder');
      expect(ring.markSide?.color, const Color(0xFFD1D5DB));
      expect(sw.trackColor, const Color(0xFFD1D5DB));
      expect(sw.thumb.radius, 8, reason: 'a 16 px thumb, 2 px in from the track');
    });

    testWidgets('on, each is SSUI\'s primary: a white check, dot and thumb', (tester) async {
      final (tree, _) = await _show(tester, {
        'box': hugging('checkbox', {'value': true}),
        'ring': hugging('radio', {'value': 'a', 'groupValue': 'a'}),
        'sw': hugging('switch', {'value': true}),
      });
      expect(_toggle(tree, 'box').markFill, _primary);
      expect(_toggle(tree, 'box').markSide, isNull);
      expect(_toggle(tree, 'ring').markFill, _primary);
      expect(_toggle(tree, 'sw').trackColor, _primary);
      expect(_toggle(tree, 'sw').thumb.center.dx, 26, reason: 'at the end of the track');
      expect(_toggle(tree, 'box'), paints..rrect(color: _primary)..path(color: const Color(0xFFFFFFFF)));
    });

    testWidgets('in dark mode and under a document theme the toggles take their tokens', (tester) async {
      final (tree, _) = await _show(tester, {
        'box': hugging('checkbox', {'value': true}),
        'sw': hugging('switch'),
      }, theme: {'primary': '#FF1F6F4A', 'dark': {'primary': '#FF7FD1A6'}}, dark: true, fill: '#FF1C1C1C');
      expect(_toggle(tree, 'box').markFill, const Color(0xFF7FD1A6));
      expect(_toggle(tree, 'sw').trackColor, const Color(0xFF4A4A4A), reason: 'SSUI\'s dark secondaryBorder');
    });

    testWidgets('a label sits beside the mark, 8 px away and centered on it; the control hugs both, and a tap on the label toggles', (tester) async {
      final (tree, recorded) = await _show(tester, {
        'box': hugging('checkbox', {'label': 'Remember me'}),
        'ring': hugging('radio', {'value': 'a', 'label': 'Monthly'}),
        'sw': hugging('switch', {'label': 'Notifications'}),
      });
      for (final id in ['box', 'ring', 'sw']) {
        final t = _toggle(tree, id);
        final mark = t.markRect, glyphs = t.labels.single.glyphs;
        final text = glyphs.reduce((a, b) => a.expandToInclude(b));
        expect(mark.left, 0, reason: '$id mark at the start');
        expect(text.left, mark.right + RenderToggle.labelGap, reason: '$id gap');
        expect(text.center.dy, closeTo(mark.center.dy, .5), reason: '$id label centered on its mark');
        expect(t.size.width, greaterThan(mark.width + 40), reason: '$id hugs its label too');
        expect(t.size.height, greaterThanOrEqualTo(mark.height));
      }
      expect(_toggle(tree, 'sw').markRect.size, const Size(36, 20));
      expect(_toggle(tree, 'box').semanticsName, 'Remember me');
      // The label is part of the control: a tap on it toggles.
      final box = _toggle(tree, 'box');
      await tester.tapAt(box.localToGlobal(Offset(box.size.width - 4, box.size.height / 2)));
      await tester.pump();
      expect(box.value, true);
      expect(recorded.fired, contains('box changed'));
    });

    testWidgets('a node with a size keeps the islands\' proportions; compact and fillTrack fill it', (tester) async {
      final (tree, _) = await _show(tester, {
        'box': {'type': 'checkbox', 'layout': {'width': 40, 'height': 40}},
        'compact': {'type': 'checkbox', 'layout': {'width': 18, 'height': 18}, 'props': {'compact': true}},
        'ring': {'type': 'radio', 'layout': {'width': 32, 'height': 32}},
        'sw': {'type': 'switch', 'layout': {'width': 59, 'height': 40}},
        'fill': {'type': 'switch', 'layout': {'width': 50, 'height': 30}, 'props': {'fillTrack': true}},
      });
      expect(_toggle(tree, 'box').markRect.size, const Size(18, 18));
      expect(_toggle(tree, 'compact').markRect.size, const Size(18, 18));
      expect(_toggle(tree, 'ring').markRect.size, const Size(18, 18));
      expect(_toggle(tree, 'sw').markRect.width, closeTo(52, .01));
      expect(_toggle(tree, 'fill').markRect, const Rect.fromLTWH(0, 0, 50, 30));
    });
  });

  group('values', () {
    testWidgets('a tap toggles each and reports changed; a radio chooses itself once', (tester) async {
      final (tree, recorded) = await _show(tester, {
        'box': hugging('checkbox'),
        'ring': hugging('radio', {'value': 'a'}),
        'sw': hugging('switch'),
      });
      for (final id in ['box', 'ring', 'sw', 'ring']) {
        await tester.tapAt(centerOf(tree, id));
        await tester.pump();
      }
      expect(recorded.fired, ['box changed', 'ring changed', 'sw changed']);
      expect(_toggle(tree, 'box').value, isTrue);
      expect(_toggle(tree, 'ring').value, 'a');
      expect(_toggle(tree, 'sw').value, isTrue);
    });

    testWidgets('a toggleable radio lets go when tapped again', (tester) async {
      final (tree, recorded) = await _show(tester, {'ring': hugging('radio', {'value': 'a', 'groupValue': 'a', 'toggleable': true})});
      await tester.tapAt(centerOf(tree, 'ring'));
      await tester.pump();
      expect(_toggle(tree, 'ring').value, isNull);
      expect(_toggle(tree, 'ring').checked, isFalse);
      expect(recorded.fired, ['ring changed']);
    });

    testWidgets('a tristate checkbox goes false, true, mixed, false, and says mixed to screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      final (tree, _) = await _show(tester, {'box': hugging('checkbox', {'value': false, 'tristate': true})});
      final box = _toggle(tree, 'box');
      final seen = <Object?>[];
      for (var i = 0; i < 3; i++) {
        await tester.tapAt(centerOf(tree, 'box'));
        await tester.pumpAndSettle();
        seen.add(box.value);
        if (box.value == null) {
          expect(box.mixed, isTrue);
          expect(box.debugSemantics!.getSemanticsData().flagsCollection.isChecked, CheckedState.mixed);
        }
      }
      expect(seen, [true, null, false]);
      handle.dispose();
    });

    testWidgets('a bound value writes back through changed and follows its variable', (tester) async {
      final s = await _bound(tester);
      await tester.tapAt(s.$1.localToGlobal(s.$1.size.center(Offset.zero)));
      await tester.pumpAndSettle();
      expect(s.$2.read('on'), true, reason: 'the changed value is written to the bound variable');
      s.$2.set('on', false);
      await tester.pumpAndSettle();
      expect(s.$1.value, false);
    });
  });

  testWidgets('a switch\'s thumb eases over SSUI\'s 150 ms on the tree\'s ticker', (tester) async {
    final (tree, _) = await _show(tester, {'sw': hugging('switch')});
    final sw = _toggle(tree, 'sw');
    await tester.tapAt(centerOf(tree, 'sw'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(sw.position, inExclusiveRange(0.2, 0.95));
    expect(sw.thumb.center.dx, inExclusiveRange(10, 26));
    await tester.pump(const Duration(milliseconds: 100));
    expect(sw.position, 1);
    expect(sw.thumb.center.dx, 26);
  });

  testWidgets('Tab focuses with SSUI\'s ring, Space and Enter toggle; disabled draws at half and takes nothing', (tester) async {
    final (tree, recorded) = await _show(tester, {
      'off': hugging('switch', {'enabled': false}),
      'box': hugging('checkbox'),
    });
    await tester.tapAt(centerOf(tree, 'off'));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final box = _toggle(tree, 'box');
    expect(box.focusHighlight, isTrue, reason: 'Tab skips the disabled switch');
    expect(box, paints..rrect()..rrect()..rrect(color: const Color(0x802563EB), style: PaintingStyle.stroke));
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(recorded.fired, ['box changed', 'box changed']);
    expect(box.value, isFalse);
    expect(_toggle(tree, 'off').paintedAlpha, 128);
    expect(_toggle(tree, 'off').value, isFalse);
  });

  testWidgets('a disabled state from the node\'s bindings disables a checkbox', (tester) async {
    final (tree, recorded) = await _show(tester, {'box': hugging('checkbox')});
    tree.setState('box', api.WidgetState.disabled, true);
    await tester.pump();
    await tester.tapAt(centerOf(tree, 'box'));
    await tester.pump();
    expect(recorded.fired, isEmpty);
    expect(_toggle(tree, 'box').paintedAlpha, 128);
  });

  testWidgets('screen readers see checked, toggled and grouped controls they can tap', (tester) async {
    final handle = tester.ensureSemantics();
    final (tree, recorded) = await _show(tester, {
      'box': hugging('checkbox', {'value': true}),
      'ring': hugging('radio', {'value': 'a', 'groupValue': 'b'}),
      'sw': hugging('switch', {'value': true}),
    });
    final box = _toggle(tree, 'box').debugSemantics!.getSemanticsData();
    final ring = _toggle(tree, 'ring').debugSemantics!.getSemanticsData();
    final sw = _toggle(tree, 'sw').debugSemantics!.getSemanticsData();
    expect(box.flagsCollection.isChecked, CheckedState.isTrue);
    expect(ring.flagsCollection.isChecked, CheckedState.isFalse);
    expect(ring.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
    expect(sw.flagsCollection.isToggled, Tristate.isTrue);
    expect(sw.flagsCollection.isEnabled, Tristate.isTrue);
    expect(sw.hasAction(SemanticsAction.tap), isTrue);
    tester.binding.renderViews.first.owner!.semanticsOwner!.performAction(_toggle(tree, 'ring').debugSemantics!.id, SemanticsAction.tap);
    await tester.pump();
    expect(recorded.fired, ['ring changed']);
    handle.dispose();
  });

  testWidgets('on a touch screen a 16 px checkbox takes taps in a 44 × 44 target', (tester) async {
    final (tree, recorded) = await _show(tester, {'box': hugging('checkbox')});
    final r = rectOf(tree, 'box');
    await tester.tapAt(Offset(r.center.dx, r.bottom + 12));
    await tester.pump();
    expect(recorded.fired, ['box changed']);
  });

  testWidgets('on a design canvas they show their value and take no tap', (tester) async {
    final tree = NodeTree(DocumentSource(LayoutDocument.fromJson(columnDoc({'box': hugging('checkbox', {'value': true})}))));
    addTearDown(tree.dispose);
    await tester.pumpWidget(NodeView(tree: tree, rootId: 'col'));
    final box = _toggle(tree, 'box');
    expect(box.position, 1);
    await tester.tapAt(centerOf(tree, 'box'));
    await tester.pump();
    expect(box.value, isTrue);
  });

  group('against SSUI\'s own toggles', () {
    setUpAll(loadRoboto);
    for (final dark in [false, true]) {
      final mode = dark ? 'dark' : 'light';
      testWidgets('zero-prop checkboxes, radios and switches match soft_saas_ui\'s within 1 % of the pixels: $mode',
          (tester) async {
        final (tree, image) = await renderSsuiToggles(tester, dark: dark);
        await saveRender(tester, image, 'toggles-$mode');
        final ours = await rgbaOf(tester, image);
        final reference = await decodePng(tester, ssuiTogglesReference(dark));
        // The row of toggles: y 24 to 48.
        final share = differingShare(ours, reference, ssuiTogglesSize.width.toInt(), const Rect.fromLTRB(24, 24, 340, 48));
        // ignore: avoid_print
        print('SSUI toggles $mode: ${(share * 100).toStringAsFixed(2)} % of the pixels differ');
        expect(share, lessThan(0.01));
        expect(rectOf(tree, 'switchOn').size, const Size(36, 20));
      });
    }
  });
}

/// A checkbox bound to `on`, in a running app.
Future<(RenderToggle, VariableScope)> _bound(WidgetTester tester) async {
  final doc = LayoutDocument.fromJson(columnDoc({
    'box': {
      ...hugging('checkbox'),
      'bind': {'props.value': r'${on}'},
    },
  }));
  final scope = VariableScope([Variable(name: 'on', type: VariableType.boolean, value: false)]);
  final values = NodeValues(DocumentSource(doc));
  final tree = NodeTree(values, binder: NodeBinder(scope: scope), environment: const IslandEnvironment(interactive: true));
  final context = RuntimeActionContext(scope: scope, ui: const NoActionUi(), tree: tree, nodeValues: values, services: Services());
  final reactions = TreeReactions(runner: const CodelesslyActions(), context: context);
  tree.interactions = reactions;
  addTearDown(() {
    reactions.dispose();
    tree.dispose();
    scope.dispose();
  });
  await tester.pumpWidget(NodeView(tree: tree, rootId: 'col', interactive: true));
  await tester.pump();
  return (controlIn<RenderToggle>(tree, 'box'), scope);
}
