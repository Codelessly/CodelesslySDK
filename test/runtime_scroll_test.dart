import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/layout/design_scroll.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'actions/wiring_test.dart' as fixture;

Map<String, api.Json> content({
  bool horizontal = false,
  bool reverse = false,
  String physics = 'clamping',
}) => {
  'scroll': {
    'type': horizontal ? 'row' : 'column',
    'children': ['top', 'target', 'footer'],
    'layout': {'width': 300, 'height': 200},
    'props': {
      'scrollable': true,
      'scrollDirection': horizontal ? 'horizontal' : 'vertical',
      'reverse': reverse,
      'physics': physics,
      'squeezeChildren': false,
    },
  },
  'top': {
    'type': 'box',
    'layout': {
      'width': horizontal ? 400 : 300,
      'height': horizontal ? 200 : 400,
    },
  },
  'target': {
    'type': 'box',
    'layout': {
      'width': horizontal ? 100 : 300,
      'height': horizontal ? 200 : 100,
    },
    'actions': [
      fixture.reaction('click', [fixture.add('taps')]),
    ],
  },
  'footer': {
    'type': 'box',
    'layout': {
      'width': horizontal ? 100 : 300,
      'height': horizontal ? 200 : 100,
    },
  },
};

List<T> descendants<T extends RenderObject>(RenderObject root) {
  final found = <T>[];
  void visit(RenderObject r) {
    if (r is T) found.add(r);
    r.visitChildren(visit);
  }

  visit(root);
  return found;
}

RenderRuntimeScroll viewport(fixture.Screen s, String id) =>
    descendants<RenderRuntimeScroll>(s.tree.boxOf(id)!).first;
Future<void> wheel(WidgetTester tester, Offset point, Offset delta) async {
  final p = TestPointer(20, PointerDeviceKind.mouse);
  await tester.sendEventToBinding(p.hover(point));
  await tester.sendEventToBinding(p.scroll(delta));
  await tester.pump();
}

void main() {
  testWidgets(
    'a regular column scrolls by wheel, clamps and transforms child hits',
    (tester) async {
      final s = await fixture.show(
        tester,
        content(),
        root: 'scroll',
        variables: [fixture.v('taps', 0, VariableType.integer)],
      );
      final view = viewport(s, 'scroll');
      expect(view.viewportExtent, 200);
      expect(view.maxScrollExtent, 400);
      await wheel(tester, const Offset(50, 50), const Offset(0, 120));
      expect(view.pixels, 120);
      expect(s.tree.boxOf('target')!.localToGlobal(Offset.zero).dy, 280);
      view.jumpTo(999);
      await tester.pump();
      expect(view.pixels, 400);
      await tester.tapAt(const Offset(50, 50));
      await tester.pump();
      expect(s['taps'], 1);
      view.jumpTo(-100);
      expect(view.pixels, 0);
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('touch dragging moves regular content and physics settles', (
    tester,
  ) async {
    final s = await fixture.show(tester, content(), root: 'scroll');
    final view = viewport(s, 'scroll');
    await tester.timedDragFrom(
      const Offset(150, 150),
      const Offset(0, -100),
      const Duration(milliseconds: 300),
    );
    expect(view.pixels, greaterThan(50));
    await tester.pumpAndSettle();
    expect(view.pixels, inInclusiveRange(0, 400));
  });
  testWidgets(
    'horizontal and reversed viewports map physical deltas correctly',
    (tester) async {
      final s = await fixture.show(
        tester,
        content(horizontal: true, reverse: true),
        root: 'scroll',
      );
      final view = viewport(s, 'scroll');
      expect(view.maxScrollExtent, 300);
      expect(view.pixels, 0);
      await wheel(tester, const Offset(50, 50), const Offset(-90, 0));
      expect(view.pixels, 90);
      view.scrollBy(20);
      expect(view.pixels, 70);
      await tester.pump(const Duration(milliseconds: 200));
    },
  );
  testWidgets(
    'a nested viewport consumes wheels, then its parent at its edge',
    (tester) async {
      final s = await fixture.show(tester, {
        'outer': {
          'type': 'column',
          'children': ['inner', 'long'],
          'layout': {'width': 300, 'height': 200},
          'props': {
            'scrollable': true,
            'physics': 'clamping',
            'squeezeChildren': false,
          },
        },
        'inner': {
          'type': 'column',
          'children': ['inside'],
          'layout': {'width': 300, 'height': 100},
          'props': {
            'scrollable': true,
            'physics': 'clamping',
            'squeezeChildren': false,
          },
        },
        'inside': {
          'type': 'box',
          'layout': {'width': 300, 'height': 300},
        },
        'long': {
          'type': 'box',
          'layout': {'width': 300, 'height': 500},
        },
      }, root: 'outer');
      final outer = viewport(s, 'outer'), inner = viewport(s, 'inner');
      await wheel(tester, const Offset(50, 50), const Offset(0, 80));
      expect(inner.pixels, 80);
      expect(outer.pixels, 0);
      inner.jumpTo(inner.maxScrollExtent);
      await tester.pump();
      await wheel(tester, const Offset(50, 50), const Offset(0, 60));
      expect(outer.pixels, 60);
      expect(inner.pixels, 200);
      await tester.pump(const Duration(milliseconds: 200));
    },
  );
  testWidgets('offset survives bound-node rebuild and clamps after filtering', (
    tester,
  ) async {
    final s = await fixture.show(tester, content(), root: 'scroll');
    final view = viewport(s, 'scroll');
    view.jumpTo(300);
    s.tree.reapply(['scroll']);
    await tester.pump();
    expect(identical(view, viewport(s, 'scroll')), isTrue);
    expect(view.pixels, 300);
    s.context.nodeValues!.set('top', 'layout.height', 50);
    await tester.pump();
    expect(view.maxScrollExtent, 50);
    expect(view.pixels, 50);
  });
  testWidgets(
    'never physics blocks user scrolling but permits reveal/actions',
    (tester) async {
      final s = await fixture.show(
        tester,
        content(physics: 'never'),
        root: 'scroll',
      );
      final view = viewport(s, 'scroll');
      await wheel(tester, const Offset(50, 50), const Offset(0, 100));
      expect(view.pixels, 0);
      view.jumpTo(100);
      expect(view.pixels, 100);
    },
  );
  testWidgets(
    'scrollTo with an explicit axis reveals a node in a native column',
    (tester) async {
      final s = await fixture.show(tester, content(), root: 'scroll');
      final view = viewport(s, 'scroll');
      final trigger = api.Node.fromJson({
        'type': 'box',
        'actions': [
          fixture.reaction('click', [
            {
              'type': 'scrollTo',
              'node': 'target',
              'alignment': 0,
              'durationMs': 0,
              'axis': 'vertical',
            },
          ]),
        ],
      }, id: 'trigger')!;
      await const CodelesslyActions().run(trigger, 'click', s.context);
      await tester.pump();
      expect(view.pixels, 400);
      expect(s.tree.boxOf('target')!.localToGlobal(Offset.zero).dy, 0);
    },
  );
  testWidgets('programmatic animation completes and emits scroll/end events', (
    tester,
  ) async {
    final nodes = content();
    nodes['scroll']!['actions'] = [
      fixture.reaction('scroll', [fixture.add('updates')]),
      fixture.reaction('scrollEnd', [fixture.add('ends')]),
    ];
    final s = await fixture.show(
      tester,
      nodes,
      root: 'scroll',
      variables: [
        fixture.v('updates', 0, VariableType.integer),
        fixture.v('ends', 0, VariableType.integer),
      ],
    );
    final view = viewport(s, 'scroll');
    final done = view.animateTo(
      200,
      duration: const Duration(milliseconds: 200),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(view.pixels, greaterThan(0));
    expect(view.pixels, lessThan(200));
    await tester.pump(const Duration(milliseconds: 100));
    await done;
    await tester.pump();
    expect(view.pixels, 200);
    expect(s['updates'] as int, greaterThan(0));
    expect(s['ends'], 1);
  });
  testWidgets(
    'design scrolling stays at rest and creates no runtime viewport',
    (tester) async {
      final s = await fixture.show(
        tester,
        content(),
        root: 'scroll',
        interactive: false,
      );
      expect(
        descendants<RenderRuntimeScroll>(s.tree.boxOf('scroll')!),
        isEmpty,
      );
      expect(
        descendants<RenderDesignScroll>(s.tree.boxOf('scroll')!),
        hasLength(1),
      );
      await wheel(tester, const Offset(50, 50), const Offset(0, 100));
      expect(s.tree.boxOf('target')!.localToGlobal(Offset.zero).dy, 400);
    },
  );
}
