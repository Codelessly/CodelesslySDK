import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// Lamplight's Sunrise sky: a frame designed 414 wide that is 350 wide at
// runtime, with a hill whose x and width are bound to the sky's width
// (`${= 0.45 * skyW}`, `${= 0.8 * skyW}`). The hill must sit at its bound x
// in the runtime sky, as on the canvas, whether it is aligned or pinned:
// translating it from its design place put it off by tens of pixels, since
// its alignment or pins move it when the sky is narrower than designed.

const double _designW = 414;
const double _runtimeW = 350;
const double _h = 190;

Finder _of(String id) =>
    find.byKey(ValueKey('Rectangle Transformer of $id [$id]'));

RectangleNode _hill({
  AlignmentModel alignment = AlignmentModel.none,
  PositioningMode mode = PositioningMode.align,
  EdgePinsModel pins = EdgePinsModel.standard,
  Map<String, String> variables = const {
    'x': r'${= 0.45 * parent.width}',
    'y': r'${= 0.65 * parent.height}',
    'width': r'${= 0.8 * parent.width}',
  },
}) =>
    RectangleNode(
        id: 'hill',
        name: 'hill',
        basicBoxLocal: NodeBox(
          0.45 * _designW,
          0.65 * _h,
          0.8 * _designW,
          0.5 * _h,
        ),
        alignment: alignment,
        edgePins: pins,
      )
      ..parentID = 'sky'
      ..positioningMode = mode
      ..variables.addAll(variables);

Future<Offset> _pump(WidgetTester tester, BaseNode hill) async {
  tester.view.physicalSize = const Size(800, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final FrameNode sky = FrameNode(
    id: 'sky',
    name: 'sky',
    basicBoxLocal: NodeBox(0, 0, _designW, _h),
    horizontalFit: SizeFit.expanded,
    children: [hill.id],
  )..parentID = kRootNode;
  final registry = NodeRegistry()..setNodes({sky.id: sky, hill.id: hill});
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
              width: _runtimeW,
              child: Builder(
                builder: (context) => manager.buildWidgetFromNode(
                  sky,
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
  final Offset frame = tester.getTopLeft(_of('sky'));
  expect(tester.getSize(_of('sky')).width, _runtimeW);
  return tester.getTopLeft(_of('hill')) - frame;
}

void main() {
  const Offset bound = Offset(0.45 * _runtimeW, 0.65 * _h);

  testWidgets('an aligned child sits at its bound x/y in the runtime box', (
    tester,
  ) async {
    // An alignment that doesn't match the bound place (bottom right).
    final Offset at = await _pump(
      tester,
      _hill(alignment: AlignmentModel.bottomRight),
    );
    expect(at.dx, moreOrLessEquals(bound.dx));
    expect(at.dy, moreOrLessEquals(bound.dy));
    expect(tester.getSize(_of('hill')).width, 0.8 * _runtimeW);
  });

  testWidgets('a centred child too', (tester) async {
    final Offset at = await _pump(
      tester,
      _hill(alignment: AlignmentModel.center),
    );
    expect(at.dx, moreOrLessEquals(bound.dx));
  });

  testWidgets('a child pinned to the end edge', (tester) async {
    final Offset at = await _pump(
      tester,
      _hill(
        mode: PositioningMode.pin,
        pins: const EdgePinsModel(
          left: null,
          top: null,
          right: _designW - 0.45 * _designW - 0.8 * _designW,
          bottom: 0,
        ),
      ),
    );
    expect(at.dx, moreOrLessEquals(bound.dx));
    expect(at.dy, moreOrLessEquals(bound.dy));
  });

  testWidgets('a child pinned to the start edge, its pin stale', (
    tester,
  ) async {
    final Offset at = await _pump(
      tester,
      _hill(
        mode: PositioningMode.pin,
        pins: const EdgePinsModel(
          left: 120,
          top: 20,
          right: null,
          bottom: null,
        ),
      ),
    );
    expect(at.dx, moreOrLessEquals(bound.dx));
    expect(at.dy, moreOrLessEquals(bound.dy));
  });

  testWidgets('an unbound axis keeps its alignment', (tester) async {
    final Offset at = await _pump(
      tester,
      _hill(
        alignment: AlignmentModel.bottomRight,
        variables: const {'x': r'${= 0.45 * parent.width}'},
      ),
    );
    expect(at.dx, moreOrLessEquals(bound.dx));
    // Bottom aligned: 190 - 95.
    expect(at.dy, moreOrLessEquals(_h - 0.5 * _h));
  });

  test('the bound start overrides the offset, not the size', () {
    const FreeformAxisPlacement aligned = FreeformAxisPlacement(
      mode: FreeformAxisMode.align,
      start: 186.3,
      extent: 331.2,
      parentExtent: 414,
      alignment: 1,
    );
    final FreeformAxisPlacement placed = aligned.withBoundStart(157.5);
    expect(placed.offsetIn(350, 280, wraps: false), 157.5);
    expect(placed.constraintsIn(350, 350), aligned.constraintsIn(350, 350));
    expect(placed, isNot(aligned));
    expect(placed.withSizeFactor(0.5, 0).boundStart, 157.5);
  });
}
