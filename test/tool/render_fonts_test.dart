// The render command's fonts: a WOFF web font (what an npm @fontsource
// package or a site's fonts folder holds) is decoded and drawn; a font it
// cannot read, and a family it does not have, are reported with the family,
// weight and style asked for and where it looked.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import '../../tool/render/src/args.dart';
import '../../tool/render/src/fonts.dart';
import '../../tool/render/src/render.dart';

/// [ttf] as a WOFF file (W3C WOFF 1.0: each table zlib-compressed).
Uint8List woffOf(Uint8List ttf) {
  final b = ByteData.sublistView(ttf);
  final n = b.getUint16(4);
  final tables = <(int, int, Uint8List, int)>[]; // tag, checksum, compressed, original length
  for (var i = 0; i < n; i++) {
    final rec = 12 + 16 * i;
    final off = b.getUint32(rec + 8), len = b.getUint32(rec + 12);
    final data = Uint8List.sublistView(ttf, off, off + len);
    final z = Uint8List.fromList(zlib.encode(data));
    tables.add((b.getUint32(rec), b.getUint32(rec + 4), z.length < len ? z : Uint8List.fromList(data), len));
  }
  final header = ByteData(44 + 20 * n);
  var offset = 44 + 20 * n;
  final body = BytesBuilder();
  for (var i = 0; i < n; i++) {
    final (tag, sum, data, orig) = tables[i];
    final rec = 44 + 20 * i;
    header
      ..setUint32(rec, tag)
      ..setUint32(rec + 4, offset)
      ..setUint32(rec + 8, data.length)
      ..setUint32(rec + 12, orig)
      ..setUint32(rec + 16, sum);
    final padded = (data.length + 3) & ~3;
    body
      ..add(data)
      ..add(Uint8List(padded - data.length));
    offset += padded;
  }
  header
    ..setUint32(0, 0x774F4646) // wOFF
    ..setUint32(4, b.getUint32(0))
    ..setUint32(8, offset)
    ..setUint16(12, n);
  return Uint8List.fromList([...header.buffer.asUint8List(), ...body.takeBytes()]);
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('render_fonts_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('a WOFF decodes to the TrueType file it wraps: the same family, weight and tables', () {
    final ttf = File('../references/strata/assets/fonts/Manrope-Regular.ttf').readAsBytesSync();
    final sfnt = sfntOf(woffOf(ttf))!;
    expect(readFontFace(sfnt), readFontFace(ttf));
    expect(readFontFace(sfnt)!.family, 'Manrope');
    expect(sfnt.length, closeTo(ttf.length, 64));
  });

  testWidgets('a font package folder: .woff drawn, .woff2 reported, a missing family said precisely', (tester) async {
    // As node_modules/@fontsource/manrope/files/ holds them.
    final files = Directory('${dir.path}/fonts/@fontsource/manrope/files')..createSync(recursive: true);
    File('${files.path}/manrope-latin-400-normal.woff')
        .writeAsBytesSync(woffOf(File('../references/strata/assets/fonts/Manrope-Regular.ttf').readAsBytesSync()));
    File('${files.path}/fraunces-latin-600-normal.woff2').writeAsBytesSync([0x77, 0x4F, 0x46, 0x32, ...List.filled(60, 0)]);
    File('${dir.path}/page.json').writeAsStringSync('''
{"schema": 2, "roots": ["c"], "nodes": {
 "c": {"type": "canvas", "slots": {"body": "col"}, "layout": {"width": 390, "height": 300}},
 "col": {"type": "column", "children": ["a", "b"], "layout": {"width": {"fill": 390}, "height": {"fill": 300}}},
 "a": {"type": "text", "layout": {"width": {"hug": 10}, "height": {"hug": 10}}, "props": {"text": "Manrope", "style": {"fontFamily": "Manrope", "fontWeight": 400, "color": "#FF000000"}}},
 "b": {"type": "text", "layout": {"width": {"hug": 10}, "height": {"hug": 10}}, "props": {"text": "Fraunces", "style": {"fontFamily": "Fraunces", "fontWeight": 600, "fontStyle": "italic", "color": "#FF000000"}}}}}''');
    final report = await runRender(tester,
        RenderArgs(inputs: ['${dir.path}/page.json'], out: '${dir.path}/out', sizes: const [Size(390, 300)], fontDirs: ['${dir.path}/fonts']));
    final fallbacks = [for (final d in report.diagnostics) if (d['code'] == 'font_fallback') d['message'] as String];
    expect(fallbacks, hasLength(1), reason: 'Manrope is read from its .woff');
    expect(fallbacks.single, allOf(contains('"Fraunces" 600 italic'), contains('fontStyle italic'), contains('${dir.path}/fonts'),
        contains('fraunces-latin-600-normal.woff2: WOFF2')));
  });

  test('of a font package\'s subset files for one face, the one with Latin text\'s characters is served', () {
    final root = '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter'}/bin/cache/artifacts/material_fonts';
    // Two files of the same family, weight and style: the first (an icon
    // font standing in for a Cyrillic subset) has no Latin letters.
    final faces = <FontFace>[
      (family: 'Body', weight: 400, italic: false, path: '$root/MaterialIcons-Regular.otf'),
      (family: 'Body', weight: 400, italic: false, path: '$root/Roboto-Regular.ttf'),
    ];
    expect(DirectoryFontFetcher(faces).match('Body', 400, false)!.path, endsWith('Roboto-Regular.ttf'));
    expect(DirectoryFontFetcher(faces.reversed.toList()).match('Body', 400, false)!.path, endsWith('Roboto-Regular.ttf'));
  });
}
