// Drag and drop (`draggable`, `dropTarget`) on the render tree. A two-column board: each column is a list of
// `cards` filtered by lane and a drop target that owns its list; each card
// is draggable. Dropping runs `moveItems` on `cards`. Column b takes at
// most 2 cards (a WIP limit).
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/runtime/gestures/drag_and_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

class Board {
  Board(this.tree, this.scope);
  final NodeTree tree;
  final VariableScope scope;

  Map<String, Object?> get drag => DragAndDrop.of(tree).value;

  List<String> lane(String lane) => [
        for (final card in (scope.read('cards')! as List).cast<Map>())
          if (card['lane'] == lane) card['id'] as String,
      ];
}

/// The global rects of the paragraphs reading [text].
Rect textRect(WidgetTester tester, String text, {bool feedback = false}) {
  final out = <Rect>[];
  void visit(RenderObject o) {
    if (o is RenderParagraph && o.text.toPlainText() == text && o.attached && o.hasSize) {
      out.add(MatrixUtils.transformRect(o.getTransformTo(null), Offset.zero & o.size));
    }
    o.visitChildren(visit);
  }

  visit(tester.binding.rootElement!.renderObject!);
  return feedback ? out.last : out.first;
}

int paragraphs(WidgetTester tester, String text) {
  var n = 0;
  void visit(RenderObject o) {
    if (o is RenderParagraph && o.text.toPlainText() == text) n++;
    o.visitChildren(visit);
  }

  visit(tester.binding.rootElement!.renderObject!);
  return n;
}

Map<String, Object?> lane(String lane,
        {String acceptIf = '', List<Json> actions = const [], Map<String, Object?> target = const {}}) =>
    {
      'list_$lane': {
        'type': 'listView',
        'children': ['card_$lane'],
        'layout': {'width': 160, 'height': 400},
        'bind': {'data': "\${= filter(cards, c => c.lane == '$lane')}"},
        'dropTarget': {
          'accepts': ['card'],
          'key': lane,
          'listNodeId': 'list_$lane',
          'acceptIf': acceptIf,
          ...target,
        },
        'actions': [
          {
            'trigger': {'type': 'drop'},
            'actions': [
              {
                'type': 'setVariable',
                'variable': 'cards',
                'value': r"${= moveItems(cards, result.ids, result.beforeId, object('lane', result.key))}",
              },
            ],
          },
          ...actions,
        ],
      },
      'card_$lane': {
        'type': 'text',
        'layout': {'width': 160, 'height': 40},
        'props': {'text': r'${item.title}'},
        'draggable': {'group': 'card', 'data': r'${item.id}', 'start': 'press', 'whileDragging': 'hidden'},
      },
    };

Future<Board> pump(WidgetTester tester,
    {List<Json> cardActions = const [], List<Json> bActions = const [], Map<String, Object?> bTarget = const {}}) async {
  tester.view.physicalSize = const Size(400, 500);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final nodes = <String, Object?>{
    'board': {
      'type': 'row',
      'children': ['list_a', 'list_b'],
      'layout': {'width': 320, 'height': 400},
    },
    ...lane('a'),
    ...lane('b',
        acceptIf: r"${= count(filter(cards, c => c.lane == 'b' && !contains(drag.ids, c.id))) + drag.count <= 2}",
        actions: bActions,
        target: bTarget),
  };
  (nodes['card_a']! as Map)['actions'] = cardActions;
  final doc = api.LayoutDocument.fromJson({'roots': ['board'], 'nodes': nodes});
  final values = ValuesScope({'drag': dragIdleValues});
  final scope = VariableScope([
    const Variable(name: 'cards', type: VariableType.list, value: [
      {'id': 'c1', 'title': 'One', 'lane': 'a'},
      {'id': 'c2', 'title': 'Two', 'lane': 'a'},
      {'id': 'c3', 'title': 'Three', 'lane': 'a'},
      {'id': 'c4', 'title': 'Four', 'lane': 'b'},
    ]),
    const Variable(name: 'log', type: VariableType.list, value: []),
  ], parent: values);
  final source = NodeValues(DocumentSource(doc));
  final tree = NodeTree(source, binder: NodeBinder(scope: scope));
  final context = RuntimeActionContext(scope: scope, tree: tree, nodeValues: source, services: Services());
  final reactions = TreeReactions(runner: const CodelesslyActions(), context: context);
  tree.interactions = reactions;
  addTearDown(() {
    reactions.dispose();
    tree.dispose();
  });
  await tester.pumpWidget(MaterialApp(
    home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'board', interactive: true)),
  ));
  await tester.pump();
  return Board(tree, scope);
}

Json log(String what) => {
      'type': 'setVariable',
      'variable': 'log',
      'op': 'add',
      'value': what,
    };

Future<TestGesture> dragTo(WidgetTester tester, Offset start, Offset to, {bool release = true}) async {
  final gesture = await tester.startGesture(start);
  await tester.pump();
  for (var i = 1; i <= 10; i++) {
    await gesture.moveTo(Offset.lerp(start, to, i / 10)!);
    await tester.pump();
  }
  if (release) {
    await gesture.up();
    await tester.pumpAndSettle();
  }
  return gesture;
}

void main() {
  testWidgets('a card dragged into the other column lands before the card under the pointer', (tester) async {
    final b = await pump(tester);
    final start = textRect(tester, 'One').center;
    final four = textRect(tester, 'Four').topCenter;
    final gesture = await dragTo(tester, start, four + const Offset(0, 4), release: false);
    final drag = b.drag;
    expect(drag['active'], isTrue);
    expect(drag['data'], 'c1');
    expect(drag['over'], 'b');
    expect(drag['beforeId'], 'c4');
    expect(drag['index'], 0);
    expect(drag['accepted'], isTrue);
    expect(drag['width'], 160);
    // The card follows the pointer in the overlay, and the scope reads it.
    expect(paragraphs(tester, 'One'), 2);
    expect(textRect(tester, 'One', feedback: true).center.dx, closeTo(four.dx, 1));
    expect(textRect(tester, 'One', feedback: true).center.dy, closeTo(four.dy + 4, 3));
    expect(b.scope.read('drag.over'), 'b');
    // The slot of column b's list.
    expect(dropSlotOf(b.tree, 'list_b'), const DropSlotSpec(before: 0, size: Size(160, 40)));
    expect(dropSlotOf(b.tree, 'list_a'), isNull);
    // Column b opens it: the card the drop lands before moves down by the
    // dragged card's height (and the list's spacing).
    await tester.pump();
    expect(textRect(tester, 'Four').top, greaterThanOrEqualTo(four.dy + 40 - 0.5));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(b.lane('a'), ['c2', 'c3']);
    expect(b.lane('b'), ['c1', 'c4']);
    expect(b.drag['active'], isFalse);
    expect(paragraphs(tester, 'One'), 1);
    expect(dropSlotOf(b.tree, 'list_b'), isNull);
  });

  testWidgets('a full column refuses the drop (acceptIf) and nothing moves', (tester) async {
    final b = await pump(tester, bActions: [
      {
        'trigger': {'type': 'dropRejected'},
        'actions': [log(r'rejected ${result.data} ${result.key}')],
      },
    ], cardActions: [
      {
        'trigger': {'type': 'dragCancel'},
        'actions': [log(r'cancel ${result.data}')],
      },
    ]);
    await dragTo(tester, textRect(tester, 'One').center, const Offset(240, 300));
    expect(b.lane('b'), ['c4', 'c1']);

    final gesture = await dragTo(tester, textRect(tester, 'Two').center, const Offset(240, 300), release: false);
    expect(b.drag['over'], 'b');
    expect(b.drag['accepted'], isFalse);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(b.lane('a'), ['c2', 'c3']);
    expect(b.lane('b'), ['c4', 'c1']);
    expect(b.scope.read('log'), ['rejected c2 b', 'cancel c2']);
  });

  testWidgets('a slot node at its own size, and none for a refused drop when asked', (tester) async {
    final b = await pump(tester, bTarget: {'slot': 'node', 'slotNodeId': 'line', 'slotSize': 'node', 'slotWhenRefused': false});
    var g = await dragTo(tester, textRect(tester, 'One').center, const Offset(240, 300), release: false);
    expect(dropSlotOf(b.tree, 'list_b'),
        const DropSlotSpec(before: 1, size: Size(160, 40), slotNodeId: 'line', ownSize: true));
    await g.up();
    await tester.pumpAndSettle();
    g = await dragTo(tester, textRect(tester, 'Two').center, const Offset(240, 300), release: false);
    // Column b is full: refused, and it opens nothing.
    expect(b.drag['accepted'], isFalse);
    expect(dropSlotOf(b.tree, 'list_b'), const DropSlotSpec(before: 2, size: Size.zero));
    await g.up();
    await tester.pumpAndSettle();
  });

  testWidgets('drag.x/y and fx/fy give where the dragged node lands', (tester) async {
    final b = await pump(tester);
    // The dragged node's center is the pointer less the grab's distance
    // from the node's center. Column b spans x 160..320, y 0..400.
    final start = textRect(tester, 'One').center;
    final box = b.tree.boxOf('card_a')!.contentBox!;
    final card = box.localToGlobal(Offset.zero) & box.size;
    final fromCenter = start - card.center;
    var to = const Offset(240, 300);
    final gesture = await dragTo(tester, start, to, release: false);
    var drag = b.drag;
    var center = to - fromCenter - const Offset(160, 0);
    expect(drag['over'], 'b');
    expect(drag['x'] as double, closeTo(center.dx, 0.5));
    expect(drag['y'] as double, closeTo(center.dy, 0.5));
    expect(drag['fx'] as double, closeTo(center.dx / 160, 0.01));
    expect(drag['fy'] as double, closeTo(center.dy / 400, 0.01));
    to = const Offset(250, 100);
    await gesture.moveTo(to);
    await tester.pump();
    drag = b.drag;
    center = to - fromCenter - const Offset(160, 0);
    expect(drag['x'] as double, closeTo(center.dx, 0.5));
    expect(drag['fy'] as double, closeTo(center.dy / 400, 0.01));
    await gesture.up();
    await tester.pumpAndSettle();
    // The drop keeps where it landed for the drop's actions.
    expect(b.drag['fy'] as double, closeTo(center.dy / 400, 0.01));
  });

  testWidgets('reordering within a column', (tester) async {
    final b = await pump(tester);
    final start = textRect(tester, 'Three').center;
    final to = textRect(tester, 'One').topCenter + const Offset(0, 2);
    final gesture = await dragTo(tester, start, to, release: false);
    expect(b.drag['beforeId'], 'c1');
    await gesture.up();
    await tester.pumpAndSettle();
    expect(b.lane('a'), ['c3', 'c1', 'c2']);
  });

  testWidgets('the source fires start and completed; the target enter, exit and drop', (tester) async {
    final b = await pump(tester, cardActions: [
      {
        'trigger': {'type': 'dragStart'},
        'actions': [log(r'start ${result.data}')],
      },
      {
        'trigger': {'type': 'dragCompleted'},
        'actions': [log(r'completed ${result.data}')],
      },
    ], bActions: [
      {
        'trigger': {'type': 'dragEnter'},
        'actions': [log(r'enter ${result.over}')],
      },
      {
        'trigger': {'type': 'dragExit'},
        'actions': [log('exit')],
      },
      {
        'trigger': {'type': 'drop'},
        'actions': [log(r'drop ${result.key} ${result.index}')],
      },
    ]);
    final g = await dragTo(tester, textRect(tester, 'One').center, const Offset(240, 300), release: false);
    await g.moveTo(const Offset(80, 300));
    await tester.pump();
    await g.moveTo(const Offset(240, 300));
    await tester.pump();
    await g.up();
    await tester.pumpAndSettle();
    final logged = b.scope.read('log')! as List;
    expect(logged.take(4), ['start c1', 'enter b', 'exit', 'enter b']);
    expect(logged.skip(4), unorderedEquals(['drop b 1', 'completed c1']));
  });

  testWidgets('let go over no target springs back and cancels', (tester) async {
    final b = await pump(tester, cardActions: [
      {
        'trigger': {'type': 'dragCancel'},
        'actions': [log(r'cancel ${result.data}')],
      },
    ]);
    await dragTo(tester, textRect(tester, 'One').center, const Offset(360, 450));
    expect(b.scope.read('log'), ['cancel c1']);
    expect(b.lane('a'), ['c1', 'c2', 'c3']);
    expect(b.drag['active'], isFalse);
  });

  group('a source and a target on a stack', () {
    // A 60×60 source at (20, 20) and a 200×200 target at (180, 180).
    Future<(NodeTree, VariableScope)> stack(WidgetTester tester,
        {Map<String, Object?> source = const {}, Map<String, Object?> target = const {}, bool interactive = true}) async {
      Json log(String trigger, String what) => {
            'trigger': {'type': trigger},
            'actions': [
              {'type': 'setVariable', 'variable': 'log', 'op': 'add', 'value': what},
            ],
          };
      final doc = api.LayoutDocument.fromJson({
        'roots': ['s'],
        'nodes': {
          's': {
            'type': 'stack',
            'children': ['src', 'dst'],
            'layout': {'width': 400, 'height': 400},
          },
          'src': {
            'type': 'box',
            'layout': {'width': 60, 'height': 60, 'x': {'start': 20}, 'y': {'start': 20}},
            'decoration': {'fills': [{'color': '#FFFF0000'}]},
            'draggable': {'group': 'g', 'data': 'pin', 'start': 'press', ...source},
            'actions': [log('dragCancel', 'cancel')],
          },
          'dst': {
            'type': 'box',
            'layout': {'width': 200, 'height': 200, 'x': {'start': 180}, 'y': {'start': 180}},
            'decoration': {'fills': [{'color': '#FF00FF00'}]},
            'dropTarget': {'accepts': ['g'], ...target},
            'actions': [
              log('drop', r'drop ${result.x} ${result.y}'),
              log('dropFull', r'full ${result.full}'),
              log('dragHover', 'hover'),
            ],
          },
        },
      });
      final scope = VariableScope([const Variable(name: 'log', type: VariableType.list, value: [])],
          parent: ValuesScope({'drag': dragIdleValues}));
      final values = NodeValues(DocumentSource(doc));
      final tree = NodeTree(values, binder: NodeBinder(scope: scope));
      final reactions = TreeReactions(
        runner: const CodelesslyActions(),
        context: RuntimeActionContext(scope: scope, tree: tree, nodeValues: values, services: Services()),
      );
      tree.interactions = reactions;
      addTearDown(() {
        reactions.dispose();
        tree.dispose();
      });
      await tester.pumpWidget(MaterialApp(
        home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 's', interactive: interactive)),
      ));
      return (tree, scope);
    }

    RenderDragSource sourceOf(NodeTree tree) {
      RenderDragSource? found;
      void visit(RenderObject o) {
        if (o is RenderDragSource) found ??= o;
        o.visitChildren(visit);
      }

      visit(tree.boxOf('src')!);
      return found!;
    }

    testWidgets('a centered copy is held by its center: drag.x/y is the pointer', (tester) async {
      final (tree, scope) = await stack(tester, source: {'feedbackAnchor': 'center'});
      final g = await dragTo(tester, const Offset(30, 30), const Offset(280, 230), release: false);
      expect(DragAndDrop.of(tree).value['x'], closeTo(100, 0.01));
      expect(DragAndDrop.of(tree).value['y'], closeTo(50, 0.01));
      await g.up();
      await tester.pumpAndSettle();
      expect(scope.read('log'), ['drop 100.0 50.0']);
    });

    testWidgets('a full target says so, refuses the drop and the source springs back', (tester) async {
      final (tree, scope) = await stack(tester, target: {'fullIf': r'${= true}'});
      final g = await dragTo(tester, const Offset(30, 30), const Offset(280, 280), release: false);
      expect(DragAndDrop.of(tree).value['over'], 'dst');
      expect(DragAndDrop.of(tree).value['full'], isTrue);
      expect(DragAndDrop.of(tree).value['accepted'], isFalse);
      await g.up();
      await tester.pump();
      // Flying home from where it was let go.
      await tester.pump(const Duration(milliseconds: 16));
      expect(sourceOf(tree).debugReturnShift.dx, greaterThan(100));
      await tester.pumpAndSettle();
      expect(sourceOf(tree).debugReturnShift, Offset.zero);
      expect(scope.read('log'), ['full true', 'cancel']);
    });

    testWidgets('the source ghosts while dragged and flies back on its spring', (tester) async {
      final (tree, scope) = await stack(tester, source: {'ghostOpacity': 0.3});
      final g = await dragTo(tester, const Offset(30, 30), const Offset(120, 60), release: false);
      final layers = <OpacityLayer>[];
      void visit(Layer l) {
        if (l is OpacityLayer) layers.add(l);
        if (l is ContainerLayer) {
          for (var c = l.firstChild; c != null; c = c.nextSibling) {
            visit(c);
          }
        }
      }

      visit(tester.binding.renderViews.first.debugLayer!);
      expect(layers.any((l) => l.alpha == (0.3 * 255).round()), isTrue);
      await g.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      // Under way home: drawn between where it was let go (90, 30 to the
      // right and down) and its place.
      final shift = sourceOf(tree).debugReturnShift;
      expect(shift.dx, inExclusiveRange(0, 90));
      expect(shift.dy, inExclusiveRange(0, 30));
      await tester.pumpAndSettle();
      expect(scope.read('log'), ['cancel']);
      expect(DragAndDrop.of(tree).session, isNull);
    });

    testWidgets('a target with a hover delay fires dragHover after it', (tester) async {
      final (_, scope) = await stack(tester, target: {'hoverDelay': 200});
      final g = await dragTo(tester, const Offset(30, 30), const Offset(280, 280), release: false);
      await tester.pump(const Duration(milliseconds: 100));
      expect(scope.read('log'), isEmpty);
      await tester.pump(const Duration(milliseconds: 150));
      expect(scope.read('log'), ['hover']);
      await g.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a disabled source, a target that takes another group', (tester) async {
      var (tree, scope) = await stack(tester, source: {'enabled': false});
      await dragTo(tester, const Offset(30, 30), const Offset(280, 280));
      expect(scope.read('log'), isEmpty);
      await tester.pumpWidget(const SizedBox());
      (tree, scope) = await stack(tester, target: {'accepts': ['other']});
      final g = await dragTo(tester, const Offset(30, 30), const Offset(280, 280), release: false);
      expect(DragAndDrop.of(tree).value['over'], '');
      await g.up();
      await tester.pumpAndSettle();
      expect(scope.read('log'), ['cancel']);
    });

    testWidgets('the design canvas takes no drag', (tester) async {
      final (tree, _) = await stack(tester, interactive: false);
      var found = false;
      void visit(RenderObject o) {
        if (o is RenderDragSource || o is RenderDropTarget) found = true;
        o.visitChildren(visit);
      }

      visit(tree.boxOf('s')!);
      expect(found, isFalse);
    });
  });
}
