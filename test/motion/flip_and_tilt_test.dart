
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// Behaviors, at rest and running: motion swing,
// phase, pause, arc, wrapping and paced paths, upright orientation and
// shimmer; loop phases; drag tracks parked, relative and in their parent.

Map<String, Object?> doc(Map<String, Map<String, Object?>> nodes) => {
      'roots': ['s'],
      'nodes': {
        's': {'type': 'stack', 'children': nodes.keys.toList(), 'layout': {'width': 400, 'height': 300}},
        ...nodes,
      },
    };

Future<(NodeTree, RenderObject, DocumentSource)> showDoc(WidgetTester tester, Map<String, Object?> json,
    {bool interactive = false}) async {
  final source = DocumentSource(api.LayoutDocument.fromJson(json));
  final tree = NodeTree(source);
  addTearDown(tree.dispose);
  await tester.pumpWidget(MaterialApp(
    home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 's', interactive: interactive)),
  ));
  return (tree, tester.renderObject(find.byType(NodeView)), source);
}

Future<(NodeTree, RenderObject, DocumentSource)> show(WidgetTester tester, Map<String, Map<String, Object?>> nodes,
    {bool interactive = false}) async {
  final source = DocumentSource(api.LayoutDocument.fromJson(doc(nodes)));
  final tree = NodeTree(source);
  addTearDown(tree.dispose);
  await tester.pumpWidget(MaterialApp(
    home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 's', interactive: interactive)),
  ));
  return (tree, tester.renderObject(find.byType(NodeView)), source);
}

Map<String, Object?> box(Map<String, Object?> extra, {double x = 0, double y = 0, double size = 20}) => {
      'type': 'box',
      'layout': {'width': size, 'height': size, 'x': {'start': x}, 'y': {'start': y}},
      ...extra,
    };

/// The ids of the node boxes a hit at [at] goes through.
Set<String> hitIds(WidgetTester tester, NodeTree tree, Offset at, List<String> ids) {
  final result = tester.hitTestOnBinding(at);
  final targets = {for (final e in result.path) e.target};
  return {
    for (final id in ids)
      if (targets.contains(tree.boxOf(id))) id,
  };
}

Map<String, Map<String, Object?>> card({bool flipped = false, Map<String, Object?> motion = const {}}) => {
      'card': {
        'type': 'stack',
        'children': ['front', 'back'],
        'layout': {'width': 100, 'height': 60, 'x': {'start': 0}, 'y': {'start': 0}},
        'flip': {if (flipped) 'flipped': true},
        if (motion.isNotEmpty) 'motion': motion,
      },
      'front': {'type': 'box', 'layout': {'width': 100, 'height': 60}, 'decoration': {'fills': [{'color': '#FFFF0000'}]}},
      'back': {'type': 'box', 'layout': {'width': 100, 'height': 60}, 'decoration': {'fills': [{'color': '#FF0000FF'}]}},
    };

// Flip cards and tilt in a running app:
// a card follows and writes its variable, turns under a drag, and the nodes
// inside read `${flip.*}` and `${tilt.*}`.

class Shown {
  Shown(this.tree, this.scope);
  final NodeTree tree;
  final VariableScope scope;
}

Future<Shown> showCard(WidgetTester tester, Map<String, Json> nodes, {List<Variable> variables = const []}) async {
  final doc = LayoutDocument.fromJson({
    'roots': ['s'],
    'nodes': {
      's': {
        'type': 'stack',
        'children': [for (final e in nodes.entries) if (e.value['root'] == true) e.key],
        'layout': {'width': 400, 'height': 300},
      },
      for (final e in nodes.entries) e.key: {...e.value}..remove('root'),
    },
  });
  final scope = VariableScope(variables);
  final values = NodeValues(DocumentSource(doc));
  final tree = NodeTree(values, binder: NodeBinder(scope: scope));
  final reactions = TreeReactions(
    runner: const CodelesslyActions(),
    context: RuntimeActionContext(scope: scope, tree: tree, nodeValues: values),
  );
  tree.interactions = reactions;
  addTearDown(() {
    reactions.dispose();
    tree.dispose();
  });
  await tester.pumpWidget(
    MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: NodeView(tree: tree, rootId: 's', interactive: true),
      ),
    ),
  );
  return Shown(tree, scope);
}

String textOf(NodeTree tree, String id) {
  RenderParagraph? found;
  void visit(RenderObject o) {
    if (o is RenderParagraph) found ??= o;
    o.visitChildren(visit);
  }

  visit(tree.boxOf(id)!);
  return found!.text.toPlainText();
}

Set<String> hitIdsAt(WidgetTester tester, NodeTree tree, Offset at, List<String> ids) {
  final targets = {for (final e in tester.hitTestOnBinding(at).path) e.target};
  return {
    for (final id in ids)
      if (targets.contains(tree.boxOf(id))) id,
  };
}

Map<String, Json> flipCard(Json flip) => {
  'card': {
    'root': true,
    'type': 'stack',
    'children': ['front', 'back'],
    'layout': {'width': 200, 'height': 120, 'x': {'start': 0}, 'y': {'start': 0}},
    'flip': flip,
  },
  'front': {
    'type': 'stack',
    'children': ['label'],
    'layout': {'width': 200, 'height': 120},
    'decoration': {
      'fills': [
        {'color': '#FFFF0000'},
      ],
    },
  },
  'label': {
    'type': 'text',
    'layout': {'width': 200, 'height': 20},
    'props': {'text': r'front ${flip.flipped}'},
  },
  'back': {
    'type': 'box',
    'layout': {'width': 200, 'height': 120},
    'decoration': {
      'fills': [
        {'color': '#FF0000FF'},
      ],
    },
  },
};

void main() {
  Map<String, Object?> cardDoc({bool flipped = false}) => {
        'roots': ['s'],
        'nodes': {
          's': {'type': 'stack', 'children': ['card'], 'layout': {'width': 400, 'height': 300}},
          ...card(flipped: flipped),
        },
      };

  testWidgets('a flip card shows the face it is turned to', (tester) async {
    final (tree, _, _) = await showDoc(tester, cardDoc(flipped: true));
    expect(hitIds(tester, tree, const Offset(50, 30), ['front', 'back']), {'back'});
    final (tree2, _, _) = await showDoc(tester, cardDoc());
    expect(hitIds(tester, tree2, const Offset(50, 30), ['front', 'back']), {'front'});
  });

  testWidgets('a tilting node tips toward the pointer and settles back when it leaves', (tester) async {
    final (tree, view, _) = await show(
        tester,
        {
          't': box({
            'tilt': {
              'max': {'rotateX': 0, 'rotateY': 0, 'scale': 1.5}
            },
          }, x: 100, y: 100, size: 40),
        },
        interactive: true);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(390, 290));
    addTearDown(mouse.removePointer);
    await mouse.moveTo(const Offset(120, 120));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(tree.boxOf('t')!.rectIn(view)!.width, closeTo(60, 0.5));
    await mouse.moveTo(const Offset(390, 290));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tree.boxOf('t')!.rectIn(view)!.width, closeTo(40, 0.5));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a tap turns a flip card over, and its faces can read which side shows', (tester) async {
    final s = await showCard(tester, flipCard({'variable': 'open'}), variables: [const Variable(name: 'open', type: VariableType.boolean, value: false)]);
    expect(textOf(s.tree, 'label'), 'front false');
    await tester.tapAt(const Offset(100, 60));
    await tester.pump();
    expect(s.scope.read('open'), true);
    await tester.pump(const Duration(milliseconds: 700));
    expect(hitIdsAt(tester, s.tree, const Offset(100, 60), ['front', 'back']), {'back'});
    expect(textOf(s.tree, 'label'), 'front true');
    // The variable set elsewhere turns it back.
    s.scope.set('open', false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(hitIdsAt(tester, s.tree, const Offset(100, 60), ['front', 'back']), {'front'});
  });

  testWidgets('dragging a flip card past halfway turns it, and short of that it springs back', (tester) async {
    final s = await showCard(
      tester,
      flipCard({'variable': 'open', 'dragToFlip': true, 'tapToFlip': false}),
      variables: [const Variable(name: 'open', type: VariableType.boolean, value: false)],
    );
    // A short drag left, slowly: back to the front.
    var g = await tester.startGesture(const Offset(150, 60));
    for (var i = 0; i < 10; i++) {
      await g.moveBy(const Offset(-4, 0));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 200));
    await g.up();
    await tester.pumpAndSettle();
    expect(s.scope.read('open'), false);
    expect(hitIdsAt(tester, s.tree, const Offset(100, 60), ['front', 'back']), {'front'});
    // Past halfway (120 of 200px): it turns over.
    g = await tester.startGesture(const Offset(180, 60));
    for (var i = 0; i < 12; i++) {
      await g.moveBy(const Offset(-10, 0));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 200));
    await g.up();
    await tester.pumpAndSettle();
    expect(s.scope.read('open'), true);
    expect(hitIdsAt(tester, s.tree, const Offset(100, 60), ['front', 'back']), {'back'});
  });

  testWidgets('the nodes inside a tilting node can read the tilt as the pointer moves', (tester) async {
    final s = await showCard(tester, {
      't': {
        'root': true,
        'type': 'stack',
        'children': ['label'],
        'layout': {'width': 200, 'height': 100, 'x': {'start': 0}, 'y': {'start': 0}},
        'tilt': {
          'max': {'rotateX': 0, 'rotateY': 0},
        },
      },
      'label': {
        'type': 'text',
        'layout': {'width': 200, 'height': 100},
        'props': {'text': r'${tilt.x} ${tilt.active}'},
      },
    });
    expect(textOf(s.tree, 'label'), '0 false');
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(390, 290));
    addTearDown(mouse.removePointer);
    await mouse.moveTo(const Offset(150, 50));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(textOf(s.tree, 'label'), '0.5 true');
    await mouse.moveTo(const Offset(390, 290));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(textOf(s.tree, 'label'), '0 false');
  });
}
