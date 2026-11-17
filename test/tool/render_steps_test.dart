// The render command's steps on a site of pages and components: how a step
// names a node (by canvas, call path, list copy), hover and drag steps, and
// steps on nodes shown only at another size. Run in-process on
// test/tool/fixtures/steps.
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

/// The color (0xRRGGBB) at [x], [y].
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
  setUp(() => out = Directory.systemTemp.createTempSync('render_steps_test'));
  tearDown(() => out.deleteSync(recursive: true));

  group('steps on a site of pages and components', () {
    RenderArgs steps(List<Step> steps, {List<Size> sizes = const [Size(390, 844)]}) =>
        RenderArgs(inputs: [stepsSite], out: out.path, sizes: sizes, steps: steps, dumpLayout: true);

    // The color of flag [id] (green: what it watches happened) in [png].
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

    testWidgets('--type names a field by an id a component\'s text shares: the one with a text field is typed into', (tester) async {
      var report = await runRender(tester, steps(const [Step('type', 'email', 'a@b.co')]));
      expect(report.errors, 0, reason: '${report.diagnostics}');
      // A tap has no such tie-break: both are named, as paths to write.
      report = await runRender(tester, steps(const [Step('tap', 'email')]));
      final failed = report.diagnostics.where((d) => d['code'] == 'interaction_failed').single;
      expect(failed['message'], allOf(contains('page/email'), contains('footer/email')));
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
}
