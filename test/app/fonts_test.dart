import 'dart:async';
import 'dart:typed_data';

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/app/fonts.dart';
import 'package:codelessly_sdk/src/render/convert.dart' show FontDemand;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Canvas viewport and location, layout id resolution and the initial
// screen; plus loading, caching and fonts.

class _Fonts implements FontFetcher {
  _Fonts(this.fetched);

  final List<String> fetched;

  @override
  Future<Uint8List?> fetch(PublishFont font) async {
    fetched.add('${font.family} ${font.weight}');
    return Uint8List(4);
  }
}

// A family a text style reaches only through a binding (no publish lists
// it) is fetched the first time it is drawn, once per family/weight/style.

class _Fetcher implements FontFetcher {
  final asked = <String>[];
  @override
  Future<Uint8List?> fetch(PublishFont font) async {
    asked.add('${font.family} ${font.weight}${font.italic ? ' italic' : ''}');
    return null;
  }
}

// In a browser Google Fonts serves a file per Unicode subset and the SDK
// loads the `latin` one; characters the font draws outside it (Tack's →, ⇧,
// ↵) fell back to the platform's font, with its own glyphs and line height.
// They now come in a file of their own (`text=`), registered with the family.

class _Glyphs implements GlyphFontFetcher {
  final asked = <String>[];
  @override
  Future<Uint8List?> fetch(PublishFont font) async => Uint8List.fromList([1]);
  @override
  Future<Uint8List?> fetchGlyphs(PublishFont font, String text) async {
    asked.add('${font.family} ${font.weight} $text');
    return Uint8List.fromList([2]);
  }
}

Uint8List file(int value) => Uint8List.fromList([value, 2, 3]);

void main() {
  test('the fonts of a family register together, each once', () async {
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

  test('a system font is not asked for from Google Fonts', () async {
    var calls = 0;
    final fetcher = HttpFontFetcher(client: MockClient((request) async {
      calls++;
      return http.Response('', 404);
    }));
    expect(await fetcher.fetch(const PublishFont(id:'arial', family:'Arial')), isNull);
    expect(calls, 0);
    await fetcher.fetch(const PublishFont(id:'uploaded', family:'Arial', url:'https://example.com/arial.ttf'));
    expect(calls, 1);
  });

  test('a weight the family lacks falls back to the family\'s default file', () async {
    final asked = <String>[];
    final fetcher = HttpFontFetcher(client: MockClient((request) async {
      asked.add('${request.url}');
      if ('${request.url}'.contains('wght@0,700')) return http.Response('bad weight', 400);
      if ('${request.url}'.contains('css2')) {
        return http.Response("@font-face { src: url(https://fonts.gstatic.com/s/anton/a.ttf) format('truetype'); }", 200);
      }
      return http.Response.bytes([1, 2, 3], 200);
    }));
    final bytes = await fetcher.fetch(const PublishFont(id: 'a', family: 'Anton', weight: 700));
    expect(bytes, [1, 2, 3]);
    expect(asked, [
      'https://fonts.googleapis.com/css2?family=Anton:ital,wght@0,700',
      'https://fonts.googleapis.com/css2?family=Anton',
      'https://fonts.gstatic.com/s/anton/a.ttf',
    ]);
  });

  test('a Google Font is fetched by its family, weight and style', () {
    final url = HttpFontFetcher().googleFontsUrl(const PublishFont(id: 'x', family: 'IBM Plex Mono', weight: 500, italic: true));
    expect('$url', 'https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:ital,wght@1,500');
  });

  group('fonts a document did not list', () {
    test('a style naming a font the document did not list fetches it, once', () async {
      FontDemand.handler = null;
      final fetcher = _Fetcher();
      CodelesslyFonts(fetcher: fetcher, register: (_, _) async {});
      textStyle(const api.TextStyle(fontFamily: 'Anton', fontWeight: 400));
      textStyle(const api.TextStyle(fontFamily: 'Anton', fontWeight: 400));
      textStyle(const api.TextStyle(fontFamily: 'Fraunces', fontWeight: 500, fontStyle: api.FontStyle.italic));
      await Future<void>.delayed(Duration.zero);
      expect(fetcher.asked, ['Anton 400', 'Fraunces 500 italic']);
      FontDemand.handler = null;
    });
  });

  group('characters beyond latin', () {
    setUp(CodelesslyFonts.resetGlyphs);

    test('a layout\'s characters beyond latin are fetched and registered with their family', () async {
      final fetcher = _Glyphs();
      final registered = <String, List<int>>{};
      final fonts = CodelesslyFonts(
        fetcher: fetcher,
        register: (family, files) async => registered[family] = [for (final f in files) f.first],
      );
      await fonts.load([const PublishFont(id: 'g6', family: 'Geist', weight: 600)], text: 'Backlog → Done');
      expect(fetcher.asked, ['Geist 600 →']);
      // A family of their own: on the web a family's later files add no glyphs.
      expect(registered['Geist'], [1]);
      expect(registered['Geist glyphs'], [2]);
    });

    test('text of latin characters alone fetches no extra file', () async {
      CodelesslyFonts.resetGlyphs();
      final fetcher = _Glyphs();
      final fonts = CodelesslyFonts(fetcher: fetcher, register: (_, _) async {});
      await fonts.load([const PublishFont(id: 'g4', family: 'Geist', weight: 400)], text: 'To Do, Doing, Done');
      expect(fetcher.asked, isEmpty);
    });

    test('an uploaded font has every glyph, so nothing more is fetched', () async {
      var asked = 0;
      final client = MockClient((_) async {
        asked++;
        return http.Response('', 404);
      });
      final bytes = await HttpFontFetcher(client: client)
          .fetchGlyphs(const PublishFont(id: 'u', family: 'Mine', weight: 400, url: 'https://x/mine.ttf'), '→');
      expect(bytes, isNull);
      expect(asked, 0);
    });
  });

  group('a font that fails to register', () {
    test('a font that failed to register can be tried again', () async {
      var calls = 0;
      final cache = FontRegistrationCache(
        register: (_, _) async {
          if (calls++ == 0) throw StateError('failed');
        },
      );
      await expectLater(cache.load('Barlow', [file(1)]), throwsStateError);
      await cache.load('Barlow', [file(1)]);
      expect(calls, 2);
    });
  });
}
