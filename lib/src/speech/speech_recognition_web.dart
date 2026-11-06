import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'recognition.dart';

/// The Web Speech API's SpeechRecognition (webkitSpeechRecognition in
/// Chrome and Safari). Needs a secure origin and microphone permission;
/// Chrome sends the audio to its speech service; Firefox has none.
SpeechRecognizer createPlatformRecognizer() => _WebRecognizer();

class _WebRecognizer implements SpeechRecognizer {
  JSObject? _active;

  JSFunction? get _constructor {
    final JSAny? standard = web.window.getProperty('SpeechRecognition'.toJS);
    if (standard != null && standard.isA<JSFunction>()) return standard as JSFunction;
    final JSAny? prefixed = web.window.getProperty('webkitSpeechRecognition'.toJS);
    if (prefixed != null && prefixed.isA<JSFunction>()) return prefixed as JSFunction;
    return null;
  }

  @override
  bool get available => _constructor != null;

  @override
  Future<RecognitionResult> listen({required String language, required Duration timeout}) {
    final JSFunction? make = _constructor;
    if (make == null) return Future.value(const RecognitionResult('', error: 'unavailable'));
    stop();
    final JSObject recognition = make.callAsConstructor<JSObject>();
    _active = recognition;
    recognition
      ..setProperty('lang'.toJS, language.toJS)
      ..setProperty('interimResults'.toJS, false.toJS)
      ..setProperty('maxAlternatives'.toJS, 1.toJS)
      ..setProperty('continuous'.toJS, false.toJS);
    final Completer<RecognitionResult> done = Completer<RecognitionResult>();
    String transcript = '';
    double confidence = 0;
    recognition.setProperty(
      'onresult'.toJS,
      ((JSObject event) {
        final JSObject results = event.getProperty<JSObject>('results'.toJS);
        final int count = results.getProperty<JSNumber>('length'.toJS).toDartInt;
        final StringBuffer text = StringBuffer();
        for (int i = 0; i < count; i++) {
          final JSObject alternative = results
              .callMethod<JSObject>('item'.toJS, i.toJS)
              .callMethod<JSObject>('item'.toJS, 0.toJS);
          text.write(alternative.getProperty<JSString>('transcript'.toJS).toDart);
          confidence = alternative.getProperty<JSNumber>('confidence'.toJS).toDartDouble;
        }
        transcript = text.toString().trim();
      }).toJS,
    );
    recognition.setProperty(
      'onerror'.toJS,
      ((JSObject event) {
        final String error = event.getProperty<JSString>('error'.toJS).toDart;
        if (!done.isCompleted) done.complete(RecognitionResult(transcript, confidence: confidence, error: error));
      }).toJS,
    );
    recognition.setProperty(
      'onend'.toJS,
      ((JSObject _) {
        if (!done.isCompleted) {
          done.complete(RecognitionResult(transcript, confidence: confidence, error: transcript.isEmpty ? 'no-speech' : null));
        }
        if (identical(_active, recognition)) _active = null;
      }).toJS,
    );
    recognition.callMethod<JSAny?>('start'.toJS);
    return done.future.timeout(timeout, onTimeout: () {
      recognition.callMethod<JSAny?>('stop'.toJS);
      return RecognitionResult(transcript, confidence: confidence, error: transcript.isEmpty ? 'no-speech' : null);
    });
  }

  @override
  void stop() {
    _active?.callMethod<JSAny?>('abort'.toJS);
    _active = null;
  }
}
