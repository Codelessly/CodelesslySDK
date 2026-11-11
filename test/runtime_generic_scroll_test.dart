import 'dart:ui' as ui;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'lists/support.dart' as support;

RenderDesignScroll viewport(RenderObject root) {
  RenderDesignScroll? found;
  void visit(RenderObject object) {
    if (object is RenderDesignScroll) {
      found ??= object;
      return;
    }
    object.visitChildren(visit);
  }

  visit(root);
  return found!;
}

Map<String, Json> nodes({bool horizontal = false, bool reverse = false}) => {
  'col': {
    'type': horizontal ? 'row' : 'column',
    'layout': {'width': 200, 'height': 200},
    'props': {'scrollable': true, 'scrollDirection': horizontal ? 'horizontal' : 'vertical', 'reverse': reverse},
    'children': ['a', 'b', 'c', 'd'],
  },
  for (final id in ['a', 'b', 'c', 'd'])
    id: {
      'type': 'box',
      'layout': {'width': horizontal ? 100 : 200, 'height': horizontal ? 200 : 100},
      'decoration': {
        'fills': [
          {'color': '#FF102030'},
        ],
      },
    },
};
void main() {
  testWidgets('runtime wheel scrolling moves content and clamps the offset', (tester) async {
    final s = await support.show(tester, nodes());
    final v = viewport(s.tree.boxOf('col')!);
    expect(v.maxScrollExtent, 200);
    expect(v.pixels, 0);
    await tester.sendEventToBinding(const PointerScrollEvent(position: Offset(100, 100), scrollDelta: Offset(0, 120)));
    await tester.pump();
    expect(v.pixels, 120);
    expect(s.tree.boxOf('c')!.localToGlobal(Offset.zero).dy, 80);
    v.jumpTo(999);
    expect(v.pixels, 200);
    v.jumpTo(-999);
    expect(v.pixels, 0);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('drag scrolling, reveal and animation use the same runtime position', (tester) async {
    final s = await support.show(tester, nodes());
    final v = viewport(s.tree.boxOf('col')!);
    await tester.dragFrom(const Offset(150, 150), const Offset(0, -100));
    await tester.pump();
    expect(v.pixels, greaterThan(50));
    v.jumpTo(0);
    s.tree.boxOf('d')!.showOnScreen();
    await tester.pump();
    expect(v.pixels, 200);
    final move = v.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.linear);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(v.pixels, closeTo(100, 1));
    await tester.pump(const Duration(milliseconds: 100));
    await move;
    expect(v.pixels, 0);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('horizontal reverse starts at the end and scrolls toward the beginning', (tester) async {
    final s = await support.show(tester, nodes(horizontal: true, reverse: true));
    final v = viewport(s.tree.boxOf('col')!);
    expect(s.tree.boxOf('a')!.localToGlobal(Offset.zero).dx, -200);
    await tester.sendEventToBinding(const PointerScrollEvent(position: Offset(100, 100), scrollDelta: Offset(-120, 0)));
    await tester.pump();
    expect(v.pixels, 120);
    expect(s.tree.boxOf('a')!.localToGlobal(Offset.zero).dx, -80);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('design canvases remain at rest and ignore runtime input', (tester) async {
    final s = await support.show(tester, nodes(), interactive: false);
    final v = viewport(s.tree.boxOf('col')!);
    v.jumpTo(100);
    await tester.sendEventToBinding(const PointerScrollEvent(position: Offset(100, 100), scrollDelta: Offset(0, 100)));
    await tester.pump();
    expect(v.pixels, 0);
    expect(s.tree.boxOf('a')!.localToGlobal(Offset.zero), Offset.zero);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('a precise child trim track wins over its vertical scrolling ancestor', (tester) async {
    final s = await support.show(
      tester,
      {
        'col': {
          'type': 'column',
          'layout': {'width': 200, 'height': 200},
          'props': {'scrollable': true},
          'children': ['before', 'strip', 'after'],
        },
        'before': {
          'type': 'box',
          'layout': {'width': 200, 'height': 100},
        },
        'strip': {
          'type': 'stack',
          'layout': {'width': 200, 'height': 100},
          'children': ['handle'],
        },
        'handle': {
          'type': 'box',
          'layout': {
            'width': 20,
            'height': 20,
            'x': {'start': 20},
            'y': {'start': 0},
          },
          'drag': {
            'track': {
              'variable': 'trim',
              'min': 0,
              'max': 10,
              'step': .1,
              'fineStep': .01,
              'x1': 0,
              'y1': 0,
              'x2': 0,
              'y2': 80,
            },
          },
        },
        'after': {
          'type': 'box',
          'layout': {'width': 200, 'height': 200},
        },
      },
      variables: [support.v('trim', 0, VariableType.decimal)],
    );
    final v = viewport(s.tree.boxOf('col')!);
    v.jumpTo(100);
    await tester.pump();
    final start = s.center('handle');
    final gesture = await tester.startGesture(start);
    await gesture.moveBy(const Offset(0, 5));
    await gesture.moveBy(const Offset(0, 45));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(s['trim'], greaterThan(0));
    expect(v.pixels, 100);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('reverse short content keeps its end alignment without scrolling', (tester) async {
    final doc = nodes(reverse: true);
    doc['col']!['children'] = ['a'];
    final s = await support.show(tester, doc);
    final v = viewport(s.tree.boxOf('col')!);
    expect(v.maxScrollExtent, 0);
    expect(s.tree.boxOf('a')!.localToGlobal(Offset.zero).dy, 100);
    v.jumpTo(200);
    expect(v.pixels, 0);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('viewport scrolling publishes useful accessibility extents', (tester) async {
    final s = await support.show(tester, nodes());
    final v = viewport(s.tree.boxOf('col')!);
    final semantics = SemanticsConfiguration();
    v.describeSemanticsConfiguration(semantics);
    expect(semantics.hasImplicitScrolling, true);
    // Its texts and controls are their own nodes, not merged into one label.
    expect(semantics.explicitChildNodes, true);
    expect(semantics.scrollExtentMin, 0);
    expect(semantics.scrollExtentMax, 200);
    expect(semantics.onScrollDown, isNull);
    semantics.onScrollUp!();
    expect(v.pixels, 160);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('a scrolling stack measures and reveals positioned content', (tester) async {
    final s = await support.show(tester, {
      'col': {
        'type': 'stack',
        'layout': {'width': 200, 'height': 200},
        'props': {'scrollable': true},
        'children': ['tail'],
      },
      'tail': {
        'type': 'box',
        'layout': {
          'width': 200,
          'height': 100,
          'y': {'start': 300},
        },
      },
    });
    final v = viewport(s.tree.boxOf('col')!);
    expect(v.maxScrollExtent, 200);
    s.tree.boxOf('tail')!.showOnScreen();
    await tester.pump();
    expect(v.pixels, 200);
    expect(s.tree.boxOf('tail')!.localToGlobal(Offset.zero).dy, 100);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('wheel input hands off to an ancestor at a nested scroll boundary', (tester) async {
    final s = await support.show(tester, {
      'col': {
        'type': 'column',
        'layout': {'width': 200, 'height': 200},
        'props': {'scrollable': true},
        'children': ['inner', 'tail'],
      },
      'inner': {
        'type': 'column',
        'layout': {'width': 200, 'height': 100},
        'props': {'scrollable': true},
        'children': ['inside'],
      },
      'inside': {
        'type': 'box',
        'layout': {'width': 200, 'height': 400},
      },
      'tail': {
        'type': 'box',
        'layout': {'width': 200, 'height': 300},
      },
    });
    final outer = viewport(s.tree.boxOf('col')!), inner = viewport(s.tree.boxOf('inner')!);
    await tester.sendEventToBinding(const PointerScrollEvent(position: Offset(100, 50), scrollDelta: Offset(0, 300)));
    await tester.pump();
    expect(inner.pixels, 300);
    expect(outer.pixels, 0);
    await tester.sendEventToBinding(const PointerScrollEvent(position: Offset(100, 50), scrollDelta: Offset(0, 50)));
    await tester.pump();
    expect(inner.pixels, 300);
    expect(outer.pixels, 50);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('semantic directions match Flutter SingleChildScrollView actions', (tester) async {
    final handle = tester.ensureSemantics();
    final s = await support.show(tester, nodes());
    final v = viewport(s.tree.boxOf('col')!);
    v.jumpTo(100);
    final ours = SemanticsConfiguration();
    v.describeSemanticsConfiguration(ours);
    ours.onScrollUp!();
    final up = v.pixels;
    ours.onScrollDown!();
    final down = v.pixels;
    final native = ScrollController(initialScrollOffset: 100);
    addTearDown(native.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 200,
            height: 200,
            child: SingleChildScrollView(controller: native, child: const SizedBox(width: 200, height: 400)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final owner = tester.binding.renderViews.single.owner!.semanticsOwner!;
    SemanticsNode? actionNode;
    void visit(SemanticsNode node) {
      if (node.getSemanticsData().hasAction(ui.SemanticsAction.scrollUp)) actionNode = node;
      node.visitChildren((child) {
        visit(child);
        return true;
      });
    }

    visit(owner.rootSemanticsNode!);
    expect(actionNode, isNotNull);
    owner.performAction(actionNode!.id, ui.SemanticsAction.scrollUp);
    await tester.pumpAndSettle();
    expect(native.offset, up);
    expect(up, greaterThan(100));
    owner.performAction(actionNode!.id, ui.SemanticsAction.scrollDown);
    await tester.pumpAndSettle();
    expect(native.offset, down);
    expect(down, lessThan(up));
    await tester.pumpWidget(const SizedBox());
    handle.dispose();
  });
  testWidgets('motion-decorated design content does not enable runtime scrolling', (tester) async {
    final doc = nodes();
    doc['a']!['motion'] = {
      'opacity': .5,
      'enter': {'durationMs': 500},
    };
    final s = await support.show(tester, doc, interactive: false);
    final v = viewport(s.tree.boxOf('col')!);
    expect(s.tree.animates, false);
    expect(s.tree.islands.environment.interactive, false);
    expect(v.interactive, false);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.sendEventToBinding(const PointerScrollEvent(position: Offset(100, 100), scrollDelta: Offset(0, 100)));
    await tester.pump();
    expect(v.pixels, 0);
    await tester.pumpWidget(const SizedBox());
  });
}
