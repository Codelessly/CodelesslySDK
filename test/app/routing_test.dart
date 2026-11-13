
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// Canvas viewport and location, layout id resolution and the initial
// screen; plus loading, caching and fonts.

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

// A link opens a screen with the screens beneath it (ScreenRoute.under),
// and a translucent screen's route lets the one beneath show.

PublishModel museum() {
  PublishLayoutInfo screen(String id, String? path, [api.ScreenRoute route = api.ScreenRoute.none]) =>
      PublishLayoutInfo(id: id, canvases: [PublishCanvas(id: id, name: id, path: path, route: route)]);
  return PublishModel(
    projectId: 'museum',
    entryLayoutId: 'wall',
    layouts: {
      'wall': screen('wall', 'layer/:layer'),
      'specimen': screen('specimen', 'specimen/:id', const api.ScreenRoute(under: '/')),
      'photo': screen('photo', 'specimen/:id/photo', const api.ScreenRoute(under: 'specimen/:id', translucent: true)),
      'glossary': screen('glossary', 'glossary', const api.ScreenRoute(under: '/')),
      'loop': screen('loop', 'loop', const api.ScreenRoute(under: 'loop')),
      'lost': screen('lost', '*path'),
    },
  );
}

void main() {
  group('CanvasLocation', () {
    final model = tidepool();

    test('a path opens the screen with that path', () {
      final match = CanvasLocation.match(model, '/guide/bat-star?from=tides&id=ignored');
      expect(match?.layoutId, 'creature');
      expect(match?.params, {'id': 'bat-star', 'from': 'tides'});
      expect(CanvasLocation.match(model, 'journal/')?.canvasId, 'journal');
      expect(CanvasLocation.match(model, 'guide')?.canvasId, 'guide');
    });

    test('a literal path segment wins over a parameter', () {
      expect(CanvasLocation.match(model, 'guide/new')?.canvasId, 'newCreature');
    });

    test('the root and an unknown path match no screen', () {
      expect(CanvasLocation.match(model, ''), isNull);
      expect(CanvasLocation.match(model, '/'), isNull);
      expect(CanvasLocation.match(model, 'guide/bat-star/more'), isNull);
      expect(CanvasLocation.match(model, 'kraken'), isNull);
    });

    test("an app's not-found screen takes every unknown path", () {
      final lost = tidepool(withNotFound: true);
      final match = CanvasLocation.match(lost, '/amp/room?x=1');
      expect(match?.canvasId, 'lost');
      expect(match?.params, {'x': '1', 'path': 'amp/room'});
      expect(CanvasLocation.match(lost, 'guide/new')?.canvasId, 'newCreature');
      expect(CanvasLocation.match(lost, '/'), isNull);
    });

    test('a path\'s parameters are filled in from values', () {
      expect(CanvasLocation.locationOf(model, 'creature', {'id': 'sea star', 'from': 'tides', 'none': null}),
          'guide/sea%20star?from=tides');
      expect(CanvasLocation.locationOf(model, 'journal', {}), 'journal');
      expect(CanvasLocation.locationOf(model, 'tides', {}), '');
      expect(CanvasLocation.locationOf(model, 'tides', {'a': 1}), '?a=1');
      expect(CanvasLocation.locationOf(model, 'settings', {}), isNull);
      expect(CanvasLocation.locationOf(model, 'creature', {}), isNull);
    });

    test('a catch-all path takes the rest of the path and loses to every other match', () {
      final m = tidepool(extra: {'notFound': '*path', 'docs': 'docs/*rest'});
      expect(CanvasLocation.match(m, 'kraken/deep?x=1')?.params, {'path': 'kraken/deep', 'x': '1'});
      expect(CanvasLocation.match(m, 'docs/a/b')?.params, {'rest': 'a/b'});
      expect(CanvasLocation.match(m, 'docs')?.canvasId, 'notFound');
      expect(CanvasLocation.match(m, 'guide/bat-star')?.canvasId, 'creature');
      expect(CanvasLocation.locationOf(m, 'docs', {'rest': 'a/b', 'q': 1}), 'docs/a/b?q=1');
      expect(CanvasLocation.locationOf(m, 'notFound', {}), isNull);
    });

    test('an optional last parameter matches with or without its segment', () {
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

    test('a screen\'s path comes from its name, made unique among the others', () {
      expect(CanvasLocation.defaultPathOf('Log entry'), 'log-entry');
      expect(CanvasLocation.defaultPathOf('  Café · Menu!  '), 'café-menu');
      expect(CanvasLocation.defaultPathOf('***'), isNull);
      expect(CanvasLocation.uniquePath('log-entry', {'log-entry', 'log-entry-2'}), 'log-entry-3');
      expect(CanvasLocation.uniquePath('home', {}), 'home');
    });

    test('a link to a screen by its id shows the screen\'s path', () {
      final model = tidepool();
      expect(CanvasLocation.named(model, 'creature?id=kraken'), 'guide/kraken');
      // The entry screen's id is the root.
      expect(CanvasLocation.named(model, 'tides'), '');
      // A param the path needs is missing, or the screen has no path.
      expect(CanvasLocation.named(model, 'creature'), 'creature');
      expect(CanvasLocation.named(model, 'settings'), 'settings');
      expect(CanvasLocation.named(model, 'guide/bat-star'), 'guide/bat-star');
    });

    test('a location shows its screen\'s layout', () {
      final model = tidepool(withNotFound: true);
      expect(CodelesslyAppIdentity.layoutIdAt(model, '/'), 'tides');
      expect(CodelesslyAppIdentity.layoutIdAt(model, '/guide/bat-star'), 'creature');
      // A screen at /<its id> wins over the catch-all.
      expect(CodelesslyAppIdentity.layoutIdAt(model, '/settings'), 'settings');
      expect(CodelesslyAppIdentity.layoutIdAt(model, '/nowhere'), 'lost');
    });

    test('a screen opened by its id or name wins over a catch-all path', () {
      final model = tidepool(withNotFound: true);
      // 'settings' has no path: the catch-all used to take it.
      expect(CodelesslyWidget.resolveScreen(model, '/settings')?.$1, 'settings');
      final withQuery = CodelesslyWidget.resolveScreen(model, 'settings?tab=b')!;
      expect(withQuery.$1, 'settings');
      expect(withQuery.$2, {'tab': 'b'});
      // A name, loosely: 'new-creature' is the screen named "newCreature".
      expect(CodelesslyWidget.resolveScreen(model, 'new-creature')?.$1, 'newCreature');
      // What names no screen still lands on the catch-all, with the path.
      expect(CodelesslyWidget.resolveScreen(model, '/nowhere')?.$2, <String, Object?>{'path': 'nowhere'});
      expect(CodelesslyWidget.resolveScreen(model, '/settings/deep')?.$1, 'lost');
      // Paths still win: 'guide/new' is newCreature's own path.
      expect(CodelesslyWidget.resolveScreen(model, 'guide/bat-star')?.$1, 'creature');
    });

  });

  group('screens shown over other screens', () {
    test('a link to a screen shown over others opens the screens beneath it, outermost first', () {
      final m = museum();
      expect(CanvasLocation.beneath(m, '/specimen/trilobite/photo?zoom=2'), ['/', '/specimen/trilobite']);
      expect(CanvasLocation.beneath(m, '/specimen/trilobite'), ['/']);
      expect(CanvasLocation.beneath(m, 'glossary?q=fossil'), ['/']);
      expect(CanvasLocation.beneath(m, '/layer/kaibab'), isEmpty);
      expect(CanvasLocation.beneath(m, '/nowhere'), isEmpty);
      expect(CanvasLocation.beneath(m, '/loop'), isEmpty);
    });

    test('a see-through screen shows the one beneath', () {
      final m = museum();
      expect(CanvasLocation.isTranslucent(m, '/specimen/a/photo'), isTrue);
      expect(CanvasLocation.isTranslucent(m, '/specimen/a'), isFalse);
    });

    test('opening on a see-through screen builds the stack beneath it', () async {
      final app = Codelessly(
        config: const CodelesslyConfig(projectId: 'museum'),
        loader: MemoryPublishLoader(PublishBundle(model: museum(), layouts: const {})),
        fonts: const NoFontFetcher(),
      );
      addTearDown(app.dispose);
      await app.initialize();
      final routes = CodelesslyWidget.onGenerateInitialRoutes(app)('/specimen/a/photo');
      expect([for (final r in routes) r.settings.name], ['/', '/specimen/a', '/specimen/a/photo']);
      expect([for (final r in routes) (r as PageRoute).opaque], [true, true, false]);
    });
  });
}
