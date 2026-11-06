import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Finder _of(String id) =>
    find.byKey(ValueKey('Rectangle Transformer of $id [$id]'));

/// A progress bar: a padded row track with a fill whose share is bound.
Future<void> _pumpBar(
  WidgetTester tester, {
  required String widthFactor,
  SizeFit trackFit = SizeFit.fixed,
}) async {
  final RectangleNode fill = RectangleNode(
    id: 'fill',
    name: 'fill',
    basicBoxLocal: NodeBox(2, 2, 100, 10),
    verticalFit: SizeFit.expanded,
  )..variables['widthFactor'] = widthFactor;
  final RowColumnNode track = RowColumnNode(
    id: 'track',
    name: 'track',
    basicBoxLocal: NodeBox(0, 0, 300, 14),
    rowColumnType: RowColumnType.row,
    mainAxisAlignment: MainAxisAlignmentC.start,
    crossAxisAlignment: CrossAxisAlignmentC.stretch,
    horizontalFit: trackFit,
    padding: const EdgeInsetsModel.all(2),
    children: ['fill'],
  );
  final RowColumnNode root = RowColumnNode(
    id: 'root',
    name: 'root',
    basicBoxLocal: NodeBox(0, 0, 300, 100),
    rowColumnType: RowColumnType.column,
    mainAxisAlignment: MainAxisAlignmentC.start,
    crossAxisAlignment: CrossAxisAlignmentC.stretch,
    children: ['track'],
  )..parentID = kRootNode;
  track.parentID = root.id;
  fill.parentID = track.id;
  final NodeRegistry registry = NodeRegistry()
    ..setNodes({root.id: root, track.id: track, fill.id: fill});
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
          child: Builder(
            builder: (c) => manager.buildWidgetFromNode(
              root,
              c,
              settings: const WidgetBuildSettings(debugLabel: 'test'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a bound widthFactor sizes a fill in a fixed row track', (
    tester,
  ) async {
    await _pumpBar(tester, widthFactor: r'${= 14 / 18}');
    expect(tester.getSize(_of('fill')).width, closeTo(296 * 14 / 18, 0.5));
  });

  testWidgets('a bound widthFactor sizes a fill in an expanded row track', (
    tester,
  ) async {
    await _pumpBar(
      tester,
      widthFactor: r'${= 6 / 18}',
      trackFit: SizeFit.expanded,
    );
    expect(tester.getSize(_of('fill')).width, closeTo(296 * 6 / 18, 0.5));
  });
}
