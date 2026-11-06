import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A card that clips its content (a photo with rounded corners) keeps its
/// border outside the clip, as Flutter's Container does: clipped too, the
/// border's edge was cut, leaving a light seam between it and the shadow.
void main() {
  Future<void> pump(WidgetTester tester, {required bool clips}) async {
    final RectangleNode card = RectangleNode(
      id: 'card',
      name: 'Card',
      basicBoxLocal: NodeBox(0, 0, 200, 120),
      cornerRadius: const CornerRadius.all(RadiusModel.circular(6)),
      fills: [PaintModel.solid(id: 'f', color: ColorRGB.fromHex('#FFFBF2'))],
      strokes: [PaintModel.solid(id: 's', color: ColorRGB.fromHex('#1F2A44'))],
      strokeWeight: 2.5,
    )..parentID = kRootNode;
    if (!clips) {
      card
        ..cornerRadius = CornerRadius.zero
        ..clipsContent = false;
    }
    final registry = NodeRegistry()..setNodes({card.id: card});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty(),
        child: MaterialApp(
          home: Center(
            child: Builder(
              builder: (context) => manager.buildWidgetFromNode(
                card,
                context,
                settings: const WidgetBuildSettings(debugLabel: 'test'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Finder border() => find.byWidgetPredicate(
    (w) =>
        w is DecoratedBox &&
        w.decoration is BoxDecoration &&
        (w.decoration as BoxDecoration).border != null,
  );

  testWidgets('a clipping card paints its border outside the clip', (
    tester,
  ) async {
    await pump(tester, clips: true);
    expect(border(), findsOneWidget);
    // No clip around the border; the fill is clipped to the corners.
    expect(
      find.ancestor(of: border(), matching: find.byType(ClipRRect)),
      findsNothing,
    );
    expect(
      find.ancestor(of: border(), matching: find.byType(ClipPath)),
      findsNothing,
    );
    expect(find.byType(ClipRRect), findsWidgets);
  });

  testWidgets('a card that does not clip is built as before', (tester) async {
    await pump(tester, clips: false);
    expect(border(), findsOneWidget);
    expect(find.byType(ClipRRect), findsNothing);
  });
}
