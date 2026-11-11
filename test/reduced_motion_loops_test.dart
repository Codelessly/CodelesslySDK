// With the platform asking for no animation (prefers-reduced-motion), a
// loop rests at its first frame, as the design canvas draws it.
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/behaviors.dart' show RenderLoops;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<RenderLoops> show(WidgetTester tester) async {
    final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({
      'roots': ['g'],
      'nodes': {
        'g': {
          'type': 'box',
          'layout': {'width': 64, 'height': 64},
          'decoration': {'fills': [{'color': '#FFFF0000'}]},
          'loops': [{'type': 'flicker', 'duration': 600, 'opacityFrom': 0.5, 'opacityTo': 0.9}],
        },
      },
    })));
    addTearDown(tree.dispose);
    await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'g', interactive: true))));
    RenderLoops? loops;
    void visit(RenderObject o) {
      if (o is RenderLoops) loops ??= o;
      o.visitChildren(visit);
    }

    visit(tester.renderObject(find.byType(NodeView)));
    return loops!;
  }

  final first = 0.5 + (0.9 - 0.5) * api.flickerAt(0);

  testWidgets('reduced motion: a flicker rests at its first frame', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final loops = await show(tester);
    for (final ms in [37, 120, 260]) {
      await tester.pump(Duration(milliseconds: ms));
      expect(loops.opacity, closeTo(first, 1e-9));
    }
    expect(tester.binding.hasScheduledFrame, isFalse, reason: 'nothing ticks');
  });

  testWidgets('otherwise it flickers', (tester) async {
    final loops = await show(tester);
    final seen = <double>{};
    for (final ms in [37, 120, 260]) {
      await tester.pump(Duration(milliseconds: ms));
      seen.add(loops.opacity);
    }
    expect(seen.length, greaterThan(1));
    await tester.pumpWidget(const SizedBox());
  });
}
