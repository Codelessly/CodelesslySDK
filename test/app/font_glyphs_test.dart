// In a browser Google Fonts serves a file per Unicode subset and the SDK
// loads the `latin` one; characters the font draws outside it (Tack's →, ⇧,
// ↵) fell back to the platform's font, with its own glyphs and line height.
// They now come in a file of their own (`text=`), registered with the family.
import 'dart:typed_data';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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

void main() {
  test('the characters beyond the latin subset, each once', () {
    expect(CodelesslyFonts.glyphsBeyondLatin('Backlog → Done ↑ ↓ – … é ⇧ ← → ↵'), '→⇧←↵');
    expect(CodelesslyFonts.glyphsBeyondLatin('Plain text, “quotes” — 100 €'), '');
  });

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
    expect(registered['Geist'], [1, 2]);
  });

  test('a font asked for when first drawn fetches the shown layouts\' characters too', () async {
    final fetcher = _Glyphs();
    final fonts = CodelesslyFonts(fetcher: fetcher, register: (_, _) async {});
    // Another app's fonts note what it shows: the characters are global.
    CodelesslyFonts(fetcher: const NoFontFetcher(), register: (_, _) async {}).addText('Shift ⇧ and ↵');
    fonts.addText('Backlog → Done ⇧');
    await fonts.load([const PublishFont(id: 'm5', family: 'Geist Mono', weight: 500)]);
    expect(fetcher.asked, ['Geist Mono 500 ⇧↵→']);
  });

  test('a font drawn on an earlier screen fetches a later layout\'s new characters', () async {
    final fetcher = _Glyphs();
    final registered = <List<int>>[];
    final fonts = CodelesslyFonts(fetcher: fetcher, register: (_, files) async => registered.add([for (final f in files) f.first]));
    await fonts.addText('Boards ⌘');
    await fonts.load([const PublishFont(id: 'g4', family: 'Geist', weight: 400)]);
    expect(fetcher.asked, ['Geist 400 ⌘']);
    await fonts.addText('Backlog → Done ⌘');
    expect(fetcher.asked, ['Geist 400 ⌘', 'Geist 400 →'], reason: 'only the new character');
    expect(registered, [[1, 2], [2]]);
    await fonts.addText('Nothing new →');
    expect(fetcher.asked.length, 2);
  });

  test('text of latin characters only: no extra file', () async {
    CodelesslyFonts.resetGlyphs();
    final fetcher = _Glyphs();
    final fonts = CodelesslyFonts(fetcher: fetcher, register: (_, _) async {});
    await fonts.load([const PublishFont(id: 'g4', family: 'Geist', weight: 400)], text: 'To Do, Doing, Done');
    expect(fetcher.asked, isEmpty);
  });

  test('HttpFontFetcher asks Google Fonts for just those characters', () async {
    final urls = <Uri>[];
    final client = MockClient((req) async {
      urls.add(req.url);
      if (req.url.host == 'fonts.googleapis.com') {
        return http.Response(
            "@font-face { font-family: 'Geist'; src: url(https://fonts.gstatic.com/l/font?kit=x) format('woff2'); unicode-range: U+2192; }",
            200);
      }
      return http.Response.bytes([7, 7], 200);
    });
    final bytes = await HttpFontFetcher(client: client)
        .fetchGlyphs(const PublishFont(id: 'g', family: 'Geist', weight: 400), '→⇧');
    expect(bytes, [7, 7]);
    expect(urls.first.queryParameters['text'], '→⇧');
    expect(urls.first.queryParameters['family'], 'Geist:ital,wght@0,400');
    expect(urls.last.toString(), 'https://fonts.gstatic.com/l/font?kit=x');
  });

  test('an uploaded font holds every glyph: nothing more is fetched', () async {
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
}
