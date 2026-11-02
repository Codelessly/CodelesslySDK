import 'sound.dart';

/// No audio outside the browser: a stopwatch clock.
SoundEngine createSoundEngine() => SilentSoundEngine();
