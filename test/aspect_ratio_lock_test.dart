import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A node with its aspect ratio locked keeps it at runtime when it fills
/// an axis, like a floor plan that fills the width of a narrow screen.
void main() {
  Future<Size> sizeOf(
    WidgetTester tester, {
    required SizeFit horizontal,
    required SizeFit vertical,
    required Size slot,
    bool locked = true,
  }) async {
    final FrameNode plan = FrameNode(
      id: 'plan',
      name: 'plan',
      basicBoxLocal: NodeBox(0, 0, 600, 400),
      horizontalFit: horizontal,
      verticalFit: vertical,
      aspectRatioLock: locked,
      children: const [],
    )..parentID = kRootNode;
    final registry = NodeRegistry()..setNodes({plan.id: plan});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty(),
        child: MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: slot.width,
              height: slot.height,
              child: Align(
                alignment: Alignment.topLeft,
                child: Builder(
                  builder: (context) => manager.buildWidgetFromNode(
                    plan,
                    context,
                    settings: const WidgetBuildSettings(debugLabel: 'test'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    return tester.getSize(
      find.byKey(const ValueKey('Rectangle Transformer of plan [plan]')),
    );
  }

  testWidgets('filling the width, the height follows', (tester) async {
    expect(
      await sizeOf(
        tester,
        horizontal: SizeFit.expanded,
        vertical: SizeFit.fixed,
        slot: const Size(300, 800),
      ),
      const Size(300, 200),
    );
  });

  testWidgets('filling the height, the width follows', (tester) async {
    expect(
      await sizeOf(
        tester,
        horizontal: SizeFit.fixed,
        vertical: SizeFit.expanded,
        slot: const Size(800, 100),
      ),
      const Size(150, 100),
    );
  });

  testWidgets('filling both, the largest box of the ratio fits', (
    tester,
  ) async {
    expect(
      await sizeOf(
        tester,
        horizontal: SizeFit.expanded,
        vertical: SizeFit.expanded,
        slot: const Size(900, 300),
      ),
      const Size(450, 300),
    );
    expect(
      await sizeOf(
        tester,
        horizontal: SizeFit.expanded,
        vertical: SizeFit.expanded,
        slot: const Size(300, 900),
      ),
      const Size(300, 200),
    );
  });

  testWidgets('without the lock it fills and keeps its design height', (
    tester,
  ) async {
    expect(
      await sizeOf(
        tester,
        horizontal: SizeFit.expanded,
        vertical: SizeFit.fixed,
        slot: const Size(300, 800),
        locked: false,
      ),
      const Size(300, 400),
    );
  });
}
