import 'dart:ui' as ui;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/layout/design_scroll.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lists/support.dart' as lists;
import '../support/screen.dart' as harness;

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

RenderDesignScroll scrollViewUnder(RenderObject root) {
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

Map<String, Json> scrollingNodes({bool horizontal = false, bool reverse = false}) => {
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

// A scroll view that hugs its content (a sheet as tall as its content up to
// the screen, scrolling past that) keeps where it was scrolled to when its
// content changes: typing into a field in it relaid it out with room for
// all of it, and the position went back to the top.

// A focused text field in a scrolling column doesn't hold the column in
// place: after typing, the column still scrolls away from the field (the
// send sheet's note, then down to the Send button), as in any app.

void main() {
  testWidgets('dragging scrolls to content that was clipped, and a button taps where it now is', (tester) async {
    final screen = await harness.show(
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

  testWidgets('the mouse wheel scrolls and stops at both ends', (tester) async {
    final screen = await harness.show(tester, nodes());
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

  testWidgets('a reversed row starts at its end and scrolls back', (tester) async {
    final screen = await harness.show(tester, nodes(horizontal: true, reverse: true));
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

  testWidgets('on the design canvas nothing scrolls', (tester) async {
    final screen = await harness.show(tester, nodes(), interactive: false);
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

  testWidgets('focus and screen-reader scrolling bring clipped content into view', (tester) async {
    final screen = await harness.show(tester, nodes());
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

  testWidgets('a view that cannot be scrolled by hand can still be scrolled by an action', (tester) async {
    final authored = nodes();
    (authored['col']!['props'] as Map)['physics'] = 'never';
    final screen = await harness.show(tester, authored);
    final view = viewport(screen.tree);
    final at = view.localToGlobal(const Offset(100, 100));
    await tester.dragFrom(at, const Offset(0, -500));
    await tester.sendEventToBinding(PointerScrollEvent(position: at, scrollDelta: const Offset(0, 200)));
    await tester.pump();
    expect(view.pixels, 0);
    await view.reveal(screen.tree.boxOf('item5')!);
    expect(view.pixels, 400);
  });

  testWidgets('the wheel scrolls the inner view first, then its parent once the inner one is at its end', (tester) async {
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
    final screen = await harness.show(tester, authored);
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

  testWidgets('Shift + wheel and a sideways wheel scroll a row from over a column inside it', (tester) async {
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
    final screen = await harness.show(tester, authored);
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

  testWidgets('on desktop a scrollbar shows while the mouse is over its track or the view scrolls', (tester) async {
    final screen = await harness.show(tester, nodes());
    final view = viewport(screen.tree);
    // 200 tall, 600 of content: a third of the track, at the top.
    expect(view.showsScrollbar, isTrue);
    expect(view.thumbShown, isFalse);
    expect(view.thumbRect, rectMoreOrLessEquals(const Rect.fromLTWH(194, 0, 6, 200 / 3)));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: view.localToGlobal(const Offset(100, 100)));
    addTearDown(mouse.removePointer);
    await tester.pump();
    expect(view.thumbShown, isFalse, reason: 'over the content, not the track');
    await mouse.moveTo(view.localToGlobal(const Offset(197, 100)));
    await tester.pump();
    expect(view.thumbShown, isTrue);
    await mouse.moveTo(const Offset(700, 500));
    await tester.pump();
    expect(view.thumbShown, isFalse);
    // A wheel scroll shows it a moment, at its new place.
    await tester.sendEventToBinding(PointerScrollEvent(position: view.localToGlobal(const Offset(100, 100)), scrollDelta: const Offset(0, 400)));
    await tester.pump();
    expect(view.thumbShown, isTrue);
    expect(view.thumbRect.bottom, closeTo(200, 0.01));
    await tester.pump(const Duration(milliseconds: 700));
    expect(view.thumbShown, isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('on a touch device there is no scrollbar', (tester) async {
    final screen = await harness.show(tester, nodes());
    expect(viewport(screen.tree).showsScrollbar, isFalse);
  });

  testWidgets('a scroll-to action follows its axis, alignment, offset and animation', (tester) async {
    final screen = await harness.show(tester, nodes());
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

  group('more scrolling', () {
    testWidgets('a sideways slider inside a scrolling column takes a sideways drag', (tester) async {
      final s = await lists.show(
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
        variables: [lists.v('trim', 0, VariableType.decimal)],
      );
      final v = scrollViewUnder(s.tree.boxOf('col')!);
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
    testWidgets('reversed content shorter than its view stays at its end and does not scroll', (tester) async {
      final doc = scrollingNodes(reverse: true);
      doc['col']!['children'] = ['a'];
      final s = await lists.show(tester, doc);
      final v = scrollViewUnder(s.tree.boxOf('col')!);
      expect(v.maxScrollExtent, 0);
      expect(s.tree.boxOf('a')!.localToGlobal(Offset.zero).dy, 100);
      v.jumpTo(200);
      expect(v.pixels, 0);
      await tester.pumpWidget(const SizedBox());
    });
    testWidgets('a scrolling stack is as long as its furthest child and can reveal it', (tester) async {
      final s = await lists.show(tester, {
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
      final v = scrollViewUnder(s.tree.boxOf('col')!);
      expect(v.maxScrollExtent, 200);
      s.tree.boxOf('tail')!.showOnScreen();
      await tester.pump();
      expect(v.pixels, 200);
      expect(s.tree.boxOf('tail')!.localToGlobal(Offset.zero).dy, 100);
      await tester.pumpWidget(const SizedBox());
    });
    testWidgets('screen-reader scroll directions match Flutter\'s scroll view', (tester) async {
      final handle = tester.ensureSemantics();
      final s = await lists.show(tester, scrollingNodes());
      final v = scrollViewUnder(s.tree.boxOf('col')!);
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
  });

  group('scroll position', () {
    testWidgets('a scroll view that hugs keeps its position when its content changes', (tester) async {
      final scope = VariableScope([const Variable(name: 'tall', type: VariableType.boolean, value: false)]);
      final tree = NodeTree(
        DocumentSource(LayoutDocument.fromJson({
          'roots': ['page'],
          'nodes': {
            'page': {
              'type': 'row',
              'children': ['card'],
              'layout': {'width': 400, 'height': 500, 'padding': 20},
              'props': {'mainAxisAlignment': 'center', 'crossAxisAlignment': 'center'},
            },
            'card': {
              'type': 'column',
              'children': ['scroll'],
              'layout': {'width': {'fill': 360}, 'height': {'hug': 10}},
              'props': {'crossAxisAlignment': 'stretch'},
            },
            'scroll': {
              'type': 'column',
              'children': ['a', 'grow', 'b'],
              'layout': {'width': {'fill': 360}, 'height': {'hug': 10}, 'padding': 20},
              'props': {'scrollable': true, 'crossAxisAlignment': 'stretch'},
            },
            'a': {'type': 'box', 'layout': {'width': {'fill': 320}, 'height': 400}},
            'grow': {
              'type': 'box',
              'layout': {'width': {'fill': 320}, 'height': 40},
              'bind': {'layout.height': r'${= tall ? 60 : 40}'},
            },
            'b': {'type': 'box', 'layout': {'width': {'fill': 320}, 'height': 300}},
          },
        })),
        binder: NodeBinder(scope: scope, logic: const LayoutLogic()),
      );
      addTearDown(tree.dispose);
      await tester.pumpWidget(MaterialApp(
        home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'page', interactive: true)),
      ));
      await tester.pump();
      RenderDesignScroll? scroll;
      void visit(RenderObject o) {
        if (o is RenderDesignScroll && scroll == null) scroll = o;
        o.visitChildren(visit);
      }
      visit(tester.renderObject(find.byType(NodeView)));
      expect(scroll!.maxScrollExtent, greaterThan(150));
      scroll!.jumpBy(150);
      await tester.pump();
      expect(scroll!.offset, 150);
      // The content changes (a field grows as it's typed into).
      scope.set('tall', true);
      await tester.pump();
      await tester.pump();
      expect(scroll!.offset, 150);
    });

    for (final bound in [false, true]) {
      testWidgets('a column can be scrolled away from a text field that has focus (bound text: $bound)', (tester) async {
        final scope = VariableScope([const Variable(name: 'msg', type: VariableType.text, value: '')]);
        final tree = NodeTree(
          DocumentSource(LayoutDocument.fromJson({
            'roots': ['col'],
            'nodes': {
              'col': {
                'type': 'column',
                'children': ['top', 'f', 'tail'],
                'layout': {'width': 300, 'height': 400},
                'props': {'scrollable': true},
              },
              'top': {'type': 'box', 'layout': {'width': 300, 'height': 120}},
              'f': {
                'type': 'textField',
                'layout': {'width': 300, 'height': {'hug': 48}},
                if (bound) 'bind': {'props.initialValue': r'${msg}'},
                if (bound)
                  'actions': [
                    {
                      'trigger': {'type': 'changed'},
                      'actions': [
                        {'type': 'setVariable', 'variable': 'msg', 'value': r'${value}'},
                      ],
                    },
                  ],
              },
              'tail': {'type': 'box', 'layout': {'width': 300, 'height': 800}},
            },
          })),
          binder: NodeBinder(scope: scope, logic: const LayoutLogic()),
        );
        addTearDown(tree.dispose);
        await tester.pumpWidget(MaterialApp(
          home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'col', interactive: true)),
        ));
        await tester.pump();
        final field = find.byType(TextField);
        await tester.tap(field);
        await tester.pump();
        // As the MCP's preview.type does: the keyboard's value, a few frames.
        final editable = tester.state<EditableTextState>(find.byType(EditableText));
        editable.updateEditingValue(const TextEditingValue(
          text: 'Thanks for pairing', selection: TextSelection.collapsed(offset: 18)));
        for (var i = 0; i < 3; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        RenderDesignScroll? scroll;
        void visit(RenderObject o) {
          if (o is RenderDesignScroll && scroll == null) scroll = o;
          o.visitChildren(visit);
        }
        visit(tester.renderObject(find.byType(NodeView)));
        expect(scroll, isNotNull);
        expect(FocusManager.instance.primaryFocus, isNotNull, reason: 'the field still has focus');
        // Scroll the field out of view, as a person reaching the Send button.
        for (var i = 0; i < 3; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        scroll!.jumpBy(300);
        for (var i = 0; i < 3; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        await tester.pumpAndSettle();
        expect(scroll!.offset, 300);
      });
    }
  });
}
