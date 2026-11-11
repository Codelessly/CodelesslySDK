// A node box whose chain was rebuilt after layout isn't hit until it's laid
// out: hit testing it (the mouse tracker does after every frame) threw in
// debug builds and broke every later pointer event.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a box with an unlaid child is not hit, then is hit tested normally once laid out', (tester) async {
    final doc = LayoutDocument.fromJson({
      'roots': ['b'],
      'nodes': {
        'b': {'type': 'box', 'layout': {'width': 100, 'height': 100}, 'decoration': {'fills': [{'color': '#FF000000'}]}},
      },
    });
    final scope = VariableScope(const []);
    final tree = NodeTree(NodeValues(DocumentSource(doc)), binder: NodeBinder(scope: scope));
    addTearDown(tree.dispose);
    await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'b'))));
    final box = tree.boxOf('b')!;
    expect(box.hitTest(BoxHitTestResult(), position: const Offset(50, 50)), isTrue);
    // A fresh child, not laid out yet (what a chain rebuilt after layout is).
    box.child = RenderConstrainedBox(additionalConstraints: const BoxConstraints.tightFor(width: 100, height: 100));
    expect(box.hitTest(BoxHitTestResult(), position: const Offset(50, 50)), isFalse);
    box.markNeedsLayout();
    await tester.pump();
    expect(box.child!.hasSize, isTrue);
    expect(() => box.hitTest(BoxHitTestResult(), position: const Offset(50, 50)), returnsNormally);
  });
}
