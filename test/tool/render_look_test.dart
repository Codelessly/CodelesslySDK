// The render command and a site's own look: `--theme` captures light or
// dark (and a toggle step switches it), the fonts site.json declares are
// used with no --fonts, a family that is not available is reported with
// the nodes that use it, and a missing font or image file is named.
import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import '../../tool/render/src/args.dart';
import '../../tool/render/src/compare.dart';
import '../../tool/render/src/render.dart';

const _fixture = 'test/tool/fixtures/look';

void main() {
  late Directory out;
  setUp(() => out = Directory.systemTemp.createTempSync('render_look_test'));
  tearDown(() => out.deleteSync(recursive: true));

  /// The background (paper) color at the page's bottom left, as 0xRRGGBB.
  Future<int> paper(WidgetTester tester, String png) async => (await tester.runAsync(() async {
        final img = await decodePng(File('${out.path}/$png').readAsBytesSync());
        final i = ((img.height - 20) * img.width + 10) * 4;
        return img.rgba[i] << 16 | img.rgba[i + 1] << 8 | img.rgba[i + 2];
      }))!;

  /// A copy of the fixture site to change, in [out].
  Directory copySite() {
    final dir = Directory('${out.path}/site')..createSync();
    for (final f in Directory(_fixture).listSync(recursive: true).whereType<File>()) {
      final rel = f.path.substring(_fixture.length + 1);
      File('${dir.path}/$rel')
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(f.readAsBytesSync());
    }
    return dir;
  }

  test('--theme takes light, dark or system and nothing else', () {
    expect(parseArgs(['a.json', '--out', 'o', '--theme', 'Dark']).theme, 'dark');
    expect(() => parseArgs(['a.json', '--out', 'o', '--theme', 'night']), throwsFormatException);
  });

  testWidgets('--theme captures the site light or dark, with its declared fonts and local image, and no diagnostics',
      (tester) async {
    for (final mode in ['light', 'dark']) {
      final r = await runRender(tester, RenderArgs(inputs: [_fixture], out: out.path, sizes: const [Size(390, 844)], theme: mode));
      expect(r.diagnostics, isEmpty, reason: '$mode: ${r.diagnostics}');
      expect(r.images.single, endsWith('home@390x844-$mode.png'));
    }
    expect(await paper(tester, 'home@390x844-light.png'), 0xF7F4EE);
    expect(await paper(tester, 'home@390x844-dark.png'), 0x101010);
  });

  testWidgets('a toggle step after --theme light captures the dark site', (tester) async {
    final r = await runRender(tester, RenderArgs(
      inputs: [_fixture],
      out: out.path,
      sizes: const [Size(390, 844)],
      theme: 'light',
      steps: const [Step('tap', 'toggle')],
      label: 'toggled',
    ));
    expect(r.diagnostics, isEmpty, reason: '${r.diagnostics}');
    expect(await paper(tester, 'home@390x844-light-toggled.png'), 0x101010);
  });

  testWidgets('a family no one declared is a font_fallback naming the nodes; a missing font or image file is named',
      (tester) async {
    final site = copySite();
    final page = File('${site.path}/home.json');
    page.writeAsStringSync(page
        .readAsStringSync()
        .replaceFirst('"style": "title"', '"style": {"from": "title", "fontFamily": "Nowhere Serif"}')
        .replaceFirst('images/photo.png', 'images/missing.jpg'));
    File('${site.path}/fonts/dm-sans-latin-700-normal.woff').deleteSync();
    final r = await runRender(tester, RenderArgs(inputs: [site.path], out: '${out.path}/png', sizes: const [Size(390, 844)]));
    final fallback = r.diagnostics.firstWhere((d) => d['code'] == 'font_fallback');
    expect(fallback['message'], contains('"Nowhere Serif"'));
    expect(fallback['message'], contains('"title"'), reason: 'the node that asked for it');
    expect(fallback['message'], contains('Declare it in site.json'));
    expect(fallback['nodeId'], 'title');
    final missingFont = r.diagnostics.firstWhere((d) => d['code'] == 'font_missing');
    expect(missingFont['message'], contains('fonts/dm-sans-latin-700-normal.woff'));
    expect(missingFont['file'], 'site.json');
    final missingImage = r.diagnostics.firstWhere((d) => d['code'] == 'image_failed');
    expect(missingImage['message'], contains('images/missing.jpg'));
    expect(missingImage['nodeId'], 'card');
  });

  testWidgets('a declared WOFF2 file is reported as not read', (tester) async {
    final site = copySite();
    final manifest = File('${site.path}/site.json');
    manifest.writeAsStringSync(manifest.readAsStringSync().replaceFirst('dm-sans-latin-700-normal.woff', 'dm-sans-latin-700-normal.woff2'));
    final r = await runRender(tester, RenderArgs(inputs: [site.path], out: '${out.path}/png', sizes: const [Size(390, 844)], validateOnly: true));
    final d = r.diagnostics.singleWhere((d) => d['code'] == 'font_format');
    expect(d['message'], contains('WOFF2'));
    expect(d['file'], 'site.json');
  });
}
