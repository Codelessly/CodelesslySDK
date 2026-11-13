import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _Engine implements SoundEngine, DisposableSoundEngine {
  int closes = 0, plays = 0;
  @override
  bool get available => true;
  @override
  double get now => 0;
  @override
  void resume() {}
  @override
  void play(SoundVoice voice, {double? time, double volume = 1, double pitch = 1}) => plays++;
  @override
  void dispose() => closes++;
}

void main() {
  test('repeated app disposal releases each owned storage notifier', () async {
    for (var i = 0; i < 30; i++) {
      final app = Codelessly();
      final storage = (app.services as Services).storage as ChangeNotifier;
      app.dispose();
      await Future<void>.delayed(Duration.zero);
      // A FlutterError up to Flutter 3.47; a StateError once ChangeNotifier moved to package:listen.
    expect(() => storage.addListener(() {}), throwsA(anyOf(isFlutterError, isStateError)));
    }
  });
  test('borrowed services remain usable; their owner releases sound exactly once', () async {
    final engine = _Engine();
    final services = Services(sound: SoundService(engine: engine));
    final app = Codelessly(config: CodelesslyConfig(services: services));
    app.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(engine.closes, 0);
    services.sound.play(SoundVoice.tap);
    expect(engine.plays, 1);
    await services.dispose();
    services.sound.dispose();
    services.sound.play(SoundVoice.tap);
    expect(engine.closes, 1);
    expect(engine.plays, 1);
    expect(services.sound.available, false);
  });
}
