import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

FreeformPlacement at(double x, double y) => FreeformPlacement(
  horizontal: FreeformAxisPlacement(
    mode: FreeformAxisMode.fraction,
    start: 0,
    extent: 20,
    parentExtent: 200,
    size: 20,
    fraction: x,
  ),
  vertical: FreeformAxisPlacement(
    mode: FreeformAxisMode.fraction,
    start: 0,
    extent: 20,
    parentExtent: 200,
    size: 20,
    fraction: y,
  ),
);

/// Two pins placed by data in a freeform container, like the floor plan.
Widget plan(FreeformPlacement a, FreeformPlacement b) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: 200,
      height: 200,
      child: FreeformLayout(
        wrapsWidth: false,
        wrapsHeight: false,
        designSize: const Size(200, 200),
        children: [
          FreeformChild(
            placement: a,
            child: Semantics(
              button: true,
              label: 'Pin A',
              child: const SizedBox(width: 20, height: 20),
            ),
          ),
          FreeformChild(
            placement: b,
            child: Semantics(
              button: true,
              label: 'Pin B',
              child: const SizedBox(width: 20, height: 20),
            ),
          ),
        ],
      ),
    ),
  ),
);

void main() {
  testWidgets('a child moved by data moves its semantics box too', (
    tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(plan(at(0.1, 0.1), at(0.5, 0.5)));
    Rect rectOf(String label) {
      final SemanticsNode node = tester.getSemantics(
        find.bySemanticsLabel(label),
      );
      return MatrixUtils.transformRect(
        node.transform ?? Matrix4.identity(),
        node.rect,
      ).shift(Offset.zero);
    }

    final Offset before = tester.getTopLeft(find.bySemanticsLabel('Pin A'));
    // Only A moves; B keeps its place.
    await tester.pumpWidget(plan(at(0.8, 0.8), at(0.5, 0.5)));
    final Offset after = tester.getTopLeft(find.bySemanticsLabel('Pin A'));
    expect(after, isNot(before));
    // The semantics node's box follows the painted child.
    final Rect painted = tester.getRect(find.bySemanticsLabel('Pin A'));
    final SemanticsNode node = tester.getSemantics(
      find.bySemanticsLabel('Pin A'),
    );
    final Rect global = _globalRect(node);
    final double dpr = tester.view.devicePixelRatio;
    expect(global.topLeft, painted.topLeft * dpr);
    expect(rectOf('Pin B'), isNotNull);
    handle.dispose();
  });
}

/// [node]'s rect in global coordinates, through its ancestors' transforms.
Rect _globalRect(SemanticsNode node) {
  Rect rect = node.rect;
  SemanticsNode? current = node;
  while (current != null) {
    if (current.transform != null) {
      rect = MatrixUtils.transformRect(current.transform!, rect);
    }
    current = current.parent;
  }
  return rect;
}
