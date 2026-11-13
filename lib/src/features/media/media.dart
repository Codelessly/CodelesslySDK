// The media feature: speech, sounds (short voices, sustained notes and
// instrument voices, sound files), printing and saving files, and the
// `media.*` functions (probe, import, export). The core runtime doesn't
// import this: `mediaFeature` registers it through the plugin seam
// (runtime/actions/feature.dart).
import 'dart:async';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:just_audio/just_audio.dart' as audio;

import '../../runtime/actions/feature.dart';
import '../../runtime/actions/files.dart';
import '../../runtime/actions/runner.dart';
import '../../runtime/contracts.dart';
import '../../runtime/expressions/scopes.dart';
import '../../services/file_exports.dart' show FileExporter;
import '../../services/storage.dart' show CloudFileStorage, MemoryFileStorage;
import 'media_export.dart';
import 'media_probe.dart';
import 'printing.dart';
import 'sound.dart';
import 'speech.dart';

/// Speech, sound, printing, file saving and the `media.*` functions.
const CodelesslyFeature mediaFeature = CodelesslyFeature(
  name: 'media',
  actions: {
    SpeakAction.typeName: _speak,
    PlaySoundAction.typeName: _playSound,
    PrintAction.typeName: _print,
    DownloadFileAction.typeName: _downloadFile,
  },
  functions: {
    'media.probe': _mediaImport,
    'media.import': _mediaImport,
    'media.export': _mediaExport,
    'media.cancelExport': _mediaExport,
  },
  scopes: {'speech': _speechScope},
);

Future<void> _print(ActionDef action, ActionRun run) => printNodeAction((action as PrintAction).node, run);

Future<void> _downloadFile(ActionDef action, ActionRun run) async {
  final a = action as DownloadFileAction;
  final exports = run.service<FileExporter>();
  if (exports == null) throw StateError('downloadFile needs Services.');
  run.result = {
    'saved': await exports.saveText(fileName: run.text(a.fileName), text: run.text(a.text), mimeType: run.text(a.mimeType)),
  };
}

// --- speech and sound ---------------------------------------------------------------

Future<void> _speak(ActionDef action, ActionRun run) async {
  final r = await _speakNow(action as SpeakAction, run);
  if (r != null) run.result = r;
}

Future<Object?> _speakNow(SpeakAction a, ActionRun run) async {
  final speech = run.require<SpeechService>('Speech');
  if (a.stop) {
    speech.stop();
    return null;
  }
  double number(String text, double min, double max) =>
      (double.tryParse(run.text(text).trim()) ?? 1).clamp(min, max).toDouble();
  if (a.readAlong) {
    // Waits for the text to be said: a chain can go on (turn the page) only
    // when it was said to the end, not stopped.
    final completed = await speech.readAlong(run.text(a.text),
        language: run.text(a.language).trim(),
        rate: number(a.rate, 0.1, 10),
        pitch: a.pitch.isEmpty ? 1 : number(a.pitch, 0.5, 2),
        startWord: int.tryParse(run.text(a.startWord).trim()) ?? double.tryParse(run.text(a.startWord).trim())?.round() ?? 0);
    return {'completed': completed};
  }
  unawaited(speech.speak(run.text(a.text),
      language: run.text(a.language).trim(),
      rate: number(a.rate, 0.1, 10),
      pitch: a.pitch.isEmpty ? 1 : number(a.pitch, 0.5, 2)));
  return null;
}

/// The latest timed start of each voice id (see [_playSound]).
final Map<String, Object> _soundTokens = {};

void _playSound(ActionDef action, ActionRun run) {
  final a = action as PlaySoundAction;
  double? number(String v) => double.tryParse(run.text(v).trim());
  final service = run.require<SoundService>('Sound');
  switch (a.operation) {
    case 'start':
      final id = run.text(a.voiceId).trim();
      final note = a.note.isEmpty ? null : number(a.note);
      final frequency = note != null ? midiToHz(note) : number(a.frequency) ?? 440;
      service.startNoteWithWaveform(id, frequency: frequency, volume: number(a.volume) ?? 1, waveform: run.text(a.waveform).trim());
      // A voice with a duration releases itself, unless something started
      // another voice under its id in the meantime.
      final ms = a.duration.isEmpty ? null : number(a.duration);
      if (ms != null && ms >= 0) {
        final token = _soundTokens[id] = Object();
        Timer(Duration(milliseconds: ms.round()), () {
          if (identical(_soundTokens[id], token)) {
            _soundTokens.remove(id);
            service.stopNote(id);
          }
        });
      } else {
        _soundTokens.remove(id);
      }
      return;
    case 'stop':
      service.stopNote(run.text(a.voiceId).trim());
      return;
    case 'stopAll':
      service.stopAllNotes();
      return;
  }
  final url = run.text(a.url).trim();
  if (url.isNotEmpty) {
    unawaited(_playFile(url, (number(a.volume) ?? 1).clamp(0, 1).toDouble()));
    return;
  }
  final at = run.text(a.at).trim();
  service.play(
        SoundVoice.named(run.text(a.sound)),
        time: at.isEmpty ? null : double.tryParse(at),
        volume: number(a.volume) ?? 1,
        pitch: number(a.pitch) ?? 1,
      );
}

Future<void> _playFile(String url, double volume) async {
  final player = audio.AudioPlayer();
  try {
    await player.setUrl(url);
    await player.setVolume(volume);
    await player.play();
  } catch (_) {
    // A sound that can't play is skipped.
  } finally {
    await player.dispose();
  }
}

// Built-in callFunction names keep media encoding in the runtime host,
// never in the script sandbox. An app may override them in functions.
Future<Object?> _mediaExport(CallFunctionAction action, ActionRun run) async {
  final service = run.service<MediaExportService>();
  if (service == null) return {'ok': false, 'error': 'Video export is unavailable'};
  if (action.name == 'media.cancelExport') {
    service.cancel();
    return {'cancelled': true};
  }
  final params = run.json(action.params);
  final progress = params['progressVariable'] as String? ?? '';
  try {
    final raw = params['project'];
    if (raw is! Map) throw ArgumentError('Export needs a project with source clips');
    final request = MediaExportRequest.fromJson(raw.cast<String,Object?>(),
      fileName: params['fileName'] as String? ?? 'video.webm',
      width: (params['width'] as num?)?.toInt() ?? 640,
      height: (params['height'] as num?)?.toInt() ?? 360);
    final previousGeneration = service.generation;
    final operation = service.export(request, onProgress: (value) {
      if (progress.isNotEmpty) run.context.setVariable(progress, value);
    });
    final generation = service.generation;
    if (generation != previousGeneration) {
      run.host.onDispose(() { if (service.running && service.generation == generation) service.cancel(); });
    }
    final result = await operation;
    return {'ok': true, ...result};
  } catch (error) {
    return {'ok': false, 'error': '$error', 'cancelled': error is MediaExportCancelled};
  }
}

// Imported bytes are inspected before uploading. Public URL probing keeps the
// same HTTPS/MP4 restriction as the player; neither exposes DOM to scripts.
Future<Object?> _mediaImport(CallFunctionAction action, ActionRun run) async {
  try {
    final params = run.json(action.params);
    if (action.name == 'media.probe') {
      return {'ok': true, ...await probeMedia(params['url'] as String? ?? '')};
    }
    final files = run.require<CloudFileStorage>('Video import');
    if (files is MemoryFileStorage) {
      throw StateError(
        'Connect cloud file storage before choosing a device video. You can import a public HTTPS MP4 URL instead.',
      );
    }
    final picked = await pickFiles(run, images: false, multiple: false);
    if (run.isCanceled || picked.isEmpty) {
      return {'ok': false, 'cancelled': true};
    }
    final file = picked.first;
    final metadata = await probePickedVideo(file.name, file.bytes, contentType: file.contentType);
    if (run.isCanceled) {
      return {'ok': false, 'cancelled': true};
    }
    final name = file.name.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
    final uploaded = await files.upload(
      'media/imports/${DateTime.now().microsecondsSinceEpoch}-$name',
      file.bytes,
      contentType: 'video/mp4',
    );
    return {'ok': true, ...metadata, 'url': uploaded.url, 'name': file.name};
  } catch (error) {
    return {'ok': false, 'error': '$error'};
  }
}

// --- the `speech` value ---------------------------------------------------------------

NamedScope _speechScope(FeatureScopeHost host, ValueScope parent) => SpeechScope(host.services, parent: parent);

/// `speech` in expressions: the current utterance, including
/// boundary-driven word highlighting.
class SpeechScope extends NamedScope {
  SpeechScope(CodelesslyServices services, {super.parent}) : _speech = services.lookup<SpeechService>() {
    _speech?.addListener(_changed);
  }
  final SpeechService? _speech;
  void _changed() => changed(const ['speech']);
  @override
  bool declares(String name) => name == 'speech';
  @override
  Object? valueOf(String name, ValueScope reader) => _speech?.value ?? const <String, Object?>{};
  @override
  void dispose() {
    _speech?.removeListener(_changed);
    super.dispose();
  }
}
