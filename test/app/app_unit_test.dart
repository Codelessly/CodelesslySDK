// Ported from SDK 8.x: canvas_viewport_test, canvas_location_test,
// resolve_layout_id_test, initial_screen_test; plus loading, caching and
// fonts.
import 'dart:typed_data';

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Node canvasNode(double w, double h, {ScaleMode mode = ScaleMode.responsive, bool hug = false, double? maxWidth}) => Node.fromJson({
      'type': 'canvas',
      'layout': {
        'width': w,
        'height': hug ? {'hug': h} : h,
        if (maxWidth != null) 'constraints': {'maxWidth': maxWidth},
      },
      if (mode != ScaleMode.responsive) 'props': {'scaleMode': mode.name},
    }, id: 'c')!;

/// Tidepool: tides (entry), guide, creature at guide/:id, newCreature at
/// guide/new, journal, settings (no path).
PublishModel tidepool({bool withNotFound = false, Map<String, String> extra = const {}}) {
  final paths = <String, String?>{
    'tides': null,
    'guide': 'guide',
    'creature': 'guide/:id',
    'newCreature': 'guide/new',
    'journal': '/journal/',
    'settings': null,
    if (withNotFound) 'lost': '*',
    ...extra,
  };
  return PublishModel(
    projectId: 'tidepool',
    entryLayoutId: 'tides',
    layouts: {
      for (final e in paths.entries)
        e.key: PublishLayoutInfo(id: e.key, canvases: [PublishCanvas(id: e.key, name: e.key, path: e.value)]),
    },
  );
}

void main() {
  group('CanvasViewport', () {
    const screen = BoxConstraints(maxWidth: 390, maxHeight: 844);

    test('a screen canvas fills the space it is given', () {
      final box = CanvasViewport.resolve(canvasNode(1440, 900), screen);
      expect((box.width, box.height, box.scale), (390.0, 844.0, 1.0));
    });

    test('a dialog canvas keeps its design size, within the screen', () {
      final c = canvasNode(1440, 900);
      final box = CanvasViewport.resolve(c, screen, sizing: CanvasSizing.design);
      expect((box.width, box.height), (390.0, 844.0));
      final wide = CanvasViewport.resolve(c, const BoxConstraints(maxWidth: 1920, maxHeight: 1080), sizing: CanvasSizing.design);
      expect((wide.width, wide.height), (1440.0, 900.0));
    });

    test('a sheet fills the width at its design height', () {
      final box = CanvasViewport.resolve(canvasNode(390, 300), const BoxConstraints(maxWidth: 800, maxHeight: 1000),
          sizing: CanvasSizing.fillWidth);
      expect((box.width, box.height), (800.0, 300.0));
    });

    test('unbounded: the design height, or the content height when it hugs', () {
      const tall = BoxConstraints(maxWidth: 390);
      expect(CanvasViewport.resolve(canvasNode(390, 844), tall).height, 844);
      expect(CanvasViewport.resolve(canvasNode(390, 844, hug: true), tall).height, isNull);
      expect(CanvasViewport.resolve(canvasNode(390, 844), const BoxConstraints(maxHeight: 500)).width, 390);
    });

    test('autoScale lays out at the design width, scaled to the space', () {
      final c = canvasNode(1440, 900, mode: ScaleMode.autoScale);
      final box = CanvasViewport.resolve(c, const BoxConstraints(maxWidth: 720));
      expect(box.layoutWidth, 1440);
      expect(box.scale, 0.5);
      expect(box.height, 450);
      final capped = CanvasViewport.resolve(canvasNode(1440, 900, mode: ScaleMode.autoScale, maxWidth: 720),
          const BoxConstraints(maxWidth: 2000, maxHeight: 1000));
      expect(capped.scale, 0.5);
      expect(capped.layoutHeight, 2000);
      expect(CanvasViewport.autoScaleHeight(c, 2880), 1800);
    });
  });

  group('CanvasLocation', () {
    final model = tidepool();

    test('matches a canvas by its path', () {
      final match = CanvasLocation.match(model, '/guide/bat-star?from=tides&id=ignored');
      expect(match?.layoutId, 'creature');
      expect(match?.params, {'id': 'bat-star', 'from': 'tides'});
      expect(CanvasLocation.match(model, 'journal/')?.canvasId, 'journal');
      expect(CanvasLocation.match(model, 'guide')?.canvasId, 'guide');
    });

    test('prefers literal segments over params', () {
      expect(CanvasLocation.match(model, 'guide/new')?.canvasId, 'newCreature');
    });

    test('matches nothing for the root or an unknown path', () {
      expect(CanvasLocation.match(model, ''), isNull);
      expect(CanvasLocation.match(model, '/'), isNull);
      expect(CanvasLocation.match(model, 'guide/bat-star/more'), isNull);
      expect(CanvasLocation.match(model, 'kraken'), isNull);
    });

    test("an app's not found screen takes every unknown path", () {
      final lost = tidepool(withNotFound: true);
      final match = CanvasLocation.match(lost, '/amp/room?x=1');
      expect(match?.canvasId, 'lost');
      expect(match?.params, {'x': '1', 'path': 'amp/room'});
      expect(CanvasLocation.match(lost, 'guide/new')?.canvasId, 'newCreature');
      expect(CanvasLocation.match(lost, '/'), isNull);
    });

    test('fills a path with params', () {
      expect(CanvasLocation.locationOf(model, 'creature', {'id': 'sea star', 'from': 'tides', 'none': null}),
          'guide/sea%20star?from=tides');
      expect(CanvasLocation.locationOf(model, 'journal', {}), 'journal');
      expect(CanvasLocation.locationOf(model, 'tides', {}), '');
      expect(CanvasLocation.locationOf(model, 'tides', {'a': 1}), '?a=1');
      expect(CanvasLocation.locationOf(model, 'settings', {}), isNull);
      expect(CanvasLocation.locationOf(model, 'creature', {}), isNull);
    });

    test('catch-all paths take the rest, and lose to every other match', () {
      final m = tidepool(extra: {'notFound': '*path', 'docs': 'docs/*rest'});
      expect(CanvasLocation.match(m, 'kraken/deep?x=1')?.params, {'path': 'kraken/deep', 'x': '1'});
      expect(CanvasLocation.match(m, 'docs/a/b')?.params, {'rest': 'a/b'});
      expect(CanvasLocation.match(m, 'docs')?.canvasId, 'notFound');
      expect(CanvasLocation.match(m, 'guide/bat-star')?.canvasId, 'creature');
      expect(CanvasLocation.locationOf(m, 'docs', {'rest': 'a/b', 'q': 1}), 'docs/a/b?q=1');
      expect(CanvasLocation.locationOf(m, 'notFound', {}), isNull);
    });

    test('an optional trailing param matches with or without its segment', () {
      final pattern = CanvasLocation.segmentsOf('sheet/:id?');
      expect(CanvasLocation.matchPattern(pattern, ['sheet']), <String, String>{});
      expect(CanvasLocation.matchPattern(pattern, ['sheet', 'doom']), {'id': 'doom'});
      expect(CanvasLocation.matchPattern(pattern, ['sheet', 'a', 'b']), isNull);
      expect(CanvasLocation.matchPattern(pattern, ['patches']), isNull);
      expect(CanvasLocation.expandOptional('sheet/:id?'), ['sheet/:id', 'sheet']);
      expect(CanvasLocation.expandOptional('guide/:id'), ['guide/:id']);
      expect(CanvasLocation.fill('sheet/:id?', {'id': 'doom'}), 'sheet/doom');
      expect(CanvasLocation.fill('sheet/:id?', {'id': ''}), 'sheet');
      expect(CanvasLocation.fill('sheet/:id?', {}), 'sheet');
      final m = tidepool(extra: {'sheet': 'sheet/:id?'});
      expect(CanvasLocation.match(m, 'sheet')?.canvasId, 'sheet');
      expect(CanvasLocation.match(m, 'sheet/doom')?.params, {'id': 'doom'});
    });

    test('a screen\'s path from its name, unique among the others', () {
      expect(CanvasLocation.defaultPathOf('Log entry'), 'log-entry');
      expect(CanvasLocation.defaultPathOf('  Café · Menu!  '), 'café-menu');
      expect(CanvasLocation.defaultPathOf('***'), isNull);
      expect(CanvasLocation.uniquePath('log-entry', {'log-entry', 'log-entry-2'}), 'log-entry-3');
      expect(CanvasLocation.uniquePath('home', {}), 'home');
    });

    test('a link to a screen by its id is at its path', () {
      final model = tidepool();
      expect(CanvasLocation.named(model, 'creature?id=kraken'), 'guide/kraken');
      // The entry screen's id is the root.
      expect(CanvasLocation.named(model, 'tides'), '');
      // A param the path needs is missing, or the screen has no path.
      expect(CanvasLocation.named(model, 'creature'), 'creature');
      expect(CanvasLocation.named(model, 'settings'), 'settings');
      expect(CanvasLocation.named(model, 'guide/bat-star'), 'guide/bat-star');
    });

    test('the layout shown at a location', () {
      final model = tidepool(withNotFound: true);
      expect(CodelesslyAppIdentity.layoutIdAt(model, '/'), 'tides');
      expect(CodelesslyAppIdentity.layoutIdAt(model, '/guide/bat-star'), 'creature');
      // A screen at /<its id> wins over the catch-all.
      expect(CodelesslyAppIdentity.layoutIdAt(model, '/settings'), 'settings');
      expect(CodelesslyAppIdentity.layoutIdAt(model, '/nowhere'), 'lost');
    });
  });

  group('NavigationRequest', () {
    test('reads navigate actions', () {
      final r = NavigationRequest.fromJson({
        'type': 'navigate', 'mode': 'reset', 'to': 'a', 'params': {'x': 1}, 'base': 'b', //
      });
      expect((r.type, r.destinationId, r.baseDestinationId), (NavigationType.reset, 'a', 'b'));
      expect(r.params, {'x': 1});
      final d = NavigationRequest.fromJson({'type': 'navigate', 'to': 'a', 'base': ''});
      expect((d.type, d.baseDestinationId), (NavigationType.push, null));
    });
  });

  group('MapValueScope', () {
    test('reads paths, falls back to its parent, and notifies', () {
      final root = MapValueScope(values: {
        'data': {
          'user': {'name': 'Ada', 'tags': ['a', 'b']},
        },
      });
      final screen = MapValueScope(values: {'count': 1}, parent: root);
      expect(screen.read('data.user.name'), 'Ada');
      expect(screen.read('data.user.tags[1]'), 'b');
      expect(screen.read('data.user.tags.0'), 'a');
      expect(screen.read('count'), 1);
      expect(screen.read('nope.x'), isNull);
      var notified = 0;
      screen.addListener(() => notified++);
      screen.set('count', 1);
      expect(notified, 0);
      screen.set('count', 2);
      root.set('data', {'user': {'name': 'Grace'}});
      expect(notified, 2);
      expect(screen.scopeOf('data'), same(root));
      screen.dispose();
      root.dispose();
    });

    test('variables start at their published values', () {
      final layout = PublishLayout.fromJson({
        'id': 'l',
        'roots': ['c'],
        'nodes': {'c': {'type': 'canvas'}},
        'variables': {
          'c': [
            {'name': 'n', 'type': 'integer', 'value': 3},
            {'name': 'list', 'type': 'list', 'value': [1, 2]},
            {'name': 'twice', 'formula': 'n * 2'},
          ],
        },
      });
      expect(initialVariables(layout, 'c'), {'n': 3, 'list': [1, 2]});
    });
  });

  group('Codelessly', () {
    final layout = PublishLayout(
      document: LayoutDocument(id: 'home', roots: const ['c'], nodes: {'c': canvasNode(390, 844)}),
      fonts: const ['f'],
      lastUpdated: DateTime.utc(2026),
    );
    PublishBundle bundle({DateTime? updated}) => PublishBundle(
          model: PublishModel(
            projectId: 'p',
            entryLayoutId: 'home',
            layouts: {'home': PublishLayoutInfo(id: 'home', canvases: const [PublishCanvas(id: 'c')], fonts: const ['f'], lastUpdated: updated ?? DateTime.utc(2026))},
            layoutIDMap: const {'welcome': 'home'},
            fonts: const {'f': PublishFont(id: 'f', family: 'Inter', weight: 700)},
          ),
          layouts: {'home': updated == null ? layout : layout.copyWith(lastUpdated: updated)},
        );

    test('loads the model and layouts, by any id, once', () async {
      final loader = MemoryPublishLoader(bundle());
      final fetched = <String>[];
      final c = Codelessly(config: const CodelesslyConfig(projectId: 'p'), loader: loader, fonts: _Fonts(fetched));
      expect(c.status, isA<CEmpty>());
      await c.initialize();
      expect(c.status, isA<CLoaded>());
      expect((await c.loadLayout('welcome')).id, 'home');
      expect((await c.loadLayout('c')).id, 'home');
      expect(loader.calls, ['model:publish', 'layout:publish:home']);
      expect(fetched, ['Inter 700']);
      expect(() => c.loadLayout('nope'), throwsA(isA<PublishLoadException>()));
    });

    test('opens from the cache, refreshing republished layouts', () async {
      final cache = MemoryPublishCache();
      final first = Codelessly(config: const CodelesslyConfig(projectId: 'p'), loader: MemoryPublishLoader(bundle()), cache: cache, fonts: const NoFontFetcher());
      await first.loadLayout('home');
      expect(cache.entries.keys, {'publish/p', 'publish/p/layouts/home'});

      // Unchanged: served from the cache.
      final same = MemoryPublishLoader(bundle());
      final second = Codelessly(config: const CodelesslyConfig(projectId: 'p'), loader: same, cache: cache, fonts: const NoFontFetcher());
      await second.loadLayout('home');
      expect(same.calls.where((c) => c.startsWith('layout')), isEmpty);

      // Republished: the model's newer time makes the cached layout stale.
      final newer = MemoryPublishLoader(bundle(updated: DateTime.utc(2027)));
      final third = Codelessly(config: const CodelesslyConfig(projectId: 'p'), loader: newer, cache: MemoryPublishCache(), fonts: const NoFontFetcher());
      for (final e in cache.entries.entries) {
        await third.cache.write(e.key, e.value);
      }
      await third.initialize();
      await Future<void>.delayed(Duration.zero);
      expect((await third.loadLayout('home')).lastUpdated, DateTime.utc(2027));
      expect(newer.calls, contains('layout:publish:home'));
    });

    test('a failed load is an error status', () async {
      final c = Codelessly(config: const CodelesslyConfig());
      await expectLater(c.initialize(), throwsA(isA<PublishLoadException>()));
      expect(c.status, isA<CError>());
    });

    test('the default instance is optional and explicit', () {
      expect(Codelessly.maybeInstance, isNull);
      expect(() => Codelessly.instance, throwsStateError);
      final c = Codelessly();
      Codelessly.setDefault(c);
      expect(Codelessly.instance, same(c));
      c.dispose();
      expect(Codelessly.maybeInstance, isNull);
    });
  });

  test('fonts of a family register together, each once', () async {
    final registered = <String, int>{};
    final fonts = CodelesslyFonts(
      fetcher: _Fonts([]),
      register: (family, files) async => registered[family] = (registered[family] ?? 0) + files.length,
    );
    const a = PublishFont(id: 'a', family: 'Inter');
    const b = PublishFont(id: 'b', family: 'Inter', weight: 700);
    const c = PublishFont(id: 'c', family: 'Barlow', italic: true);
    await fonts.load([a, b, c]);
    await fonts.load([a, c]);
    expect(registered, {'Inter': 2, 'Barlow': 1});
    expect(fonts.loaded, {'a', 'b', 'c'});
  });

  test('Google Fonts are fetched by family, weight and style', () {
    final url = HttpFontFetcher().googleFontsUrl(const PublishFont(id: 'x', family: 'IBM Plex Mono', weight: 500, italic: true));
    expect('$url', 'https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:ital,wght@1,500');
  });

  test('a Google Font\'s file is its latin subset in a browser, the one file elsewhere', () {
    const browser = '''
/* cyrillic */
@font-face {
  font-family: 'Geist';
  src: url(https://fonts.gstatic.com/s/geist/cyr.woff2) format('woff2');
  unicode-range: U+0301, U+0400-045F;
}
/* latin-ext */
@font-face {
  font-family: 'Geist';
  src: url(https://fonts.gstatic.com/s/geist/latin-ext.woff2) format('woff2');
}
/* latin */
@font-face {
  font-family: 'Geist';
  src: url(https://fonts.gstatic.com/s/geist/latin.woff2) format('woff2');
}
''';
    expect(HttpFontFetcher.fontFileOf(browser), 'https://fonts.gstatic.com/s/geist/latin.woff2');
    // No labels: the last file (the base subset comes last).
    expect(HttpFontFetcher.fontFileOf(browser.replaceAll(RegExp(r'/\*.*\*/'), '')), 'https://fonts.gstatic.com/s/geist/latin.woff2');
    const tool = "@font-face {\n  font-family: 'Geist';\n  src: url(https://fonts.gstatic.com/s/geist/full.ttf) format('truetype');\n}";
    expect(HttpFontFetcher.fontFileOf(tool), 'https://fonts.gstatic.com/s/geist/full.ttf');
    expect(HttpFontFetcher.fontFileOf('nothing'), isNull);
  });

  test('theme tokens make the theme', () {
    final theme = themeDataOf(const api.ThemeTokens(primary: api.Color(0xFF3366FF), fontFamily: 'Barlow'));
    expect(theme.colorScheme.primary, const Color(0xFF3366FF));
  });
}

class _Fonts implements FontFetcher {
  _Fonts(this.fetched);

  final List<String> fetched;

  @override
  Future<Uint8List?> fetch(PublishFont font) async {
    fetched.add('${font.family} ${font.weight}');
    return Uint8List(4);
  }
}
