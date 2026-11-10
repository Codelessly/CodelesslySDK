import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A rating dial's needs, built into drag tracks: a parked place for a
/// value outside the range, tapping round an arc to point there, and
/// keyboard focus, keys and slider semantics.
void main() {
  late double value;
  late List<double> changes;
  late List<(double, double, double)> releases;
  late List<TrackValues> seen;
  late void Function(double) setValue;

  /// A 400x400 faceplate with a [size] node laid out at [at] (top left),
  /// inside a [WidgetsApp] so Tab moves focus.
  Widget plate(
    DragTrackModel track, {
    Size size = const Size(20, 20),
    Offset at = const Offset(100, 100),
    bool enabled = true,
  }) {
    return WidgetsApp(
      color: const Color(0xFF000000),
      builder: (context, _) => StatefulBuilder(
        builder: (context, setState) {
          setValue = (v) => setState(() => value = v);
          // The page's scope, as a navigator's route gives it.
          return FocusScope(
            autofocus: true,
            child: Stack(
              children: [
                Positioned(
                  left: at.dx,
                  top: at.dy,
                  width: size.width,
                  height: size.height,
                  child: NodeDragTrack(
                    track: track,
                    value: value,
                    enabled: enabled,
                    onChanged: (v) {
                      changes.add(v);
                      setState(() => value = v);
                    },
                    onRelease: (v, start, velocity) =>
                        releases.add((v, start, velocity)),
                    child: Builder(
                      builder: (context) {
                        seen.add(TrackScope.maybeOf(context)!);
                        return const SizedBox.expand(child: Text('cap'));
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  setUp(() {
    value = 0;
    changes = [];
    releases = [];
    seen = [];
  });

  // A 1 to 5 rating on a 200px horizontal throw (50px a step); unrated (0)
  // parks 25px before the start.
  const rating = DragTrackModel(
    variable: 'r',
    min: 1,
    max: 5,
    step: 1,
    x2: 200,
    y2: 0,
    parkedProgress: -0.125,
  );

  double capX(WidgetTester tester) =>
      tester.getCenter(find.text('cap')).dx - 110;

  group('parked', () {
    test('the model parks values outside the range or not a number', () {
      expect(rating.isParked(0), isTrue);
      expect(rating.isParked(6), isTrue);
      expect(rating.isParked(double.nan), isTrue);
      expect(rating.isParked(1), isFalse);
      expect(rating.restProgressOf(0), -0.125);
      expect(rating.restProgressOf(3), 0.5);
      final unparked = rating.copyWith(clearParked: true);
      expect(unparked.isParked(0), isFalse);
      expect(unparked.restProgressOf(0), 0);
      // JSON round trip.
      expect(DragTrackModel.fromJson(rating.toJson()), rating);
      expect(rating.toJson()['parkedProgress'], -0.125);
      expect(unparked.toJson().containsKey('parkedProgress'), isFalse);
      expect(unparked.toJson().containsKey('keyboard'), isFalse);
      expect(rating.copyWith(keyboard: false).toJson()['keyboard'], isFalse);
    });

    testWidgets('a value below, above or empty draws the node parked', (
      tester,
    ) async {
      await tester.pumpWidget(plate(rating));
      expect(capX(tester), closeTo(-25, 0.01));
      expect(seen.last.progress, -0.125);
      setValue(6);
      await tester.pump();
      expect(capX(tester), closeTo(-25, 0.01));
      setValue(double.nan);
      await tester.pump();
      expect(capX(tester), closeTo(-25, 0.01));
      expect(seen.last.toMap()['value'], isNull);
      setValue(3);
      await tester.pump();
      expect(capX(tester), closeTo(100, 0.01));
      expect(seen.last.progress, 0.5);
      // Without a parked place the nearest end.
      setValue(0);
      await tester.pumpWidget(plate(rating.copyWith(clearParked: true)));
      expect(capX(tester), closeTo(0, 0.01));
    });

    testWidgets('an arc parks past its start', (tester) async {
      value = 0;
      const dial = DragTrackModel(
        shape: DragTrackShape.arc,
        variable: 'r',
        min: 1,
        max: 5,
        step: 1,
        startAngle: -120,
        endAngle: 120,
        parkedProgress: -0.125,
      );
      await tester.pumpWidget(
        plate(dial, size: const Size(100, 100), at: const Offset(150, 150)),
      );
      expect(_rotation(tester), closeTo(-150, 0.5));
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('dragging a parked node starts from the nearest end', (
      tester,
    ) async {
      await tester.pumpWidget(plate(rating));
      final g = await tester.startGesture(const Offset(85, 110));
      await g.moveBy(const Offset(20, 0));
      await g.moveBy(const Offset(40, 0));
      await tester.pump();
      // Grabbed 25px before the start: 60px on is 60px along, 1.2 steps.
      expect(value, 2);
      expect(capX(tester), closeTo(50, 0.01));
      await g.up();
      await tester.pump(const Duration(seconds: 1));
      expect(releases.single.$1, 2);
      expect(releases.single.$2, 0);
    });

    testWidgets('any drag brings a parked node onto the track', (tester) async {
      await tester.pumpWidget(plate(rating.copyWith(overscroll: 1)));
      final g = await tester.startGesture(const Offset(85, 110));
      await g.moveBy(const Offset(-20, 0));
      await tester.pump();
      expect(value, 1); // dragging brings it onto the track
      await g.up();
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('glides between parked and on the track', (tester) async {
      await tester.pumpWidget(
        plate(rating.copyWith(settleMs: 200, settleCurve: MotionCurve.linear)),
      );
      setValue(1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(capX(tester), closeTo(-12.5, 0.5));
      expect(seen.last.progress, closeTo(-0.0625, 0.005));
      await tester.pump(const Duration(milliseconds: 150));
      expect(capX(tester), closeTo(0, 0.01));
      // Emptied: back to its park.
      setValue(double.nan);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(capX(tester), closeTo(-12.5, 0.5));
      // Rebuilding with the same empty value doesn't restart the glide.
      setValue(double.nan);
      await tester.pump(const Duration(milliseconds: 150));
      expect(capX(tester), closeTo(-25, 0.01));
    });
  });

  group('tap to jump on an arc', () {
    // A 1 to 5 dial over 240 degrees: 1 at -120, 3 up, 5 at 120.
    const dial = DragTrackModel(
      shape: DragTrackShape.arc,
      variable: 'r',
      min: 1,
      max: 5,
      step: 1,
      startAngle: -120,
      endAngle: 120,
      parkedProgress: -0.125,
      jumpOnTap: true,
    );

    Offset at(double degrees, double r) {
      final double a = degrees * math.pi / 180;
      return Offset(200 + r * math.sin(a), 200 - r * math.cos(a));
    }

    Widget dialPlate(DragTrackModel track) =>
        plate(track, size: const Size(100, 100), at: const Offset(150, 150));

    testWidgets('tapping round the dial points it at the tapped angle', (
      tester,
    ) async {
      await tester.pumpWidget(dialPlate(dial));
      await tester.tapAt(at(55, 40)); // nearest step: 4 at 60
      await tester.pump(const Duration(seconds: 1));
      expect(value, 4);
      expect(_rotation(tester), closeTo(60, 0.5));
      await tester.tapAt(at(-100, 40));
      await tester.pump(const Duration(seconds: 1));
      expect(value, 1);
      // In the gap below: to the nearer end.
      await tester.tapAt(at(165, 40));
      await tester.pump(const Duration(seconds: 1));
      expect(value, 5);
      await tester.tapAt(at(-165, 40));
      await tester.pump(const Duration(seconds: 1));
      expect(value, 1);
      // Too near the pivot for an angle: no jump.
      value = 3;
      await tester.pumpWidget(dialPlate(dial));
      await tester.tapAt(at(90, 5));
      await tester.pump(const Duration(seconds: 1));
      expect(value, 3);
    });

    testWidgets('a tap jump goes on as a drag from there', (tester) async {
      await tester.pumpWidget(dialPlate(dial));
      final g = await tester.startGesture(at(60, 40));
      for (double a = 50; a >= -20; a -= 10) {
        await g.moveTo(at(a, 40));
      }
      await tester.pump();
      expect(value, 3);
      await g.up();
      await tester.pump(const Duration(seconds: 1));
      expect(changes.first, 4);
      // Started unrated.
      expect(releases.last.$2, 0);
    });

    testWidgets('without jumpOnTap a tap does not move the dial', (
      tester,
    ) async {
      value = 3;
      await tester.pumpWidget(dialPlate(dial.copyWith(jumpOnTap: false)));
      await tester.tapAt(at(60, 40));
      await tester.pump(const Duration(seconds: 1));
      expect(value, 3);
    });

    testWidgets('the circle an orbiting node sweeps takes the tap', (
      tester,
    ) async {
      value = 0;
      // A dot on a ring 100px below its rest centre (200, 100).
      const ring = DragTrackModel(
        shape: DragTrackShape.arc,
        variable: 'p',
        startAngle: 0,
        endAngle: 90,
        pivotY: 100,
        rotate: false,
        jumpOnTap: true,
      );
      await tester.pumpWidget(
        plate(ring, size: const Size(20, 20), at: const Offset(190, 90)),
      );
      // Off the dot, right of the pivot (200, 200): 90 degrees.
      await tester.tapAt(const Offset(280, 200));
      await tester.pump(const Duration(seconds: 1));
      expect(value, 1);
      expect(
        tester.getCenter(find.text('cap')),
        offsetMoreOrLessEquals(const Offset(300, 200)),
      );
      // Outside the swept circle: not hit.
      value = 0;
      await tester.pumpWidget(
        plate(ring, size: const Size(20, 20), at: const Offset(190, 90)),
      );
      await tester.tapAt(const Offset(390, 200));
      await tester.pump(const Duration(seconds: 1));
      expect(value, 0);
    });
  });

  group('keyboard', () {
    Future<void> focus(WidgetTester tester) async {
      await tester.tap(find.text('cap'), warnIfMissed: false);
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('tapping focuses it and the keys step it', (tester) async {
      value = 3;
      await tester.pumpWidget(plate(rating));
      expect(seen.last.focused, isFalse);
      await focus(tester);
      expect(seen.last.focused, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(value, 4);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(value, 5);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(value, 5); // at the end
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(value, 3);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(value, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(value, 5);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pump();
      expect(value, 1);
      expect(changes, [4, 5, 4, 3, 1, 5, 1]);
      // Each step ends like a drag let go, without velocity.
      expect(releases.last, (1.0, 5.0, 0.0));
      expect(releases, hasLength(changes.length));
    });

    testWidgets('a parked track steps onto its nearest end', (tester) async {
      await tester.pumpWidget(plate(rating));
      await focus(tester);
      // The tap focused it without moving it.
      expect(value, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(value, 1);
    });

    testWidgets('a continuous track steps 1% and pages 10%', (tester) async {
      value = 50;
      await tester.pumpWidget(
        plate(const DragTrackModel(variable: 'v', max: 100, x2: 200, y2: 0)),
      );
      await focus(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(value, closeTo(51, 1e-9));
      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.pump();
      expect(value, closeTo(61, 1e-9));
    });

    testWidgets('Tab reaches it', (tester) async {
      value = 3;
      await tester.pumpWidget(plate(rating));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(seen.last.focused, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(value, 4);
    });

    testWidgets('disabled or keyboard off, the keys do nothing', (
      tester,
    ) async {
      value = 3;
      await tester.pumpWidget(plate(rating.copyWith(keyboard: false)));
      await focus(tester);
      expect(seen.last.focused, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(value, 3);
      await tester.pumpWidget(plate(rating, enabled: false));
      await focus(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(seen.last.focused, isFalse);
      expect(value, 3);
      expect(changes, isEmpty);
    });
  });

  group('semantics', () {
    testWidgets('it is a slider with its value and increase / decrease', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      value = 3;
      await tester.pumpWidget(plate(rating));
      expect(
        tester.getSemantics(find.text('cap')),
        isSemantics(
          isSlider: true,
          value: '3',
          increasedValue: '4',
          decreasedValue: '2',
          hasIncreaseAction: true,
          hasDecreaseAction: true,
          isFocusable: true,
        ),
      );
      final SemanticsNode node = tester.getSemantics(find.text('cap'));
      node.owner!.performAction(node.id, SemanticsAction.increase);
      await tester.pump();
      expect(value, 4);
      node.owner!.performAction(node.id, SemanticsAction.decrease);
      await tester.pump();
      expect(value, 3);
      // Unrated: no value; at the end: no increase.
      value = 0;
      await tester.pumpWidget(plate(rating));
      expect(
        tester.getSemantics(find.text('cap')),
        isSemantics(isSlider: true, value: '', hasIncreaseAction: true),
      );
      value = 5;
      await tester.pumpWidget(plate(rating));
      expect(
        tester.getSemantics(find.text('cap')),
        isSemantics(
          isSlider: true,
          value: '5',
          hasIncreaseAction: false,
          hasDecreaseAction: true,
        ),
      );
      handle.dispose();
    });
  });

  group('through the node pipeline', () {
    late CodelesslyContext codelesslyContext;

    // A rating dial: a 100px cap on a 1 to 5 arc, parked unrated.
    List<BaseNode> dial() => [
      FrameNode(
        id: 'plate',
        name: 'plate',
        basicBoxLocal: NodeBox(0, 0, 300, 300),
        children: ['cap'],
      )..parentID = kRootNode,
      FrameNode(
          id: 'cap',
          name: 'cap',
          basicBoxLocal: NodeBox(100, 100, 100, 100),
          horizontalFit: SizeFit.fixed,
          verticalFit: SizeFit.fixed,
          children: ['pointer'],
        )
        ..parentID = 'plate'
        ..drag = const DragModel(
          track: DragTrackModel(
            shape: DragTrackShape.arc,
            variable: 'rating',
            min: 1,
            max: 5,
            step: 1,
            startAngle: -120,
            endAngle: 120,
            parkedProgress: -0.125,
            jumpOnTap: true,
          ),
        ),
      TextNode(
        id: 'pointer',
        name: 'pointer',
        basicBoxLocal: NodeBox(40, 0, 20, 20),
        data: 'P',
        textMixedProps: [StartEndProp(start: 0, end: 1, fontSize: 12)],
      )..parentID = 'cap',
    ];

    Future<void> pump(
      WidgetTester tester, {
      required bool runtime,
      required Object rating,
    }) async {
      final List<BaseNode> nodes = dial();
      final registry = NodeRegistry()
        ..setNodes({for (final node in nodes) node.id: node});
      final manager = PassiveNodeTransformerManager(
        registry.getNodeByID,
        (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
      );
      codelesslyContext = CodelesslyContext.empty().copyWith(
        variables: {
          'rating': Observable(
            VariableData(
              id: 'rating',
              name: 'rating',
              type: VariableType.integer,
              value: rating,
            ),
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

    double pointer(WidgetTester tester) {
      final RenderBox box = tester.renderObject(
        find.text('P', findRichText: true),
      );
      final Matrix4 m = box.getTransformTo(null);
      final Offset a = MatrixUtils.transformPoint(m, Offset.zero);
      final Offset b = MatrixUtils.transformPoint(m, const Offset(1, 0));
      return (b - a).direction * 180 / math.pi;
    }

    Object? rating() =>
        codelesslyContext.findVariableByName('rating')!.value.getValue();

    testWidgets('the design canvas parks an unrated dial', (tester) async {
      await pump(tester, runtime: false, rating: 0);
      expect(pointer(tester), closeTo(-150, 0.5));
      await pump(tester, runtime: false, rating: 4);
      expect(pointer(tester), closeTo(60, 0.5));
    });

    testWidgets('at runtime an empty dial parks, taps and steps', (
      tester,
    ) async {
      await pump(tester, runtime: true, rating: '');
      expect(pointer(tester), closeTo(-150, 0.5));
      // Tap 40px out at 60 degrees round the centre (150, 150): 4.
      await tester.tapAt(const Offset(184.64, 130));
      await tester.pump(const Duration(seconds: 1));
      expect(rating(), 4);
      expect(pointer(tester), closeTo(60, 0.5));
      // The tap focused it: the keys step it.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(rating(), 5);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(rating(), 1);
      expect(pointer(tester), closeTo(-120, 0.5));
    });
  });
}

/// The rotation the cap is drawn at, in degrees clockwise from up.
double _rotation(WidgetTester tester) {
  final RenderBox box = tester.renderObject(find.text('cap'));
  final Matrix4 m = box.getTransformTo(null);
  final Offset a = MatrixUtils.transformPoint(m, Offset.zero);
  final Offset b = MatrixUtils.transformPoint(m, const Offset(1, 0));
  return (b - a).direction * 180 / math.pi;
}
