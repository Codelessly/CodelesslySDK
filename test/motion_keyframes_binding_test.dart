import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a keyframes binding reads maps or JSON, skipping bad entries', () {
    final frames = WidgetNodeTransformerManager.motionKeyframesOf([
      {'t': 0.2, 'translateX': 0, 'translateY': 0},
      {'t': '0.35', 'translateY': -60},
      {'translateY': 4},
      'nonsense',
    ]);
    expect(frames, hasLength(2));
    expect(frames[1].t, 0.35);
    expect(frames[1].translateY, -60);
    expect(frames[1].translateX, isNull);

    final json = WidgetNodeTransformerManager.motionKeyframesOf('[{"t": 0.5, "scale": 1.2}]');
    expect(json.single.scale, 1.2);
    expect(WidgetNodeTransformerManager.motionKeyframesOf(42), isEmpty);
    expect(WidgetNodeTransformerManager.motionKeyframesOf('not json'), isEmpty);
  });

  test('three keyframes make a gust: calm, a full push half way, calm', () {
    final frames = WidgetNodeTransformerManager.motionKeyframesOf([
      {'t': 0.3, 'translateY': 0},
      {'t': 0.4, 'translateY': -90},
      {'t': 0.5, 'translateY': 0},
    ]);
    double at(double t) => MotionModel.keyframedValue(frames, 'translateY', 0, 0, t)!;
    expect(at(0.2), closeTo(0, 1e-9));
    expect(at(0.4), closeTo(-90, 1e-9));
    expect(at(0.35), inInclusiveRange(-90, 0));
    expect(at(0.7), closeTo(0, 1e-9));
  });
}
