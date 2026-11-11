import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class DisposableVoice extends SilentSoundEngine
    implements DisposableSoundEngine {
  int disposals = 0;
  @override
  void dispose() {
    disposals++;
  }
}

void main() {
  test('closing a project disposes its default services', () async {
    final project = Codelessly();
    final services = project.services as Services;
    final storage = services.storage as ChangeNotifier;
    project.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(() => storage.addListener(() {}), throwsFlutterError);
  });
  test('closing a project leaves injected services to their owner', () async {
    final services = Services();
    final project = Codelessly(config: CodelesslyConfig(services: services));
    project.dispose();
    final storage = services.storage as ChangeNotifier;
    void listener() {}
    storage.addListener(listener);
    storage.removeListener(listener);
    await services.dispose();
  });
  test(
    'sound disposal releases optional engine resources once and stops playback',
    () async {
      final engine = DisposableVoice();
      final sound = SoundService(engine: engine);
      await sound.dispose();
      await sound.dispose();
      sound.play(SoundVoice.beep);
      expect(engine.disposals, 1);
      expect(engine.played, isEmpty);
      expect(sound.available, false);
    },
  );
  test('disposing services releases the sound engine', () async {
    final engine = DisposableVoice();
    final services = Services(sound: SoundService(engine: engine));
    await services.dispose();
    expect(engine.disposals, 1);
  });
}
