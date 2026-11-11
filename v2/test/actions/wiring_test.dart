// Triggers in the render tree: nodes tapped (pressed, hovered, swiped...)
// in a NodeView(interactive: true) run their reactions; a variable they set
// re-applies only the boxes that read it.
import 'package:codelessly_api_v2/codelessly_api.dart' as api;
import 'package:codelessly_sdk_v2/codelessly_sdk.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
    expect(NodeBox.debugApplyCounts.keys, ['label']);
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

  testWidgets('a popover flips above when there is no room below and stays on screen', (tester) async {
    final layout = PopoverLayout(anchor: const Rect.fromLTWH(700, 560, 80, 30), placement: api.PopoverPlacement.belowStart);
    // 600 tall: 200 doesn't fit below 594, so above; 800 wide keeps it in.
    expect(layout.getPositionForChild(const Size(800, 600), const Size(232, 200)), const Offset(560, 356));
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
              // SDK 8.x's name for the new text, which migrated actions use.
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
