import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/src/ui/node_play.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a shake swings its own count unless cycles says', () {
    // Default: four swings, so a quarter swing in is at t = 1/16.
    expect(effectTransformAt(EffectAnimationType.shake, 1 / 16, 1).dx, closeTo(12 * (1 - 1 / 16), 1e-9));
    // Three swings (the Orrery's refused drop): peak at t = 1/12.
    final double t = 1 / 12;
    expect(effectTransformAt(EffectAnimationType.shake, t, 8 / 12, cycles: 3).dx,
        closeTo(math.sin(t * math.pi * 6) * 8 * (1 - t), 1e-9));
  });

  test('cycles survives JSON and defaults away', () {
    const e = EffectAnimation(name: 'shake', type: EffectAnimationType.shake, cycles: 3);
    expect(EffectAnimation.fromJson(e.toJson()), e);
    expect(const EffectAnimation(name: 's', type: EffectAnimationType.shake).toJson().containsKey('cycles'), isFalse);
  });
}
