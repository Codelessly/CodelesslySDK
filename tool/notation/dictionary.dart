// Dictionaries: folders of definitions (a `<Word>.txt` each, a `define` or a
// `primitive`) a page reads after its own definitions, its site's and its
// design system's, and before the notation's own words
// (codelessly_api NotationOptions.dictionary).
//
// expand, validate, print and prompt read the folders `--dictionary <folder>`
// names (written again for each further folder) or, with none written, the
// ones CODELESSLY_DICTIONARY lists (separated as in PATH; --no-dictionary
// reads none); a site's site.json adds its own (`"dictionary": ["../words"]`,
// relative to it) after those. The first that defines a word is the one
// read. The vocabulary record names the folder a word was read from, and the
// prompt lists the dictionaries' words.
import 'dart:io';

import 'package:codelessly_api/notation.dart';

/// The environment variable that names the dictionaries read when no
/// `--dictionary` is written.
const dictionaryVariable = 'CODELESSLY_DICTIONARY';

/// The folders `--dictionary` names in [args], in order; with none, those
/// [dictionaryVariable] lists (none with `--no-dictionary`).
List<String> dictionaryFolders(List<String> args) {
  final named = [
    for (var i = 0; i + 1 < args.length; i++)
      if (args[i] == '--dictionary') args[i + 1],
  ];
  if (named.isNotEmpty || args.contains('--no-dictionary')) return named;
  final listed = Platform.environment[dictionaryVariable] ?? '';
  return [
    for (final f in listed.split(Platform.isWindows ? ';' : ':'))
      if (f.trim().isNotEmpty) f.trim(),
  ];
}

/// Says each of [folders] that is not a folder, and whether all are.
bool dictionaryFoldersExist(List<String> folders) {
  var ok = true;
  for (final d in folders) {
    if (!FileSystemEntity.isDirectorySync(d)) {
      stderr.writeln('--dictionary $d: no such folder.');
      ok = false;
    }
  }
  return ok;
}

/// The name a dictionary is known by: its folder's last part.
String dictionaryName(String folder) => Directory(folder).absolute.uri.pathSegments.where((s) => s.isNotEmpty).last;

/// The definition files of [folder] (`*.txt`), by file name; what does not
/// read as a definition is given to [say], one sentence each.
Map<String, String> dictionaryTexts(String folder, {void Function(String)? say}) {
  final dir = Directory(folder);
  if (!dir.existsSync()) {
    say?.call('The dictionary $folder is not a folder: none of its words are read.');
    return const {};
  }
  final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.txt')).toList()..sort((a, b) => a.path.compareTo(b.path));
  final texts = {for (final f in files) f.uri.pathSegments.last: f.readAsStringSync()};
  for (final p in readDefinitions(texts, dictionary: dictionaryName(folder)).problems) {
    say?.call('The dictionary $folder: $p');
  }
  return texts;
}

/// [vocabulary] with the dictionaries in [folders] under the ones it has
/// already: of two that define a word, the earlier is read.
NotationVocabulary withDictionaries(NotationVocabulary vocabulary, List<String> folders, {void Function(String)? say}) {
  if (folders.isEmpty) return vocabulary;
  var added = NotationVocabulary.none;
  for (final folder in folders.reversed) {
    added = added.withDictionary(dictionaryTexts(folder, say: say), name: dictionaryName(folder));
  }
  // What [vocabulary] has is over what is added (its own dictionaries
  // first).
  return added.merge(vocabulary);
}

/// [options] with the dictionaries in [folders] (the earlier read first).
NotationOptions withDictionaryOptions(NotationOptions options, List<String> folders, {void Function(String)? say}) {
  var out = options;
  for (final folder in folders.reversed) {
    out = out.dictionary(dictionaryTexts(folder, say: say), name: dictionaryName(folder));
  }
  return out;
}
