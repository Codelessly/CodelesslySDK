import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// Lamplight's loading view: a 960:600 plan skeleton (layoutAspectRatio 1.6)
// in a column with too little room left for it. Flutter's
// `AspectRatio(1.6)` in a Column keeps its ratio and overflows (clipped by
// an ancestor); a layoutAspectRatio box must too, rather than squeezing
// down to the room left, and its expanded pulse layer fills it.

Finder _of(String id) =>
    find.byKey(ValueKey('Rectangle Transformer of $id [$id]'));

RowColumnNode _page({
  required double height,
  CrossAxisAlignmentC cross = CrossAxisAlignmentC.stretch,
}) => RowColumnNode(
  id: 'page',
  name: 'page',
  basicBoxLocal: NodeBox(0, 0, 350, height),
  rowColumnType: RowColumnType.column,
  mainAxisAlignment: MainAxisAlignmentC.start,
  crossAxisAlignment: cross,
  clipsContent: true,
  children: const ['top', 'plan'],
)..parentID = kRootNode;

RectangleNode _top() => RectangleNode(
  id: 'top',
  name: 'top',
  basicBoxLocal: NodeBox(0, 0, 350, 200),
)..parentID = 'page';

RowColumnNode _plan() =>
    RowColumnNode(
        id: 'plan',
        name: 'plan',
        // The editor stored 100 tall; the ratio decides the height.
        basicBoxLocal: NodeBox(0, 200, 350, 100),
        rowColumnType: RowColumnType.column,
        crossAxisAlignment: CrossAxisAlignmentC.stretch,
        horizontalFit: SizeFit.expanded,
        verticalFit: SizeFit.fixed,
        children: const ['pulse'],
      )
      ..layoutAspectRatio = 1.6
      ..parentID = 'page';

RectangleNode _pulse() => RectangleNode(
  id: 'pulse',
  name: 'pulse',
  basicBoxLocal: NodeBox(0, 0, 350, 100),
  horizontalFit: SizeFit.expanded,
  verticalFit: SizeFit.expanded,
)..parentID = 'plan';

Future<void> _pump(WidgetTester tester, List<BaseNode> nodes) async {
  tester.view.physicalSize = const Size(800, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final registry = NodeRegistry()..setNodes({for (final n in nodes) n.id: n});
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
            builder: (context) => manager.buildWidgetFromNode(
              nodes.first,
              context,
              settings: const WidgetBuildSettings(debugLabel: 'test'),
            ),
          ),
        ),
      ),
    ),
  );
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('the box keeps its ratio and overflows a short column', (
    tester,
  ) async {
    // 300 tall: 100 left after the 200 px box above it.
    await _pump(tester, [_page(height: 300), _top(), _plan(), _pulse()]);
    expect(tester.getSize(_of('page')), const Size(350, 300));
    expect(tester.getSize(_of('plan')), const Size(350, 350 / 1.6));
    // The expanded layer fills the box, not its stored 100 px.
    expect(tester.getSize(_of('pulse')), const Size(350, 350 / 1.6));
  });

  testWidgets('with room to spare it is the same', (tester) async {
    await _pump(tester, [_page(height: 600), _top(), _plan(), _pulse()]);
    expect(tester.getSize(_of('plan')), const Size(350, 350 / 1.6));
    expect(tester.getSize(_of('pulse')), const Size(350, 350 / 1.6));
  });

  testWidgets('an expanded aspect box in a fixed column fills its height', (
    tester,
  ) async {
    // Like Expanded(AspectRatio(1.6)): the column's 100 px left are the
    // height, the width follows.
    final RowColumnNode plan = _plan()
      ..verticalFit = SizeFit.expanded
      ..horizontalFit = SizeFit.fixed;
    await _pump(tester, [
      _page(height: 300, cross: CrossAxisAlignmentC.start),
      _top(),
      plan,
      _pulse(),
    ]);
    expect(tester.getSize(_of('plan')).height, 100);
    expect(tester.getSize(_of('plan')).width, 160);
    expect(tester.getSize(_of('pulse')), const Size(160, 100));
  });

  test('the ratio sets the intrinsic extent of the derived axis', () {
    final RenderFitBox box = RenderFitBox(
      width: 350,
      height: 100,
      fillWidth: true,
      aspectRatio: 1.6,
    );
    expect(box.getMinIntrinsicHeight(320), 200);
    expect(box.getMaxIntrinsicHeight(320), 200);
    expect(box.getMinIntrinsicWidth(100), 160);
    // An unbounded width: the design width.
    expect(box.getMinIntrinsicHeight(double.infinity), 350 / 1.6);
  });
}
