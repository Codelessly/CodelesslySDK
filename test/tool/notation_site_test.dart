// tool/notation/notation_site.dart: `expand` knows the site a notation file
// belongs to (found beside the file or above it, as site.json or
// site/site.json): its components written in the notation (callable by
// name, each expanded after those it calls), its variables (a component
// that writes one does not declare its own), its theme (a plain text takes
// the theme's body), and a component named like a word of the notation is
// said, not silently a frame.
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_api/notation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/notation/notation_site.dart';

late Directory _root;

void _write(String path, String text) => File('${_root.path}/$path')
  ..parent.createSync(recursive: true)
  ..writeAsStringSync(text);

ExpandSettings _settings({double width = 1280}) =>
    (width: width, reflow: false, named: false, nearestColors: false, open: false, aliases: NotationVocabulary.core);

Map<String, Object?> _nodes(NotationResult r) => (r.document['nodes'] as Map).cast<String, Object?>();

void main() {
  setUp(() {
    _root = Directory.systemTemp.createTempSync('notation_site_test');
    _write('site/site.json', jsonEncode({
      'schema': 3,
      'pages': ['home.json'],
      'components': ['components/Tag.json', 'components/TagRow.json', 'components/Footer.json'],
      'variables': {'lang': 'ts'},
      'theme': {
        'colors': {'ink': '#FF202020'},
        'textStyles': {
          'body': {'fontSize': 15, 'color': 'ink'},
          'label': {'fontSize': 11, 'fontWeight': 600, 'color': 'ink'},
        },
      },
    }));
    // TagRow calls Tag: Tag is expanded first, whatever the file order.
    _write('components/TagRow.txt', 'component TagRow "Tags in a row."\nRow#tr gap=4\n  Tag label="a"\n  Tag label="b"\n');
    _write('components/Tag.txt', 'component Tag "A tag that sets the language."\n  param label="x"\nRow#tag onTap={lang=props.label}\n  Text "{props.label}" style=label\n');
    _write('components/Footer.txt', 'component Footer "The foot."\nColumn#ft\n  Text "foot"\n');
    _write('pages/home.txt', 'Column\n  TagRow\n  Tag label="py"\n  Text "{lang}"\n');
  });
  tearDown(() => _root.deleteSync(recursive: true));

  test('a page finds its site above it and calls the site\'s notation components by name', () async {
    final path = findSiteManifest(file: '${_root.path}/pages/home.txt');
    expect(path, isNotNull);
    final site = await NotationSite.load(path!);
    expect(site.sources.keys.toSet(), {'Tag', 'TagRow', 'Footer'});
    expect([for (final s in site.ordered()) s.type].indexOf('Tag'), lessThan([for (final s in site.ordered()) s.type].indexOf('TagRow')));
    final expander = NotationExpander(site: site, settings: _settings());
    final r = expander.expand(File('${_root.path}/pages/home.txt').readAsStringSync(), path: 'home.txt', screen: 'home');
    expect(r.issues, isEmpty);
    final types = {for (final n in _nodes(r).values) (n as Map)['type']};
    expect(types, containsAll(['TagRow', 'Tag']));
    expect(expander.failedComponents, isEmpty);
    // The site's variable is read by name: the page declares no copy of it.
    final vars = r.document['variables'];
    expect(jsonEncode(vars ?? const {}), isNot(contains('"lang"')));
  });

  test('a component that writes a site variable declares no variable of its own', () async {
    final site = await NotationSite.load(findSiteManifest(file: '${_root.path}/components/Tag.txt')!);
    final r = NotationExpander(site: site, settings: _settings()).expand(site.sources['Tag']!.text, path: 'Tag.txt', screen: 'screen');
    expect(r.issues, isEmpty);
    expect(jsonEncode(r.document['variables'] ?? const {}), isNot(contains('"lang"')));
  });

  test('the site\'s theme: a plain text takes its body', () async {
    _write('pages/look.txt', 'Column\n  Text "plain"\n');
    final site = await NotationSite.load(findSiteManifest(file: '${_root.path}/pages/look.txt')!);
    final r = NotationExpander(site: site, settings: _settings()).expand(File('${_root.path}/pages/look.txt').readAsStringSync(), path: 'look.txt', screen: 'look');
    expect(r.issues, isEmpty);
    final texts = [for (final n in _nodes(r).values) if ((n as Map)['type'] == 'text') (n['props'] as Map)['style']];
    expect(texts.single, {'from': 'body'});
  });

  test('a component named like a frame word is an issue that says how to call it', () async {
    _write('pages/foot.txt', 'Page\n  Section\n    Text "x"\n  Footer\n');
    final site = await NotationSite.load(findSiteManifest(file: '${_root.path}/pages/foot.txt')!);
    final r = NotationExpander(site: site, settings: _settings()).expand(File('${_root.path}/pages/foot.txt').readAsStringSync(), path: 'foot.txt', screen: 'foot');
    expect(r.issues.map((i) => i.message), contains(contains('the component Footer is not called')));
    _write('pages/foot2.txt', 'Page\n  Section\n    Text "x"\n  Footer type=Footer\n');
    final r2 = NotationExpander(site: site, settings: _settings()).expand(File('${_root.path}/pages/foot2.txt').readAsStringSync(), path: 'foot2.txt', screen: 'foot2');
    expect(r2.issues, isEmpty);
    expect({for (final n in _nodes(r2).values) (n as Map)['type']}, contains('Footer'));
  });

  test('outside a site nothing is found, and the expansion is as before', () {
    final alone = Directory.systemTemp.createTempSync('notation_alone');
    addTearDown(() => alone.deleteSync(recursive: true));
    File('${alone.path}/a.txt').writeAsStringSync('Text "a"\n');
    expect(findSiteManifest(file: '${alone.path}/a.txt'), isNull);
    final r = NotationExpander(settings: _settings(width: 390)).expand('Text "a"\n', path: 'a.txt', screen: 'screen');
    final plain = Catalog.run(standardCatalog, () => parseNotation('Text "a"\n', catalog: standardCatalog, options: const NotationOptions(reflow: false)));
    expect(jsonEncode(r.document), jsonEncode(plain.document));
  });
}
