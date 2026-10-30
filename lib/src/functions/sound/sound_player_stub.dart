import 'sound_player.dart';

/// No speech engine off the web.
Future<void> speak(
  String text, {
  required double rate,
  required double pitch,
  required String language,
}) async {}

/// No synthesizer off the web.
Future<void> playTones(List<Tone> tones, {required double volume}) async {}
