// The render command (tool/render) on sites: diagnostics that are true at
// the size rendered, components with their previews, and the site
// manifest's theme. Run in-process on the fixtures next to this file.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import '../../tool/render/src/args.dart';
import '../../tool/render/src/render.dart';

const fixtures = 'test/tool/fixtures';
const a0 = '$fixtures/authoring';

List<String> codes(RenderReport r, [String? severity]) => [
      for (final d in r.diagnostics)
        if (severity == null || d['severity'] == severity) d['code'] as String,
    ];

void main() {
  late Directory out;
  setUp(() => out = Directory.systemTemp.createTempSync('render_components_test'));
  tearDown(() => out.deleteSync(recursive: true));

  group('every diagnostic is true for the document as it renders at that size', () {
    const t = '$fixtures/truth';
    List<Map<String, Object?>> diag(RenderReport r, String code) =>
        [for (final d in r.diagnostics) if (d['code'] == code) d.cast<String, Object?>()];

    testWidgets('a row a media rule makes scroll on phones: its cells are not offscreen nor overflowing', (tester) async {
      final report = await runRender(tester, RenderArgs(inputs: ['$t/scroll_by_media.json'], out: out.path));
      expect(report.diagnostics, isEmpty);
    });

    testWidgets('a path past its box is reported only where no ancestor clips it away', (tester) async {
      final report = await runRender(tester, RenderArgs(inputs: ['$t/clipped_paths.json'], out: out.path, sizes: const [Size(390, 844)]));
      expect(diag(report, 'path_overflow').map((d) => d['nodeId']), ['grid2']);
    });

    testWidgets('several exceptions in one frame: each named by its node', (tester) async {
      final report = await runRender(tester, RenderArgs(inputs: ['$t/overflowing_cards.json'], out: out.path, sizes: const [Size(390, 844)]));
      final errors = diag(report, 'render_exception');
      expect(errors, isNotEmpty);
      for (final e in errors) {
        expect(e['nodeId'], 'card', reason: '${e['message']}');
        expect(e['message'] as String, isNot(contains('Multiple exceptions')));
      }
    });

    testWidgets('a full-page capture after a tap that scrolled shows the whole page from its top', (tester) async {
      final report = await runRender(tester,
          RenderArgs(inputs: ['$t/tap_far_down.json'], out: out.path, sizes: const [Size(390, 844)], fullPage: true, steps: const [Step('tap', 'button')]));
      expect(report.errors, 0, reason: '${report.diagnostics}');
      final bytes = File('${out.path}/long@390x844.png').readAsBytesSync();
      final height = (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23];
      expect(height, 2100);
      final image = await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final data = await frame.image.toByteData();
        return (data!, frame.image.width);
      });
      int px(int x, int y, int c) => image!.$1.getUint8((y * image.$2 + x) * 4 + c);
      expect([px(195, 10, 0), px(195, 10, 1)], [255, 0], reason: 'the red top band at the top of the PNG');
      expect([px(195, 2050, 0), px(195, 2050, 1)], [0, 255], reason: 'the green button at the bottom');
      // A viewport capture shows where the tap scrolled to.
      final view = await runRender(tester,
          RenderArgs(inputs: ['$t/tap_far_down.json'], out: out.path, sizes: const [Size(390, 844)], steps: const [Step('tap', 'button')], label: 'v'));
      expect(view.errors, 0);
      final vb = File('${out.path}/long@390x844-v.png').readAsBytesSync();
      final vimage = await tester.runAsync(() async {
        final frame = await (await ui.instantiateImageCodec(vb)).getNextFrame();
        return (await frame.image.toByteData())!;
      });
      expect(vimage!.getUint8((10 * 390 + 195) * 4 + 1), isNot(0), reason: 'scrolled past the red band');
    });
  });

  // Sections and components (docs/design/06): a directory with site.json is
  // a site of pages and components.
  group('a site with components', () {
    const site = '$fixtures/components';
    test('the render command reads a component with its props and slots', () {
      final a = parseArgs([site, '--out', 'o', '--component', 'Card', '--props', '{"title": "x"}', '--slots', 's.json']);
      expect([a.component, a.props, a.slots], ['Card', '{"title": "x"}', 's.json']);
    });

    testWidgets('pages render their calls; steps address nodes inside instances by path', (tester) async {
      final report = await runRender(tester, RenderArgs(inputs: [site], out: out.path, sizes: const [Size(390, 844)],
          steps: const [Step('tap', 'card1/btn'), Step('tap', 'card2/btn')], dumpLayout: true));
      expect(report.diagnostics, isEmpty, reason: '${report.diagnostics}');
      final boxes = jsonDecode(File('${out.path}/home@390x844.layout.json').readAsStringSync()) as List;
      final paths = {for (final b in boxes) (b as Map)['path'] ?? b['id']};
      expect(paths, containsAll(['card1', 'card1/title', 'card1/btn', 'card2/none', 'note']));
      expect(paths, isNot(contains('card1/none')), reason: 'the call passes children: the slot shows them');
    });

    testWidgets('a component renders each of its previews at its size, or the given props and slots at each size', (tester) async {
      var report = await runRender(tester, RenderArgs(inputs: [site], out: out.path, component: 'Card'));
      expect(report.errors, 0, reason: '${report.diagnostics}');
      expect(report.images.map((f) => f.split('/').last), ['Card-hello@320x240.png']);
      report = await runRender(tester, RenderArgs(inputs: [site], out: out.path, component: 'Card', props: '{"title": "Ad hoc", "count": 5}',
          slots: '$site/slots.json', sizes: const [Size(390, 844), Size(834, 1112)], dumpLayout: true));
      expect(report.errors, 0, reason: '${report.diagnostics}');
      expect(report.images.map((f) => f.split('/').last), ['Card@390x844.png', 'Card@834x1112.png']);
      final boxes = jsonDecode(File('${out.path}/Card@390x844.layout.json').readAsStringSync()) as List;
      expect(boxes.map((b) => (b as Map)['id']), containsAll(['passed', 'title', 'btn']));
      report = await runRender(tester, RenderArgs(inputs: [site], out: out.path, component: 'Nope'));
      expect(codes(report), ['unknown_screen_arg']);
    });

    testWidgets('every component of a site can be rendered alone, each preview at its size', (tester) async {
      expect(parseArgs([site, '--out', 'o', '--components-all']).componentsAll, isTrue);
      final report = await runRender(tester, RenderArgs(inputs: ['$fixtures/guide-components'], out: out.path, componentsAll: true,
          sizes: const [Size(390, 844)]));
      expect(report.errors, 0, reason: '${report.diagnostics}');
      expect(report.images.map((f) => f.split('/').last), isNotEmpty);
      expect(report.images.every((f) => f.split('/').last.startsWith('Chip')), isTrue, reason: '${report.images}');
      final again = await runRender(tester, RenderArgs(inputs: [site], out: out.path, componentsAll: true));
      expect(again.images.map((f) => f.split('/').last), ['Card-hello@320x240.png']);
    });

    testWidgets('a call to a component the site lacks: the render reports it', (tester) async {
      final dir = Directory('${out.path}/site')..createSync();
      File('${dir.path}/home.json').writeAsStringSync(jsonEncode({
        'schema': 2,
        'roots': ['home'],
        'nodes': {
          'home': {'type': 'canvas', 'slots': {'body': 'c'}, 'layout': {'width': 390, 'height': 844}},
          'c': {'type': 'Missing', 'layout': {'width': 100, 'height': 40}},
        },
      }));
      File('${dir.path}/site.json').writeAsStringSync('{"schema": 2}');
      final report = await runRender(tester, RenderArgs(inputs: [dir.path], out: '${out.path}/o', sizes: const [Size(390, 844)]));
      expect(codes(report), contains('component_missing'));
      expect(report.diagnostics.firstWhere((d) => d['code'] == 'component_missing')['nodeId'], 'c');
    });

    // The guide's example (codelessly_api tool/reference/examples/sections,
    // copied): a chip component, its calls, an event and a list of calls.
    testWidgets('the guide\'s components example renders clean, and its event reaches the page', (tester) async {
      final report = await runRender(tester, RenderArgs(inputs: ['$fixtures/guide-components'], out: out.path,
          sizes: const [Size(390, 844)], steps: const [Step('tap', 'design/remove')], dumpLayout: true));
      expect(report.diagnostics, isEmpty, reason: '${report.diagnostics}');
      final boxes = jsonDecode(File('${out.path}/home@390x844.layout.json').readAsStringSync()) as List;
      expect(boxes.where((b) => (b as Map)['id'] == 'text'), hasLength(3), reason: 'one chip called directly, two from the list');
    });

    // The Relay pricing page (m05 c2, B) as a site of sections and components
    // (examples/relay-pricing) draws the same pixels as the one-document page.
    testWidgets('the rewritten Relay pricing page renders pixel-identical to the original', (tester) async {
      final o = await runRender(tester, RenderArgs(inputs: ['$fixtures/sections/original'], out: '${out.path}/o', sizes: const [Size(390, 844)],
          fullPage: true, steps: const [Step('tap', 'fq#1')]));
      final s = await runRender(tester, RenderArgs(inputs: ['examples/relay-pricing'], out: '${out.path}/s', sizes: const [Size(390, 844)], screens: const ['pricing'],
          fullPage: true, steps: const [Step('tap', 'faq/fq#1')]));
      expect(s.errors, 0, reason: '${s.diagnostics}');
      expect(codes(s, 'error'), codes(o, 'error'));
      final a = File(o.images.single).readAsBytesSync(), b = File(s.images.single).readAsBytesSync();
      expect(b, a);
    });
  });

  group('named colors and text styles (the site manifest\'s theme)', () {
    const t = '$fixtures/theme';
    testWidgets('a page naming the theme renders as the page with the styles written out, at each size', (tester) async {
      for (final size in const [Size(390, 844), Size(1440, 900)]) {
        final named = await runRender(tester, RenderArgs(inputs: ['$t/named'], out: '${out.path}/n', sizes: [size]));
        final inline = await runRender(tester, RenderArgs(inputs: ['$t/inline/home.json'], out: '${out.path}/i', sizes: [size]));
        expect(named.diagnostics, isEmpty, reason: '${named.diagnostics}');
        expect(File(named.images.single).readAsBytesSync(), File(inline.images.single).readAsBytesSync(), reason: '$size');
      }
    });
  });
}
