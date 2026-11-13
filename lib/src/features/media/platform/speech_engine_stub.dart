import '../speech.dart';

/// No voice outside the web: `speech.available` is false.
SpeechEngine createSpeechEngine() => const SilentSpeechEngine();
