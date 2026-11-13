// A legacy motion's clocks on the one animation player: a spin speeding up
// over its ramp and winding down when paused, a counted loop ending where
// Flutter's repeat(count:) ends, and a motion transition through keyframes
// (a card that swells as it turns over).
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> doc(Map<String, Object?> node) => {
      'roots': ['s'],
      'nodes': {
        's': {'type': 'stack', 'children': ['b'], 'layout': {'width': 400, 'height': 300}},
        'b': {'type': 'box', 'layout': {'width': 40, 'height': 40, 'x': {'start': 100}, 'y': {'start': 100}}, ...node},
      },
    };

Future<(NodeTree, DocumentSource, RenderObject)> show(WidgetTester tester, Map<String, Object?> node) async {
  final source = DocumentSource(api.LayoutDocument.fromJson(doc(node)));
  final tree = NodeTree(source);
  addTearDown(tree.dispose);
  await tester.pumpWidget(MaterialApp(
    home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 's', interactive: true)),
  ));
  return (tree, source, tester.renderObject(find.byType(NodeView)));
}

void main() {
  testWidgets('a spin speeds up over its ramp and winds down when paused', (tester) async {
    Map<String, Object?> node(bool paused) => {
          'motion': {'spin': 1, 'spinRamp': 1000, 'paused': paused},
        };
    final (tree, source, _) = await show(tester, node(false));
    final spin = tree.boxOf('b')!.animations!.clockOf('spin')!;
    await tester.pump();
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    // Half way up a linear ramp to 1 turn/s: 0.5 · 0.5 · 0.5 = 0.125 turns.
    expect(spin.value, closeTo(0.125, 0.01));
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    // 1 s up (0.5 turns), then 0.5 s at full speed.
    expect(spin.value, closeTo(1.0 % 1, 0.02));
    source.document = api.LayoutDocument.fromJson(doc(node(true)));
    await tester.pump();
    final stopAt = spin.value;
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // Winding down (the speed falls by its own share of the ramp each
    // moment, as the motion's spin did): most of a turn more (the ramp's
    // length at the speed it had, less what the steps lose), then still.
    expect((spin.value - stopAt) % 1, inInclusiveRange(0.85, 1));
    expect(spin.isAnimating, isFalse);
  });

  testWidgets('a counted restart loop ends at its start (rest)', (tester) async {
    final (tree, _, view) = await show(tester, {
      'motion': {'translateX': 50, 'loop': 'restart', 'repeat': 2, 'duration': 200, 'curve': 'linear'},
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tree.boxOf('b')!.rectIn(view)!.left, closeTo(125, 1));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(tree.boxOf('b')!.rectIn(view)!.left, closeTo(100, 0.5));
  });

  testWidgets('a motion transition passes its keyframes on any change (a swell as it turns)', (tester) async {
    Map<String, Object?> node(double turn) => {
          'motion': {'rotateY': turn, 'perspective': 0, 'duration': 400, 'curve': 'linear', 'keyframes': [{'t': 0.5, 'scale': 2}]},
        };
    final (tree, source, view) = await show(tester, node(0));
    await tester.pump();
    source.document = api.LayoutDocument.fromJson(doc(node(180)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    // Edge on, and swollen to twice its height.
    final r = tree.boxOf('b')!.rectIn(view)!;
    expect(r.height, closeTo(80, 1));
    expect(r.width, lessThan(2));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tree.boxOf('b')!.rectIn(view)!.height, closeTo(40, 0.5));
  });
}
