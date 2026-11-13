import 'dart:math' as math;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/behaviors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show BoxHitTestResult, RenderConstrainedBox;
import 'package:flutter_test/flutter_test.dart';

void main() {
  late RenderAnimations player;
  Future<RenderMotion> mount(WidgetTester tester, Map<String, Object?> motion) async {
    final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({
      'roots': ['card'],
      'nodes': {
        'card': {'type': 'box', 'layout': {'width': 100, 'height': 100}, 'motion': motion},
      },
    })));
    addTearDown(tree.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'card', interactive: true)),
    ));
    RenderMotion? found;
    void visit(RenderObject o) {
      if (o is RenderMotion) found = o;
      // The opacity is the node's now, drawn by its animation player.
      if (o is RenderAnimations) player = o;
      o.visitChildren(visit);
    }

    visit(tree.boxOf('card')!);
    return found!;
  }

  double degrees(RenderMotion m) {
    final t = m.effectiveTransform.storage;
    return math.atan2(t[1], t[0]) * 180 / math.pi;
  }

  const entrance = {
    'enter': true,
    'enterFrom': {'translateY': 40, 'rotate': 8, 'opacity': 0},
    'duration': 1000,
    'curve': 'easeOutBack',
  };

  testWidgets('an entrance wobbles upright on its own rotation curve and fades in first', (tester) async {
    final m = await mount(tester, {...entrance, 'rotateCurve': 'elasticOut', 'fadeShare': 0.35});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 175));
    expect(player.opacity, closeTo(AnimationCurve.easeOut.transform(0.5), 0.03));
    await tester.pump(const Duration(milliseconds: 75));
    // elasticOut overshoots past upright by a quarter of the way in.
    expect(degrees(m), lessThan(-0.3));
    await tester.pump(const Duration(milliseconds: 150));
    expect(player.opacity, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(degrees(m), closeTo(0, 1e-6));
    expect(player.opacity, 1);
  });

  testWidgets('without them every property follows the one curve', (tester) async {
    final m = await mount(tester, entrance);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(degrees(m), greaterThan(0.5));
    expect(player.opacity, lessThan(1));
  });

  test('a pose layer not laid out yet is not hit (and does not throw)', () {
    final pose = RenderPose()
      ..child = RenderConstrainedBox(additionalConstraints: const BoxConstraints.tightFor(width: 10, height: 10))
      ..transform = Matrix4.rotationZ(0.1);
    expect(pose.hitTest(BoxHitTestResult(), position: const Offset(5, 5)), isFalse);
  });
}
