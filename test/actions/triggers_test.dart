
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/controls/segmented.dart' show RenderSegmentedButton;
import 'package:codelessly_sdk/src/runtime/actions/text_fields.dart' show TextFieldHandle;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../controls/toggles_support.dart';
import '../support/screen.dart' as harness;
import '../support/fields.dart';

// Triggers in the render tree: nodes tapped (pressed, hovered, swiped...)
// in a NodeView(interactive: true) run their reactions; a variable they set
// re-applies only the boxes that read it.

// Triggers in the render tree: nodes tapped (pressed, hovered, swiped...)
// in a NodeView(interactive: true) run their reactions; a variable they set
// re-applies only the boxes that read it.

void main() {
  {
    testWidgets('a timer whose interval is a formula follows it, and stops when its node goes', (tester) async {
      final s=await harness.show(tester,harness.counter(actions:[harness.reaction('clock',[harness.add('count')],extra:{'every':r'${= 1000 / speed}'})]),variables:[harness.v('count',0,VariableType.integer),harness.v('speed',10,VariableType.integer)]);
      await tester.pump(const Duration(milliseconds:250));expect(s['count'],2);
      s.scope.set('speed',20);await tester.pump(const Duration(milliseconds:150));expect(s['count'],5);
      s.scope.set('speed',0);await tester.pump(const Duration(seconds:1));expect(s['count'],5);
      s.scope.set('speed',5);await tester.pump(const Duration(milliseconds:400));expect(s['count'],7);
      await tester.pumpWidget(const SizedBox());s.scope.set('speed',10);
      await tester.pump(const Duration(seconds:1));expect(s['count'],7);
    });


    testWidgets('a timer runs only while its condition holds', (tester) async {
      final nodes=harness.counter();nodes['other']={...nodes['other']!, 'actions':[harness.reaction('clock',[harness.add('ticks')],extra:{'every':r'${period}','runWhen':r'${playing}'})]};
      final s=await harness.show(tester,nodes,variables:[harness.v('count',0,VariableType.integer),harness.v('ticks',0,VariableType.integer),harness.v('period',100,VariableType.integer),harness.v('playing',false,VariableType.boolean)]);
      await tester.pump(const Duration(milliseconds:350));expect(s['ticks'],0);
      s.scope.set('playing',true);await tester.pump(const Duration(milliseconds:100));expect(s['ticks'],1);
      s.scope.set('period',50);await tester.pump(const Duration(milliseconds:100));expect(s['ticks'],3);
      s.scope.set('playing',false);await tester.pump(const Duration(milliseconds:300));expect(s['ticks'],3);
    });

    testWidgets('a value-changed reaction on one field ignores changes to its neighbours', (tester) async {
      final nodes=harness.counter();
      nodes['other']={...nodes['other']!, 'actions':[
        harness.reaction('valueChanged',[harness.add('keySeen'), {'type':'setVariable','variable':'session.key','value':'0'}],extra:{'variable':'fifthIndex'}),
        harness.reaction('valueChanged',[harness.add('playSeen')],extra:{'variable':'session.playing'}),
      ]};
      final s=await harness.show(tester,nodes,variables:[harness.v('count',0,VariableType.integer),harness.v('fifthIndex',0,VariableType.integer),harness.v('session',{'key':0,'playing':false,'notes':[]},VariableType.map),harness.v('keySeen',0,VariableType.integer),harness.v('playSeen',0,VariableType.integer)]);
      s.scope.set('session',{'key':0,'playing':false,'notes':[60,64,67]});await tester.pump();
      expect(s['keySeen'],0);expect(s['playSeen'],0);
      s.scope.set('fifthIndex',1);await tester.pump();await tester.pump();
      expect(s['keySeen'],1);expect(s['playSeen'],0);
      s.scope.set('session',{'key':0,'playing':true,'notes':[60,64,67]});await tester.pump();
      expect(s['keySeen'],1);expect(s['playSeen'],1);
    });

    testWidgets('pointer down and up give their position within the node and on the screen', (tester) async {
      final s = await harness.show(tester, harness.counter(actions: [
        harness.reaction('pointerDown', [
          {'type':'setVariable','variable':'down','value':r'${result}'},
        ]),
        harness.reaction('pointerUp', [
          {'type':'setVariable','variable':'up','value':r'${result}'},
        ]),
      ]), variables: [harness.v('count',0,VariableType.integer),harness.v('down',{},VariableType.map),harness.v('up',{},VariableType.map)]);
      final point=s.center('button');
      final gesture=await tester.startGesture(point);
      await tester.pump();
      final down=s['down'] as Map;
      expect(down['x'],50);expect(down['y'],20);
      expect(down['globalX'],point.dx);expect(down['globalY'],point.dy);
      await gesture.up();await tester.pump();
      final up=s['up'] as Map;
      expect(up['x'],50);expect(up['y'],20);
      expect(up['globalX'],point.dx);expect(up['globalY'],point.dy);
    });

    testWidgets('a node with a click reaction is a labelled button to screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      final nodes = harness.counter(actions: [harness.reaction('click', [harness.add('count')])]);
      nodes['button'] = {...nodes['button']!, 'type': 'column', 'children': ['buttonLabel']};
      nodes['buttonLabel'] = {'type': 'text', 'layout': {'width': 100, 'height': 20}, 'props': {'text': 'Appreciate'}};
      final screen = await harness.show(tester, nodes, variables: [harness.v('count', 0, VariableType.integer)]);
      final found = <SemanticsNode>[];
      void visit(SemanticsNode node) {
        if (node.getSemanticsData().label == 'Appreciate') found.add(node);
        node.visitChildren((child) { visit(child); return true; });
      }
      visit(tester.binding.renderViews.single.owner!.semanticsOwner!.rootSemanticsNode!);
      final semantics = found.single;
      expect(semantics.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      tester.binding.renderViews.single.owner!.semanticsOwner!.performAction(semantics.id, SemanticsAction.tap);
      await tester.pump();
      expect(screen['count'], 1);
      handle.dispose();
    });

    testWidgets('a tap runs its reaction, and only the nodes reading the changed variable update', (tester) async {
      final s = await harness.show(tester, harness.counter(actions: [harness.reaction('click', [harness.add('count')])]), variables: [harness.v('count', 0, VariableType.integer)]);
      expect(harness.textOf(s.tree, 'label'), 'Count 0');
      NodeBox.debugApplyCounts.clear();
      NodeBox.debugCountApplies = true;
      addTearDown(() => NodeBox.debugCountApplies = false);
      await tester.tapAt(s.center('button'));
      await tester.pump();
      expect(s['count'], 1);
      expect(harness.textOf(s.tree, 'label'), 'Count 1');
      // The label's text is set in place (NodeBox._retextOnly): no box
      // re-applies, the label included.
      expect(NodeBox.debugApplyCounts.keys, isEmpty);
      await tester.tapAt(s.center('button'));
      await tester.tapAt(s.center('other'));
      await tester.pump();
      expect(harness.textOf(s.tree, 'label'), 'Count 2');
    });

    testWidgets('on the design canvas nothing reacts', (tester) async {
      final s = await harness.show(tester, harness.counter(actions: [harness.reaction('click', [harness.add('count')])]),
          variables: [harness.v('count', 0, VariableType.integer)], interactive: false);
      await tester.tapAt(s.center('button'));
      await tester.pump();
      expect(s['count'], 0);
    });

    testWidgets('the innermost node with a tap reaction takes the tap', (tester) async {
      final nodes = harness.counter(actions: [harness.reaction('click', [harness.add('inner')])]);
      nodes['col'] = {...nodes['col']!, 'actions': [harness.reaction('click', [harness.add('outer')])]};
      final s = await harness.show(tester, nodes, variables: [harness.v('inner', 0, VariableType.integer), harness.v('outer', 0, VariableType.integer), harness.v('count', 0, VariableType.integer)]);
      await tester.tapAt(s.center('button'));
      await tester.pump();
      expect((s['inner'], s['outer']), (1, 0));
      await tester.tapAt(s.center('other'));
      await tester.pump();
      expect((s['inner'], s['outer']), (1, 1));
    });

    testWidgets('long press, double tap and tap each run their own reaction, also on a node that has both taps', (tester) async {
      final s = await harness.show(tester, harness.counter(actions: [
        harness.reaction('click', [harness.add('count')]),
        harness.reaction('doubleTap', [harness.add('count', '10')]),
        harness.reaction('longPress', [harness.add('count', '100')]),
      ]), variables: [harness.v('count', 0, VariableType.integer)]);
      await tester.tapAt(s.center('button'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(s['count'], 1);
      await tester.tapAt(s.center('button'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(s.center('button'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(s['count'], 11);
      await tester.longPressAt(s.center('button'));
      await tester.pump();
      expect(s['count'], 111);
    });

    testWidgets('a double tap reports where it landed, and a drag its step and position', (tester) async {
      Json set(String name, String value) => {'type': 'setVariable', 'variable': name, 'value': value};
      final s = await harness.show(tester, harness.counter(actions: [
        harness.reaction('doubleTap', [set('tapX', r'${result.x}'), set('tapY', r'${result.y}')]),
        harness.reaction('drag', [set('stepX', r'${result.deltaX}'), set('atX', r'${result.x}')]),
      ]), variables: [
        harness.v('tapX', 0, VariableType.decimal), harness.v('tapY', 0, VariableType.decimal),
        harness.v('stepX', 0, VariableType.decimal), harness.v('atX', 0, VariableType.decimal),
      ]);
      final box = s.tree.boxOf('button')!;
      final topLeft = box.localToGlobal(Offset.zero);
      await tester.tapAt(topLeft + const Offset(7, 5));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(topLeft + const Offset(7, 5));
      await tester.pump(const Duration(milliseconds: 400));
      expect((s['tapX'], s['tapY']), (7.0, 5.0));
      final g = await tester.startGesture(topLeft + const Offset(4, 4));
      for (var i = 0; i < 6; i++) {
        await g.moveBy(const Offset(10, 0));
        await tester.pump();
      }
      await g.up();
      await tester.pump(const Duration(milliseconds: 500));
      expect(s['stepX'], 10.0);
      expect(s['atX'], 64.0);
    });

    testWidgets('hovering changes the cursor and runs the enter and exit reactions', (tester) async {
      final s = await harness.show(tester, harness.counter(actions: [
        harness.reaction('click', []),
        harness.reaction('cursorEnter', [harness.add('count')]),
        harness.reaction('cursorExit', [harness.add('count', '10')]),
      ]), variables: [harness.v('count', 0, VariableType.integer)]);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: const Offset(150, 300));
      await mouse.moveTo(s.center('button'));
      await tester.pump();
      expect(s['count'], 1);
      RenderReactions? reactions;
      void visit(RenderObject o) {
        if (o is RenderReactions) reactions ??= o;
        o.visitChildren(visit);
      }

      visit(s.tree.boxOf('button')!);
      expect(reactions!.cursor, SystemMouseCursors.click);
      await mouse.moveTo(const Offset(150, 300));
      await tester.pump();
      expect(s['count'], 11);
    });

    testWidgets('a swipe runs the reaction for its direction', (tester) async {
      final s = await harness.show(tester, harness.counter(actions: [
        harness.reaction('swipeLeft', [harness.add('count')]),
        harness.reaction('swipeUp', [harness.add('count', '10')]),
      ]), variables: [harness.v('count', 0, VariableType.integer)]);
      await tester.flingFrom(s.center('button'), const Offset(-80, 0), 1000);
      await tester.pumpAndSettle();
      expect(s['count'], 1);
      await tester.flingFrom(s.center('button'), const Offset(0, -60), 1000);
      await tester.pumpAndSettle();
      expect(s['count'], 11);
    });

    testWidgets('a load reaction runs once when the screen appears, and a timer ticks until the screen goes', (tester) async {
      final nodes = harness.counter();
      nodes['col'] = {
        ...nodes['col']!,
        'actions': [
          harness.reaction('load', [harness.add('count')]),
          harness.reaction('timer', [harness.add('ticks')], extra: {'intervalMs': 100}),
        ],
      };
      final s = await harness.show(tester, nodes, variables: [harness.v('count', 0, VariableType.integer), harness.v('ticks', 0, VariableType.integer)]);
      await tester.pump();
      expect(s['count'], 1);
      await tester.pump(const Duration(milliseconds: 350));
      expect(s['ticks'], 3);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 500));
      expect(s['ticks'], 3);
      expect(s['count'], 1);
    });

    testWidgets('a node that is removed stops its running reaction', (tester) async {
      final s = await harness.show(tester, harness.counter(actions: [
        harness.reaction('click', [harness.add('count'), {'type': 'delay', 'ms': 500}, harness.add('count')]),
      ]), variables: [harness.v('count', 0, VariableType.integer)]);
      await tester.tapAt(s.center('button'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(s['count'], 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(s['count'], 1);
    });

    testWidgets('a value-changed reaction runs when its variable changes', (tester) async {
      final nodes = harness.counter();
      nodes['other'] = {...nodes['other']!, 'actions': [harness.reaction('valueChanged', [harness.add('seen')], extra: {'variable': 'count'})]};
      final s = await harness.show(tester, nodes, variables: [harness.v('count', 0, VariableType.integer), harness.v('seen', 0, VariableType.integer)]);
      await tester.pump();
      expect(s['seen'], 0);
      s.scope.set('count', 5);
      await tester.pump();
      expect(s['seen'], 1);
    });

    testWidgets('a popover presentation opens by its trigger, not centered', (tester) async {
      late BuildContext appContext;
      final ui = NavigatorActionUi(
        context: () => appContext,
        modal: (to, params) => SizedBox(key: ValueKey(to), width: 120, height: 80),
      );
      final s = await harness.show(tester, harness.counter(actions: [
        harness.reaction('click', [
          {'type': 'openModal', 'to': 'menu', 'presentation': 'popover', 'anchor': 'trigger', 'placement': 'belowStart', 'anchorGap': 6},
        ]),
      ]), variables: [harness.v('count', 0, VariableType.integer)], ui: ui);
      appContext = tester.element(find.byType(NodeView));
      final box = s.tree.boxOf('button')!;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      await tester.tapAt(rect.center);
      await tester.pumpAndSettle();
      // Below the button, its start edges aligned.
      expect(tester.getTopLeft(find.byKey(const ValueKey('menu'))), Offset(rect.left, rect.bottom + 6));
    });

    testWidgets('a popover in a scaled app (an editor\'s run preview) opens right under its trigger', (tester) async {
      late BuildContext appContext;
      final ui = NavigatorActionUi(
        context: () => appContext,
        modal: (to, params) => SizedBox(key: ValueKey(to), width: 120, height: 80),
      );
      final doc = LayoutDocument.fromJson({
        'roots': ['col'],
        'nodes': harness.counter(actions: [
          harness.reaction('click', [
            {'type': 'openModal', 'to': 'menu', 'presentation': 'popover', 'anchor': 'trigger', 'placement': 'belowEnd', 'anchorGap': 6},
          ]),
        ]),
      });
      final scope = VariableScope([harness.v('count', 0, VariableType.integer)]);
      final values = NodeValues(DocumentSource(doc));
      final tree = NodeTree(values, binder: NodeBinder(scope: scope));
      final context = RuntimeActionContext(scope: scope, ui: ui, tree: tree, nodeValues: values, services: Services());
      final reactions = TreeReactions(runner: const CodelesslyActions(), context: context);
      tree.interactions = reactions;
      addTearDown(() {
        reactions.dispose();
        tree.dispose();
      });
      await tester.pumpWidget(Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 400,
          height: 300,
          child: Transform.scale(
            scale: 0.5,
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 800,
              height: 600,
              child: MaterialApp(home: Scaffold(body: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'col', interactive: true)))),
            ),
          ),
        ),
      ));
      appContext = tester.element(find.byType(NodeView));
      final box = tree.boxOf('button')!;
      final rect = MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size);
      await tester.tapAt(rect.center);
      await tester.pumpAndSettle();
      // Its end under the trigger's end, 6 (3 on screen) below it.
      final menu = tester.getRect(find.byKey(const ValueKey('menu')));
      expect(menu.right, closeTo(rect.right, 0.5));
      expect(menu.top, closeTo(rect.bottom + 3, 0.5));
    });

    testWidgets('a popover that reserves room moves up to keep it', (tester) async {
      // 844 tall, anchor bottom 603: a 112 menu fits below at 609, but 609 +
      // 360 passes 836, so its top moves to 844 - 8 - 360.
      final reserving = PopoverLayout(
          anchor: const Rect.fromLTWH(320, 575, 28, 28), placement: api.PopoverPlacement.belowEnd, gap: 6, reserve: 360);
      expect(reserving.getPositionForChild(const Size(390, 844), const Size(200, 112)).dy, 476);
      // Room for it: placed below as usual.
      final roomy = PopoverLayout(
          anchor: const Rect.fromLTWH(320, 375, 28, 28), placement: api.PopoverPlacement.belowEnd, gap: 6, reserve: 360);
      expect(roomy.getPositionForChild(const Size(390, 844), const Size(200, 112)).dy, 409);
      // Too tall for the room below: still below its anchor's side, moved up
      // to keep the reserve (overlapping the anchor), not flipped above.
      final tall = PopoverLayout(
          anchor: const Rect.fromLTWH(264, 664, 592, 34), placement: api.PopoverPlacement.belowStart, gap: 6, reserve: 400);
      expect(tall.getPositionForChild(const Size(1440, 900), const Size(320, 301)).dy, 492);
      // No reserve: below.
      final plain =
          PopoverLayout(anchor: const Rect.fromLTWH(320, 575, 28, 28), placement: api.PopoverPlacement.belowEnd, gap: 6);
      expect(plain.getPositionForChild(const Size(390, 844), const Size(200, 112)).dy, 609);
    });

    testWidgets('set-value and set-variant actions change nodes while the app runs', (tester) async {
      final nodes = harness.counter(actions: [
        harness.reaction('click', [
          {'type': 'setValue', 'node': 'other', 'values': [{'path': 'visible', 'value': false}]},
        ]),
      ]);
      final s = await harness.show(tester, nodes, variables: [harness.v('count', 0, VariableType.integer)]);
      expect(s.tree.resolve('other')!.visible, isTrue);
      await tester.tapAt(s.center('button'));
      await tester.pump();
      expect(s.tree.resolve('other')!.visible, isFalse);
    });

    testWidgets('each item of a bound list taps with its own data', (tester) async {
      final s = await harness.show(
        tester,
        {
          'list': {
            'type': 'listView',
            'children': ['row'],
            'layout': {'width': 200, 'height': {'hug': 90}},
            'props': {'itemCount': 1},
            'bind': {'data': r'${rows}'},
          },
          'row': {
            'type': 'box',
            'layout': {'width': 200, 'height': 30},
            'decoration': {'fills': [{'color': '#FF00FF00'}]},
            'actions': [harness.reaction('click', [{'type': 'setVariable', 'variable': 'picked', 'value': r'${item}:${index}'}])],
          },
        },
        root: 'list',
        variables: [harness.v('rows', const ['a', 'b', 'c'], VariableType.list), harness.v('picked', '')],
      );
      final list = s.tree.boxOf('list')!;
      final top = list.localToGlobal(Offset.zero);
      await tester.tapAt(top + const Offset(100, 15));
      await tester.pump();
      expect(s['picked'], 'a:0');
      await tester.tapAt(top + const Offset(100, 75));
      await tester.pump();
      expect(s['picked'], 'c:2');
    });

    for (final width in [<String, Object>{'hug': 0}, 320])
    testWidgets('a segmented track selects by tap, raises the selection and hugs or shares its width ($width)',
        (tester) async {
      final s = await harness.show(
        tester,
        {
          'col': {'type': 'column', 'children': ['seg'], 'layout': {'width': 400, 'height': {'hug': 40}}},
          'seg': {
            'type': 'segmentedButton',
            'layout': {'width': width, 'height': {'hug': 0}},
            'props': {
              'variant': 'track',
              'segments': [
                for (final x in ['All', 'Live', 'Draft', 'Closed']) {'value': x.toLowerCase(), 'label': x},
              ],
              'selectedBackgroundColor': '#FFFFFFFF',
              'backgroundColor': '#FFE2E7EE',
              'selectedShadows': [
                {'type': 'dropShadow', 'color': '#14000000', 'offset': [0, 2], 'blurRadius': 8},
              ],
            },
            'bind': {'props.selected': r'${= [filter]}'},
            'actions': [
              harness.reaction('changed', [
                {'type': 'setVariable', 'variable': 'filter', 'value': r'${result[0]}'},
              ]),
            ],
          },
        },
        variables: [harness.v('filter', 'all')],
      );
      final seg = controlIn<RenderSegmentedButton>(s.tree, 'seg');
      // Hugging, every label fits on one line; a narrower share ellipsizes.
      expect(seg.labels.map((l) => l.text), ['All', 'Live', 'Draft', 'Closed']);
      if (width is! int) {
        for (var i = 0; i < 4; i++) {
          expect(seg.labelFits(i), isTrue);
        }
      }
      final widths = [for (final i in [0, 3]) seg.segmentRects[i].width];
      if (width is int) {
        // A filling track shares its width: 320 less the 3px inset each side, by 4.
        expect(widths, everyElement(closeTo((320 - 6) / 4, 0.5)));
      } else {
        expect(widths[0], lessThan(widths[1]));
      }
      expect(seg.selectedShadows, hasLength(1));
      expect(seg.raised, ['all']);
      final draft = seg.segmentRects[2].center;
      await tester.tapAt(seg.localToGlobal(draft));
      await tester.pumpAndSettle();
      expect(s['filter'], 'draft');
      expect(seg.raised, ['draft']);
    });

    testWidgets('a focus action reaches the field in the same list item, even one the same tap reveals', (tester) async {
      final s = await harness.show(
        tester,
        {
          'lanes': {
            'type': 'listView',
            'children': ['lane'],
            'layout': {'width': 400, 'height': 200},
            'props': {'scrollDirection': 'horizontal'},
            'bind': {'data': r'${lanes}'},
          },
          'lane': {
            'type': 'column',
            'children': ['add', 'field'],
            'layout': {'width': 200, 'height': 200},
          },
          'add': {
            'type': 'box',
            'layout': {'width': 200, 'height': 40},
            'decoration': {'fills': [{'color': '#FF2196F3'}]},
            'actions': [
              harness.reaction('click', [
                {'type': 'setVariable', 'variable': 'adding', 'value': r'${item}'},
                {'type': 'focus', 'node': 'field'},
              ]),
            ],
          },
          'field': {
            'type': 'textField',
            'layout': {'width': 200, 'height': 48},
            'visible': true,
            'bind': {'visible': r'${= adding == item}'},
          },
        },
        root: 'lanes',
        variables: [harness.v('lanes', const ['todo', 'doing'], VariableType.list), harness.v('adding', '')],
      );
      await tester.pumpAndSettle();
      // The second column's button.
      final adds = s.tree.boxesOf('add').toList()..sort((a, b) => a.localToGlobal(Offset.zero).dx.compareTo(b.localToGlobal(Offset.zero).dx));
      final second = adds.last;
      await tester.tapAt(second.localToGlobal(second.size.center(Offset.zero)));
      await tester.pumpAndSettle();
      expect(s['adding'], 'doing');
      // The second column's field has the focus, the first column's doesn't.
      expect(TextFieldHandle.near(s.tree, 'field', second.instance)!.focusNode.hasFocus, isTrue);
      expect(tester.testTextInput.hasAnyClients, isTrue, reason: 'the keyboard is the field\'s');
      expect(TextFieldHandle.near(s.tree, 'field', adds.first.instance), isNull,
          reason: 'the first column\'s field is hidden, so not built');
    });

    testWidgets('typing reports a change and writes the bound variable', (tester) async {
      final s = await harness.show(
        tester,
        {
          'col': {'type': 'column', 'children': ['field', 'label'], 'layout': {'width': 300, 'height': {'hug': 80}}},
          'field': {
            'type': 'textField',
            'layout': {'width': 300, 'height': 48},
            'bind': {'props.initialValue': r'${name}'},
            'actions': [
              harness.reaction('changed', [
                {'type': 'setVariable', 'variable': 'echo', 'value': r'${result}!'},
                // The new text's other name, `value`.
                {'type': 'setVariable', 'variable': 'query', 'value': r'${value}'},
              ]),
              harness.reaction('submitted', [harness.add('sent')]),
            ],
          },
          'label': {'type': 'text', 'layout': {'width': 300, 'height': 20}, 'props': {'text': r'Hi ${name}'}},
        },
        variables: [harness.v('name', ''), harness.v('echo', ''), harness.v('query', ''), harness.v('sent', 0, VariableType.integer)],
      );
      await typeInto(tester, 'Ada');
      await tester.pump();
      expect((s['name'], s['echo']), ('Ada', 'Ada!'));
      expect(s['query'], 'Ada');
      expect(harness.textOf(s.tree, 'label'), 'Hi Ada');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(s['sent'], 1);
    });

    testWidgets('a checkbox and a button report their own events', (tester) async {
      final s = await harness.show(
        tester,
        {
          'col': {'type': 'column', 'children': ['check', 'button'], 'layout': {'width': 200, 'height': {'hug': 100}}},
          'check': {
            'type': 'checkbox',
            'layout': {'width': 40, 'height': 40},
            'props': {'value': false},
            'bind': {'props.value': r'${on}'},
          },
          'button': {
            'type': 'elevatedButton',
            'layout': {'width': 120, 'height': 40},
            'props': {'label': 'Go'},
            'actions': [harness.reaction('click', [harness.add('count')])],
          },
        },
        variables: [harness.v('on', false, VariableType.boolean), harness.v('count', 0, VariableType.integer)],
      );
      await tester.tapAt(s.center('check'));
      await tester.pump();
      expect(s['on'], true);
      await tester.tapAt(s.center('button'));
      await tester.pump();
      expect(s['count'], 1);
    });

    testWidgets('a node entering and leaving the view runs its enter and exit reactions', (tester) async {
      final s = await harness.show(
        tester,
        {
          'col': {
            'type': 'stack',
            'children': ['target'],
            'layout': {'width': 200, 'height': 400},
          },
          'target': {
            'type': 'box',
            'layout': {'width': 200, 'height': 100, 'x': {'start': 0}, 'y': {'start': 0}},
            'bind': {'layout.y': r'${gap}'},
            'actions': [
              harness.reaction('enterViewport', [harness.add('shown')]),
              harness.reaction('exitViewport', [harness.add('hidden')]),
            ],
          },
        },
        variables: [harness.v('shown', 0, VariableType.integer), harness.v('hidden', 0, VariableType.integer), harness.v('gap', 900, VariableType.integer)],
      );
      await tester.pump();
      await tester.pump();
      expect((s['shown'], s['hidden']), (0, 0));
      s.scope.set('gap', 0);
      await tester.pump();
      await tester.pump();
      expect((s['shown'], s['hidden']), (1, 0));
      s.scope.set('gap', 900);
      await tester.pump();
      await tester.pump();
      expect((s['shown'], s['hidden']), (1, 1));
    });
  }

  group('sound', () {
    testWidgets('a play-sound action plays a note by its MIDI number and releases it after its duration', (tester) async {
      final engine = SilentSoundEngine();
      final s = await harness.show(tester, harness.counter(actions: [
        harness.reaction('pointerDown', [
          {'type': 'playSound', 'operation': 'start', 'voiceId': 'k60', 'note': r'${midi}', 'waveform': 'felt'},
          {'type': 'playSound', 'operation': 'start', 'voiceId': 'tick', 'frequency': '1760', 'duration': '50'},
        ]),
        harness.reaction('pointerUp', [
          {'type': 'playSound', 'operation': 'stop', 'voiceId': 'k60'},
        ]),
      ]), services: Services(sound: SoundService(engine: engine)), variables: [
        harness.v('count', 0, VariableType.integer), harness.v('midi', 60, VariableType.integer),
      ]);
      final g = await tester.startGesture(s.center('button'));
      await tester.pump();
      expect(engine.notes['k60']!.$1, closeTo(261.63, 0.01));
      expect(engine.waveforms['k60'], 'felt');
      expect(engine.notes.containsKey('tick'), isTrue);
      await tester.pump(const Duration(milliseconds: 60));
      expect(engine.notes.containsKey('tick'), isFalse, reason: 'released after its duration');
      expect(engine.notes.containsKey('k60'), isTrue, reason: 'no duration: held until stop');
      await g.up();
      await tester.pump();
      expect(engine.notes, isEmpty);
      expect(midiToHz(69), 440);
    });
  });
}
