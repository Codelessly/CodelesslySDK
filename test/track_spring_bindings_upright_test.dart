import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A deck's drag track: a settle spring of its own that carries a fling's
/// speed (into the next card an action picks too), a range that follows
/// data, `track` read only inside a track, and a badge that stays upright
/// as it travels round a path.
void main() {
  group('settle spring', () {
    late double value;
    late List<(double, double, double)> releases;
    late void Function(double) setValue;

    // A 200px horizontal throw, 0 to 4: 50px a unit.
    const DragTrackModel deck = DragTrackModel(
      variable: 'v',
      min: 0,
      max: 4,
      x2: 200,
      y2: 0,
      settleCurve: MotionCurve.spring,
    );

    Widget plate(
      DragTrackModel track, {
      void Function(double v, double start, double velocity)? onRelease,
    }) => Directionality(
      textDirection: TextDirection.ltr,
      child: StatefulBuilder(
        builder: (context, setState) {
          setValue = (v) => setState(() => value = v);
          return Stack(
            children: [
              Positioned(
                left: 100,
                top: 100,
                width: 20,
                height: 20,
                child: NodeDragTrack(
                  track: track,
                  value: value,
                  onChanged: (v) => setState(() => value = v),
                  onRelease: (v, start, velocity) {
                    releases.add((v, start, velocity));
                    onRelease?.call(v, start, velocity);
                  },
                  child: const SizedBox.expand(child: Text('cap')),
                ),
              ),
            ],
          );
        },
      ),
    );

    double capX(WidgetTester tester) =>
        tester.getCenter(find.text('cap')).dx - 110;

    setUp(() {
      value = 0;
      releases = [];
    });

    test('the spring defaults to the motion spring', () {
      final SpringDescription s = trackSettleSpring(deck);
      expect(s.stiffness, 380);
      expect(s.damping, 20);
      expect(deck.settleStiffness, 380);
      expect(deck.settleDamping, 20);
      final SpringDescription custom = trackSettleSpring(
        deck.copyWith(settleStiffness: 260, settleDamping: 27.7),
      );
      expect(custom.stiffness, 260);
      expect(custom.damping, 27.7);
      expect(custom.mass, 1);
    });

    testWidgets('a glide runs with the track\'s stiffness and damping', (
      tester,
    ) async {
      Future<double> after(DragTrackModel track) async {
        value = 0;
        await tester.pumpWidget(plate(track));
        setValue(4);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final double x = capX(tester);
        await tester.pumpAndSettle();
        expect(capX(tester), closeTo(200, 0.5));
        // A fresh state for the next track.
        await tester.pumpWidget(const SizedBox());
        return x;
      }

      final double soft = await after(
        deck.copyWith(settleStiffness: 60, settleDamping: 15.5),
      );
      final double stiff = await after(
        deck.copyWith(settleStiffness: 900, settleDamping: 60),
      );
      // The spring's own position 100ms in, from 0 to 200px at rest.
      double expected(double k, double c) =>
          200 *
          SpringSimulation(
            SpringDescription(mass: 1, stiffness: k, damping: c),
            0,
            1,
            0,
          ).x(0.1);
      expect(soft, closeTo(expected(60, 15.5), 3));
      expect(stiff, closeTo(expected(900, 60), 3));
      expect(stiff, greaterThan(soft + 40));
    });

    testWidgets('a flung node carries on past where it was let go', (
      tester,
    ) async {
      await tester.pumpWidget(plate(deck));
      // 100px right in 100ms: let go at value 2 moving about 1000px/s.
      await tester.timedDragFrom(
        const Offset(110, 110),
        const Offset(100, 0),
        const Duration(milliseconds: 100),
      );
      expect(releases, hasLength(1));
      final (double v, double start, double velocity) = releases.single;
      expect(start, 0);
      expect(velocity, greaterThan(5));
      final double letGo = deck.progressOf(v) * 200;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      // Without the fling's speed it would sit still at its value.
      expect(capX(tester), greaterThan(letGo + 10));
      await tester.pumpAndSettle();
      expect(capX(tester), closeTo(letGo, 0.5));
    });

    testWidgets('an action moving the variable on release keeps the speed', (
      tester,
    ) async {
      const DragTrackModel stepped = DragTrackModel(
        variable: 'v',
        min: 0,
        max: 4,
        step: 1,
        x2: 200,
        y2: 0,
        settleCurve: MotionCurve.spring,
        settleStiffness: 260,
        settleDamping: 27.7,
      );
      await tester.pumpWidget(
        plate(
          stepped,
          // The deck's dragEnd: framePos = round(value + velocity × 0.18).
          onRelease: (v, start, velocity) =>
              setValue((v + velocity * 0.18).roundToDouble().clamp(0, 4)),
        ),
      );
      await tester.timedDragFrom(
        const Offset(110, 110),
        const Offset(50, 0),
        const Duration(milliseconds: 100),
      );
      final (double v, _, double velocity) = releases.single;
      final double target = (v + velocity * 0.18).roundToDouble().clamp(0, 4);
      expect(target, greaterThan(v));
      expect(value, target);
      final double from = stepped.progressOf(v);
      final double to = stepped.progressOf(target);
      SpringSimulation sim(double startVelocity) =>
          SpringSimulation(trackSettleSpring(stepped), from, to, startVelocity);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final double carried = sim(velocity / 4).x(0.05) * 200;
      final double fromRest = sim(0).x(0.05) * 200;
      // One glide from where it was let go at the release speed, not a
      // fresh start from rest.
      expect(carried - fromRest, greaterThan(8));
      expect(capX(tester), closeTo(carried, 2.5));
      await tester.pumpAndSettle();
      expect(capX(tester), closeTo(to * 200, 0.5));
    });
  });

  group('bound range', () {
    late CodelesslyContext codelesslyContext;

    VariableData variable(String name, VariableType type, Object value) =>
        VariableData(id: name, name: name, type: type, value: value);

    List<BaseNode> deck() => [
      FrameNode(
        id: 'stage',
        name: 'stage',
        basicBoxLocal: NodeBox(0, 0, 400, 100),
        children: ['card'],
      )..parentID = kRootNode,
      FrameNode(
          id: 'card',
          name: 'card',
          basicBoxLocal: NodeBox(0, 0, 40, 40),
          horizontalFit: SizeFit.fixed,
          verticalFit: SizeFit.fixed,
          children: ['label'],
        )
        ..variables.addAll({
          DragTrackModel.maxVariableKey: r'${= frames - 1}',
          DragTrackModel.x2VariableKey: r'${= (frames - 1) * 50}',
        })
        ..parentID = 'stage'
        ..drag = const DragModel(
          track: DragTrackModel(
            variable: 'framePos',
            min: 0,
            max: 1,
            step: 1,
            x2: 300,
            y2: 0,
          ),
        ),
      TextNode(
        id: 'label',
        name: 'label',
        basicBoxLocal: NodeBox(0, 0, 40, 20),
        data: 'C',
        textMixedProps: [StartEndProp(start: 0, end: 1, fontSize: 12)],
      )..parentID = 'card',
    ];

    Future<void> pump(
      WidgetTester tester, {
      required bool runtime,
      required int frames,
      required int framePos,
    }) async {
      final List<BaseNode> nodes = deck();
      final registry = NodeRegistry()
        ..setNodes({for (final node in nodes) node.id: node});
      final manager = PassiveNodeTransformerManager(
        registry.getNodeByID,
        (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
      );
      codelesslyContext = CodelesslyContext.empty().copyWith(
        variables: {
          'frames': Observable(
            variable('frames', VariableType.integer, frames),
          ),
          'framePos': Observable(
            variable('framePos', VariableType.integer, framePos),
          ),
        },
      );
      await tester.pumpWidget(
        ChangeNotifierProvider<CodelesslyContext>.value(
          value: codelesslyContext,
          child: MaterialApp(
            home: Material(
              child: Align(
                alignment: Alignment.topLeft,
                child: Builder(
                  builder: (context) => manager.buildWidgetFromNode(
                    nodes.first,
                    context,
                    settings: WidgetBuildSettings(
                      debugLabel: runtime ? 'runtime' : 'design canvas',
                      isPreview: !runtime,
                      withReactions: runtime,
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

    double cardX(WidgetTester tester) =>
        tester.getTopLeft(find.text('C', findRichText: true)).dx;

    test('the range, step, throw and line ends bind as track.<name>', () {
      expect(DragTrackModel.minVariableKey, 'track.min');
      expect(DragTrackModel.maxVariableKey, 'track.max');
      expect(DragTrackModel.stepVariableKey, 'track.step');
      expect(DragTrackModel.pixelsPerRangeVariableKey, 'track.pixelsPerRange');
      expect(DragTrackModel.x2VariableKey, 'track.x2');
    });

    testWidgets('resolvedTrack reads bound settings and keeps the rest', (
      tester,
    ) async {
      final FrameNode node =
          FrameNode(
              id: 'n',
              name: 'n',
              basicBoxLocal: NodeBox(0, 0, 10, 10),
              children: [],
            )
            ..variables.addAll({
              'track.max': r'${= frames - 1}',
              'track.step': '0.5',
              'track.pixelsPerRange': r'${notANumber}',
            })
            ..drag = const DragModel(
              track: DragTrackModel(variable: 'p', max: 9, step: 1),
            );
      final ScopedValues values = ScopedValues.preview(
        variables: {
          'frames': variable('frames', VariableType.integer, 6),
          'notANumber': variable('notANumber', VariableType.text, 'x'),
        },
      );
      final DragTrackModel t = WidgetNodeTransformerManager.resolvedTrack(
        node,
        node.drag!.track!,
        values,
      );
      expect(t.max, 5);
      expect(t.step, 0.5);
      expect(t.pixelsPerRange, 200);
      expect(t.variable, 'p');
      node.variables['track.pixelsPerRange'] = r'${= frames * 100}';
      expect(
        WidgetNodeTransformerManager.resolvedTrack(
          node,
          node.drag!.track!,
          values,
        ).pixelsPerRange,
        600,
      );
    });

    testWidgets('the design canvas draws the deck with its bound range', (
      tester,
    ) async {
      // 3 frames: max 2, 100px throw; frame 1 is halfway.
      await pump(tester, runtime: false, frames: 3, framePos: 1);
      expect(cardX(tester), closeTo(50, 0.5));
    });

    testWidgets('at runtime the range follows the data', (tester) async {
      await pump(tester, runtime: true, frames: 3, framePos: 2);
      expect(cardX(tester), closeTo(100, 0.5));
      // A hive with 5 frames: max 4, a 200px throw, frame 2 halfway.
      codelesslyContext.findVariableByName('frames')!.value = codelesslyContext
          .findVariableByName('frames')!
          .value
          .copyWith(value: 5);
      await tester.pumpAndSettle();
      expect(cardX(tester), closeTo(100, 0.5));
      codelesslyContext
          .findVariableByName('framePos')!
          .value = codelesslyContext
          .findVariableByName('framePos')!
          .value
          .copyWith(value: 4);
      await tester.pumpAndSettle();
      expect(cardX(tester), closeTo(200, 0.5));
    });
  });

  group('track outside a track', () {
    tearDown(() => VariablePreview.scopeResolver = null);

    test('reads null where no track encloses the node', () {
      final ScopedValues values = ScopedValues.preview(variables: const {});
      expect(
        PropertyValueDelegate.getVariableValueFromPath<Object>(
          'track.progress',
          scopedValues: values,
        ),
        isNull,
      );
      expect(
        PropertyValueDelegate.getVariableValueFromPath<Object>(
          'track',
          scopedValues: values,
        ),
        isNull,
      );
    });

    test('reads the track\'s values inside one', () {
      final ScopedValues values = ScopedValues.preview(
        variables: const {},
        trackValues: const TrackValues(value: 3, progress: 0.75),
      );
      expect(
        PropertyValueDelegate.getVariableValueFromPath<Object>(
          'track.progress',
          scopedValues: values,
        ),
        0.75,
      );
    });

    testWidgets('on the design canvas a node inside a track reads its pose '
        'and one outside reads nothing', (tester) async {
      final Map<String, VariableData> previews = {
        'pos': VariableData(
          id: 'pos',
          name: 'pos',
          type: VariableType.integer,
          value: 3,
        ),
      };
      VariablePreview.scopeResolver = (_) =>
          ScopedValues.preview(variables: previews);
      final List<BaseNode> nodes = [
        FrameNode(
          id: 'stage',
          name: 'stage',
          basicBoxLocal: NodeBox(0, 0, 400, 200),
          children: ['knob', 'outside'],
        )..parentID = kRootNode,
        FrameNode(
            id: 'knob',
            name: 'knob',
            basicBoxLocal: NodeBox(0, 0, 100, 40),
            horizontalFit: SizeFit.fixed,
            verticalFit: SizeFit.fixed,
            children: ['inside'],
          )
          ..parentID = 'stage'
          ..drag = const DragModel(
            track: DragTrackModel(variable: 'pos', max: 4, x2: 100, y2: 0),
          ),
        TextNode(
          id: 'inside',
          name: 'inside',
          basicBoxLocal: NodeBox(0, 0, 100, 20),
          data: r'in ${track.progress}',
          textMixedProps: [StartEndProp(start: 0, end: 21, fontSize: 12)],
        )..parentID = 'knob',
        TextNode(
          id: 'outside',
          name: 'outside',
          basicBoxLocal: NodeBox(0, 100, 200, 20),
          data: r'out ${= track.progress == null ? "none" : "zero"}',
          textMixedProps: [StartEndProp(start: 0, end: 50, fontSize: 12)],
        )..parentID = 'stage',
      ];
      final registry = NodeRegistry()
        ..setNodes({for (final node in nodes) node.id: node});
      final manager = PassiveNodeTransformerManager(
        registry.getNodeByID,
        (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
      );
      await tester.pumpWidget(
        ChangeNotifierProvider<CodelesslyContext>.value(
          value: CodelesslyContext.empty(),
          child: MaterialApp(
            home: Material(
              child: Align(
                alignment: Alignment.topLeft,
                child: Builder(
                  builder: (context) => manager.buildWidgetFromNode(
                    nodes.first,
                    context,
                    settings: const WidgetBuildSettings(
                      debugLabel: 'design canvas',
                      isPreview: true,
                      withReactions: false,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('in 0.75', findRichText: true), findsOneWidget);
      expect(find.text('out none', findRichText: true), findsOneWidget);
    });
  });

  group('upright along a path', () {
    test('folds the path direction into -90..90 degrees', () {
      double deg(double d) =>
          uprightPathAngle(d * math.pi / 180) * 180 / math.pi;
      expect(deg(0), closeTo(0, 1e-9));
      expect(deg(60), closeTo(60, 1e-9));
      expect(deg(-60), closeTo(-60, 1e-9));
      expect(deg(90), closeTo(90, 1e-9));
      expect(deg(120), closeTo(-60, 1e-9));
      expect(deg(180), closeTo(0, 1e-9));
      expect(deg(-180), closeTo(0, 1e-9));
      expect(deg(-120), closeTo(60, 1e-9));
      expect(deg(240), closeTo(60, 1e-9));
    });

    // A hexagon, about 600px round: right along the top, down the right
    // sides, back left along the bottom (heading 180°) and up the left.
    const String hexagon = 'M0 0 L100 0 L150 87 L100 173 L0 173 L-50 87 Z';

    double turnOf(WidgetTester tester, String text) {
      final RenderBox box = tester.renderObject(find.text(text));
      final Matrix4 m = box.getTransformTo(null);
      final Offset a = MatrixUtils.transformPoint(m, Offset.zero);
      final Offset b = MatrixUtils.transformPoint(m, const Offset(1, 0));
      return (b - a).direction * 180 / math.pi;
    }

    Widget badge(MotionModel motion) => Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: NodeMotion(
          motion: motion,
          animate: false,
          child: const SizedBox(width: 40, height: 20, child: Text('queen')),
        ),
      ),
    );

    testWidgets('a badge on the bottom edge reads upright', (tester) async {
      // 0.58 of the way round is the middle of the bottom edge, heading
      // left.
      const MotionModel along = MotionModel(
        path: hexagon,
        pathProgress: 0.58,
        orientToPath: true,
      );
      await tester.pumpWidget(badge(along));
      expect(turnOf(tester, 'queen').abs(), closeTo(180, 0.5));
      await tester.pumpWidget(badge(along.copyWith(orientUpright: true)));
      expect(turnOf(tester, 'queen'), closeTo(0, 0.5));
      // Down the lower right side (heading 120°, down and left) it leans
      // the other way: -60°.
      await tester.pumpWidget(
        badge(along.copyWith(orientUpright: true, pathProgress: 0.42)),
      );
      expect(turnOf(tester, 'queen'), closeTo(-60, 1));
      // Upright changes nothing without turning with the path.
      await tester.pumpWidget(
        badge(along.copyWith(orientToPath: false, orientUpright: true)),
      );
      expect(turnOf(tester, 'queen'), closeTo(0, 0.5));
    });

    test('a drag track on a path keeps upright too', () {
      const DragTrackModel track = DragTrackModel(
        shape: DragTrackShape.path,
        variable: 'p',
        path: hexagon,
        orientToPath: true,
      );
      expect(
        DragTrackGeometry(track).rotationAt(0.58).abs(),
        closeTo(180, 0.5),
      );
      expect(
        DragTrackGeometry(track.copyWith(orientUpright: true)).rotationAt(0.58),
        closeTo(0, 0.5),
      );
    });
  });
}
