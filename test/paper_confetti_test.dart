import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/src/render/particles.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class Particles extends SingleChildRenderObjectWidget {
  const Particles(this.emitter, {super.key}) : super(child: const SizedBox(width: 200, height: 200));
  final api.ParticleEmitter emitter;
  @override
  RenderParticles createRenderObject(BuildContext context) => RenderParticles()
    ..nodeId = 'paper'
    ..emitter = emitter;
}

void main() {
  test('drag slows a particle and the fall is capped at the terminal speed', () {
    // Without drag it is the plain parabola.
    expect(particlePosition(Offset.zero, const Offset(100, 0), 900, 1), const Offset(100, 450));
    // Drag: x approaches v/k.
    final far = particlePosition(Offset.zero, const Offset(100, 0), 0, 50, drag: 2);
    expect(far.dx, closeTo(50, 1e-6));
    // Terminal: after reaching 100 px/s it falls at 100 px/s.
    final a = particlePosition(Offset.zero, Offset.zero, 900, 2, terminal: 100);
    final b = particlePosition(Offset.zero, Offset.zero, 900, 3, terminal: 100);
    expect(b.dy - a.dy, closeTo(100, 1e-9));
    // With drag too, once at terminal speed each second adds that much.
    final c = particlePosition(Offset.zero, const Offset(0, -800), 1266, 2, drag: 1.9, terminal: 135);
    final d = particlePosition(Offset.zero, const Offset(0, -800), 1266, 2.5, drag: 1.9, terminal: 135);
    expect(d.dy - c.dy, closeTo(67.5, 1e-6));
    // Thrown up, it rises first.
    expect(particlePosition(Offset.zero, const Offset(0, -800), 1266, .1, drag: 1.9, terminal: 135).dy, lessThan(0));
  });

  testWidgets('a delayed burst waits, then runs its life; emoji, triangles and squiggles paint', (tester) async {
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: Particles(api.ParticleEmitter(
          count: 12,
          delay: 300,
          lifetime: 200,
          mirror: true,
          drag: 1.9,
          terminalVelocity: 135,
          sway: 10,
          flutter: 11,
          fadeOut: 100,
          glyph: '🔥',
          shapes: [api.ParticleShape.emoji, api.ParticleShape.triangle, api.ParticleShape.squiggle],
        )),
      ),
    ));
    final render = tester.renderObject<RenderParticles>(find.byType(Particles));
    var done = false;
    ParticlePlayers.play('paper', 'particles').then((_) => done = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(done, false, reason: 'still waiting out the delay');
    await tester.pump(const Duration(milliseconds: 150));
    expect(render.activeBursts, 1);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 200));
    expect(done, true);
    expect(render.activeBursts, 0);
  });
}
