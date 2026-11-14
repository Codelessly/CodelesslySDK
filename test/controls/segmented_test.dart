// The segmented button as a render object (render/controls/segmented.dart):
// SSUI's segmented control with nothing styled, each label measured centred
// in its segment across and down, tap and arrow keys, single and multi
// select, the bound selection, screen readers per segment, and a pixel match
// to soft_saas_ui's own segmented control.
import 'dart:ui' show Tristate;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/controls/segmented.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ssui_toggles_page.dart';
import 'support.dart';
import 'toggles_support.dart';

Future<(NodeTree, RecordedInteractions)> _show(WidgetTester tester, Map<String, Map<String, Object?>> nodes,
    {bool dark = false, Object? fill, Map<String, Object?>? theme}) async {
  final (tree, recorded) = runningTree(columnDoc(nodes, fill: fill, width: 500),
      dark: dark, theme: theme == null ? null : ThemeTokens.fromJson(theme));
  addTearDown(tree.dispose);
  await tester.pumpWidget(NodeView(tree: tree, rootId: 'col', interactive: true));
  return (tree, recorded);
}

RenderSegmentedButton _seg(RenderTree tree, [String id = 'seg']) => controlIn<RenderSegmentedButton>(tree, id);

const _days = [
  {'value': 'd', 'label': 'Day'},
  {'value': 'w', 'label': 'Week'},
  {'value': 'm', 'label': 'Month'},
];

void main() {
  testWidgets('with nothing styled it is SSUI\'s segmented control: 28 high, segments inset 2, the selection raised',
      (tester) async {
    final (tree, _) = await _show(tester, {'seg': hugging('segmentedButton', {'segments': _days, 'selected': ['w']})});
    final s = _seg(tree);
    expect(s.size.height, 28);
    expect(s.segmentRects.map((r) => r.height), everyElement(24));
    expect(s.segmentRects.first.left, 2);
    expect(s.segmentRects.last.right, s.size.width - 2);
    expect(s.trackColor, const Color(0xFFF3F4F6));
    expect(s.selectedColor, const Color(0xFFFFFFFF));
    expect(s.raised, ['w']);
    expect(s.labelColorOf(1), const Color(0xFF111827));
    expect(s.labelColorOf(0), const Color(0xFF4B5563), reason: 'SSUI\'s secondaryText');
  });

  for (final (name, layout) in [
    ('hugging', {'width': {'hug': 0}, 'height': {'hug': 0}}),
    ('32 high and 300 wide', {'width': 300, 'height': 32}),
    ('xs (24)', {'width': {'hug': 0}, 'height': 24}),
  ]) {
    testWidgets('each label is centred in its segment, across and down: $name', (tester) async {
      final (tree, _) = await _show(tester, {
        'seg': {'type': 'segmentedButton', 'layout': layout, 'props': {'segments': _days, 'selected': ['d']}},
      }, theme: {'fontFamily': 'Roboto'});
      final s = _seg(tree);
      final labels = s.labels;
      expect(labels.map((l) => l.text), ['Day', 'Week', 'Month']);
      for (var i = 0; i < 3; i++) {
        final r = s.segmentRects[i];
        final glyphs = labels[i].glyphs;
        final left = glyphs.map((g) => g.left).reduce((a, b) => a < b ? a : b);
        final right = glyphs.map((g) => g.right).reduce((a, b) => a > b ? a : b);
        final top = glyphs.map((g) => g.top).reduce((a, b) => a < b ? a : b);
        final bottom = glyphs.map((g) => g.bottom).reduce((a, b) => a > b ? a : b);
        expect((left + right) / 2, closeTo(r.center.dx, .75), reason: '${labels[i].text} across');
        expect((top + bottom) / 2, closeTo(r.center.dy, .5), reason: '${labels[i].text} down');
      }
    });
  }

  testWidgets('a tap chooses a segment and reports the selection; a fixed width is shared', (tester) async {
    final (tree, recorded) = await _show(tester, {
      'seg': {'type': 'segmentedButton', 'layout': {'width': 300, 'height': 28}, 'props': {'segments': _days, 'selected': ['d'], 'expanded': true}},
    });
    final s = _seg(tree);
    expect(s.segmentRects.map((r) => r.width), everyElement(closeTo(296 / 3, .01)));
    await tester.tapAt(s.localToGlobal(s.segmentRects[2].center));
    await tester.pump();
    expect(s.selection, ['m']);
    expect(recorded.fired, ['seg changed']);
    await tester.tapAt(s.localToGlobal(s.segmentRects[2].center));
    await tester.pump();
    expect(recorded.fired, ['seg changed'], reason: 'single select: the chosen one stays');
  });

  testWidgets('multi select toggles segments, keeping one unless empty is allowed', (tester) async {
    final (tree, _) = await _show(tester, {
      'seg': hugging('segmentedButton', {'segments': _days, 'selected': ['d'], 'multiSelectionEnabled': true}),
    });
    final s = _seg(tree);
    await tester.tapAt(s.localToGlobal(s.segmentRects[1].center));
    await tester.pump();
    expect(s.selection, ['d', 'w']);
    for (final i in [0, 1]) {
      await tester.tapAt(s.localToGlobal(s.segmentRects[i].center));
      await tester.pump();
    }
    expect(s.selection, ['w'], reason: 'the last one stays (emptySelectionAllowed is false)');
  });

  testWidgets('arrow keys move the selection, skipping disabled segments and wrapping; multi select moves a cursor',
      (tester) async {
    final (tree, recorded) = await _show(tester, {
      'seg': hugging('segmentedButton', {
        'segments': [
          ..._days.take(2),
          {'value': 'm', 'label': 'Month', 'enabled': false},
        ],
        'selected': ['d'],
      }),
      'multi': hugging('segmentedButton', {'segments': _days, 'selected': ['d'], 'multiSelectionEnabled': true}),
    });
    final s = _seg(tree);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(s.focusHighlight, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(s.selection, ['w']);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(s.selection, ['d'], reason: 'past the disabled one, wrapping');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    expect(s.selection, ['w']);
    expect(recorded.fired, ['seg changed', 'seg changed', 'seg changed']);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    final m = _seg(tree, 'multi');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(m.selection, ['d'], reason: 'multi select: the cursor moves');
    expect(m.cursorSegment, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(m.selection, ['d', 'w']);
  });

  testWidgets('a new bound selection shows', (tester) async {
    final source = DocumentSource(LayoutDocument.fromJson(columnDoc({'seg': hugging('segmentedButton', {'segments': _days, 'selected': ['d']})})));
    final tree = NodeTree(source, environment: const IslandEnvironment(interactive: true));
    addTearDown(tree.dispose);
    await tester.pumpWidget(NodeView(tree: tree, rootId: 'col', interactive: true));
    source.document = source.document.copyWith(nodes: {
      ...source.document.nodes,
      'seg': source.document['seg']!.withProp(SegmentedButtonProps.selected, const ['m']),
    });
    await tester.pump();
    expect(_seg(tree).selection, ['m']);
  });

  testWidgets('screen readers see one button per segment, selected or not, that a tap chooses', (tester) async {
    final handle = tester.ensureSemantics();
    final (tree, recorded) = await _show(tester, {'seg': hugging('segmentedButton', {'segments': _days, 'selected': ['w']})});
    final node = _seg(tree).debugSemantics!;
    final children = <SemanticsNode>[];
    node.visitChildren((c) {
      children.add(c);
      return true;
    });
    expect(children.map((c) => c.getSemanticsData().label), ['Day', 'Week', 'Month']);
    expect(children[1].getSemanticsData().flagsCollection.isSelected, Tristate.isTrue);
    expect(children[0].getSemanticsData().flagsCollection.isButton, isTrue);
    tester.binding.renderViews.first.owner!.semanticsOwner!.performAction(children[2].id, SemanticsAction.tap);
    await tester.pump();
    expect(_seg(tree).selection, ['m']);
    expect(recorded.fired, ['seg changed']);
    handle.dispose();
  });

  testWidgets('in dark mode the well is SSUI\'s secondary background with a hairline', (tester) async {
    final (tree, _) = await _show(tester, {'seg': hugging('segmentedButton', {'segments': _days, 'selected': ['w']})},
        dark: true, fill: '#FF141414');
    final s = _seg(tree);
    expect(s.trackColor, const Color(0xFF1C1C1C));
    expect(s.trackSide?.color, const Color(0xFF383838));
    expect(s.selectedColor, const Color(0xFF383838));
  });

  group('against SSUI\'s own segmented control', () {
    setUpAll(loadRoboto);
    for (final dark in [false, true]) {
      final mode = dark ? 'dark' : 'light';
      testWidgets('zero-prop segmented buttons match soft_saas_ui\'s within 1 % of the pixels: $mode', (tester) async {
        final (tree, image) = await renderSsuiToggles(tester, dark: dark);
        final ours = await rgbaOf(tester, image);
        final reference = await decodePng(tester, ssuiTogglesReference(dark));
        // The row of segmented controls: y 96 to 130.
        final share = differingShare(ours, reference, ssuiTogglesSize.width.toInt(), const Rect.fromLTRB(24, 96, 500, 130));
        // ignore: avoid_print
        print('SSUI segmented $mode: ${(share * 100).toStringAsFixed(2)} % of the pixels differ');
        expect(share, lessThan(0.01));
        expect(rectOf(tree, 'week').height, 28);
      });
    }
  });
}
