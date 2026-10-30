import 'speech_stub.dart'
    if (dart.library.js_interop) 'speech_web.dart'
    as platform;

/// Speaks text aloud with the platform's text-to-speech. [SpeakAction]s run
/// through [Speech.backend], which tests and apps can replace.
abstract interface class SpeechBackend {
  /// Speaks [text] in [language] (a BCP-47 tag such as `ja-JP`; empty for
  /// the default voice) at [rate] (`1` normal) and [pitch] (`1` normal),
  /// replacing anything being spoken.
  void speak(
    String text, {
    required String language,
    required double rate,
    required double pitch,
  });

  /// Stops any speech.
  void stop();
}

/// Where [SpeakAction]s speak.
abstract final class Speech {
  /// The backend in use: the browser's speech synthesis on web, a no-op
  /// elsewhere. Replace it to speak another way or to observe calls in tests.
  static SpeechBackend backend = platform.createSpeechBackend();
}
