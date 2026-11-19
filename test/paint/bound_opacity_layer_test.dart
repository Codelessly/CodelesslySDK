import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart' hide Node;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// A node whose opacity is bound composites as Flutter's Opacity widget does:
// through an opacity layer at every visible value, 1 included (a button the
// reference wraps in Opacity(onTap == null ? 0.45 : 1)). The layer stays the
// same as the value changes. A node with a fixed opacity of 1 draws straight
// on the page, with no layer. A node whose transitions animate its
// opacity keeps the layer the same way (its transition player draws it).

List<RenderOpacity> _opacities(RenderObject root) {
  final out = <RenderOpacity>[];
  void visit(RenderObject o) {
    if (o is RenderOpacity) out.add(o);
    o.visitChildren(visit);
  }

  visit(root);
  return out;
}

/// A node's transition player (its RenderAnimations).
RenderObject _player(RenderObject root) {
  RenderObject? out;
  void visit(RenderObject o) {
    if (out == null && o.runtimeType.toString() == 'RenderAnimations') out = o;
    o.visitChildren(visit);
  }

  visit(root);
  return out!;
}

void main() {
  testWidgets('a bound opacity keeps an opacity layer at 1; a fixed 1 has none', (tester) async {
    final scope = VariableScope([Variable(id: 'o', name: 'o', type: VariableType.decimal, value: 1.0)]);
    final tree = NodeTree(
      DocumentSource(LayoutDocument.fromJson({
        'schema': 3,
        'roots': ['col'],
        'nodes': {
          'col': {'type': 'column', 'children': ['bound', 'fixed', 'constant', 'plain'], 'layout': {'width': 100, 'height': {'hug': 80}}},
          'bound': {
            'type': 'box',
            'layout': {'width': 60, 'height': 30},
            'decoration': {'strokes': [{'color': '#FFE9D9B4'}], 'strokeWidth': 1.4, 'radius': 4},
            'bind': {'opacity': r'${o}'},
          },
          'constant': {
            'type': 'row',
            'layout': {'width': 60, 'height': 30},
            'decoration': {'fills': [{'color': '#00000000'}], 'strokes': [{'color': '#FFE9D9B4'}], 'strokeWidth': 1.4, 'radius': 4},
            'bind': {'opacity': r'${= 1}'},
            'states': {'pressed': {'@constant': {'motion': {'scale': 0.97}}}},
            'transitions': [{'property': 'opacity', 'duration': 120}, {'property': 'motion.scale', 'duration': 120}, {'property': 'decoration.fills', 'duration': 120}, {'property': 'visible', 'duration': 120}],
          },
          'plain': {
            'type': 'row',
            'layout': {'width': 60, 'height': 30},
            'decoration': {'fills': [{'color': '#00000000'}], 'strokes': [{'color': '#FFE9D9B4'}], 'strokeWidth': 1.4, 'radius': 4},
            'states': {'pressed': {'@plain': {'motion': {'scale': 0.97}}}},
            'transitions': [{'property': 'opacity', 'duration': 120}, {'property': 'motion.scale', 'duration': 120}, {'property': 'decoration.fills', 'duration': 120}, {'property': 'visible', 'duration': 120}],
          },
          'fixed': {
            'type': 'box',
            'layout': {'width': 60, 'height': 30},
            'decoration': {'strokes': [{'color': '#FFE9D9B4'}], 'strokeWidth': 1.4, 'radius': 4},
          },
        },
      })),
      binder: NodeBinder(scope: scope),
    );
    addTearDown(tree.dispose);
    await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'col'))));

    final layer = _opacities(tree.boxOf('bound')!).single;
    expect(layer.opacity, 1);
    expect(layer.alwaysNeedsCompositing, isTrue);
    expect(_opacities(tree.boxOf('fixed')!), isEmpty);
    // Two opacity layers: the bound box's, and the constant-bound button's
    // (drawn by its transition player, which takes over its opacity: an
    // expression always 1 still binds); none for the fixed box.
    expect(_player(tree.boxOf('constant')!).alwaysNeedsCompositing, isTrue);
    expect(_player(tree.boxOf('plain')!).alwaysNeedsCompositing, isFalse);

    // Dimmed, as a disabled button: the same layer, at the new value.
    scope.set('o', 0.45);
    await tester.pump();
    expect(_opacities(tree.boxOf('bound')!).single, same(layer));
    expect(layer.opacity, closeTo(0.45, 1e-9));
  });
}
