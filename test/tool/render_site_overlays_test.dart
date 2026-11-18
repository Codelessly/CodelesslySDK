// Two pages of a site write `Drawer#nav` and draw it differently: site
// expansion makes each page's its own (`nav--board`, `nav--archive`:
// tool/notation/site_overlays.dart). Rendered, each page opens its own,
// from its own button and from a component's (one for the whole site), and
// a step names the drawer as its page wrote it (`nav/pick`).
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:codelessly_api/notation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/notation/notation_site.dart';
import '../../tool/render/src/args.dart';
import '../../tool/render/src/render.dart';

void main() {
  late Directory root;
  void write(String path, String text) => File('${root.path}/$path')
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(text);

  setUp(() async {
    root = Directory.systemTemp.createTempSync('render_site_overlays_test');
    write('site/site.json', jsonEncode({
      'schema': 3,
      'pages': ['board.json', 'archive.json'],
      'components': ['components/NavButton.json'],
    }));
    write('components/NavButton.txt', 'component NavButton "Opens the navigation."\nButton#nb "Navigation" onTap={open nav}\n');
    for (final p in ['board', 'archive']) {
      write('pages/$p.txt', '''state last=""
Column gap=8
  Button#menu "Menu" onTap={open nav}
  NavButton#call
  Text "Last: {last}"
Drawer#nav
  Text "The $p drawer"
  Button#pick "Pick" onTap={last="$p"; close}
''');
    }
    final site = await NotationSite.load('${root.path}/site/site.json');
    final r = expandSitePages(
        NotationExpander(site: site, settings: (width: 390, reflow: false, named: false, nearestColors: false, open: false, aliases: NotationVocabulary.core)),
        site);
    expect([for (final x in [...r.results, ...r.componentResults.values]) ...x.issues], isEmpty);
    expect(r.scoping.issues, isEmpty);
    for (final c in r.components) {
      write('site/components/${c.type}.json', jsonEncode(c.document));
    }
    for (final p in r.pages) {
      write('site/${p.name}.json', jsonEncode(p.document));
    }
  });
  tearDown(() => root.deleteSync(recursive: true));

  Future<(List<String>, List<Map>)> render(WidgetTester tester, String screen, List<Step> steps) async {
    final out = Directory('${root.path}/out-$screen-${steps.length}')..createSync();
    final report = await runRender(tester,
        RenderArgs(inputs: ['${root.path}/site'], out: out.path, sizes: const [Size(390, 844)], screens: [screen], steps: steps, dumpLayout: true));
    final boxes = jsonDecode(File('${out.path}/$screen@390x844.layout.json').readAsStringSync()) as List;
    return ([for (final b in boxes) if ((b as Map)['text'] case final String t) t], [for (final d in report.diagnostics) d as Map]);
  }

  for (final p in ['board', 'archive']) {
    final other = p == 'board' ? 'archive' : 'board';
    testWidgets('$p opens its own drawer from its button', (tester) async {
      final (texts, diagnostics) = await render(tester, p, const [Step('tap', 'menu')]);
      expect(diagnostics, isEmpty, reason: '$diagnostics');
      expect(texts, contains('The $p drawer'));
      expect(texts, isNot(contains('The $other drawer')));
    });

    testWidgets("$p opens its own drawer from a component's button", (tester) async {
      final (texts, diagnostics) = await render(tester, p, const [Step('tap', 'call/nb')]);
      expect(diagnostics, isEmpty, reason: '$diagnostics');
      expect(texts, contains('The $p drawer'));
      expect(texts, isNot(contains('The $other drawer')));
    });
  }

  testWidgets('no drawer is drawn until one is opened', (tester) async {
    final (texts, diagnostics) = await render(tester, 'board', const []);
    expect(diagnostics, isEmpty, reason: '$diagnostics');
    expect(texts.where((t) => t.endsWith('drawer')), isEmpty);
  });

  testWidgets('--screen with the id as written is not one page\'s pick', (tester) async {
    final out = Directory('${root.path}/out-screen')..createSync();
    final report = await runRender(tester, RenderArgs(inputs: ['${root.path}/site'], out: out.path, sizes: const [Size(390, 844)], screens: const ['nav']));
    expect('${report.diagnostics}', allOf(contains('unknown_screen_arg'), contains('nav--archive, nav--board')));
  });

  testWidgets('a step names the drawer as its page wrote it', (tester) async {
    final (texts, diagnostics) = await render(tester, 'board', const [Step('tap', 'menu'), Step('tap', 'nav/pick')]);
    expect(diagnostics, isEmpty, reason: '$diagnostics');
    expect(texts, contains('Last: board'));
  });
}
