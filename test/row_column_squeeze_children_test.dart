import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A column whose fixed children are taller than it shrinks them to fit,
/// unless it lets them overflow (`squeezeChildren: false`), as a Flutter
/// Column does: Safecracker's mobile vault column is 2 px taller than the
/// screen, and the reference keeps its info strip at 90.
void main() {
  Future<List<double>> heights(WidgetTester tester, {required bool squeeze}) async {
    final nodes = <BaseNode>[
      RowColumnNode(
        id: 'col',
        name: 'col',
        rowColumnType: RowColumnType.column,
        basicBoxLocal: NodeBox(0, 0, 100, 100),
        horizontalFit: SizeFit.fixed,
        verticalFit: SizeFit.fixed,
        crossAxisAlignment: CrossAxisAlignmentC.stretch,
        mainAxisAlignment: MainAxisAlignmentC.start,
        children: ['a', 'b'],
      )
        ..parentID = kRootNode
        ..squeezeChildren = squeeze,
      for (final id in ['a', 'b'])
        FrameNode(
          id: id,
          name: id,
          basicBoxLocal: NodeBox(0, 0, 100, 51),
          horizontalFit: SizeFit.expanded,
          verticalFit: SizeFit.fixed,
          children: [],
        )..parentID = 'col',
    ];
    final registry = NodeRegistry()..setNodes({for (final n in nodes) n.id: n});
    final manager = PassiveNodeTransformerManager(registry.getNodeByID, (a, b, c, d, e) => const SizedBox());
    await tester.pumpWidget(ChangeNotifierProvider<CodelesslyContext>.value(
      value: CodelesslyContext.empty(),
      child: MaterialApp(
        home: Material(
          child: Align(
            alignment: Alignment.topLeft,
            child: Builder(
              builder: (context) => manager.buildWidgetFromNode(nodes.first, context,
                  settings: const WidgetBuildSettings(debugLabel: 'test', withReactions: false)),
            ),
          ),
        ),
      ),
    ));
    return [for (final id in ['a', 'b']) tester.getSize(find.byKey(ValueKey(id)).first).height];
  }

  testWidgets('by default, children that overflow shrink to fit', (tester) async {
    final List<double> h = await heights(tester, squeeze: true);
    expect(h[0] + h[1], closeTo(100, 0.01));
  });

  testWidgets('squeezeChildren false keeps them at their size, overflowing', (tester) async {
    final List<double> h = await heights(tester, squeeze: false);
    expect(h, [51, 51]);
    // Flutter reports the overflow; the layout is the point here.
    expect(tester.takeException(), anyOf(isNull, isA<FlutterError>()));
  });
}
