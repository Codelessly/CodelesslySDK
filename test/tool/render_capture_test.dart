// The render command's captures and steps on multi-page sites: full-page
// captures with sticky and fixed content, modals and navigation; route
// parameters on --navigate; drag steps; downloads and the clipboard; steps
// that name a node ambiguously or one shown only at another size. Run
// in-process on test/tool/fixtures/capture.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import '../../tool/render/src/args.dart';
import '../../tool/render/src/compare.dart';
import '../../tool/render/src/render.dart';

const capture = 'test/tool/fixtures/capture';
const stepsSite = 'test/tool/fixtures/steps';

List<String> codes(RenderReport r, [String? severity]) => [
      for (final d in r.diagnostics)
        if (severity == null || d['severity'] == severity) d['code'] as String,
    ];

/// The PNG's pixels.
Future<Pixels> pixelsOf(WidgetTester tester, String png) async =>
    (await tester.runAsync(() => decodePng(File(png).readAsBytesSync())))!;

/// The colour (0xRRGGBB) at [x], [y].
int rgbAt(Pixels p, int x, int y) {
  final i = (y * p.width + x) * 4;
  return (p.rgba[i] << 16) | (p.rgba[i + 1] << 8) | p.rgba[i + 2];
}

/// The rows whose pixel at [x] is [rgb].
List<int> rowsOf(Pixels p, int x, int rgb) => [for (var y = 0; y < p.height; y++) if (rgbAt(p, x, y) == rgb) y];

/// The runs of consecutive rows in [rows]: (first, count).
List<(int, int)> runsOf(List<int> rows) {
  final out = <(int, int)>[];
  for (final r in rows) {
    if (out.isNotEmpty && out.last.$1 + out.last.$2 == r) {
      out[out.length - 1] = (out.last.$1, out.last.$2 + 1);
    } else {
      out.add((r, 1));
    }
  }
  return out;
}

void main() {
  late Directory out;
  setUp(() => out = Directory.systemTemp.createTempSync('render_capture_test'));
  tearDown(() => out.deleteSync(recursive: true));

  RenderArgs run(List<Step> steps, {List<String> screens = const ['long'], bool fullPage = true, String? label}) => RenderArgs(
        inputs: [capture],
        out: out.path,
        sizes: const [Size(390, 844)],
        screens: screens,
        steps: steps,
        fullPage: fullPage,
        label: label,
      );

  group('full-page captures', () {
    testWidgets('a sticky header is drawn once, where it is at the top of the page, not once per window', (tester) async {
      final report = await runRender(tester, run(const []));
      expect(report.errors, 0, reason: '${report.diagnostics}');
      final p = await pixelsOf(tester, report.images.single);
      // The page: 60 (header) + 50 (bar) + 4 × 600, on a 844 window.
      expect(p.height, 60 + 50 + 2400);
      expect(runsOf(rowsOf(p, 300, 0xFF0000)), [(0, 60)]);
      // Each section once, whole, in its place.
      expect(runsOf(rowsOf(p, 300, 0x808080)), [(110 + 1800, 600)]);
      expect(runsOf(rowsOf(p, 300, 0x404040)), [(110 + 600, 600)]);
    });

    testWidgets('a sticky header scrolled to by a step is still drawn once, at the top', (tester) async {
      final report = await runRender(tester, run(const [Step('scroll', 'lcol', '1500')]));
      final p = await pixelsOf(tester, report.images.single);
      expect(runsOf(rowsOf(p, 300, 0xFF0000)), [(0, 60)]);
    });

    testWidgets('an open modal is drawn once, over the first window, and the page below it is not dimmed', (tester) async {
      final report = await runRender(tester, run(const [Step('tap', 'open')]));
      expect(report.errors, 0, reason: '${report.diagnostics}');
      final p = await pixelsOf(tester, report.images.single);
      expect(p.height, 60 + 50 + 2400);
      // The dialog (blue, 100 high) once, in the first window.
      final blue = runsOf(rowsOf(p, 195, 0x0000FF));
      expect(blue, hasLength(1));
      expect(blue.single.$2, 100);
      expect(blue.single.$1, lessThan(844));
      // Below the first window the page shows as it is, undimmed.
      expect(rgbAt(p, 195, 1200), 0x404040);
      expect(rgbAt(p, 195, 2400), 0x808080);
    });

    testWidgets('after a tap that navigates, the capture is the destination page at its own height', (tester) async {
      final report = await runRender(tester, run(const [Step('tap', 'go')]));
      expect(report.errors, 0, reason: '${report.diagnostics}');
      final p = await pixelsOf(tester, report.images.single);
      // Detail: 400 + 1000, not the long page's 2510.
      expect(p.height, 1400);
      expect(runsOf(rowsOf(p, 195, 0x00FF00)), [(0, 400)]);
      expect(runsOf(rowsOf(p, 195, 0xFF00FF)), [(400, 1000)]);
    });

    testWidgets('after --navigate the capture is the destination page once, at its own height', (tester) async {
      final report = await runRender(tester, run(const [Step('navigate', 'detail')]));
      expect(report.errors, 0, reason: '${report.diagnostics}');
      final p = await pixelsOf(tester, report.images.single);
      expect(p.height, 1400);
      expect(runsOf(rowsOf(p, 195, 0x000000)), [(0, 400)]);
      expect(runsOf(rowsOf(p, 195, 0xFF00FF)), [(400, 1000)]);
    });
  });

  group('--navigate with route parameters', () {
    for (final target in ['detail?id=42', '/detail?id=42', 'Detail?id=42']) {
      testWidgets('--navigate $target opens the screen with id=42 as \${route.id}', (tester) async {
        final report = await runRender(tester, run([Step('navigate', target)], fullPage: false));
        expect(report.errors, 0, reason: '${report.diagnostics}');
        final p = await pixelsOf(tester, report.images.single);
        expect(rgbAt(p, 195, 200), 0x00FF00);
      });
    }

    testWidgets('--navigate to no screen is an error naming the screens', (tester) async {
      final report = await runRender(tester, run(const [Step('navigate', 'nowhere?id=1')], fullPage: false));
      final failed = report.diagnostics.where((d) => d['code'] == 'interaction_failed').single;
      expect(failed['message'], contains('detail'));
    });
  });

  group('platform services in a headless run', () {
    testWidgets('a downloadFile action succeeds: the file lands in the out dir and is listed in the diagnostics', (tester) async {
      final report = await runRender(tester, run(const [Step('tap', 'dl')], screens: const ['tools'], fullPage: false, label: 'saved'));
      expect(codes(report, 'error'), isEmpty, reason: '${report.diagnostics}');
      final saved = File('${out.path}/downloads/tools@390x844-saved/brief.txt');
      expect(saved.readAsStringSync(), 'Day 1: Zurich');
      final json = jsonDecode(File('${out.path}/diagnostics-saved.json').readAsStringSync()) as Map;
      expect((json['downloads'] as List).single['fileName'], 'brief.txt');
      // The chain went on after it.
      final p = await pixelsOf(tester, report.images.single);
      expect(rgbAt(p, 195, 120), 0x00FF00);
      expect(formatReport(report), contains('downloaded '));
    });

    testWidgets('copyToClipboard copies in memory, the chain after it runs, and the text is listed', (tester) async {
      final report = await runRender(tester, run(const [Step('tap', 'cp')], screens: const ['tools'], fullPage: false));
      expect(codes(report, 'error'), isEmpty, reason: '${report.diagnostics}');
      expect(report.clipboard.single['text'], '12 Rue Example');
      final p = await pixelsOf(tester, report.images.single);
      expect(rgbAt(p, 195, 170), 0x00FF00);
    });
  });

  group('clocks', () {
    testWidgets('--now pins now(): a clock a timer writes from it shows that time', (tester) async {
      final args = parseArgs([capture, '--out', out.path, '--sizes', '390x844', '--screen', 'tools', '--now', '2026-01-01T09:00:00Z', '--wait', '1500']);
      final report = await runRender(tester, args);
      expect(codes(report, 'error'), isEmpty, reason: '${report.diagnostics}');
      final p = await pixelsOf(tester, report.images.single);
      expect(rgbAt(p, 195, 220), 0x00FF00);
    });

    testWidgets('a --set holds when a timer writes the variable after it, and the run says so', (tester) async {
      final report = await runRender(tester, run(const [Step('set', 'clock', '"2026-01-01T10:00:00Z"'), Step('wait', '2500')],
          screens: const ['tools'], fullPage: false));
      final p = await pixelsOf(tester, report.images.single);
      expect(rgbAt(p, 195, 220), 0x00FF00);
      expect(codes(report, 'warning'), contains('set_overwritten'));
    });
  });

  group('steps on a site of pages and components', () {
    RenderArgs steps(List<Step> steps, {List<Size> sizes = const [Size(390, 844)]}) =>
        RenderArgs(inputs: [stepsSite], out: out.path, sizes: sizes, steps: steps, dumpLayout: true);

    // The colour of flag [id] (green: what it watches happened) in [png].
    Future<int> flag(WidgetTester tester, String png, String id) async {
      final boxes = jsonDecode(File(png.replaceFirst('.png', '.layout.json')).readAsStringSync()) as List;
      final b = boxes.cast<Map>().firstWhere((b) => b['id'] == id);
      final p = await pixelsOf(tester, png);
      return rgbAt(p, (b['x'] as int) + 20, (b['y'] as int) + 20);
    }

    testWidgets('an id two shown nodes share (a page\'s and a component\'s) is an error that lists how to name each', (tester) async {
      final report = await runRender(tester, steps(const [Step('tap', 'saved')]));
      final failed = report.diagnostics.where((d) => d['code'] == 'interaction_failed').single;
      expect(failed['severity'], 'error');
      expect(failed['message'], allOf(contains('ambiguous'), contains('page/saved'), contains('footer/saved')));
      expect(await flag(tester, report.images.single, 'fSaved'), 0x000000);
      expect(await flag(tester, report.images.single, 'fFooter'), 0x000000);
    });

    testWidgets('the page\'s own node is named under its canvas, the component\'s by its call', (tester) async {
      var report = await runRender(tester, steps(const [Step('tap', 'page/saved')]));
      expect(report.errors, 0, reason: '${report.diagnostics}');
      expect(await flag(tester, report.images.single, 'fSaved'), 0x00FF00);
      expect(await flag(tester, report.images.single, 'fFooter'), 0x000000);
      report = await runRender(tester, steps(const [Step('tap', 'footer/saved')]));
      expect(report.errors, 0, reason: '${report.diagnostics}');
      expect(await flag(tester, report.images.single, 'fSaved'), 0x000000);
      expect(await flag(tester, report.images.single, 'fFooter'), 0x00FF00);
    });

    testWidgets('a node inside a list\'s n-th copy is named <template>#<n>/<node>, as <node>#<n> is', (tester) async {
      for (final target in ['evCard#1/evReserve', 'evReserve#1']) {
        final report = await runRender(tester, steps([Step('tap', target)]));
        expect(report.diagnostics, isEmpty, reason: '$target: ${report.diagnostics}');
        expect(await flag(tester, report.images.single, 'fReserved'), 0x00FF00, reason: target);
      }
    });

    testWidgets('a step on a node hidden at one width is skipped there with a note, and runs at the others', (tester) async {
      final report = await runRender(tester, steps(const [Step('tap', 'menu')], sizes: const [Size(390, 844), Size(1440, 900)]));
      expect(report.errors, 0, reason: '${report.diagnostics}');
      final note = report.diagnostics.single;
      expect(note['severity'], 'warning');
      expect(note['size'], '1440x900');
      expect(note['message'], contains('--tap menu (hidden at this width)'));
      expect(await flag(tester, report.images.firstWhere((i) => i.contains('390x844')), 'fMenu'), 0x00FF00);
    });

    testWidgets('a step on a component\'s node (by its path) hidden at one width is skipped there with a note, not failed', (tester) async {
      final report = await runRender(tester, steps(const [Step('tap', 'footer/narrowOnly')], sizes: const [Size(390, 844), Size(1440, 900)]));
      expect(report.errors, 0, reason: '${report.diagnostics}');
      final note = report.diagnostics.single;
      expect(note['size'], '1440x900');
      expect(note['code'], 'step_skipped', reason: 'a skip, not a failed interaction');
      expect(note['message'], contains('--tap footer/narrowOnly (hidden at this width)'));
    });

    testWidgets('a hover step at several sizes moves one mouse per size and captures each', (tester) async {
      final report = await runRender(tester,
          steps(const [Step('hover', 'slider'), Step('hover', 'footer/saved')], sizes: const [Size(390, 844), Size(834, 1112), Size(1440, 900)]));
      expect(report.errors, 0, reason: '${report.diagnostics}');
      expect(report.images, hasLength(3));
    });

    testWidgets('typing into a field and then tapping a button that removes the form leaves no exception', (tester) async {
      final report = await runRender(tester, steps(const [Step('type', 'email', 'a@b.co'), Step('tap', 'send')]));
      expect(report.diagnostics, isEmpty, reason: '${report.diagnostics}');
      final boxes = jsonDecode(File(report.images.single.replaceFirst('.png', '.layout.json')).readAsStringSync()) as List;
      expect(boxes.cast<Map>().any((b) => b['id'] == 'thanks' && (b['h'] as num) > 0), isTrue);
    });

    testWidgets('a drag step moves a slider by an offset', (tester) async {
      final report = await runRender(tester, steps(const [Step('drag', 'slider', '150,0')]));
      expect(report.diagnostics, isEmpty, reason: '${report.diagnostics}');
      expect(await flag(tester, report.images.single, 'fVolume'), 0x00FF00);
    });

    testWidgets('a drag step says where to when it is given nowhere', (tester) async {
      final report = await runRender(tester, steps(const [Step('drag', 'slider', '')]));
      expect(report.diagnostics.single['message'], contains('--drag slider=<dx>,<dy>'));
    });
  });

  group('--compare finds the reference by its exact name', () {
    late Directory refs;
    setUp(() {
      refs = Directory('${out.path}/refs')..createSync();
      for (final f in [
        'section--saved--390x844.png', 'section--saved-empty--390x844.png', 'search--results--390x844.png',
        'search--no-results--390x844.png', 'index--default--390x844.png', 'about--default--390x844.png', 'about--390x844.png',
        'section--saved--1440x900.png',
      ]) {
        File('${refs.path}/$f').writeAsBytesSync(const []);
      }
    });
    String? pick(String capture, [Map<String, String> map = const {}]) => referenceFor('/x/$capture', refs.path, map: map).file?.split('/').last;

    test('a state whose name begins another state\'s name gets its own file', () {
      expect(pick('section@390x844-saved.png'), 'section--saved--390x844.png');
      expect(pick('section@390x844-saved-empty.png'), 'section--saved-empty--390x844.png');
      expect(pick('search@390x844-results.png'), 'search--results--390x844.png');
      expect(pick('search@390x844-no-results.png'), 'search--no-results--390x844.png');
      expect(pick('section@1440x900-saved.png'), 'section--saved--1440x900.png');
    });

    test('no label is the default state; nothing matching is no reference, not a near one', () {
      expect(pick('about@390x844.png'), 'about--default--390x844.png');
      expect(pick('section@390x844.png'), isNull);
      expect(pick('section@390x844-sav.png'), isNull);
    });

    test('--compare-map names the reference of a screen, or of a screen and state', () {
      expect(pick('home@390x844.png'), isNull);
      expect(pick('home@390x844.png', {'home': 'index'}), 'index--default--390x844.png');
      expect(pick('home@390x844-empty.png', {'home-empty': 'section--saved-empty'}), 'section--saved-empty--390x844.png');
      expect(parseArgs(['s', '--out', 'o', '--compare', 'r', '--compare-map', 'home=index']).compareMap, {'home': 'index'});
    });
  });

  testWidgets('links to a screen that is not there yet are one error per screen, saying how many and where', (tester) async {
    final report = await runRender(tester, RenderArgs(inputs: ['test/tool/fixtures/missing'], out: out.path, validateOnly: true));
    final unknown = report.diagnostics.where((d) => d['code'] == 'unknown_screen').toList();
    expect(unknown, hasLength(2));
    expect(unknown.first['message'], allOf(contains('No screen "about": 3 links'), contains('"pages"')));
    expect(unknown.first['count'], 3);
    expect(unknown.last['message'], startsWith('No screen "contact": "to" is a canvas id'));
  });
}
