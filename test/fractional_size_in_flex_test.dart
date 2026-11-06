import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Finder _of(String id) =>
    find.byKey(ValueKey('Rectangle Transformer of $id [$id]'));

/// A progress track, a [type] row or column 200 x 200 with 20 padding, with
/// a fill 10 x 10 sized by [variables] (or [widthFactor]) as a fraction of
/// the track.
Future<void> _pump(
  WidgetTester tester, {
  RowColumnType type = RowColumnType.row,
  Map<String, String> variables = const {},
  double? widthFactor,
  SizeFit trackFit = SizeFit.fixed,
}) async {
  final RectangleNode fill = RectangleNode(
    id: 'fill',
    name: 'fill',
    basicBoxLocal: NodeBox(0, 0, 10, 10),
  )
    ..parentID = 'track'
    ..widthFactor = widthFactor;
  fill.variables.addAll(variables);
  final RowColumnNode track = RowColumnNode(
    id: 'track',
    name: 'track',
    basicBoxLocal: NodeBox(0, 0, 200, 200),
    children: const ['fill'],
    rowColumnType: type,
    horizontalFit: trackFit,
    verticalFit: SizeFit.fixed,
    padding: const EdgeInsetsModel.all(20),
  )..parentID = kRootNode;
  final registry = NodeRegistry()
    ..setNodes({track.id: track, fill.id: fill});
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: CodelesslyContext.empty(),
      child: MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 400,
              child: Align(
                alignment: Alignment.topLeft,
                child: Builder(
                  builder: (context) => manager.buildWidgetFromNode(
                    track,
                    context,
                    settings: const WidgetBuildSettings(debugLabel: 'test'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('a bound widthFactor sizes a row child by the row', (
    tester,
  ) async {
    await _pump(tester, variables: {'widthFactor': r'${= 0.5}'});
    // Half of the track's content box: (200 - 2 * 20) / 2.
    expect(tester.getSize(_of('fill')).width, 80);
  });

  testWidgets('a widthFactor of its own only caps a row child', (
    tester,
  ) async {
    // The editor's layout takes a node's own factor as a cap on its size.
    await _pump(tester, widthFactor: 0.25);
    expect(tester.getSize(_of('fill')).width, 10);
  });

  testWidgets('a bound heightFactor sizes a column child by the column', (
    tester,
  ) async {
    await _pump(
      tester,
      type: RowColumnType.column,
      variables: {'heightFactor': r'${= 0.5}'},
    );
    expect(tester.getSize(_of('fill')).height, 80);
  });

  testWidgets('an expanded track gives its runtime width', (tester) async {
    await _pump(
      tester,
      trackFit: SizeFit.expanded,
      variables: {'widthFactor': r'${= 0.5}'},
    );
    // (400 - 2 * 20) / 2.
    expect(tester.getSize(_of('fill')).width, 180);
  });
}
