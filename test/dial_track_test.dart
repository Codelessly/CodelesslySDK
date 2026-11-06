import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A combination dial on a drag track: endless turns, a flick that coasts
/// (momentum), drawn between numbers while it moves and snapped onto one
/// when it stops (smooth), pointer gain, every number crossed reported, a
/// settle callback, and actions that step it. Built for Safecracker.
void main() {
  late double value;
  late List<TrackChange> changes;
  late List<double> settled;

  // 40 numbers a turn: the value counts numbers turned (clockwise up), so
  // the number under the index is mod(-value, 40).
  const dial = DragTrackModel(
    shape: DragTrackShape.arc,
    variable: 'dial',
    min: 0,
    max: 40,
    step: 1,
    startAngle: 0,
    endAngle: 360,
    endless: true,
    momentum: true,
    smooth: true,
    wheel: true,
  );

  Widget plate(DragTrackModel track, {double? gain}) => Directionality(
    textDirection: TextDirection.ltr,
    child: StatefulBuilder(
      builder: (context, setState) => Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            width: 400,
            height: 400,
            child: NodeDragTrack(
              track: track,
              value: value,
              nodeId: 'dial-node',
              gain: gain,
              onChanged: (v) => setState(() => value = v),
              onChange: changes.add,
              onSettled: settled.add,
              child: const SizedBox.expand(child: Text('face')),
            ),
          ),
        ],
      ),
    ),
  );

  setUp(() {
    value = 0;
    changes = [];
    settled = [];
  });

  /// Drags round the centre (200, 200) at radius 150 from [fromDeg] by [deg]
  /// in [steps] moves 16 ms apart, letting go without stopping.
  Future<void> arc(WidgetTester t, double fromDeg, double deg, {int steps = 20, int ms = 16}) async {
    Offset pt(double a) =>
        const Offset(200, 200) + Offset(math.sin(a * math.pi / 180), -math.cos(a * math.pi / 180)) * 150;
    final g = await t.startGesture(pt(fromDeg));
    for (int i = 1; i <= steps; i++) {
      await g.moveTo(pt(fromDeg + deg * i / steps), timeStamp: Duration(milliseconds: ms * i));
      await t.pump(Duration(milliseconds: ms));
    }
    await g.up(timeStamp: Duration(milliseconds: ms * steps + 1));
  }

  /// The face's paint transform to the screen (it is drawn turned).
  Matrix4 transformOf(WidgetTester t) => t.renderObject<RenderBox>(find.text('face')).getTransformTo(null);

  testWidgets('endless: turns go past a full turn and keep counting', (t) async {
    await t.pumpWidget(plate(dial.copyWith(momentum: false)));
    // Two and a half turns clockwise, slowly.
    for (int k = 0; k < 5; k++) {
      await arc(t, k * 180.0, 180, steps: 30, ms: 40);
      await t.pumpAndSettle();
    }
    expect(value, 100);
    expect(DragTrackModel.fromJson(dial.toJson()).endless, isTrue);
    expect(dial.progressOf(100), 2.5);
  });

  testWidgets('smooth: drawn between numbers while dragged, snapped at rest', (t) async {
    await t.pumpWidget(plate(dial.copyWith(momentum: false)));
    Offset pt(double a) =>
        const Offset(200, 200) + Offset(math.sin(a * math.pi / 180), -math.cos(a * math.pi / 180)) * 150;
    final g = await t.startGesture(pt(0));
    for (int i = 1; i <= 10; i++) {
      await g.moveTo(pt(i * 2.0)); // 20° = 2.22 numbers
      await t.pump(const Duration(milliseconds: 40));
    }
    // Drawn at 20°, not at the 18° of the 2 the variable holds.
    final double drawn = math.atan2(transformOf(t).storage[1], transformOf(t).storage[0]) * 180 / math.pi;
    expect(drawn, closeTo(20, 0.5));
    expect(value, 2);
    expect(settled, isEmpty);
    await t.pump(const Duration(milliseconds: 200));
    await g.up();
    await t.pumpAndSettle();
    final double rest = math.atan2(transformOf(t).storage[1], transformOf(t).storage[0]) * 180 / math.pi;
    expect(rest, closeTo(18, 0.05));
    expect(settled, [2]);
  });

  testWidgets('momentum: a flick coasts on, crossing every number, then settles', (t) async {
    await t.pumpWidget(plate(dial));
    await arc(t, 0, 90, steps: 6); // 90° in ~100 ms
    final double atRelease = value;
    expect(settled, isEmpty);
    await t.pumpAndSettle();
    expect(value, greaterThan(atRelease + 3)); // coasted several numbers
    // Every number from 0 up is reported once, in order.
    final List<double> crossed = [for (final c in changes) ...c.crossed];
    expect(crossed, [for (int i = 1; i <= value; i++) i.toDouble()]);
    expect(changes.every((c) => c.direction == 1), isTrue);
    expect(settled, [value]);
  });

  testWidgets('a slow turn that stops before letting go does not coast', (t) async {
    await t.pumpWidget(plate(dial));
    await arc(t, 0, 144, steps: 40, ms: 40); // 16 numbers at 90°/s
    await t.pumpAndSettle();
    expect(value, 16);
    expect(settled, [16]);
  });

  testWidgets('a second turn after resting turns again', (t) async {
    await t.pumpWidget(plate(dial));
    await arc(t, 0, 144, steps: 40, ms: 40);
    await t.pumpAndSettle();
    expect(value, 16);
    await t.pump(const Duration(seconds: 1));
    await arc(t, 0, 144, steps: 40, ms: 40);
    await t.pumpAndSettle();
    expect(value, 32);
  });

  testWidgets('gain: half the gain turns half as far', (t) async {
    await t.pumpWidget(plate(dial.copyWith(momentum: false), gain: 0.5));
    await arc(t, 0, 144, steps: 40, ms: 40);
    await t.pumpAndSettle();
    expect(value, 8);
  });

  testWidgets('step: an action turns it a number, as a drag would', (t) async {
    await t.pumpWidget(plate(dial));
    expect(await NodeDragTrack.step('dial-node', -1), isTrue);
    await t.pumpAndSettle();
    expect(value, -1);
    expect(changes.single.crossed, [-1]);
    expect(changes.single.direction, -1);
    expect(settled, [-1]);
    await NodeDragTrack.step('dial-node', 3);
    await t.pumpAndSettle();
    expect(value, 2);
    expect([for (final c in changes.skip(1)) ...c.crossed], [0, 1, 2]);
    expect(await NodeDragTrack.step('no-such-node', 1), isFalse);
    // A responsive screen names every layout's copy; the mounted one turns.
    expect(await NodeDragTrack.step('tablet-copy, dial-node', 1), isTrue);
    await t.pumpAndSettle();
    expect(value, 3);
  });

  testWidgets('a step while gliding to a value set from elsewhere steps from it', (t) async {
    await t.pumpWidget(plate(dial));
    value = -23; // a link sets the dial: it glides there
    await t.pumpWidget(plate(dial));
    await t.pump(const Duration(milliseconds: 16));
    expect(await NodeDragTrack.step('dial-node', -1), isTrue);
    await t.pumpAndSettle();
    expect(value, -24);
    expect(changes.last.crossed, [-24]);
    expect(settled, [-24]);
  });

  testWidgets('a value set from elsewhere glides there on a smooth track', (t) async {
    final lever = const DragTrackModel(
      shape: DragTrackShape.arc,
      variable: 'pull',
      min: 0,
      max: 1,
      startAngle: 0,
      endAngle: 90,
      smooth: true,
    );
    value = 1;
    await t.pumpWidget(plate(lever));
    value = 0; // an action springs the lever back
    await t.pumpWidget(plate(lever));
    await t.pump(const Duration(milliseconds: 30));
    final double mid = math.atan2(transformOf(t).storage[1], transformOf(t).storage[0]) * 180 / math.pi;
    expect(mid, inExclusiveRange(1, 89));
    await t.pumpAndSettle();
    final double rest = math.atan2(transformOf(t).storage[1], transformOf(t).storage[0]) * 180 / math.pi;
    expect(rest, closeTo(0, 0.1));
    // Gliding reports nothing: the variable was set, not dragged.
    expect(changes, isEmpty);
    expect(settled, isEmpty);
  });

  test('crossed steps and JSON round trip', () {
    final json = dial.copyWith(gain: 1.5, friction: 3).toJson();
    final back = DragTrackModel.fromJson(json);
    expect(back, dial.copyWith(gain: 1.5, friction: 3));
    expect(json['endless'], isTrue);
    expect(const DragTrackModel(variable: 'x').toJson().containsKey('endless'), isFalse);
    final change = const TrackChange(value: -3, from: 0, crossed: [-1, -2, -3]);
    expect(change.toMap(), {'value': -3, 'from': 0, 'direction': -1, 'crossed': [-1, -2, -3]});
  });

  test('control drag step and haptic actions read and write JSON', () {
    final a = ActionModel.fromJson({'type': 'controlDrag', 'nodeId': 'n', 'command': 'step', 'steps': -1});
    expect(a, isA<ControlDragAction>());
    expect((a as ControlDragAction).steps, '-1');
    expect(a.command, DragCommand.step);
    final h = ActionModel.fromJson({'type': 'haptic', 'kind': 'medium', 'when': r'${settings.haptics}'});
    expect((h as HapticAction).kind, HapticKind.medium);
    expect(HapticAction.fromJson(h.toJson()), h);
  });
}
