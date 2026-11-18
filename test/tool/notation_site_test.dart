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
import '../../tool/render/src/site.dart' show designSystemProblems, loadSite, sitePath;

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

  test('pages listed by name or as records are those names\' JSON (test 10: one issue a page, extensionless files)', () async {
    final m = jsonDecode(File('${_root.path}/site/site.json').readAsStringSync()) as Map;
    _write('site/site.json', jsonEncode({...m, 'pages': ['home', {'id': 'about', 'file': 'about.json'}, {'id': 'faq'}]}));
    final site = await NotationSite.load('${_root.path}/site/site.json');
    expect(site.screens, ['home', 'about', 'faq']);
    expect(site.pageOut('pages/home.txt'), endsWith('/home.json'));
    expect(site.pageOut('pages/about.txt'), endsWith('/about.json'));
    expect(site.pageOut('pages/faq.txt'), endsWith('/faq.json'));
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

  test('an overlay a site component writes is on every page that calls it (round 10, R28)', () async {
    _write('components/Mast.txt', 'component Mast "A top bar with a bag."\nRow#mast gap=8\n  Button#bag "Bag" onTap={open basket}\nDrawer#basket "Your bag" right w=440\n  Text "Items"\n');
    _write('pages/shop.txt', 'Column\n  Mast\n  Text "Body"\n');
    final m = jsonDecode(File('${_root.path}/site/site.json').readAsStringSync()) as Map;
    _write('site/site.json', jsonEncode({...m, 'pages': ['home.json', 'shop.json']}));
    final site = await NotationSite.load(findSiteManifest(file: '${_root.path}/pages/shop.txt')!);
    final r = expandSitePages(NotationExpander(site: site, settings: _settings()), site);
    for (final res in [...r.results, ...r.componentResults.values]) {
      expect(res.issues, isEmpty);
    }
    final shop = r.pages.firstWhere((p) => p.name == 'shop').document;
    expect(shop['roots'], ['shop', 'basket']);
    final basket = (shop['nodes'] as Map)['basket'] as Map;
    expect(basket['type'], 'canvas');
    final mast = r.components.firstWhere((c) => c.type == 'Mast').document;
    expect(jsonEncode(mast['nodes']), contains('"to":"basket","presentation":"dialog","cover":true'));
    // A page that does not call it has none.
    final home = r.pages.firstWhere((p) => p.name == 'home').document;
    expect(home['roots'], ['home']);
  });

  group("two pages' overlays of one id", () {
    // The site expanded whole: each page's document by name, the
    // components' by type, and what was said.
    Future<({Map<String, Json> pages, Map<String, Json> components, List<({String path, String message})> issues, OverlayScoping scoping})> expandAll() async {
      final site = await NotationSite.load(findSiteManifest(file: '${_root.path}/pages/home.txt')!);
      final r = expandSitePages(NotationExpander(site: site, settings: _settings()), site);
      for (final res in [...r.results, ...r.componentResults.values]) {
        expect(res.issues, isEmpty);
      }
      return (
        pages: {for (final p in r.pages) p.name: p.document},
        components: {for (final c in r.components) c.type: c.document},
        issues: r.scoping.issues,
        scoping: r.scoping,
      );
    }

    Map<String, Object?> nodesOf(Json d) => (d['nodes'] as Map).cast<String, Object?>();
    // Every action of [d] of [type], wherever it is.
    List<Map> actionsOf(Object? d, String type) => [
          if (d is Map && d['type'] == type) d,
          if (d is Map) for (final v in d.values) ...actionsOf(v, type),
          if (d is List) for (final v in d) ...actionsOf(v, type),
        ];

    void page(String name, String text) => _write('pages/$name.txt', 'Column\n  Button "Menu" onTap={open nav}\nDrawer#nav\n  Text "$text"\n');

    test('drawn differently: each page has its own, opened by that page', () async {
      page('board', 'board');
      page('archive', 'archive');
      final r = await expandAll();
      expect(r.issues, isEmpty);
      expect(r.scoping.renamed, {
        'nav': {'archive': 'nav--archive', 'board': 'nav--board'},
      });
      for (final p in ['board', 'archive']) {
        final d = r.pages[p]!;
        expect(d['roots'], [p, 'nav--$p']);
        final canvas = nodesOf(d)['nav--$p']! as Map;
        // The id as written stays its name: what a render step may name.
        expect(canvas['name'], 'nav');
        expect(writtenOverlayId('nav--$p', p, canvas.cast()), 'nav');
        expect(nodesOf(d).containsKey('nav'), isFalse);
        expect([for (final a in actionsOf(d['nodes'], 'openModal')) a['to']], ['nav--$p']);
        expect(jsonEncode(canvas), isNot(contains(p == 'board' ? 'archive' : '"board"')));
      }
    });

    test('drawn the same: one shared overlay, as written', () async {
      page('board', 'menu');
      page('archive', 'menu');
      final r = await expandAll();
      expect(r.issues, isEmpty);
      expect(r.scoping.renamed, isEmpty);
      for (final p in ['board', 'archive']) {
        expect(r.pages[p]!['roots'], [p, 'nav']);
        expect([for (final a in actionsOf(r.pages[p]!['nodes'], 'openModal')) a['to']], ['nav']);
      }
    });

    test('the same lines below more lines on one page (other generated ids): one shared overlay', () async {
      _write('pages/board.txt', 'Column\n  Text "a"\n  Row\n    Text "b"\n  Button "Menu" onTap={open nav}\nDrawer#nav\n  Column\n    Text "menu"\n');
      _write('pages/archive.txt', 'Column\n  Button "Menu" onTap={open nav}\nDrawer#nav\n  Column\n    Text "menu"\n');
      final r = await expandAll();
      expect(r.issues, isEmpty);
      expect(r.scoping.renamed, isEmpty);
    });

    test('an overlay drawn the same that opens a per-page one is per page too', () async {
      for (final p in ['board', 'archive']) {
        _write('pages/$p.txt', 'Column\n  Button "Keys" onTap={open keys}\nDialog#keys "Keys"\n  Button "Menu" onTap={open nav}\nDrawer#nav\n  Text "$p"\n');
      }
      final r = await expandAll();
      expect(r.issues, isEmpty);
      expect(r.scoping.renamed.keys.toSet(), {'nav', 'keys'});
      expect({for (final a in actionsOf(r.pages['board']!['nodes'], 'openModal')) a['to']}, {'keys--board', 'nav--board'});
    });

    test('on one page only: as written', () async {
      page('board', 'board');
      final r = await expandAll();
      expect(r.issues, isEmpty);
      expect(r.pages['board']!['roots'], ['board', 'nav']);
    });

    test("a component's open opens the calling page's own (through a component that calls it too)", () async {
      _write('components/NavButton.txt', 'component NavButton "Opens the navigation."\nButton#nb "Menu" onTap={open nav}\n');
      _write('components/MenuStrip.txt', 'component MenuStrip "The bar."\nRow#tb\n  NavButton\n');
      for (final p in ['board', 'archive']) {
        _write('pages/$p.txt', 'Column\n  NavButton\n  MenuStrip\nDrawer#nav\n  Text "$p"\n');
      }
      final r = await expandAll();
      expect(r.issues, isEmpty);
      // The component's open is an event of it, the action its value.
      final events = actionsOf(r.components['NavButton']!['nodes'], 'componentEvent');
      expect(events.single['event'], 'open--nav');
      expect((events.single['value'] as Map)['to'], 'nav');
      // No open is left but that value.
      expect(actionsOf(r.components['NavButton']!['nodes'], 'openModal').single, same(events.single['value']));
      // MenuStrip's call of NavButton passes it on.
      final passed = actionsOf(r.components['MenuStrip']!['nodes'], 'componentEvent');
      expect(passed.single, {'type': 'componentEvent', 'event': 'open--nav', 'value': r'${result}'});
      // Each page's calls open that page's own.
      for (final p in ['board', 'archive']) {
        final calls = [for (final n in nodesOf(r.pages[p]!).values) if (n is Map && (n['type'] == 'NavButton' || n['type'] == 'MenuStrip')) n];
        expect(calls, hasLength(2));
        for (final c in calls) {
          final reaction = (c['actions'] as List).cast<Map>().singleWhere((a) => (a['trigger'] as Map)['event'] == 'open--nav');
          expect((reaction['actions'] as List).single, containsPair('to', 'nav--$p'));
          expect((reaction['actions'] as List).single, containsPair('type', 'openModal'));
        }
      }
      // print gives back what was written: the page's own overlay as `nav`,
      // the component's open as an open.
      for (final p in ['board', 'archive']) {
        final site = await NotationSite.load(findSiteManifest(file: '${_root.path}/pages/$p.txt')!);
        final alone = NotationExpander(site: site, settings: _settings()).expand(File('${_root.path}/pages/$p.txt').readAsStringSync(), path: '$p.txt', screen: p);
        expect(jsonEncode(unscopeOverlays(r.pages[p]!)), jsonEncode(alone.document));
      }
      final site = await NotationSite.load(findSiteManifest(file: '${_root.path}/pages/board.txt')!);
      final nb = NotationExpander(site: site, settings: _settings()).expand(site.sources['NavButton']!.text, path: 'NavButton.txt', screen: 'screen');
      expect(jsonEncode(unscopeOverlays(r.components['NavButton']!)), jsonEncode(nb.document));
    });

    test('a page that calls such a component and has no overlay of that id is said', () async {
      _write('components/NavButton.txt', 'component NavButton "Opens the navigation."\nButton#nb "Menu" onTap={open nav}\n');
      for (final p in ['board', 'archive']) {
        _write('pages/$p.txt', 'Column\n  NavButton\nDrawer#nav\n  Text "$p"\n');
      }
      _write('pages/list.txt', 'Column\n  NavButton\n');
      final r = await expandAll();
      expect(r.issues.single.path, endsWith('list.txt'));
      expect(r.issues.single.message,
          allOf(contains('the component NavButton'), contains('"nav"'), contains('archive and board'), contains('Write an overlay #nav on the page list')));
    });

    test('a page whose name is the id an overlay would be given is said, and that overlay left as written', () async {
      page('board', 'board');
      page('archive', 'archive');
      _write('pages/nav--board.txt', 'Column\n  Text "x"\n');
      final r = await expandAll();
      expect(r.issues.single.message, allOf(contains('"nav--board"'), contains('is the id of a page')));
      expect(r.pages['board']!['roots'], ['board', 'nav']);
      expect(r.pages['archive']!['roots'], ['archive', 'nav--archive']);
    });

    test("an overlay with a page's id is said", () async {
      _write('pages/board.txt', 'Column\n  Button "Go" onTap={open home}\nDialog#home "Home"\n  Text "x"\n');
      final r = await expandAll();
      expect(r.issues.single.message, contains('the overlay "home" has the id of the page home'));
    });
  });

  test("a component's key lines are the page's that calls it", () async {
    _write('components/ConsoleNav.txt', '''component ConsoleNav "The sidebar."
Column#nv
  Text "nav"
key alt+1 onPress={go home}
''');
    _write('pages/keys.txt', '''Row
  ConsoleNav
  Text "page"
''');
    final site = await NotationSite.load(findSiteManifest(file: '${_root.path}/pages/keys.txt')!);
    final expander = NotationExpander(site: site, settings: _settings());
    final r = expander.expand(File('${_root.path}/pages/keys.txt').readAsStringSync(), path: 'keys.txt', screen: 'keys');
    expect(r.issues, isEmpty);
    final screen = _nodes(r)['keys']! as Map;
    expect(jsonEncode(screen['actions']), allOf(contains('"key":"alt+1"'), contains('"to":"home"')));
  });

  test('a designSystem path may be absolute or relative to site.json (expand and render both load it)', () async {
    final ds = Directory.systemTemp.createTempSync('notation_site_ds');
    addTearDown(() => ds.deleteSync(recursive: true));
    File('${ds.path}/design_system.json').writeAsStringSync(jsonEncode({'id': 'd', 'name': 'D', 'components': []}));
    final absolute = ds.path.replaceAll(r'\', '/');
    for (final ref in [absolute, ds.path]) {
      final m = jsonDecode(File('${_root.path}/site/site.json').readAsStringSync()) as Map;
      _write('site/site.json', jsonEncode({...m, 'designSystem': ref}));
      final site = await NotationSite.load('${_root.path}/site/site.json');
      expect(site.problems, isEmpty, reason: ref);
      expect(site.designSystem, isNotNull, reason: ref);
      designSystemProblems.clear();
      loadSite(['${_root.path}/site'], (_) => const []);
      expect(designSystemProblems, isEmpty, reason: ref);
    }
    expect(sitePath('/a/site', '../ds'), '/a/site/../ds');
    expect(sitePath('/a/site', 'C:/x/ds'), 'C:/x/ds');
    expect(sitePath('/a/site', r'C:\x\ds'), r'C:\x\ds');
    expect(sitePath('/a/site', '/x/ds'), '/x/ds');
  });
}
