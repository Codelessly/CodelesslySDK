// Dictionaries (tool/notation/dictionary.dart): folders of definitions a page
// reads after its own, its site's and its design system's, named by
// --dictionary, CODELESSLY_DICTIONARY or a site's site.json; the record
// names the folder a word came from.
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/notation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/notation/dictionary.dart';
import '../../tool/notation/notation_site.dart';

late Directory _root;

void _write(String path, String text) => File('${_root.path}/$path')
  ..parent.createSync(recursive: true)
  ..writeAsStringSync(text);

void main() {
  setUp(() {
    _root = Directory.systemTemp.createTempSync('dictionary_test');
    _write('words/Lede.txt', '// A lead paragraph.\ndefine Lede "text"\n  Text.body "{text}" size=18 ...\n');
    _write('words/Badge2.txt', 'define Badge2 "text"\n  Text.caption "{text}"\n');
    _write('more/Lede.txt', 'define Lede "text"\n  Text.caption "{text}"\n');
  });
  tearDown(() => _root.deleteSync(recursive: true));

  test('--dictionary names folders in order; with none, the environment variable is not read when --no-dictionary is written', () {
    expect(dictionaryFolders(['expand', 'x', '--dictionary', 'a', '--open', '--dictionary', 'b']), ['a', 'b']);
    expect(dictionaryFolders(['expand', 'x', '--no-dictionary']), isEmpty);
    expect(dictionaryName('${_root.path}/words'), 'words');
  });

  test('the first folder that defines a word is read; the record names it', () {
    final v = withDictionaries(NotationVocabulary.core, ['${_root.path}/words', '${_root.path}/more']);
    expect(v.dictionary['Lede']!.single.dictionary, 'words');
    expect(v.types.keys, containsAll(NotationVocabulary.core.types.keys));
    final r = parseNotation('Column\n  Lede "Hello"\n', options: const NotationOptions().open(vocabulary: v));
    expect(r.issues, isEmpty);
    expect([for (final u in r.vocabulary) (u.kind, u.word, u.of)], [('definition', 'Lede', 'words')]);
    // Reversed, the other one is read.
    final w = withDictionaries(NotationVocabulary.core, ['${_root.path}/more', '${_root.path}/words']);
    expect(w.dictionary['Lede']!.single.dictionary, 'more');
  });

  test('a site\'s dictionary (site.json) is read under the ones given, and the record names its folder', () async {
    _write('site/site.json', jsonEncode({'schema': 3, 'pages': ['home.json'], 'dictionary': ['../words']}));
    _write('pages/home.txt', 'Column\n  Lede "Hello"\n  Badge2 "New"\n');
    final site = await NotationSite.load(findSiteManifest(site: _root.path)!);
    expect(site.dictionaries.single.replaceAll(r'\', '/'), endsWith('site/../words'));
    final given = withDictionaries(NotationVocabulary.core, ['${_root.path}/more']);
    final expander = NotationExpander(site: site, settings: (width: 1440, reflow: false, named: false, nearestColors: false, open: false, aliases: given));
    final r = expander.expand(File('${_root.path}/pages/home.txt').readAsStringSync(), path: 'home.txt', screen: 'home');
    expect(r.issues, isEmpty);
    expect({for (final u in r.vocabulary) u.word: u.of}, {'Lede': 'more', 'Badge2': 'words'});
  });
}
