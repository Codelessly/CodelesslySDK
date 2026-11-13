// Canvas viewport and location, layout id resolution and the initial
// screen; plus loading, caching and fonts.
import 'dart:typed_data';

import 'package:codelessly_sdk/codelessly_sdk.dart';
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

void main() {

  group('variables', () {

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

  group('loading', () {
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

    test('an app and its layouts load once, by any of their ids', () async {
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

    test('an app opens from the device\'s cache and refreshes layouts that were republished', () async {
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

    test('a load that fails is reported as an error', () async {
      final c = Codelessly(config: const CodelesslyConfig());
      await expectLater(c.initialize(), throwsA(isA<PublishLoadException>()));
      expect(c.status, isA<CError>());
    });

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
