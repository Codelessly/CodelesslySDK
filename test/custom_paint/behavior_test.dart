// A node's `customPaint` in the render tree: the painter behind the node's
// content and the foreground painter over it; repeats over bound data that
// repaint when (and only when) the data changes; view box fits; the design
// canvas; hit regions that report to the node's pointer reactions; and a
// 48 × 48 board as one node.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/custom_paint.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

/// The pixel at ([x], [y]) of a 64-wide shot.
Color _at(List<int> px, int x, int y, {int w = 64}) {
  final i = (y * w + x) * 4;
  return Color.fromARGB(px[i + 3], px[i], px[i + 1], px[i + 2]);
}

RenderCustomPaintLayer _layer(NodeTree tree, String id) {
  RenderCustomPaintLayer? found;
  void visit(RenderObject o) {
    if (o is RenderCustomPaintLayer) found ??= o;
    o.visitChildren(visit);
  }

  visit(tree.boxOf(id)!);
  return found!;
}

const _red = Color(0xFFFF0000), _blue = Color(0xFF0000FF), _green = Color(0xFF00FF00), _white = Color(0xFFFFFFFF);

void main() {
  testWidgets('painter behind the content, foreground painter over it', (tester) async {
    pixelRatioOne(tester);
    final doc = LayoutDocument.fromJson({
      'roots': ['s'],
      'nodes': {
        's': {
          'type': 'stack',
          'children': ['child'],
          'layout': {'width': 60, 'height': 60},
          'decoration': {'fills': [{'color': '#FFFFFFFF'}]},
          'customPaint': {
            'painter': [
              {'op': 'rect', 'rect': [0, 0, 60, 60], 'paint': '#FFFF0000'},
            ],
            'foregroundPainter': [
              {'op': 'circle', 'c': [30, 30], 'radius': 5, 'paint': '#FF00FF00'},
            ],
          },
        },
        'child': {'type': 'box', 'layout': {'width': 30, 'height': 30, 'x': {'start': 15}, 'y': {'start': 15}}, 'decoration': {'fills': [{'color': '#FF0000FF'}]}},
      },
    });
    final tree = paintTree(doc);
    addTearDown(tree.dispose);
    final px = await shot(tester, NodeView(tree: tree, rootId: 's'));
    // The node's own fill is its content: it covers the painter.
    expect(_at(px, 5, 5), _white, reason: 'the decoration paints over the painter');
    expect(_at(px, 20, 20), _blue, reason: 'the child over the painter');
    expect(_at(px, 30, 30), _green, reason: 'the foreground painter over the child');

    // Without a fill the painter shows behind the child.
    final bare = LayoutDocument.fromJson({
      ...doc.toJson(),
      'nodes': {
        ...doc.toJson()['nodes'] as Map<String, Object?>,
        's': {...(doc.toJson()['nodes'] as Map)['s'] as Map<String, Object?>}..remove('decoration'),
      },
    });
    final tree2 = paintTree(bare);
    addTearDown(tree2.dispose);
    final px2 = await shot(tester, NodeView(tree: tree2, rootId: 's'));
    expect(_at(px2, 5, 5), _red);
    expect(_at(px2, 20, 20), _blue);
    expect(_at(px2, 30, 30), _green);
  });

  testWidgets('a repeat over bound data repaints when the data changes, and only then', (tester) async {
    pixelRatioOne(tester);
    final scope = VariableScope([
      const Variable(name: 'cells', type: VariableType.list, value: [1, 0, 0, 1]),
      const Variable(name: 'other', type: VariableType.integer, value: 0),
    ]);
    final tree = NodeTree(
      DocumentSource(paintDoc({
        'viewBox': [2, 2],
        'painter': [
          {'op': 'rect', 'rect': [0, 0, 2, 2], 'paint': '#FFFFFFFF'},
          {'op': 'repeat', 'each': r'${cells}', 'ops': [
            {'op': 'rect', 'when': r'${= item != 0}', 'rect': [r'${= index % 2}', r'${= floor(index / 2)}', 1, 1], 'paint': '#FFFF0000'},
          ]},
        ],
      })),
      binder: NodeBinder(scope: scope),
    );
    addTearDown(tree.dispose);
    var px = await shot(tester, NodeView(tree: tree, rootId: 'b'));
    expect(_at(px, 10, 10), _red);
    expect(_at(px, 45, 10), _white);
    expect(_at(px, 10, 45), _white);
    expect(_at(px, 45, 45), _red);
    final layer = _layer(tree, 'b');
    final records = layer.debugRecordCount, paints = layer.debugPaintCount;

    // A name nothing reads: nothing repaints.
    scope.set('other', 5);
    await tester.pump();
    expect(layer.debugRecordCount, records);
    expect(layer.debugPaintCount, paints);

    scope.set('cells', const [0, 1, 1, 0]);
    await tester.pump();
    expect(layer.debugRecordCount, records + 1, reason: 'only the repeat (the op that reads cells) draws again');
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: RepaintBoundary(key: key,
        child: Container(color: Colors.white, width: 64, height: 64, alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'b'))))));
    px = await pixels(tester, key);
    expect(_at(px, 10, 10), _white);
    expect(_at(px, 45, 10), _red);
    expect(_at(px, 10, 45), _red);
    expect(_at(px, 45, 45), _white);
  });

  testWidgets('a nested repeat over a 2D list names its item and index', (tester) async {
    pixelRatioOne(tester);
    final tree = paintTree(
      paintDoc({
        'viewBox': [2, 2],
        'painter': [
          {'op': 'repeat', 'each': r'${grid}', 'as': 'row', 'indexAs': 'r', 'ops': [
            {'op': 'repeat', 'each': r'${row}', 'ops': [
              {'op': 'rect', 'rect': [r'${index}', r'${r}', 1, 1], 'paint': r'${= item == 1 ? "#FF0000FF" : "#FF00FF00"}'},
            ]},
          ]},
        ],
      }),
      variables: [
        const Variable(name: 'grid', type: VariableType.list, value: [
          [1, 0],
          [0, 1],
        ]),
      ],
    );
    addTearDown(tree.dispose);
    final px = await shot(tester, NodeView(tree: tree, rootId: 'b'));
    expect(_at(px, 10, 10), _blue);
    expect(_at(px, 45, 10), _green);
    expect(_at(px, 10, 45), _green);
    expect(_at(px, 45, 45), _blue);
  });

  testWidgets('a view box fits by BoxFit: contain centers it', (tester) async {
    pixelRatioOne(tester);
    final tree = paintTree(paintDoc({
      'viewBox': [10, 20],
      'fit': 'contain',
      'painter': [
        {'op': 'rect', 'rect': [0, 0, 10, 20], 'paint': '#FFFF0000'},
      ],
    }));
    addTearDown(tree.dispose);
    final px = await shot(tester, NodeView(tree: tree, rootId: 'b'));
    // 60 × 60 box: the 10 × 20 view is 30 × 60, centered.
    expect(_at(px, 10, 30), _white);
    expect(_at(px, 16, 30), _red);
    expect(_at(px, 44, 30), _red);
    expect(_at(px, 50, 30), _white);
  });

  testWidgets('the design canvas draws it at rest, expressions at their design values', (tester) async {
    pixelRatioOne(tester);
    final doc = paintDoc({
      'painter': [
        {'op': 'circle', 'c': [30, 30], 'radius': r'${r}', 'paint': r'${tint}'},
        {'op': 'rect', 'rect': [0, 0, 6, 6], 'paint': '#FF0000FF'},
      ],
    });
    final tree = NodeTree(
      DocumentSource(doc),
      binder: NodeBinder(
        preview: true,
        scope: VariableScope([
          const Variable(name: 'r', type: VariableType.decimal, value: 20.0),
          const Variable(name: 'tint', type: VariableType.color, value: '#FFFF0000'),
        ]),
      ),
    );
    addTearDown(tree.dispose);
    final px = await shot(tester, NodeView(tree: tree, rootId: 'b'));
    expect(_at(px, 30, 30), _red);
    expect(_at(px, 30, 12), _red);
    expect(_at(px, 2, 2), _blue);

    // With no values at all, its literals still draw.
    final bare = NodeTree(DocumentSource(doc));
    addTearDown(bare.dispose);
    final px2 = await shot(tester, NodeView(tree: bare, rootId: 'b'));
    expect(_at(px2, 2, 2), _blue);
    expect(_at(px2, 30, 30), _white);
  });

  testWidgets('a hit region fires the node\'s reactions with its id, the point and its item', (tester) async {
    pixelRatioOne(tester);
    final scope = VariableScope([
      const Variable(name: 'picked', type: VariableType.text, value: ''),
      const Variable(name: 'at', type: VariableType.text, value: ''),
      const Variable(name: 'downs', type: VariableType.integer, value: 0),
      const Variable(name: 'items', type: VariableType.list, value: ['a', 'b', 'c']),
    ]);
    final doc = paintDoc({
      'viewBox': [30, 10],
      'painter': [
        {'op': 'repeat', 'each': r'${items}', 'ops': [
          {'op': 'rect', 'rect': [r'${= index * 10}', 0, 10, 10], 'paint': '#FFFF0000', 'hit': r'cell-${item}'},
        ]},
        // An invisible target (no paint) over the last cell's corner.
        {'op': 'circle', 'c': [28, 2], 'radius': 2, 'hit': 'corner'},
      ],
    }, w: 60, h: 20, extra: {
      'actions': [
        {'trigger': {'type': 'click'}, 'actions': [
          {'type': 'setVariable', 'variable': 'picked', 'value': r'${result.region}/${result.item}/${result.index}'},
          {'type': 'setVariable', 'variable': 'at', 'value': r'${result.viewX},${result.viewY}'},
        ]},
        {'trigger': {'type': 'pointerDown'}, 'actions': [
          {'type': 'setVariable', 'variable': 'downs', 'op': 'add', 'value': '1'},
        ]},
      ],
    });
    final values = NodeValues(DocumentSource(doc));
    final tree = NodeTree(values, binder: NodeBinder(scope: scope));
    final context = RuntimeActionContext(scope: scope, ui: const NoActionUi(), tree: tree, nodeValues: values, services: Services());
    final reactions = TreeReactions(runner: const CodelesslyActions(), context: context);
    tree.interactions = reactions;
    addTearDown(() {
      reactions.dispose();
      tree.dispose();
    });
    await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'b', interactive: true))));
    final origin = tester.getTopLeft(find.byType(NodeView));

    await tester.tapAt(origin + const Offset(30, 10)); // the middle cell: view (15, 5)
    await tester.pumpAndSettle();
    expect(scope.read('picked'), 'cell-b/b/1');
    expect(scope.read('at'), '15.0,5.0');
    expect(scope.read('downs'), 1);

    await tester.tapAt(origin + const Offset(57, 3)); // the invisible corner, over cell c
    await tester.pumpAndSettle();
    expect(scope.read('picked'), 'corner//', reason: 'the topmost region; it was drawn outside a repeat');

    await tester.tapAt(origin + const Offset(5, 15));
    await tester.pumpAndSettle();
    expect(scope.read('picked'), 'cell-a/a/0');
    expect(scope.read('downs'), 3);
  });

  testWidgets('a 48 × 48 board as one node: paints once, repaints only for its data', (tester) async {
    pixelRatioOne(tester);
    tester.view.physicalSize = const Size(600, 600);
    final cells = List<int>.generate(48 * 48, (i) => (i * 7 + i ~/ 48) % 3);
    final scope = VariableScope([
      Variable(name: 'cells', type: VariableType.list, value: cells),
      const Variable(name: 'pal', type: VariableType.list, value: ['#00000000', '#FF4CAF50', '#FF3F51B5']),
      const Variable(name: 'clock', type: VariableType.integer, value: 0),
    ]);
    final tree = NodeTree(
      DocumentSource(paintDoc({
        'viewBox': [48, 48],
        'willChange': true,
        'painter': [
          {'op': 'rect', 'rect': [0, 0, 48, 48], 'paint': '#FFF3E7B8'},
          {'op': 'repeat', 'each': r'${cells}', 'ops': [
            {'op': 'rect', 'when': r'${= item != 0}', 'rect': [r'${= index % 48}', r'${= floor(index / 48)}', 1, 1], 'paint': r'${pal[item]}'},
          ]},
        ],
      }, w: 480, h: 480)),
      binder: NodeBinder(scope: scope),
    );
    addTearDown(tree.dispose);
    final watch = Stopwatch()..start();
    await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'b'))));
    final first = watch.elapsedMilliseconds;
    final layer = _layer(tree, 'b');
    expect(layer.debugRecordCount, 2, reason: 'each top-level op drawn once');

    scope.set('clock', 1);
    await tester.pump();
    expect(layer.debugRecordCount, 2, reason: 'a name the board doesn\'t read changes nothing');

    // A generation: the repeat draws again, the background doesn't.
    watch.reset();
    scope.set('cells', [for (final c in cells) (c + 1) % 3]);
    await tester.pump();
    final step = watch.elapsedMilliseconds;
    expect(layer.debugRecordCount, 3);
    // ignore: avoid_print
    print('48×48 board: first frame ${first}ms, a generation ${step}ms (debug test runner)');
    expect(step, lessThan(2000), reason: 'a sanity bound, not a benchmark');
  });
}
