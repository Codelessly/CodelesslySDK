import 'dart:async';
// Triggers in the render tree: nodes tapped (pressed, hovered, swiped...)
// in a NodeView(interactive: true) run their reactions; a variable they set
// re-applies only the boxes that read it.
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:codelessly_sdk/src/runtime/actions/text_fields.dart' show TextFieldHandle;
import 'package:flutter_test/flutter_test.dart';

import 'runner_test.dart' show RecordingUi;

Variable v(String name, Object? value, [VariableType type = VariableType.text]) =>
    Variable(name: name, type: type, value: type.coerce(value));

Json reaction(String trigger, List<Json> actions, {Json extra = const {}}) => {
      'trigger': {'type': trigger, ...extra},
      'actions': actions,
    };

Json add(String name, [String by = '1']) => {'type': 'setVariable', 'variable': name, 'op': 'add', 'value': by};

class Screen {
  Screen(this.tree, this.scope, this.context, this.reactions);
  final NodeTree tree;
  final VariableScope scope;
  final RuntimeActionContext context;
  final TreeReactions reactions;

  Object? operator [](String name) => scope.read(name);

  Offset center(String id) {
    final box = tree.boxOf(id)!;
    final content = box.contentBox ?? box;
    return content.localToGlobal(content.size.center(Offset.zero));
  }
}

Future<Screen> show(
  WidgetTester tester,
  Map<String, Json> nodes, {
  List<Variable> variables = const [],
  String root = 'col',
  ActionUi ui = const NoActionUi(),
  bool interactive = true,
  Services? services,
}) async {
  final doc = LayoutDocument.fromJson({'roots': [root], 'nodes': nodes});
  final scope = VariableScope(variables);
  final values = NodeValues(DocumentSource(doc));
  final tree = NodeTree(values, binder: NodeBinder(scope: scope));
  final context = RuntimeActionContext(scope: scope, ui: ui, tree: tree, nodeValues: values, services: services ?? Services());
  final reactions = TreeReactions(runner: const CodelesslyActions(), context: context);
  tree.interactions = reactions;
  addTearDown(() {
    reactions.dispose();
    tree.dispose();
  });
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: root, interactive: interactive))),
  ));
  return Screen(tree, scope, context, reactions);
}

/// A column with a counter text and a 100×40 button box.
Map<String, Json> counter({List<Json> actions = const [], Json? extraNodes}) => {
      'col': {
        'type': 'column',
        'children': ['label', 'button', 'other'],
        'layout': {'width': 200, 'height': {'hug': 120}},
      },
      'label': {
        'type': 'text',
        'layout': {'width': 200, 'height': 20},
        'props': {'text': r'Count ${count}'},
      },
      'button': {
        'type': 'box',
        'layout': {'width': 100, 'height': 40},
        'decoration': {'fills': [{'color': '#FF2196F3'}]},
        'actions': actions,
      },
      'other': {
        'type': 'box',
        'layout': {'width': 100, 'height': 40},
        'decoration': {'fills': [{'color': '#FF000000'}]},
      },
      ...?extraNodes?.cast<String, Json>(),
    };

String textOf(NodeTree tree, String id) {
  RenderParagraph? found;
  void visit(RenderObject o) {
    if (o is RenderParagraph) found ??= o;
    o.visitChildren(visit);
  }

  visit(tree.boxOf(id)!);
  return found!.text.toPlainText();
}

void main() {
  testWidgets('a button with press feedback (a pressed state) still clicks', (tester) async {
    final nodes = counter(actions: [reaction('click', [add('count')])]);
    nodes['button'] = {
      ...nodes['button']!,
      'states': {
        'pressed': {'button': {'scale': 0.97, 'opacity': 0.82}},
        'hovered': {'button': {'scale': 1.012}},
      },
      'transitions': {'style': {'duration': 180, 'curve': 'easeOut'}},
    };
    final s = await show(tester, nodes, variables: [v('count', 0, VariableType.integer)]);
    await tester.tapAt(s.center('button'));
    await tester.pumpAndSettle();
    expect(s['count'], 1, reason: 'the pressed state re-applies the box mid-tap; the tap must survive');
    await tester.tapAt(s.center('button'));
    await tester.pumpAndSettle();
    expect(s['count'], 2);
  });

  for (final expression in ['period', r'${period}']) {
    testWidgets('clock interval reads $expression and clamps tiny periods', (tester) async {
      final s=await show(tester,counter(actions:[reaction('clock',[add('count')],extra:{'every':expression})]),variables:[v('count',0,VariableType.integer),v('period',80,VariableType.decimal)]);
      await tester.pump(const Duration(milliseconds:160));expect(s['count'],2);
      s.scope.set('period',.1);await tester.pump(const Duration(milliseconds:api.Trigger.minIntervalMs * 5));expect(s['count'],7);
      s.scope.set('period',-1);await tester.pump(const Duration(milliseconds:50));expect(s['count'],7);
    });
  }
  testWidgets('clock interval formulas reschedule on variable changes and stop when detached', (tester) async {
    final s=await show(tester,counter(actions:[reaction('clock',[add('count')],extra:{'every':r'${= 1000 / speed}'})]),variables:[v('count',0,VariableType.integer),v('speed',10,VariableType.integer)]);
    await tester.pump(const Duration(milliseconds:250));expect(s['count'],2);
    s.scope.set('speed',20);await tester.pump(const Duration(milliseconds:150));expect(s['count'],5);
    s.scope.set('speed',0);await tester.pump(const Duration(seconds:1));expect(s['count'],5);
    s.scope.set('speed',5);await tester.pump(const Duration(milliseconds:400));expect(s['count'],7);
    await tester.pumpWidget(const SizedBox());s.scope.set('speed',10);
    await tester.pump(const Duration(seconds:1));expect(s['count'],7);
  });


  testWidgets('an offstage route does not run a second transport clock', (tester) async {
    final nodes=counter();nodes['other']={...nodes['other']!,'actions':[reaction('clock',[add('ticks')],extra:{'every':'100'})]};
    final s=await show(tester,nodes,variables:[v('count',0,VariableType.integer),v('ticks',0,VariableType.integer)]);
    await tester.pump(const Duration(milliseconds:100));expect(s['ticks'],1);
    final nav=Navigator.of(tester.element(find.byType(Scaffold)));
    unawaited(nav.push(MaterialPageRoute<void>(builder:(_)=>const Scaffold(body:Text('next')))));
    await tester.pumpAndSettle();final before=s['ticks'];
    await tester.pump(const Duration(milliseconds:400));expect(s['ticks'],before);
    nav.pop();await tester.pumpAndSettle();final resumed=s['ticks'] as int;
    await tester.pump(const Duration(milliseconds:100));expect(s['ticks'],resumed+1);
  });

  testWidgets('clock evaluates interval and starts/stops with its runWhen variable', (tester) async {
    final nodes=counter();nodes['other']={...nodes['other']!, 'actions':[reaction('clock',[add('ticks')],extra:{'every':r'${period}','runWhen':r'${playing}'})]};
    final s=await show(tester,nodes,variables:[v('count',0,VariableType.integer),v('ticks',0,VariableType.integer),v('period',100,VariableType.integer),v('playing',false,VariableType.boolean)]);
    await tester.pump(const Duration(milliseconds:350));expect(s['ticks'],0);
    s.scope.set('playing',true);await tester.pump(const Duration(milliseconds:100));expect(s['ticks'],1);
    s.scope.set('period',50);await tester.pump(const Duration(milliseconds:100));expect(s['ticks'],3);
    s.scope.set('playing',false);await tester.pump(const Duration(milliseconds:300));expect(s['ticks'],3);
  });

  testWidgets('valueChanged is scoped to its path and ignores sibling writes', (tester) async {
    final nodes=counter();
    nodes['other']={...nodes['other']!, 'actions':[
      reaction('valueChanged',[add('keySeen'), {'type':'setVariable','variable':'session.key','value':'0'}],extra:{'variable':'fifthIndex'}),
      reaction('valueChanged',[add('playSeen')],extra:{'variable':'session.playing'}),
    ]};
    final s=await show(tester,nodes,variables:[v('count',0,VariableType.integer),v('fifthIndex',0,VariableType.integer),v('session',{'key':0,'playing':false,'notes':[]},VariableType.map),v('keySeen',0,VariableType.integer),v('playSeen',0,VariableType.integer)]);
    s.scope.set('session',{'key':0,'playing':false,'notes':[60,64,67]});await tester.pump();
    expect(s['keySeen'],0);expect(s['playSeen'],0);
    s.scope.set('fifthIndex',1);await tester.pump();await tester.pump();
    expect(s['keySeen'],1);expect(s['playSeen'],0);
    s.scope.set('session',{'key':0,'playing':true,'notes':[60,64,67]});await tester.pump();
    expect(s['keySeen'],1);expect(s['playSeen'],1);
  });

  testWidgets('two pointers sustain the same pitch independently and cancel releases', (tester) async {
    final engine = SilentSoundEngine();
    final s = await show(tester, counter(actions: [
      reaction('pointerDown', [
        {'type': 'playSound', 'operation': 'start', 'voiceId': r'${result.pointer}', 'frequency': '261.6'},
        {'type': 'setVariable', 'variable': 'pointer', 'value': r'${result.pointer}'},
      ]),
      reaction('pointerUp', [
        {'type': 'playSound', 'operation': 'stop', 'voiceId': r'${result.pointer}'},
        {'type': 'setVariable', 'variable': 'cancelled', 'value': r'${result.cancelled}'},
      ]),
    ]), services: Services(sound: SoundService(engine: engine)), variables: [
      v('count', 0, VariableType.integer), v('pointer', 0, VariableType.integer), v('cancelled', false, VariableType.boolean),
    ]);
    final first = await tester.startGesture(s.center('button'), pointer: 41);
    final second = await tester.startGesture(s.center('button'), pointer: 42);
    await tester.pump();
    expect(s['pointer'], 42);
    expect(engine.notes.keys.toSet(), {'41', '42'});
    await first.up();
    await tester.pump();
    expect(engine.notes.keys, ['42']);
    expect(s['cancelled'], isFalse);
    await second.cancel();
    await tester.pump();
    expect(engine.notes, isEmpty);
    expect(s['cancelled'], isTrue);
  });

  testWidgets('a key plays an instrument voice by MIDI note; a duration releases it', (tester) async {
    final engine = SilentSoundEngine();
    final s = await show(tester, counter(actions: [
      reaction('pointerDown', [
        {'type': 'playSound', 'operation': 'start', 'voiceId': 'k60', 'note': r'${midi}', 'waveform': 'felt'},
        {'type': 'playSound', 'operation': 'start', 'voiceId': 'tick', 'frequency': '1760', 'duration': '50'},
      ]),
      reaction('pointerUp', [
        {'type': 'playSound', 'operation': 'stop', 'voiceId': 'k60'},
      ]),
    ]), services: Services(sound: SoundService(engine: engine)), variables: [
      v('count', 0, VariableType.integer), v('midi', 60, VariableType.integer),
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

  testWidgets('a restarted voice is not released by an earlier start\'s duration', (tester) async {
    final engine = SilentSoundEngine();
    final s = await show(tester, counter(actions: [
      reaction('click', [
        {'type': 'playSound', 'operation': 'start', 'voiceId': 'g0', 'note': r'${= 60 + count}', 'waveform': 'pluck', 'duration': r'${= count == 0 ? 100 : 400}'},
        add('count'),
      ]),
    ]), services: Services(sound: SoundService(engine: engine)), variables: [v('count', 0, VariableType.integer)]);
    await tester.tapAt(s.center('button'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(s.center('button'));
    await tester.pump(const Duration(milliseconds: 80));
    expect(engine.waveforms['g0'], 'pluck', reason: 'the second start outlives the first one\'s 100 ms');
    await tester.pump(const Duration(milliseconds: 400));
    expect(engine.notes, isEmpty);
  });

  testWidgets('pointer down and up expose local and global coordinates', (tester) async {
    final s = await show(tester, counter(actions: [
      reaction('pointerDown', [
        {'type':'setVariable','variable':'down','value':r'${result}'},
      ]),
      reaction('pointerUp', [
        {'type':'setVariable','variable':'up','value':r'${result}'},
      ]),
    ]), variables: [v('count',0,VariableType.integer),v('down',{},VariableType.map),v('up',{},VariableType.map)]);
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

  testWidgets('custom action nodes expose a labeled accessible button', (tester) async {
    final handle = tester.ensureSemantics();
    final nodes = counter(actions: [reaction('click', [add('count')])]);
    nodes['button'] = {...nodes['button']!, 'type': 'column', 'children': ['buttonLabel']};
    nodes['buttonLabel'] = {'type': 'text', 'layout': {'width': 100, 'height': 20}, 'props': {'text': 'Appreciate'}};
    final screen = await show(tester, nodes, variables: [v('count', 0, VariableType.integer)]);
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

  testWidgets('a tap sets a variable; only the boxes reading it re-apply', (tester) async {
    final s = await show(tester, counter(actions: [reaction('click', [add('count')])]), variables: [v('count', 0, VariableType.integer)]);
    expect(textOf(s.tree, 'label'), 'Count 0');
    NodeBox.debugApplyCounts.clear();
    NodeBox.debugCountApplies = true;
    addTearDown(() => NodeBox.debugCountApplies = false);
    await tester.tapAt(s.center('button'));
    await tester.pump();
    expect(s['count'], 1);
    expect(textOf(s.tree, 'label'), 'Count 1');
    // The label's text is set in place (NodeBox._retextOnly): no box
    // re-applies, the label included.
    expect(NodeBox.debugApplyCounts.keys, isEmpty);
    await tester.tapAt(s.center('button'));
    await tester.tapAt(s.center('other'));
    await tester.pump();
    expect(textOf(s.tree, 'label'), 'Count 2');
  });

  testWidgets('a design canvas (not interactive) does not react', (tester) async {
    final s = await show(tester, counter(actions: [reaction('click', [add('count')])]),
        variables: [v('count', 0, VariableType.integer)], interactive: false);
    await tester.tapAt(s.center('button'));
    await tester.pump();
    expect(s['count'], 0);
  });

  testWidgets('the deepest node with a tap wins', (tester) async {
    final nodes = counter(actions: [reaction('click', [add('inner')])]);
    nodes['col'] = {...nodes['col']!, 'actions': [reaction('click', [add('outer')])]};
    final s = await show(tester, nodes, variables: [v('inner', 0, VariableType.integer), v('outer', 0, VariableType.integer), v('count', 0, VariableType.integer)]);
    await tester.tapAt(s.center('button'));
    await tester.pump();
    expect((s['inner'], s['outer']), (1, 0));
    await tester.tapAt(s.center('other'));
    await tester.pump();
    expect((s['inner'], s['outer']), (1, 1));
  });

  testWidgets('long press, double tap and the tap of a node that has both', (tester) async {
    final s = await show(tester, counter(actions: [
      reaction('click', [add('count')]),
      reaction('doubleTap', [add('count', '10')]),
      reaction('longPress', [add('count', '100')]),
    ]), variables: [v('count', 0, VariableType.integer)]);
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

  testWidgets('a double tap reports where it landed; a drag its step and position', (tester) async {
    Json set(String name, String value) => {'type': 'setVariable', 'variable': name, 'value': value};
    final s = await show(tester, counter(actions: [
      reaction('doubleTap', [set('tapX', r'${result.x}'), set('tapY', r'${result.y}')]),
      reaction('drag', [set('stepX', r'${result.deltaX}'), set('atX', r'${result.x}')]),
    ]), variables: [
      v('tapX', 0, VariableType.decimal), v('tapY', 0, VariableType.decimal),
      v('stepX', 0, VariableType.decimal), v('atX', 0, VariableType.decimal),
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

  testWidgets('hover: the cursor, and enter and exit', (tester) async {
    final s = await show(tester, counter(actions: [
      reaction('click', []),
      reaction('cursorEnter', [add('count')]),
      reaction('cursorExit', [add('count', '10')]),
    ]), variables: [v('count', 0, VariableType.integer)]);
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

  testWidgets('swipes', (tester) async {
    final s = await show(tester, counter(actions: [
      reaction('swipeLeft', [add('count')]),
      reaction('swipeUp', [add('count', '10')]),
    ]), variables: [v('count', 0, VariableType.integer)]);
    await tester.flingFrom(s.center('button'), const Offset(-80, 0), 1000);
    await tester.pumpAndSettle();
    expect(s['count'], 1);
    await tester.flingFrom(s.center('button'), const Offset(0, -60), 1000);
    await tester.pumpAndSettle();
    expect(s['count'], 11);
  });

  testWidgets('load runs when a screen appears, once; a timer ticks until it goes', (tester) async {
    final nodes = counter();
    nodes['col'] = {
      ...nodes['col']!,
      'actions': [
        reaction('load', [add('count')]),
        reaction('timer', [add('ticks')], extra: {'intervalMs': 100}),
      ],
    };
    final s = await show(tester, nodes, variables: [v('count', 0, VariableType.integer), v('ticks', 0, VariableType.integer)]);
    await tester.pump();
    expect(s['count'], 1);
    await tester.pump(const Duration(milliseconds: 350));
    expect(s['ticks'], 3);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 500));
    expect(s['ticks'], 3);
    expect(s['count'], 1);
  });

  testWidgets('a node leaving the tree cancels its chain', (tester) async {
    final s = await show(tester, counter(actions: [
      reaction('click', [add('count'), {'type': 'delay', 'ms': 500}, add('count')]),
    ]), variables: [v('count', 0, VariableType.integer)]);
    await tester.tapAt(s.center('button'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(s['count'], 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(s['count'], 1);
  });

  testWidgets('value changed runs when its variable changes', (tester) async {
    final nodes = counter();
    nodes['other'] = {...nodes['other']!, 'actions': [reaction('valueChanged', [add('seen')], extra: {'variable': 'count'})]};
    final s = await show(tester, nodes, variables: [v('count', 0, VariableType.integer), v('seen', 0, VariableType.integer)]);
    await tester.pump();
    expect(s['seen'], 0);
    s.scope.set('count', 5);
    await tester.pump();
    expect(s['seen'], 1);
  });

  testWidgets('navigation and modals go through the UI', (tester) async {
    final ui = RecordingUi();
    final s = await show(tester, counter(actions: [
      reaction('click', [
        {'type': 'navigate', 'mode': 'push', 'to': 'details', 'params': {'n': r'${count}'}},
        {'type': 'openModal', 'to': 'sheet', 'presentation': 'bottomSheet'},
      ]),
    ]), variables: [v('count', 3, VariableType.integer)], ui: ui);
    await tester.tapAt(s.center('button'));
    await tester.pump();
    expect(ui.log, ['navigate push details {n: 3}', 'modal sheet bottomSheet']);
  });

  testWidgets('a popover opens by the node that opened it, above it, and answers its result', (tester) async {
    late BuildContext appContext;
    late NavigatorActionUi ui;
    ui = NavigatorActionUi(
      context: () => appContext,
      modal: (to, params) => SizedBox(key: ValueKey(to), width: 120, height: 40),
    );
    final s = await show(tester, counter(actions: [
      reaction('click', [
        {'type': 'openModal', 'to': 'picker', 'presentation': 'popover', 'anchor': 'trigger', 'placement': 'aboveStart', 'anchorGap': 8},
        {'type': 'setVariable', 'variable': 'count', 'value': r'${result.n}'},
      ]),
    ]), variables: [v('count', 0, VariableType.integer)], ui: ui);
    appContext = tester.element(find.byType(NodeView));
    final box = s.tree.boxOf('button')!;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    await tester.tapAt(rect.center);
    await tester.pumpAndSettle();
    // By the button, left edges aligned, 8 px off: no room above it at
    // the top of the screen, so below.
    expect(tester.getTopLeft(find.byKey(const ValueKey('picker'))), Offset(rect.left, rect.bottom + 8));
    Navigator.of(tester.element(find.byKey(const ValueKey('picker')))).pop({'n': 7});
    await tester.pumpAndSettle();
    expect(s['count'], 7);
  });

  testWidgets('a modal anchored to its trigger or the pointer opens by it', (tester) async {
    late BuildContext appContext;
    final ui = NavigatorActionUi(
      context: () => appContext,
      modal: (to, params) => SizedBox(key: ValueKey(to), width: 120, height: 80),
    );
    final s = await show(tester, counter(actions: [
      reaction('click', [
        {'type': 'openModal', 'to': 'menu', 'anchor': 'trigger', 'placement': 'rightStart', 'anchorGap': 6},
      ]),
      reaction('secondaryClick', [
        {'type': 'openModal', 'to': 'pointerMenu', 'anchor': 'pointer'},
      ]),
    ]), variables: [v('count', 0, VariableType.integer)], ui: ui);
    appContext = tester.element(find.byType(NodeView));
    final box = s.tree.boxOf('button')!;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    await tester.tapAt(rect.center);
    await tester.pumpAndSettle();
    // Right of the button, its top edges aligned.
    expect(tester.getTopLeft(find.byKey(const ValueKey('menu'))), Offset(rect.right + 6, rect.top));
    Navigator.of(appContext).pop();
    await tester.pumpAndSettle();

    // At the pointer: below it, starting at it.
    final at = rect.center + const Offset(10, 5);
    await tester.tapAt(at, buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(const ValueKey('pointerMenu'))), Offset(at.dx, at.dy + 4));
  });

  testWidgets('a popover presentation opens by its trigger, not centered', (tester) async {
    late BuildContext appContext;
    final ui = NavigatorActionUi(
      context: () => appContext,
      modal: (to, params) => SizedBox(key: ValueKey(to), width: 120, height: 80),
    );
    final s = await show(tester, counter(actions: [
      reaction('click', [
        {'type': 'openModal', 'to': 'menu', 'presentation': 'popover', 'anchor': 'trigger', 'placement': 'belowStart', 'anchorGap': 6},
      ]),
    ]), variables: [v('count', 0, VariableType.integer)], ui: ui);
    appContext = tester.element(find.byType(NodeView));
    final box = s.tree.boxOf('button')!;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    await tester.tapAt(rect.center);
    await tester.pumpAndSettle();
    // Below the button, its start edges aligned.
    expect(tester.getTopLeft(find.byKey(const ValueKey('menu'))), Offset(rect.left, rect.bottom + 6));
  });

  testWidgets('a modal shown as a bottom sheet is as wide as the sheet; a dialog keeps its design width', (tester) async {
    late BuildContext appContext;
    final ui = NavigatorActionUi(
      context: () => appContext,
      modal: (to, params) => SizedBox(key: ValueKey('dialog $to'), width: 120, height: 80),
      sheetModal: (to, params) => SizedBox(key: ValueKey('sheet $to'), width: double.infinity, height: 80),
    );
    final s = await show(tester, counter(actions: [
      reaction('click', [
        {'type': 'openModal', 'to': 'newCard', 'presentation': 'bottomSheet', 'insets': [24, 24, 24, 24]},
      ]),
      reaction('secondaryClick', [
        {'type': 'openModal', 'to': 'newCard'},
      ]),
    ]), variables: [v('count', 0, VariableType.integer)], ui: ui);
    appContext = tester.element(find.byType(NodeView));
    await tester.tapAt(s.center('button'));
    await tester.pumpAndSettle();
    // The sheet's own width (Material 3 caps it at 640; a phone is narrower).
    expect(tester.getSize(find.byKey(const ValueKey('sheet newCard'))).width, 640);
    // A dialog's insets don't push a sheet off the screen's edge.
    expect(tester.getBottomLeft(find.byKey(const ValueKey('sheet newCard'))).dy, 600);
    // No tinted Material surface behind the screen's own.
    expect(tester.widget<BottomSheet>(find.byType(BottomSheet)).backgroundColor, Colors.transparent);
    Navigator.of(appContext).pop();
    await tester.pumpAndSettle();
    await tester.tapAt(s.center('button'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(const ValueKey('dialog newCard'))).width, 120);
  });

  testWidgets('a popover in a scaled app (an editor\'s run preview) opens right under its trigger', (tester) async {
    late BuildContext appContext;
    final ui = NavigatorActionUi(
      context: () => appContext,
      modal: (to, params) => SizedBox(key: ValueKey(to), width: 120, height: 80),
    );
    final doc = LayoutDocument.fromJson({
      'roots': ['col'],
      'nodes': counter(actions: [
        reaction('click', [
          {'type': 'openModal', 'to': 'menu', 'presentation': 'popover', 'anchor': 'trigger', 'placement': 'belowEnd', 'anchorGap': 6},
        ]),
      ]),
    });
    final scope = VariableScope([v('count', 0, VariableType.integer)]);
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

  testWidgets('a popover flips above when there is no room below and stays on screen', (tester) async {
    final layout = PopoverLayout(anchor: const Rect.fromLTWH(700, 560, 80, 30), placement: api.PopoverPlacement.belowStart);
    // 600 tall: 200 doesn't fit below 594, so above; 800 wide keeps it in.
    expect(layout.getPositionForChild(const Size(800, 600), const Size(232, 200)), const Offset(560, 356));
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
    // No reserve: below.
    final plain =
        PopoverLayout(anchor: const Rect.fromLTWH(320, 575, 28, 28), placement: api.PopoverPlacement.belowEnd, gap: 6);
    expect(plain.getPositionForChild(const Size(390, 844), const Size(200, 112)).dy, 609);
  });

  testWidgets('set value and set variant change nodes at runtime', (tester) async {
    final nodes = counter(actions: [
      reaction('click', [
        {'type': 'setValue', 'node': 'other', 'values': [{'path': 'visible', 'value': false}]},
      ]),
    ]);
    final s = await show(tester, nodes, variables: [v('count', 0, VariableType.integer)]);
    expect(s.tree.resolve('other')!.visible, isTrue);
    await tester.tapAt(s.center('button'));
    await tester.pump();
    expect(s.tree.resolve('other')!.visible, isFalse);
  });

  testWidgets('each item of a data-bound list taps with its own item', (tester) async {
    final s = await show(
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
          'actions': [reaction('click', [{'type': 'setVariable', 'variable': 'picked', 'value': r'${item}:${index}'}])],
        },
      },
      root: 'list',
      variables: [v('rows', const ['a', 'b', 'c'], VariableType.list), v('picked', '')],
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

  testWidgets('a running page view swipes, follows its bound page and reports the page shown', (tester) async {
    final s = await show(
      tester,
      {
        'pages': {
          'type': 'pageView',
          'children': ['page'],
          'layout': {'width': 300, 'height': 200},
          'props': {'scrollDirection': 'horizontal'},
          'bind': {'data': r'${lanes}', 'props.initialPage': r'${lanePage}'},
          'actions': [reaction('changed', [{'type': 'setVariable', 'variable': 'lanePage', 'value': r'${value}'}])],
        },
        'page': {
          'type': 'text',
          'layout': {'width': 300, 'height': 200},
          'props': {'text': r'Lane ${item}'},
        },
      },
      root: 'pages',
      variables: [v('lanes', const ['todo', 'doing', 'done'], VariableType.list), v('lanePage', 0, VariableType.integer)],
    );
    // The texts of the pages on screen.
    List<String> shown() {
      final view = s.tree.boxOf('pages')!;
      final area = view.localToGlobal(Offset.zero) & view.size;
      final out = <String>[];
      void visit(RenderObject o) {
        if (o is RenderParagraph && o.hasSize && area.overlaps(o.localToGlobal(Offset.zero) & o.size)) {
          out.add(o.text.toPlainText());
        }
        o.visitChildren(visit);
      }

      visit(view);
      return out;
    }

    await tester.pumpAndSettle();
    expect(shown(), ['Lane todo']);
    // The app moves the page (a tab, a link).
    s.scope.set('lanePage', 2);
    await tester.pumpAndSettle();
    expect(shown(), ['Lane done']);
    // A swipe back shows the page before and sets the variable.
    await tester.timedDrag(find.byType(PageView), const Offset(200, 0), const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(shown(), ['Lane doing']);
    expect(s['lanePage'], 1);
  });

  testWidgets('a flexible list in a running page view hugs its items', (tester) async {
    final s = await show(
      tester,
      {
        'pages': {
          'type': 'pageView',
          'children': ['page'],
          'layout': {'width': 300, 'height': 400},
          'props': {'scrollDirection': 'horizontal'},
          'bind': {'data': r'${lanes}'},
        },
        'page': {
          'type': 'column',
          'children': ['cards', 'add'],
          'layout': {'width': {'fill': 300}, 'height': {'fill': 400}},
        },
        'cards': {
          'type': 'listView',
          'children': ['card'],
          'layout': {'width': {'fill': 300}, 'height': {'flexible': 360}},
          'bind': {'data': r'${item.cards}'},
        },
        'card': {'type': 'box', 'layout': {'width': 300, 'height': 40}},
        'add': {'type': 'box', 'layout': {'width': 300, 'height': 30}},
      },
      root: 'pages',
      variables: [
        v('lanes', const [
          {'id': 'todo', 'cards': [1, 2]},
        ], VariableType.list),
      ],
    );
    await tester.pumpAndSettle();
    final view = s.tree.boxOf('pages')!;
    RenderBox? add;
    void find(RenderObject o) {
      if (o is NodeBox && o.id == 'add' && o.hasSize) add ??= o;
      o.visitChildren(find);
    }

    find(view);
    expect(add, isNotNull);
    final top = add!.localToGlobal(Offset.zero).dy - view.localToGlobal(Offset.zero).dy;
    expect(top, 80, reason: 'under the two cards');
  });

  for (final width in [<String, Object>{'hug': 0}, 320])
  testWidgets('a track segmented button selects by tap, raises the selection and hugs or shares its width ($width)',
      (tester) async {
    final s = await show(
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
            reaction('changed', [
              {'type': 'setVariable', 'variable': 'filter', 'value': r'${result[0]}'},
            ]),
          ],
        },
      },
      variables: [v('filter', 'all')],
    );
    expect(find.byType(SegmentedButton<String>), findsNothing);
    // Hugging, every label fits on one line; a narrower share ellipsizes.
    for (final label in ['All', 'Live', 'Draft', 'Closed']) {
      final p = tester.renderObject<RenderParagraph>(find.text(label));
      if (width is! int) expect(p.didExceedMaxLines, isFalse);
      expect(p.maxLines, 1);
    }
    final widths = [for (final l in ['All', 'Closed']) tester.getSize(find.ancestor(of: find.text(l), matching: find.byType(AnimatedContainer)).first).width];
    if (width is int) {
      // A filling track shares its width: 320 less the 3px inset each side, by 4.
      expect(widths, everyElement(closeTo((320 - 6) / 4, 0.5)));
    } else {
      expect(widths[0], lessThan(widths[1]));
    }
    BoxDecoration deco(String l) => tester.widget<AnimatedContainer>(
        find.ancestor(of: find.text(l), matching: find.byType(AnimatedContainer)).first).decoration! as BoxDecoration;
    expect(deco('All').boxShadow, hasLength(1));
    expect(deco('Draft').boxShadow, isNull);
    await tester.tap(find.text('Draft'));
    await tester.pumpAndSettle();
    expect(s['filter'], 'draft');
    expect(deco('Draft').boxShadow, hasLength(1));
    expect(deco('All').boxShadow, isNull);
  });

  testWidgets('focus reaches the field in the same list item, even one the same tap reveals', (tester) async {
    final s = await show(
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
            reaction('click', [
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
      variables: [v('lanes', const ['todo', 'doing'], VariableType.list), v('adding', '')],
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
    expect(FocusManager.instance.primaryFocus, TextFieldHandle.near(s.tree, 'field', second.instance)!.focusNode);
    expect(TextFieldHandle.near(s.tree, 'field', adds.first.instance), isNull,
        reason: 'the first column\'s field is hidden, so not built');
  });

  testWidgets('an input reports changed and writes its bound variable', (tester) async {
    final s = await show(
      tester,
      {
        'col': {'type': 'column', 'children': ['field', 'label'], 'layout': {'width': 300, 'height': {'hug': 80}}},
        'field': {
          'type': 'textField',
          'layout': {'width': 300, 'height': 48},
          'bind': {'props.initialValue': r'${name}'},
          'actions': [
            reaction('changed', [
              {'type': 'setVariable', 'variable': 'echo', 'value': r'${result}!'},
              // The new text's other name, `value`.
              {'type': 'setVariable', 'variable': 'query', 'value': r'${value}'},
            ]),
            reaction('submitted', [add('sent')]),
          ],
        },
        'label': {'type': 'text', 'layout': {'width': 300, 'height': 20}, 'props': {'text': r'Hi ${name}'}},
      },
      variables: [v('name', ''), v('echo', ''), v('query', ''), v('sent', 0, VariableType.integer)],
    );
    await tester.enterText(find.byType(TextField), 'Ada');
    await tester.pump();
    expect((s['name'], s['echo']), ('Ada', 'Ada!'));
    expect(s['query'], 'Ada');
    expect(textOf(s.tree, 'label'), 'Hi Ada');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(s['sent'], 1);
  });

  testWidgets('a checkbox and a button island report their own events', (tester) async {
    final s = await show(
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
          'actions': [reaction('click', [add('count')])],
        },
      },
      variables: [v('on', false, VariableType.boolean), v('count', 0, VariableType.integer)],
    );
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(s['on'], true);
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(s['count'], 1);
  });

  testWidgets('enter viewport can wait for the node to stay in view', (tester) async {
    final s = await show(
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
            reaction('enterViewport', [add('shown')], extra: {'visibleMs': 500}),
          ],
        },
      },
      variables: [v('shown', 0, VariableType.integer), v('gap', 900, VariableType.integer)],
    );
    await tester.pump();
    s.scope.set('gap', 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    s.scope.set('gap', 900); // gone before 500 ms
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(s['shown'], 0);
    s.scope.set('gap', 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(s['shown'], 1);
  });

  testWidgets('enter and exit viewport as a node moves in and out of view', (tester) async {
    final s = await show(
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
            reaction('enterViewport', [add('shown')]),
            reaction('exitViewport', [add('hidden')]),
          ],
        },
      },
      variables: [v('shown', 0, VariableType.integer), v('hidden', 0, VariableType.integer), v('gap', 900, VariableType.integer)],
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
