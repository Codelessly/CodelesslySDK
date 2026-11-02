import 'speech.dart';

/// No voice outside the web yet: `speech.available` is false, so a screen
/// can say pronunciation isn't available.
SpeechEngine createSpeechEngine() => _Silent();

class _Silent implements SpeechEngine {
  @override
  bool get available => false;

  @override
  Future<void> speak(
    String text, {
    required String language,
    required double rate,
    required double pitch,
  }) async {}

  @override
  void cancel() {}
}
