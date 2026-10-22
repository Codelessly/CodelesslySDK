import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

RectangleNode rect(String id, String parent, double height) => RectangleNode(
  id: id,
  name: id,
  basicBoxLocal: NodeBox(0, 0, 200, height),
  fills: [PaintModel.solid(id: 'f', color: ColorRGB.fromHex('#3366FF'))],
)..parentID = parent;

/// A list's loading, empty and error states: the default variant holds the
/// content, loading is a skeleton of it, empty and error have their own.
VarianceNode states() => VarianceNode(
  id: 'states',
  name: 'States',
  basicBoxLocal: NodeBox(0, 0, 200, 120),
  variables: {'currentVariantId': 'status'},
  variants: [
    Variant(id: 'default', name: 'Loaded', children: ['content']),
    Variant(
      id: kQueryStatusLoading,
      name: 'Loading',
      children: [],
      skeleton: true,
    ),
    Variant(id: kQueryStatusEmpty, name: 'Empty', children: ['nothing']),
    Variant(id: kQueryStatusError, name: 'Error', children: ['oops']),
  ],
)..parentID = kRootNode;

void main() {
  for (final Size screen in const [
    Size(390, 844),
    Size(834, 1194),
    Size(1440, 900),
  ]) {
    testWidgets('a list status picks its state and keeps the list built at '
        '${screen.width.toInt()}', (tester) async {
      tester.view.physicalSize = screen;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final VarianceNode node = states();
      final registry = NodeRegistry()
        ..setNodes({
          for (final BaseNode n in [
            node,
            rect('content', 'states', 120),
            rect('nothing', 'states', 40),
            rect('oops', 'states', 30),
          ])
            n.id: n,
        });
      final manager = PassiveNodeTransformerManager(
        registry.getNodeByID,
        (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
      );
      final Observable<VariableData> status = Observable(
        VariableData(
          id: 'status',
          name: 'status',
          type: VariableType.text,
          value: kQueryStatusLoading,
        ),
      );
      await tester.pumpWidget(
        ChangeNotifierProvider<CodelesslyContext>.value(
          value: CodelesslyContext.empty()..variables['status'] = status,
          child: MaterialApp(
            home: Align(
              alignment: Alignment.topLeft,
              child: Builder(
                builder: (context) => manager.buildWidgetFromNode(
                  node,
                  context,
                  settings: const WidgetBuildSettings(debugLabel: 'test'),
                ),
              ),
            ),
          ),
        ),
      );

      final Element loaded = tester.element(
        find.byKey(const ValueKey('loaded')),
      );
      bool skeleton() => tester.widget<Skeleton>(find.byType(Skeleton)).enabled;
      bool hidden() => tester
          .widget<Offstage>(find.byKey(const ValueKey('loaded')))
          .offstage;

      // Loading: the content shimmers as a skeleton.
      expect(skeleton(), isTrue);
      expect(hidden(), isFalse);

      status.set(status.value.copyWith(value: kQueryStatusEmpty));
      await tester.pump();
      expect(hidden(), isTrue);
      expect(find.byKey(const ValueKey(kQueryStatusEmpty)), findsOneWidget);

      status.set(status.value.copyWith(value: kQueryStatusLoaded));
      await tester.pump();
      expect(hidden(), isFalse);
      expect(skeleton(), isFalse);
      expect(find.byKey(const ValueKey(kQueryStatusEmpty)), findsNothing);

      // The content (the list) was never rebuilt from scratch.
      expect(
        tester.element(find.byKey(const ValueKey('loaded'))),
        same(loaded),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a skeleton shows a few sample items of a list', (tester) async {
    // SkeletonScope tells a loading list to show sample items.
    late bool inSkeleton;
    await tester.pumpWidget(
      MaterialApp(
        home: Skeleton(
          enabled: true,
          child: Builder(
            builder: (context) {
              inSkeleton = SkeletonScope.of(context);
              return const SizedBox(width: 10, height: 10);
            },
          ),
        ),
      ),
    );
    expect(inSkeleton, isTrue);
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.takeException(), isNull);
  });
}
