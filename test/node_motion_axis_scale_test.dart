import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Motion scales each axis on its own (a level meter's bar stretching
/// vertically while it plays), on top of the uniform scale.
void main() {
  test('scaleX and scaleY multiply the uniform scale per axis', () {
    final m = motionMatrix(
      const MotionModel(scale: 2, scaleX: 0.5, scaleY: 0.7),
    );
    expect(m.entry(0, 0), closeTo(1.0, 1e-9));
    expect(m.entry(1, 1), closeTo(1.4, 1e-9));
  });

  test('they are bindable, transform and survive JSON', () {
    expect(MotionModel.properties, containsAll(['scaleX', 'scaleY']));
    const m = MotionModel(scaleY: 0.6);
    expect(m.hasTransform, isTrue);
    expect(m.atRest.scaleY, 1);
    expect(m.withValue('scaleX', 0.8).scaleX, 0.8);
    expect(MotionModel.fromJson(m.toJson()), m);
  });

  test('a node faces away past 90 degrees of tilt', () {
    expect(facesAway(const MotionModel(rotateY: 0)), isFalse);
    expect(facesAway(const MotionModel(rotateY: 89)), isFalse);
    expect(facesAway(const MotionModel(rotateY: 120)), isTrue);
    expect(facesAway(const MotionModel(rotateY: -180)), isTrue);
    expect(facesAway(const MotionModel(rotateY: 360)), isFalse);
    expect(facesAway(const MotionModel(rotateX: 135)), isTrue);
    expect(facesAway(const MotionModel(rotateX: 180, rotateY: 180)), isFalse);
  });

  testWidgets('hideBackface hides a node turned away, keeping its size', (
    tester,
  ) async {
    Future<void> pump(double rotateY) => tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: NodeMotion(
            motion: MotionModel(rotateY: rotateY, hideBackface: true),
            child: const SizedBox(width: 100, height: 60),
          ),
        ),
      ),
    );
    await pump(0);
    expect(find.byType(Opacity), findsNothing);
    await pump(180);
    final Opacity hidden = tester.widget(find.byType(Opacity));
    expect(hidden.opacity, 0);
    expect(tester.getSize(find.byType(SizedBox).last), const Size(100, 60));
    expect(MotionCurve.easeInOutCubic.prettify, isNotEmpty);
  });
}
