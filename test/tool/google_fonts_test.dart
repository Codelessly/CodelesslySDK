// The render command's Google Fonts (tool/render/src/google_fonts.dart): a
// family no file provides is fetched by family, weight and style, kept in a
// cache directory and drawn; a system or commercial face is drawn in its
// open stand-in; off, or with no network, the cache is still read and the
// rest falls back as before. No test here reaches the network: the fetch is
// injected.
import 'dart:io';
import 'dart:typed_data';

import 'package:codelessly_api/codelessly_api.dart' show PublishFont;
import 'package:flutter_test/flutter_test.dart';

import '../../tool/render/src/fonts.dart';
import '../../tool/render/src/google_fonts.dart';

void main() {
  // A real font file to stand for what Google Fonts serves.
  final anton = File('test/tool/fixtures/latefont/fonts/Anton-Regular.ttf').readAsBytesSync();
  late Directory cache;
  setUp(() => cache = Directory.systemTemp.createTempSync('google_fonts_test'));
  tearDown(() => cache.deleteSync(recursive: true));

  test('a family no file provides is fetched once, kept in the cache, and read from it after', () async {
    final asked = <String>[];
    Future<Uint8List?> fetch(PublishFont f) async {
      asked.add('${f.family} ${f.weight}${f.italic ? ' italic' : ''}');
      return anton;
    }

    final first = GoogleFontCache(dir: cache.path, fetch: fetch);
    final faces = <FontFace>[];
    await addGoogleFonts(faces, [(family: 'Fraunces', weight: 700, italic: false)], first);
    // Its weight first, then every weight from 300 to 900 (each once).
    expect(asked.first, 'Fraunces 700');
    expect(asked.toSet(), hasLength(asked.length));
    expect(asked, contains('Fraunces 900'));
    expect(faces.map((f) => f.family).toSet(), {'Fraunces'});
    expect(File(first.fileOf('Fraunces', 700, false)).existsSync(), isTrue);
    // A second run with fetching off draws it from the cache.
    final second = GoogleFontCache(dir: cache.path, enabled: false, fetch: fetch);
    final again = <FontFace>[];
    final count = asked.length;
    await addGoogleFonts(again, [(family: 'Fraunces', weight: 700, italic: false)], second);
    expect(asked, hasLength(count));
    expect({for (final f in again) f.path}, {for (final f in faces) f.path});
    // The fetched face is what the fetcher serves for the family.
    expect(DirectoryFontFetcher(faces).match('Fraunces', 700, false)?.path, first.fileOf('Fraunces', 700, false));
  });

  test('a family a file provides is not fetched; a system face is drawn in its open stand-in', () async {
    final asked = <String>[];
    final c = GoogleFontCache(dir: cache.path, fetch: (f) async {
      asked.add(f.family);
      return f.family == 'Brush Script MT' ? null : anton;
    });
    final faces = <FontFace>[(family: 'Inter', weight: 400, italic: false, path: 'x.ttf')];
    await addGoogleFonts(faces, [(family: 'Inter', weight: 400, italic: false), (family: 'Georgia', weight: 400, italic: false), (family: 'Brush Script MT', weight: 400, italic: false)], c);
    // Georgia is not a Google family: its stand-in, Gelasio; a script that
    // Google Fonts does not have: the class's, Dancing Script.
    expect(asked.toSet(), {'Gelasio', 'Brush Script MT', 'Dancing Script'});
    expect(asked, isNot(contains('Inter')));
    expect(asked, isNot(contains('Georgia')));
    final fetcher = DirectoryFontFetcher(faces, classFiles: const {});
    expect(fetcher.openStandIn('Georgia', 400, false)?.family, 'Gelasio');
    expect(fetcher.openStandIn('Brush Script MT', 400, false)?.family, 'Dancing Script');
    expect(fetcher.openStandIn('Inter', 400, false), isNull);
  });

  test('off, or with no network, nothing is fetched and the family falls back as before, said', () async {
    final off = GoogleFontCache(dir: cache.path, enabled: false, fetch: (f) async => fail('fetched with fetching off'));
    final faces = <FontFace>[];
    await addGoogleFonts(faces, [(family: 'Fraunces', weight: 400, italic: false)], off);
    expect(faces, isEmpty);
    final offline = GoogleFontCache(dir: cache.path, fetch: (f) async => throw const SocketException('no network'));
    await addGoogleFonts(faces, [(family: 'Fraunces', weight: 400, italic: false), (family: 'Georgia', weight: 700, italic: false)], offline);
    expect(faces, isEmpty);
    expect(offline.failed, {'Fraunces', 'Gelasio'});
  });

  test('the stand-ins: a named face, else its class; a sans is Roboto, the command\'s own', () {
    expect(googleStandInOf('Times New Roman'), 'Tinos');
    expect(googleStandInOf('Helvetica'), 'Arimo');
    expect(googleStandInOf('Playfair Display'), 'Gelasio');
    expect(googleStandInOf('Rockwell'), 'Roboto Slab');
    expect(googleStandInOf('Inter'), isNull);
  });
}
