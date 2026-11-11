import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'actions/wiring_test.dart' as wiring show show;

Map<String, Json> nodes({bool horizontal = false, bool reverse = false}) => {
  'col': {
    'type': horizontal ? 'row' : 'column',
    'props': {'scrollable': true, 'scrollDirection': horizontal ? 'horizontal' : 'vertical', 'reverse': reverse},
    'layout': {'width': 200, 'height': 200},
    'children': [for (var i = 0; i < 6; i++) 'item$i'],
  },
  for (var i = 0; i < 6; i++)
    'item$i': {
      'type': 'box',
      'layout': {'width': horizontal ? 100 : 200, 'height': horizontal ? 200 : 100},
      'decoration': {
        'fills': [
          {'color': '#FF334455'},
        ],
      },
      'actions': [
        {
          'trigger': {'type': 'click'},
          'actions': [
            {'type': 'setVariable', 'variable': 'clicked', 'value': '$i'},
          ],
        },
      ],
    },
};

RenderDesignScroll viewport(NodeTree tree, [String id = 'col']) {
  RenderDesignScroll? found;
  void visit(RenderObject object) {
    if (object is RenderDesignScroll) found ??= object;
    object.visitChildren(visit);
  }

  visit(tree.boxOf(id)!);
  return found!;
}

void main() {
  testWidgets('native vertical drag scrolls to clipped content and hit tests the moved button', (tester) async {
    final screen = await wiring.show(
      tester,
      nodes(),
      variables: [const Variable(name: 'clicked', value: '')],
    );
    final view = viewport(screen.tree);
    expect(view.maxScrollExtent, 400);
    final center = view.localToGlobal(const Offset(100, 100));
    await tester.dragFrom(center, const Offset(0, -500));
    await tester.pump();
    expect(view.pixels, 400);
    expect(screen.tree.boxOf('item5')!.localToGlobal(Offset.zero).dy, closeTo(100, .01));
    await tester.tapAt(view.localToGlobal(const Offset(100, 150)));
    await tester.pump();
    expect(screen['clicked'], '5');
    await tester.dragFrom(center, const Offset(0, -1000));
    await tester.pump();
    expect(view.pixels, 400);
    await tester.dragFrom(center, const Offset(0, 1500));
    await tester.pump();
    expect(view.pixels, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wheel scrolling moves the native viewport and clamps at its bounds', (tester) async {
    final screen = await wiring.show(tester, nodes());
    final view = viewport(screen.tree);
    final at = view.localToGlobal(const Offset(100, 100));
    await tester.sendEventToBinding(PointerScrollEvent(position: at, scrollDelta: const Offset(0, 160)));
    await tester.pump();
    expect(view.pixels, 160);
    await tester.sendEventToBinding(PointerScrollEvent(position: at, scrollDelta: const Offset(0, 999)));
    await tester.pump();
    expect(view.pixels, 400);
    await tester.sendEventToBinding(PointerScrollEvent(position: at, scrollDelta: const Offset(0, -999)));
    await tester.pump();
    expect(view.pixels, 0);
  });

  testWidgets('reverse horizontal scrolling starts at the end and has correct drag and reveal bounds', (tester) async {
    final screen = await wiring.show(tester, nodes(horizontal: true, reverse: true));
    final view = viewport(screen.tree);
    expect(view.pixels, 0);
    expect(screen.tree.boxOf('item5')!.localToGlobal(Offset.zero).dx, closeTo(100, .01));
    await tester.dragFrom(view.localToGlobal(const Offset(100, 100)), const Offset(500, 0));
    await tester.pump();
    expect(view.pixels, 400);
    expect(screen.tree.boxOf('item0')!.localToGlobal(Offset.zero).dx, closeTo(0, .01));
    await view.reveal(screen.tree.boxOf('item5')!, alignment: 0);
    await tester.pump();
    expect(view.pixels, 0);
    await view.scrollTo(-100);
    expect(view.pixels, 0);
    await view.scrollTo(999);
    expect(view.pixels, 400);
  });

  testWidgets('design views remain at rest and switching out of runtime resets scroll input', (tester) async {
    final screen = await wiring.show(tester, nodes(), interactive: false);
    final view = viewport(screen.tree);
    final at = view.localToGlobal(const Offset(100, 100));
    await tester.dragFrom(at, const Offset(0, -500));
    await tester.sendEventToBinding(PointerScrollEvent(position: at, scrollDelta: const Offset(0, 300)));
    await tester.pump();
    expect(view.pixels, 0);
    Widget host(bool interactive) => MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: NodeView(tree: screen.tree, rootId: 'col', interactive: interactive),
        ),
      ),
    );
    await tester.pumpWidget(host(true));
    await view.scrollTo(300);
    await tester.pump();
    expect(view.pixels, 300);
    await tester.pumpWidget(host(false));
    expect(view.interactive, false);
    expect(view.pixels, 0);
    expect(screen.tree.boxOf('item0')!.localToGlobal(Offset.zero).dy, closeTo(0, .01));
  });

  testWidgets('showOnScreen and semantic scroll actions reveal clipped descendants', (tester) async {
    final screen = await wiring.show(tester, nodes());
    final view = viewport(screen.tree);
    await view.scrollTo(160);
    screen.tree.boxOf('item2')!.showOnScreen();
    expect(view.pixels, 160, reason: 'an already visible target needs no movement');
    screen.tree.boxOf('item5')!.showOnScreen();
    await tester.pump();
    expect(view.pixels, 400);
    final config = SemanticsConfiguration();
    view.describeSemanticsConfiguration(config);
    expect(config.hasImplicitScrolling, true);
    expect(config.scrollExtentMax, 400);
    expect(config.onScrollUp, isNull, reason: 'no forward semantic action at the end (Flutter drag-direction convention)');
    config.onScrollDown!();
    await tester.pump();
    expect(view.pixels, 240);
    final nextConfig = SemanticsConfiguration();
    view.describeSemanticsConfiguration(nextConfig);
    nextConfig.onScrollUp!();
    await tester.pump();
    expect(view.pixels, 400);
  });

  testWidgets('never physics blocks user input while programmatic reveal remains available', (tester) async {
    final authored = nodes();
    (authored['col']!['props'] as Map)['physics'] = 'never';
    final screen = await wiring.show(tester, authored);
    final view = viewport(screen.tree);
    final at = view.localToGlobal(const Offset(100, 100));
    await tester.dragFrom(at, const Offset(0, -500));
    await tester.sendEventToBinding(PointerScrollEvent(position: at, scrollDelta: const Offset(0, 200)));
    await tester.pump();
    expect(view.pixels, 0);
    await view.reveal(screen.tree.boxOf('item5')!);
    expect(view.pixels, 400);
  });

  testWidgets('nested wheel input scrolls the inner viewport then its parent at the boundary', (tester) async {
    final authored = nodes();
    authored['inner'] = {...authored['col']!};
    authored['col'] = {
      'type': 'column',
      'props': {'scrollable': true},
      'layout': {'width': 200, 'height': 200},
      'children': ['before', 'inner', 'after'],
    };
    authored['before'] = {
      'type': 'box',
      'layout': {'width': 200, 'height': 300},
    };
    authored['after'] = {
      'type': 'box',
      'layout': {'width': 200, 'height': 300},
    };
    final screen = await wiring.show(tester, authored);
    final outer = viewport(screen.tree);
    final inner = viewport(screen.tree, 'inner');
    await outer.scrollTo(300);
    await tester.pump();
    final at = inner.localToGlobal(const Offset(100, 100));
    await tester.sendEventToBinding(PointerScrollEvent(position: at, scrollDelta: const Offset(0, 100)));
    await tester.pump();
    expect(inner.pixels, 100);
    expect(outer.pixels, 300);
    await inner.scrollTo(400);
    await tester.pump();
    await tester.sendEventToBinding(PointerScrollEvent(position: at, scrollDelta: const Offset(0, 100)));
    await tester.pump();
    expect(inner.pixels, 400);
    expect(outer.pixels, 400);
  });

  testWidgets('a board scrolls sideways under the wheel over a column: Shift + wheel and a sideways scroll', (tester) async {
    // A horizontal board of vertical lanes, each scrolling its own cards.
    final authored = <String, Json>{
      'col': {
        'type': 'row',
        'props': {'scrollable': true, 'scrollDirection': 'horizontal'},
        'layout': {'width': 300, 'height': 200},
        'children': ['lane0', 'lane1', 'lane2'],
      },
      for (var l = 0; l < 3; l++)
        'lane$l': {
          'type': 'column',
          'props': {'scrollable': true},
          'layout': {'width': 200, 'height': 200},
          'children': [for (var i = 0; i < 4; i++) 'card$l$i'],
        },
      for (var l = 0; l < 3; l++)
        for (var i = 0; i < 4; i++)
          'card$l$i': {
            'type': 'box',
            'layout': {'width': 200, 'height': 100},
          },
    };
    final screen = await wiring.show(tester, authored);
    final board = viewport(screen.tree);
    final lane = viewport(screen.tree, 'lane0');
    final at = lane.localToGlobal(const Offset(100, 100));
    // A mouse wheel with Shift held scrolls the board, not the lane.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendEventToBinding(PointerScrollEvent(position: at, scrollDelta: const Offset(0, 120)));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(board.pixels, 120);
    expect(lane.pixels, 0);
    // A sideways scroll (a trackpad) too.
    await tester.sendEventToBinding(PointerScrollEvent(position: at, scrollDelta: const Offset(80, 0)));
    await tester.pump();
    expect(board.pixels, 200);
    expect(lane.pixels, 0);
    // A plain wheel still scrolls the lane.
    await tester.sendEventToBinding(PointerScrollEvent(position: board.localToGlobal(const Offset(150, 100)), scrollDelta: const Offset(0, 50)));
    await tester.pump();
    expect(board.pixels, 200);
  });

  testWidgets('native scrollTo action respects axis, alignment, offset and animation', (tester) async {
    final screen = await wiring.show(tester, nodes());
    final view = viewport(screen.tree);
    Future<void> run(Json action) => const CodelesslyActions().trigger(
      Node.fromJson({
        'type': 'box',
        'actions': [
          {
            'trigger': {'type': 'click'},
            'actions': [action],
          },
        ],
      }, id: 'action')!,
      'click',
      screen.context,
    );
    await run({'type': 'scrollTo', 'node': 'item3', 'axis': 'horizontal', 'durationMs': 0});
    expect(view.pixels, 0);
    await run({'type': 'scrollTo', 'node': 'item3', 'axis': 'vertical', 'alignment': 0, 'offset': 20, 'durationMs': 0});
    expect(view.pixels, 280);
    final animated = run({'type': 'scrollTo', 'node': 'item5', 'durationMs': 100});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await animated;
    expect(view.pixels, 400);
    expect(tester.takeException(), isNull);
  });
}
