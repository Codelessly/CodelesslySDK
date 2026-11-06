import 'recognition.dart';

/// No recognizer outside the web unless the host provides one.
SpeechRecognizer createPlatformRecognizer() => _Deaf();

class _Deaf implements SpeechRecognizer {
  @override
  bool get available => false;

  @override
  Future<RecognitionResult> listen({required String language, required Duration timeout}) async =>
      const RecognitionResult('', error: 'unavailable');

  @override
  void stop() {}
}
