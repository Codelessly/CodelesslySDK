import 'dart:async';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

class _Voice implements SpeechEngine {
  final said = <String>[];
  final pending = <Completer<void>>[];
  var cancels = 0;

  @override
  bool get available => true;

  @override
  Future<void> speak(String text, {required String language, required double rate, required double pitch}) {
    said.add('$text/$language');
    final c = Completer<void>();
    pending.add(c);
    return c.future;
  }

  @override
  void cancel() => cancels++;
}

void main() {
  // Ported from SDK 8.x's sound_clock_test.
  test('the sound clock stays continuous when audio starts and stops', () {
    final clock = SoundClock();
    expect(clock.now(wall: 5, running: false, audio: 0), 5);
    expect(clock.now(wall: 6, running: true, audio: 0.5), 6, reason: 'audio starts late: time does not jump back');
    expect(clock.now(wall: 7, running: true, audio: 1.5), 7);
    expect(clock.toAudio(8), 2.5);
    expect(clock.now(wall: 100, running: false, audio: 1.5), 7);
  });

  test('sounds clamp volume and pitch; voices match loosely', () {
    final engine = SilentSoundEngine();
    final sound = SoundService(engine: engine);
    sound.play(SoundVoice.chime, time: 1, volume: 5, pitch: 0.1);
    expect(engine.played.single, (SoundVoice.chime, 1.0, 2.0, 0.25));
    expect(sound.available, isFalse);
    expect(SoundVoice.named('Cowbell'), SoundVoice.bell);
    expect(SoundVoice.named(' HI-HAT'), SoundVoice.hat);
    expect(SoundVoice.named('fanfare'), SoundVoice.fanfare);
    expect(SoundVoice.named('???'), SoundVoice.wood);
  });

  test('speech says one thing at a time and reports its state', () async {
    final voice = _Voice();
    final speech = SpeechService(engine: voice);
    expect(speech.value, {'speaking': false, 'text': '', 'available': true});
    final first = speech.speak('hola', language: 'es');
    expect(speech.value['text'], 'hola');
    final second = speech.speak('adiós');
    voice.pending.first.complete();
    expect(await first, isTrue);
    expect(speech.speaking, isTrue, reason: 'only the latest utterance ends speaking');
    voice.pending.last.complete();
    await second;
    expect(speech.speaking, isFalse);
    expect(voice.said, ['hola/es', 'adiós/']);
    speech.stop();
    expect(voice.cancels, 3);
    speech.dispose();
  });

  test('a device without a voice says nothing', () async {
    final speech = SpeechService(engine: const SilentSpeechEngine());
    expect(await speech.speak('hi'), isFalse);
    expect(speech.value['available'], false);
    speech.dispose();
  });

  test('analytics fan out and record', () {
    final a = RecordingAnalytics(), b = RecordingAnalytics();
    final both = MultiAnalytics([a, b, const NoAnalytics()]);
    both.logEvent('paywall_open', {'placement': 'onboarding'});
    both.logScreen('Home', layoutId: 'L');
    both.logError(StateError('x'), type: 'auth_failed');
    expect(a.events, ['paywall_open']);
    expect(b.errors, ['auth_failed']);
    expect(a.records[1].data, {'layoutId': 'L'});
  });
}
