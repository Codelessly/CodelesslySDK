import 'dart:async';
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

class AsyncDisposableVoice extends SilentSoundEngine
    implements DisposableSoundEngine {
  final closed = Completer<void>();
  int disposals = 0;
  @override
  Future<void> dispose() {
    disposals++;
    return closed.future;
  }
}

void main() {
  test('concurrent sound disposal shares and awaits asynchronous engine cleanup', () async {
    final engine = AsyncDisposableVoice();
    final sound = SoundService(engine: engine);
    final first = sound.dispose();
    final second = sound.dispose();
    expect(identical(first, second), isTrue);
    expect(engine.disposals, 1);
    var completed = false;
    first.then((_) => completed = true);
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);
    engine.closed.complete();
    await second;
    expect(completed, isTrue);
    expect(engine.disposals, 1);
  });
  test('closing a project disposes its default services', () async {
    final project = Codelessly();
    final services = project.services as Services;
    final storage = services.storage as ChangeNotifier;
    project.dispose();
    await Future<void>.delayed(Duration.zero);
    // A FlutterError up to Flutter 3.47; a StateError once ChangeNotifier moved to package:listen.
    expect(() => storage.addListener(() {}), throwsA(anyOf(isFlutterError, isStateError)));
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
