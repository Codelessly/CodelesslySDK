import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
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
}
