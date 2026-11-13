// The render command (tool/render): strict validation, rendering every
// screen at each size, interactions, and the runtime checks, run in-process
// on the fixtures next to this file.
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
  setUp(() => out = Directory.systemTemp.createTempSync('render_command_test'));
  tearDown(() => out.deleteSync(recursive: true));

  test('arguments: sizes, steps in order, required values', () {
    final a = parseArgs(['site', '--out', 'o', '--sizes', '390x844,1440x900', '--tap', 'b#2', '--set', 'n=3', '--scroll', 'screen=400', '--full-page']);
    expect(a.sizes.map((s) => s.width), [390, 1440]);
    expect(a.steps.map((s) => s.toString()), ['--tap b#2', '--set n=3', '--scroll screen=400']);
    expect(a.fullPage, isTrue);
    expect(() => parseArgs(['site']), throwsFormatException);
    expect(() => parseArgs(['site', '--out', 'o', '--sizes', '390']), throwsFormatException);
    expect(() => parseArgs(['site', '--out', 'o', '--bogus']), throwsFormatException);
  });

  testWidgets('a valid two-page responsive site: no diagnostics, a PNG per screen and size', (tester) async {
    final report = await runRender(tester, RenderArgs(inputs: ['$fixtures/site'], out: out.path, sizes: const [Size(390, 844), Size(1440, 900)]));
    expect(report.diagnostics, isEmpty, reason: '${report.diagnostics}');
    final pngs = out.listSync().map((f) => f.uri.pathSegments.last).where((n) => n.endsWith('.png')).toSet();
    expect(pngs, {'home@390x844.png', 'home@1440x900.png', 'contact@390x844.png', 'contact@1440x900.png'});
    final json = jsonDecode(File('${out.path}/diagnostics.json').readAsStringSync()) as Map;
    expect(json['errors'], 0);
  });

  testWidgets('interactions run before the capture; full page captures the scroll height', (tester) async {
    final report = await runRender(
      tester,
      RenderArgs(
        inputs: ['$fixtures/site/home.json', '$fixtures/site/contact.json'],
        out: out.path,
        sizes: const [Size(390, 844)],
        screens: const ['home'],
        steps: const [Step('tap', 'm-add'), Step('tap', 'm-add'), Step('set', 'count', '40'), Step('tap', 'm-add')],
        fullPage: true,
        dumpLayout: true,
      ),
    );
    expect(report.errors, 0, reason: '${report.diagnostics}');
    final boxes = jsonDecode(File('${out.path}/home@390x844.layout.json').readAsStringSync()) as List;
    final canvas = boxes.firstWhere((b) => b['id'] == 'home-m') as Map;
    expect(canvas['h'] as num, greaterThan(844), reason: 'full page: taller than the viewport');
    final bytes = File('${out.path}/home@390x844.png').readAsBytesSync();
    // PNG height (big-endian at 20..23) is the full page.
    expect((bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23], greaterThan(844));
  });

  testWidgets('navigating to a screen of another document', (tester) async {
    final report = await runRender(
      tester,
      RenderArgs(inputs: ['$fixtures/site'], out: out.path, sizes: const [Size(1440, 900)], screens: const ['home'],
          steps: const [Step('tap', 'd-go')], label: 'contact'),
    );
    expect(report.errors, 0, reason: '${report.diagnostics}');
    expect(File('${out.path}/home@1440x900-contact.png').existsSync(), isTrue);
  });

  testWidgets('mistakes: validation codes with paths and suggestions, exit status error', (tester) async {
    final report = await runRender(tester, RenderArgs(inputs: ['$fixtures/mistakes.json'], out: out.path, sizes: const [Size(390, 844)]));
    final found = codes(report);
    expect(
      found,
      containsAll(<String>[
        'dangling_child', 'unknown_prop', 'invalid_enum', 'wrong_type', 'unknown_field', 'unknown_name', //
        'layout_field_ignored', 'unknown_bind_path', 'expression_syntax', 'unknown_screen', 'unknown_action_key',
      ]),
    );
    expect(report.errors, greaterThan(0));
    final colour = report.diagnostics.firstWhere((d) => d['code'] == 'unknown_field');
    expect(colour['path'], '/nodes/title/props/style/colour');
    expect(colour['suggestion'], 'color');
    // The formula is parsed by the SDK's own parser.
    final formula = report.diagnostics.firstWhere((d) => d['code'] == 'expression_syntax');
    expect(formula['message'], contains('does not parse'));
  });

  testWidgets('runtime checks: overflow, offscreen and clipped text are warnings', (tester) async {
    final report = await runRender(tester, RenderArgs(inputs: ['$fixtures/overflow.json'], out: out.path, sizes: const [Size(390, 400)]));
    expect(report.errors, 0, reason: '${report.diagnostics}');
    final warnings = codes(report, 'warning');
    expect(warnings, containsAll(<String>['layout_overflow', 'offscreen', 'text_clipped']));
    final overflow = report.diagnostics.firstWhere((d) => d['code'] == 'layout_overflow');
    expect(overflow['nodeId'], 'b');
    expect(File('${out.path}/tight@390x400.png').existsSync(), isTrue);
  });

  testWidgets('an unknown --screen and a missing node to tap are reported', (tester) async {
    final report = await runRender(
      tester,
      RenderArgs(inputs: ['$fixtures/site'], out: out.path, sizes: const [Size(390, 844)], screens: const ['nope', 'contact'],
          steps: const [Step('tap', 'missing')]),
    );
    expect(codes(report, 'error'), containsAll(<String>['unknown_screen_arg', 'interaction_failed']));
    expect(formatReport(report), contains('error(s)'));
  });

  testWidgets('steps for another breakpoint\'s canvas are summarised in one warning', (tester) async {
    final report = await runRender(tester, RenderArgs(inputs: ['$fixtures/site'], out: out.path, sizes: const [Size(390, 844)], screens: const ['home'],
        steps: const [Step('tap', 'd-go'), Step('hover', 'd-go')]));
    final skipped = [for (final d in report.diagnostics) if (d['code'] == 'interaction_failed') d];
    expect(skipped, hasLength(1), reason: '${report.diagnostics}');
    expect(skipped.single['severity'], 'warning');
    expect(skipped.single['message'], allOf(contains('--tap d-go'), contains('--hover d-go')));
  });

  testWidgets('a step may name a node by its name: the same name on each breakpoint canvas', (tester) async {
    final report = await runRender(tester, RenderArgs(inputs: ['$a0/named.json'], out: out.path, sizes: const [Size(390, 844), Size(1440, 900)],
        steps: const [Step('tap', 'go-button')], dumpLayout: true));
    expect(report.diagnostics.where((d) => d['severity'] == 'error' || d['code'] == 'interaction_failed'), isEmpty, reason: '${report.diagnostics}');
  });

  group('authoring fixes', () {
    const a = '$fixtures/authoring';
    List<Map> diag(RenderReport r, String code) => [for (final d in r.diagnostics) if (d['code'] == code) d];

    testWidgets('--tap reveals its target below an overlaid header, and hits it', (tester) async {
      final report = await runRender(tester, RenderArgs(inputs: ['$a/taps.json'], out: out.path, sizes: const [Size(390, 844)],
          steps: const [Step('tap', 'target'), Step('tap', 'target')], dumpLayout: true, label: 'two'));
      expect(report.errors, 0, reason: '${report.diagnostics}');
      expect(diag(report, 'tap_no_reaction'), isEmpty);
      // The header was not tapped (its menu would open); the counter shows 2.
      final boxes = jsonDecode(File('${out.path}/taps@390x844-two.layout.json').readAsStringSync()) as List;
      final target = boxes.firstWhere((b) => b['id'] == 'target') as Map;
      expect(target['y'] as num, greaterThan(64), reason: 'below the header');
      expect(File('${out.path}/diagnostics-two.json').existsSync(), isTrue, reason: 'a labelled run keeps its own diagnostics');
      expect(File('${out.path}/diagnostics.json').existsSync(), isFalse);
    });

    testWidgets('a tap on a node with a margin hits its content; a tap with no reaction is reported', (tester) async {
      final report = await runRender(tester, RenderArgs(inputs: ['$a/taps.json'], out: out.path, sizes: const [Size(390, 844)],
          steps: const [Step('tap', 'margined'), Step('tap', 'plain')]));
      expect(report.errors, 0, reason: '${report.diagnostics}');
      expect(diag(report, 'tap_no_reaction').map((d) => d['nodeId']), ['plain']);
    });

    testWidgets('a tap on a covered node names what covers it', (tester) async {
      final report = await runRender(tester, RenderArgs(inputs: ['$a/taps.json'], out: out.path, sizes: const [Size(390, 844)],
          steps: const [Step('tap', 'last')]));
      final failed = diag(report, 'interaction_failed');
      expect(failed, hasLength(1), reason: '${report.diagnostics}');
      expect(failed.single['message'], contains('"veil"'));
      final through = await runRender(tester, RenderArgs(inputs: ['$a/taps.json'], out: out.path, sizes: const [Size(390, 844)],
          steps: const [Step('tap', 'spacer-top')]));
      expect(diag(through, 'interaction_failed').single['message'], contains('no fill and no reaction'));
    });

    testWidgets('--type types into a text field: its bound variable follows, so does the text showing it', (tester) async {
      final report = await runRender(tester, RenderArgs(inputs: ['$a/checks.json'], out: out.path, sizes: const [Size(390, 844)],
          steps: const [Step('focus', 'field'), Step('type', 'field', 'cauliflower')], dumpLayout: true));
      expect(diag(report, 'interaction_failed'), isEmpty, reason: '${report.diagnostics}');
      final shown = [
        for (final d in report.diagnostics)
          if (d['nodeId'] == 'echo') d,
      ];
      expect(shown, isEmpty);
      final echo = (jsonDecode(File('${out.path}/checks@390x844.layout.json').readAsStringSync()) as List).firstWhere((b) => b['id'] == 'echo') as Map;
      expect(echo['w'] as num, greaterThan(100), reason: '"Query: cauliflower" is wider than "Query: "');
    });

    testWidgets('what draws nothing is reported: missing glyphs, unknown icons, unevaluated text, paths past their box', (tester) async {
      final report = await runRender(tester, RenderArgs(inputs: ['$a/checks.json'], out: out.path, sizes: const [Size(390, 844)]));
      expect(diag(report, 'missing_glyph').single['nodeId'], 'star');
      expect(diag(report, 'missing_glyph').single['message'], contains('U+2726'));
      expect(diag(report, 'icon_not_drawn').single['nodeId'], 'bad-icon');
      expect(diag(report, 'expression_not_evaluated'), isEmpty, reason: 'bound runs style the evaluated text');
      expect(diag(report, 'path_overflow').single['nodeId'], 'mark');
      expect(diag(report, 'icon_not_drawn').where((d) => d['nodeId'] == 'field'), isEmpty, reason: 'the prefix icon by name draws');
    });

    testWidgets('--full-page: the page\'s own scroll height only; a bar fixed to the window drawn in the first window', (tester) async {
      final report = await runRender(tester, RenderArgs(inputs: ['$a/fullpage.json'], out: out.path, sizes: const [Size(390, 844)], fullPage: true));
      expect(report.errors, 0, reason: '${report.diagnostics}');
      final bytes = File('${out.path}/long@390x844.png').readAsBytesSync();
      final height = (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23];
      expect(height, 2000, reason: 'hero 400 + rest 1600, not the inner list\'s 640');
      final image = await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final data = await frame.image.toByteData();
        return (data!, frame.image.width);
      });
      int red(int x, int y) => image!.$1.getUint8((y * image.$2 + x) * 4);
      expect(red(195, 844 - 12 - 26), 255, reason: 'the bar where a user first sees it');
      expect(red(195, 2000 - 12 - 26), isNot(255), reason: 'not at the bottom of the page');
    });
  });
}
