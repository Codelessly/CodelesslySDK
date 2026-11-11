import 'package:codelessly_sdk_v2/src/render/transform_gesture.dart';
import 'package:flutter_test/flutter_test.dart';
void main() {
  test('tiny zooms survive writing a two-way variable instead of becoming zero', () {
    for (final scale in [.0002, .000001, 1e-10]) {
      final value = TransformPose.rounded('scale', scale);
      expect(value, greaterThan(0));
      expect(value, closeTo(scale, scale * .000001));
    }
    expect(TransformPose.rounded('scaleX', .001234567), .00123457);
  });
  test('ordinary scale and pixel precision stays compatible', () {
    expect(TransformPose.rounded('scale', .123456), .123);
    expect(TransformPose.rounded('x', 12.3456), 12.35);
    expect(TransformPose.rounded('scale', 0), 0);
  });
}
