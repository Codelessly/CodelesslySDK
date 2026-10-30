import 'dart:async';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeEngine implements SpeechEngine {
  FakeEngine({this.available = true});

  @override
  final bool available;
  final List<String> said = [];
  final List<String> languages = [];
  Completer<void>? current;
  int cancels = 0;

  @override
  Future<void> speak(
    String text, {
    required String language,
    required double rate,
    required double pitch,
  }) {
    said.add(text);
    languages.add(language);
    current = Completer<void>();
    return current!.future;
  }

  @override
  void cancel() {
    cancels++;
    if (current?.isCompleted == false) current!.complete();
  }
}

/// Text-to-speech: the `speech` variable follows what is being said, and
/// the action finishes when the speech does.
void main() {
  test('speaks, reports what it says, and settles when done', () async {
    final engine = FakeEngine();
    Speech.engine = engine;
    final states = <Map<String, dynamic>>[];
    void listen() => states.add(Speech.instance.value);
    Speech.instance.addListener(listen);
    addTearDown(() => Speech.instance.removeListener(listen));

    final Future<bool> done = Speech.instance.speak('hola', language: 'es-ES');
    expect(Speech.instance.value, {
      'speaking': true,
      'text': 'hola',
      'available': true,
    });
    expect(engine.languages, ['es-ES']);
    engine.current!.complete();
    expect(await done, isTrue);
    expect(Speech.instance.speaking, isFalse);
    expect(states.last['text'], '');
  });

  test('a new word cuts the last one off; only the last ends speaking', () async {
    final engine = FakeEngine();
    Speech.engine = engine;
    final Future<bool> first = Speech.instance.speak('uno');
    final Future<bool> second = Speech.instance.speak('dos');
    await first;
    // The first one was cancelled, but "dos" is still being said.
    expect(Speech.instance.value['text'], 'dos');
    expect(Speech.instance.speaking, isTrue);
    engine.current!.complete();
    await second;
    expect(Speech.instance.speaking, isFalse);
  });

  test('without a voice it says so instead', () async {
    Speech.engine = FakeEngine(available: false);
    expect(await Speech.instance.speak('bonjour'), isFalse);
    expect(Speech.instance.value['available'], isFalse);
  });

  test('stop silences it', () {
    final engine = FakeEngine();
    Speech.engine = engine;
    Speech.instance.speak('ありがとう');
    Speech.instance.stop();
    expect(engine.cancels, greaterThan(0));
    expect(Speech.instance.speaking, isFalse);
  });

  test('the action lists the variables it reads', () {
    final action = SpeakAction(
      text: r'${card.front}',
      language: r'${deck.lang}',
    );
    expect(action.getUsedVariableNames(), containsAll(['card', 'deck']));
  });
}
