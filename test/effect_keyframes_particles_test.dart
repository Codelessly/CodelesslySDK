// Keyframed one-shot effects (a hop with squash and stretch, a fly-away and
// back) and image particles (petals, seeds, raindrops).
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/play.dart' show keyframePoseAt, RenderEffects;
import 'package:codelessly_sdk/src/render/particles.dart' show RenderParticles;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'lists/support.dart' as support;

const hop = [
  {'t': 0.12, 'scaleX': 1.07, 'scaleY': 0.86},
  {'t': 0.45, 'translateY': -110, 'scaleY': 1.1, 'scaleX': 0.95},
  {'t': 0.75, 'translateY': 0, 'scaleY': 1, 'scaleX': 1},
  {'t': 0.88, 'scaleY': 0.9, 'scaleX': 1.05},
];

void main() {
  test('a keyframes pose runs from rest through its keyframes back to rest', () {
    final kf = [for (final k in hop) api.MotionKeyframe.fromJson(k)!];
    expect(keyframePoseAt(kf, 0, 1).dy, 0);
    expect(keyframePoseAt(kf, 0.45, 1).dy, -110);
    expect(keyframePoseAt(kf, 0.12, 1).sy, closeTo(0.86, 1e-9));
    // Halfway between 0.12 (no translateY) and 0.45: translateY runs 0 -> -110
    // from t 0 to 0.45, so at 0.3 it's two thirds of the way.
    expect(keyframePoseAt(kf, 0.3, 1).dy, closeTo(-110 * 0.3 / 0.45, 1e-9));
    final end = keyframePoseAt(kf, 1, 1);
    expect([end.dx, end.dy, end.sx, end.sy, end.rotation, end.opacity], [0, 0, 1, 1, 0, 1]);
    // amount scales offsets and the scales' distance from 1.
    expect(keyframePoseAt(kf, 0.45, 0.5).dy, -55);
    expect(keyframePoseAt(kf, 0.45, 0.5).sy, closeTo(1.05, 1e-9));
  });

  test('keyframes and curve round-trip; keyframes also read from JSON text (a binding)', () {
    final e = api.EffectAnimation.fromJson({'name': 'hop', 'type': 'keyframes', 'duration': 700, 'keyframes': hop, 'curve': 'easeOut'})!;
    expect(e.type, api.EffectAnimationType.keyframes);
    expect(e.keyframes.length, 4);
    expect(e.curve, api.AnimationCurve.easeOut);
    expect(api.EffectAnimation.fromJson(e.toJson()), e);
    final text = api.EffectAnimation.fromJson({'name': 'hop', 'type': 'keyframes', 'keyframes': '[{"t": 0.5, "translateY": -40}]'})!;
    expect(text.keyframes.single.translateY, -40);
    final p = api.ParticleEmitter.fromJson({'shapes': ['image'], 'image': 'https://example.com/petal.png'})!;
    expect(p.shapes, [api.ParticleShape.image]);
    expect(api.ParticleEmitter.fromJson(p.toJson()), p);
  });

  testWidgets('a bound play key plays the keyframes on the node, then it rests', (tester) async {
    final screen = await support.show(
      tester,
      {
        'col': {
          'type': 'stack',
          'children': ['frog'],
          'layout': {'width': 400, 'height': 400},
        },
        'frog': {
          'type': 'box',
          'layout': {'width': 100, 'height': 100, 'x': {'start': 150}, 'y': {'start': 250}},
          'decoration': {'fills': [{'color': '#FF00AA00'}]},
          'effectAnimations': [
            {'name': 'hop', 'type': 'keyframes', 'duration': 1000, 'keyframes': hop},
          ],
          'particles': {'shapes': ['image'], 'image': 'https://example.com/petal.png', 'count': 8},
          'bind': {'effectAnimations[0].playKey': r'${taps}', 'particles.playKey': r'${taps}'},
        },
      },
      root: 'col',
      variables: [support.v('taps', 0, api.VariableType.integer)],
    );
    RenderEffects effects() {
      RenderEffects? found;
      void visit(RenderObject o) {
        if (o is RenderEffects) found = o;
        o.visitChildren(visit);
      }

      visit(tester.binding.renderView);
      return found!;
    }

    final particles = () {
      RenderParticles? found;
      void visit(RenderObject o) {
        if (o is RenderParticles) found = o;
        o.visitChildren(visit);
      }

      visit(tester.binding.renderView);
      return found!;
    }();
    screen.scope.set('taps', 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    final mid = effects().transform.getTranslation();
    expect(mid.y, lessThan(-60), reason: 'up in the air at 45%');
    expect(particles.activeBursts, 1);
    await tester.pump(const Duration(milliseconds: 700));
    expect(effects().transform.getTranslation().y, closeTo(0, 0.01));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
