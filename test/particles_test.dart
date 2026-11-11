import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/src/render/particles.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class Particles extends SingleChildRenderObjectWidget {
  const Particles(this.emitter, {super.key})
    : super(child: const SizedBox(width: 100, height: 100));
  final api.ParticleEmitter emitter;
  @override
  RenderParticles createRenderObject(BuildContext context) => RenderParticles()
    ..nodeId = 'test'
    ..emitter = emitter;
  @override
  void updateRenderObject(BuildContext context, RenderParticles object) =>
      object.emitter = emitter;
}

void main() {
  test('analytic particle paths have exact gravity and time invariance', () {
    expect(
      particlePosition(const Offset(10, 20), const Offset(100, -300), 900, 1),
      const Offset(110, 170),
    );
    expect(
      particlePosition(Offset.zero, const Offset(0, -100), 200, .5),
      const Offset(0, -25),
    );
  });
  testWidgets(
    'action fires particles and completes after emission plus lifetime',
    (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: Particles(api.ParticleEmitter(emit: 100, lifetime: 200)),
          ),
        ),
      );
      final render = tester.renderObject<RenderParticles>(
        find.byType(Particles),
      );
      var done = false;
      ParticlePlayers.play('test', 'particles').then((_) {
        done = true;
      });
      expect(render.activeBursts, 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(done, false);
      await tester.pump(const Duration(milliseconds: 200));
      expect(done, true);
      expect(render.activeBursts, 0);
    },
  );
  testWidgets('playKey changes fire once; detach completes pending actions', (
    tester,
  ) async {
    Widget view(String key) => Directionality(
      textDirection: TextDirection.ltr,
      child: Particles(api.ParticleEmitter(playKey: key)),
    );
    await tester.pumpWidget(view('a'));
    final render = tester.renderObject<RenderParticles>(find.byType(Particles));
    expect(render.activeBursts, 0);
    await tester.pumpWidget(view('b'));
    expect(render.activeBursts, 1);
    await tester.pumpWidget(view('b'));
    expect(render.activeBursts, 1);
    var done = false;
    ParticlePlayers.play('test', 'particles').then((_) {
      done = true;
    });
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(done, true);
  });
  testWidgets('play on appear, empty palettes and zero counts are safe', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Particles(
          api.ParticleEmitter(
            playOnAppear: true,
            colors: [],
            shapes: [],
            lifetime: 50,
          ),
        ),
      ),
    );
    final render = tester.renderObject<RenderParticles>(find.byType(Particles));
    expect(render.activeBursts, 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(render.activeBursts, 0);
  });
}
