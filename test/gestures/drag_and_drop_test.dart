// Drag and drop (`draggable`, `dropTarget`) on the render tree. A two-column board: each column is a list of
// `cards` filtered by lane and a drop target that owns its list; each card
// is draggable. Dropping runs `moveItems` on `cards`. Column b takes at
// most 2 cards (a WIP limit).
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/runtime/gestures/drag_and_drop.dart';
import 'package:flutter/gestures.dart';
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
    {List<Json> cardActions = const [],
    List<Json> bActions = const [],
    Map<String, Object?> bTarget = const {},
    Map<String, Object?> cardDraggable = const {},
    Map<String, Object?> extraNodes = const {},
    bool wrapped = false}) async {
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
  final card = nodes['card_a']! as Map;
  card['draggable'] = <String, Object?>{...(card['draggable'] as Map).cast<String, Object?>(), ...cardDraggable};
  nodes.addAll(extraNodes);
  if (wrapped) {
    // Each column is the drop target and names the list inside it (a kanban
    // column with its card list).
    for (final lane in ['a', 'b']) {
      final list = nodes['list_$lane']! as Map<String, Object?>;
      nodes['col_$lane'] = {
        'type': 'column',
        'children': ['list_$lane'],
        'layout': {'width': 160, 'height': 400},
        'dropTarget': list.remove('dropTarget'),
        'actions': list.remove('actions'),
      };
    }
    (nodes['board']! as Map)['children'] = ['col_a', 'col_b'];
  }
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

/// A board whose columns are one column repeated over `lanes` (a horizontal
/// list), each the drop target of the card list inside it, which draws
/// `slot` in its slot.
Future<Board> pumpRepeated(WidgetTester tester, {bool tabs = false}) async {
  tester.view.physicalSize = const Size(400, 500);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final doc = api.LayoutDocument.fromJson({
    'roots': ['board'],
    'nodes': {
      'board': {
        'type': 'column',
        'children': [if (tabs) 'tabs', 'lanes', 'slot'],
        'layout': {'width': 320, 'height': 400},
      },
      // A tab per lane, beside the columns: dropping on one adds to the end
      // of its column.
      'tabs': {
        'type': 'listView',
        'children': ['tab'],
        'layout': {'width': 320, 'height': 30},
        'props': {'scrollDirection': 'horizontal', 'scrollable': false},
        'bind': {'data': r'${lanes}'},
      },
      'tab': {
        'type': 'text',
        'layout': {'width': 160, 'height': 30},
        'props': {'text': r'Tab ${item}'},
        'dropTarget': {'accepts': ['card'], 'key': r'${item}', 'listNodeId': 'list', 'slot': 'node', 'slotNodeId': 'slot'},
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
        ],
      },
      'lanes': {
        'type': 'listView',
        'children': ['col'],
        'layout': {'width': 320, 'height': 370},
        'props': {'scrollDirection': 'horizontal', 'scrollable': false},
        'bind': {'data': r'${lanes}'},
      },
      'col': {
        'type': 'column',
        'children': ['list'],
        'layout': {'width': 160, 'height': 370},
        'dropTarget': {'accepts': ['card'], 'key': r'${item}', 'listNodeId': 'list', 'slot': 'node', 'slotNodeId': 'slot'},
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
        ],
      },
      'list': {
        'type': 'listView',
        'children': ['card'],
        'layout': {'width': 160, 'height': 370},
        'bind': {'data': r'${= filter(cards, c => c.lane == item)}'},
      },
      'card': {
        'type': 'text',
        'layout': {'width': 160, 'height': 40},
        'props': {'text': r'${item.title}'},
        'draggable': {'group': 'card', 'data': r'${item.id}', 'start': 'press', 'whileDragging': 'hidden'},
      },
      'slot': {
        'type': 'row',
        'children': ['slot_text'],
        'layout': {'width': {'fill': 100}, 'height': {'fill': 100}},
        'props': {'mainAxisAlignment': 'center', 'crossAxisAlignment': 'center'},
        'bind': {'visible': r'${= false}'},
      },
      'slot_text': {
        'type': 'text',
        'layout': {'width': {'hug': 60}, 'height': {'hug': 16}},
        'props': {'text': 'Drop here'},
      },
    },
  });
  final values = ValuesScope({'drag': dragIdleValues});
  final scope = VariableScope([
    const Variable(name: 'lanes', type: VariableType.list, value: ['a', 'b']),
    const Variable(name: 'cards', type: VariableType.list, value: [
      {'id': 'c1', 'title': 'One', 'lane': 'a'},
      {'id': 'c2', 'title': 'Two', 'lane': 'a'},
      {'id': 'c4', 'title': 'Four', 'lane': 'b'},
    ]),
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

  testWidgets('a column that names its card list opens the slot in that list', (tester) async {
    final b = await pump(tester, wrapped: true);
    final start = textRect(tester, 'One').center;
    final four = textRect(tester, 'Four').topCenter;
    final gesture = await dragTo(tester, start, four + const Offset(0, 4), release: false);
    expect(b.drag['over'], 'b');
    expect(dropSlotOf(b.tree, 'list_b'), const DropSlotSpec(before: 0, size: Size(160, 40)));
    await tester.pump();
    // The data-bound list draws the slot: the card below it moves down.
    expect(textRect(tester, 'Four').top, greaterThanOrEqualTo(four.dy + 40 - 0.5));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(b.lane('b'), ['c1', 'c4']);
  });

  testWidgets('the slot shows the target\'s slot node, hidden in its own place', (tester) async {
    final b = await pump(tester, wrapped: true, bTarget: {'slot': 'node', 'slotNodeId': 'slot'}, extraNodes: {
      // Designed hidden where it sits (a sibling of the columns), as an
      // editor keeps a slot node out of the way.
      'slot': {
        'type': 'row',
        'children': ['slot_text'],
        'layout': {'width': {'fill': 100}, 'height': {'fill': 100}},
        'decoration': {'fills': [{'color': '#FF4B4DED'}]},
        'props': {'mainAxisAlignment': 'center', 'crossAxisAlignment': 'center'},
        'bind': {'visible': r'${= false}'},
      },
      'slot_text': {
        'type': 'text',
        'layout': {'width': {'hug': 60}, 'height': {'hug': 16}},
        'props': {'text': r"${= drag.count > 1 ? 'Drop ' + drag.count + ' here' : 'Drop here'}"},
      },
    });
    expect(paragraphs(tester, 'Drop here'), 0);
    final start = textRect(tester, 'One').center;
    final four = textRect(tester, 'Four').topCenter;
    final gesture = await dragTo(tester, start, four + const Offset(0, 4), release: false);
    expect(b.drag['over'], 'b');
    await tester.pump();
    // In the slot: as big as the dragged card, where Four was.
    final label = textRect(tester, 'Drop here');
    expect(label.center.dx, closeTo(240, 1));
    expect(label.center.dy, closeTo(four.dy + 20, 1));
    expect(textRect(tester, 'Four').top, greaterThanOrEqualTo(four.dy + 40 - 0.5));
    expect(tester.takeException(), isNull);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(paragraphs(tester, 'Drop here'), 0);
    expect(b.lane('b'), ['c1', 'c4']);
  });

  testWidgets('of a column repeated over the lanes, only the one under the drag opens its slot', (tester) async {
    final b = await pumpRepeated(tester);
    final start = textRect(tester, 'One').center;
    final four = textRect(tester, 'Four').topCenter;
    final gesture = await dragTo(tester, start, four + const Offset(0, 4), release: false);
    expect(b.drag['over'], 'b');
    await tester.pump();
    // One slot, in the second column, where Four was; the first column's
    // Two keeps its place.
    expect(paragraphs(tester, 'Drop here'), 1);
    expect(textRect(tester, 'Drop here').center.dx, closeTo(240, 1));
    expect(textRect(tester, 'Four').top, greaterThanOrEqualTo(four.dy + 40 - 0.5));
    expect(textRect(tester, 'Two').top, closeTo(0, 0.5));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(b.lane('b'), ['c1', 'c4']);
  });

  testWidgets('the first tab opens the slot at the end of the first column', (tester) async {
    final b = await pumpRepeated(tester, tabs: true);
    final gesture = await dragTo(tester, textRect(tester, 'Four').center, textRect(tester, 'Tab a').center, release: false);
    expect(b.drag['over'], 'a');
    await tester.pump();
    // After One and Two.
    expect(textRect(tester, 'Drop here').center, offsetMoreOrLessEquals(const Offset(80, 30 + 80 + 20), epsilon: 1));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(b.lane('a'), ['c1', 'c2', 'c4']);
  });

  testWidgets('drag.target names the node of the target the drag is over, a tab or its column', (tester) async {
    final b = await pumpRepeated(tester, tabs: true);
    final gesture = await dragTo(tester, textRect(tester, 'One').center, textRect(tester, 'Tab b').center, release: false);
    expect(b.drag['over'], 'b');
    expect(b.drag['target'], 'tab');
    await gesture.moveTo(textRect(tester, 'Four').center);
    await tester.pump();
    expect(b.drag['over'], 'b');
    expect(b.drag['target'], 'col');
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('a tab beside the columns opens the slot at the end of its column', (tester) async {
    final b = await pumpRepeated(tester, tabs: true);
    final four = textRect(tester, 'Four');
    final gesture = await dragTo(tester, textRect(tester, 'One').center, textRect(tester, 'Tab b').center, release: false);
    expect(b.drag['over'], 'b');
    await tester.pump();
    expect(paragraphs(tester, 'Drop here'), 1);
    final slot = textRect(tester, 'Drop here');
    expect(slot.center.dx, closeTo(240, 1));
    // After Four, which stays put.
    expect(textRect(tester, 'Four').top, closeTo(four.top, 0.5));
    // Four's card is 40 tall; the slot (40) right after it.
    expect(slot.center.dy, closeTo(four.top + 60, 1));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(b.lane('b'), ['c4', 'c1']);
  });

  testWidgets('a running list a drop target opens its slot in still scrolls', (tester) async {
    final b = await pump(tester, wrapped: true, extraNodes: {});
    // Lane a holds three 40 px cards in a 400 px list: give it more than fits.
    b.scope.set('cards', [
      for (var i = 0; i < 14; i++) {'id': 'm$i', 'title': 'Card $i', 'lane': 'a'},
    ]);
    await tester.pump();
    RenderBox? scroll;
    void visit(RenderObject o) {
      if (scroll == null && o.runtimeType.toString() == 'RenderDesignScroll' && o.attached) scroll = o as RenderBox;
      o.visitChildren(visit);
    }
    visit(b.tree.boxOf('list_a')!);
    expect(scroll, isNotNull);
    final before = textRect(tester, 'Card 0').top;
    await tester.sendEventToBinding(PointerScrollEvent(position: textRect(tester, 'Card 2').center, scrollDelta: const Offset(0, 120)));
    await tester.pump();
    expect(textRect(tester, 'Card 0').top, closeTo(before - 120, 0.5));
  });

  testWidgets('a feedback node that hugs takes its content\'s size, not its design size', (tester) async {
    await pump(tester, cardDraggable: {'feedbackNodeId': 'fb'}, extraNodes: {
      // Designed 40 × 40 (the size a hug node is saved with), hugging
      // a label that reads the drag: it must grow with the text.
      'fb': {
        'type': 'column',
        'children': ['fb_text'],
        'visible': false,
        'layout': {'width': {'hug': 40}, 'height': {'hug': 40}},
      },
      'fb_text': {
        'type': 'text',
        'layout': {'width': {'hug': 40}, 'height': {'hug': 20}},
        'props': {'text': r"${item.title} over ${= drag.over == '' ? 'nothing yet' : drag.over}"},
      },
    });
    final start = textRect(tester, 'One').center;
    final gesture = await dragTo(tester, start, start + const Offset(20, 30), release: false);
    await tester.pump();
    final label = textRect(tester, 'One over a', feedback: true);
    expect(label.width, greaterThan(60));
    expect(label.height, lessThan(30)); // one line, not squeezed into 40 wide
    expect(tester.takeException(), isNull);
    await gesture.up();
    await tester.pumpAndSettle();
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
