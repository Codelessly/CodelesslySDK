// The render command's default faces cover text, mono and symbols: Roboto
// Mono from the Flutter SDK draws `monospace` (and Text.mono) with no
// fallback warning; every style falls back to a symbol font for arrows and
// the like when the system has one.
import 'dart:io';
import 'dart:ui' show Size;

import 'package:codelessly_api/codelessly_api.dart' show PublishFont;
import 'package:codelessly_sdk/src/render/convert.dart' show FontDemand;
import 'package:flutter_test/flutter_test.dart';

import '../../tool/render/src/args.dart';
import '../../tool/render/src/fonts.dart';
import '../../tool/render/src/render.dart';

void main() {
  final root = Platform.environment['FLUTTER_ROOT'] ?? '';

  test('Roboto Mono is a default face, and monospace is drawn in it with no miss', () async {
    final faces = defaultFonts(root);
    expect(faces.any((f) => f.family == 'Roboto Mono' && f.weight == 400 && !f.italic), isTrue);
    final fetcher = DirectoryFontFetcher(faces);
    final bytes = await fetcher.fetch(const PublishFont(id: 'm', family: 'monospace', weight: 400, italic: false));
    expect(bytes, isNotNull);
    expect(fetcher.misses, isEmpty);
    await fetcher.fetch(const PublishFont(id: 'j', family: 'JetBrains Mono', weight: 400, italic: false));
    expect(fetcher.misses.single.family, 'JetBrains Mono', reason: 'a named family the tool lacks is still said');
  });

  test('a style falls back to the symbol families last', () {
    addTearDown(() => FontDemand.symbolFallback = const []);
    expect(FontDemand.fallbackOf('Roboto', const []), isNull);
    FontDemand.symbolFallback = const ['Codelessly Symbols'];
    expect(FontDemand.fallbackOf('Roboto', const ['Noto']), ['Noto', 'Codelessly Symbols']);
  });

  testWidgets('arrows and a monospace text draw with no missing glyph where the system has a symbol font', (tester) async {
    final out = Directory.systemTemp.createTempSync('render_default_faces');
    addTearDown(() => out.deleteSync(recursive: true));
    final doc = File('${out.path}/t.json')
      ..writeAsStringSync('{"schema":3,"roots":["c"],"nodes":{"c":{"type":"column","children":["a","m"],"layout":{"width":400,"height":{"hug":0}}},'
          '"a":{"type":"text","props":{"text":"← → ↑ ↓ ↵","style":{"fontSize":16}}},'
          '"m":{"type":"text","props":{"text":"mono 0123","style":{"fontSize":16,"fontFamily":"monospace"}}}}}');
    final report = await runRender(tester, RenderArgs(inputs: [doc.path], out: '${out.path}/o', sizes: const [Size(400, 200)]));
    final codes = [for (final d in report.diagnostics) d['code']];
    expect(codes, isNot(contains('font_fallback')));
    if (systemSymbolFont() != null) expect(codes, isNot(contains('missing_glyph')));
  });
}
