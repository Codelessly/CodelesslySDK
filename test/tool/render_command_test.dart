// The render command (tool/render): rendering every
// screen at each size, interactions, and the runtime checks, run in-process
// on the fixtures next to this file.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import '../../tool/render/src/args.dart';
import '../../tool/render/src/fonts.dart' show DirectoryFontFetcher;
import '../../tool/render/src/render.dart';

const fixtures = 'test/tool/fixtures';
const a0 = '$fixtures/authoring';

List<String> codes(RenderReport r, [String? severity]) => [
      for (final d in r.diagnostics)
        if (severity == null || d['severity'] == severity) d['code'] as String,
    ];

void main() {
  _modalScreens();
  _lateFonts();
  late Directory out;
  setUp(() => out = Directory.systemTemp.createTempSync('render_command_test'));
  tearDown(() => out.deleteSync(recursive: true));

  test('the render command reads its sizes and steps in order and requires its values', () {
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
    // Named with the sizes the run was limited to, so a run at other sizes keeps its own.
    final json = jsonDecode(File('${out.path}/diagnostics@390x844+1440x900.json').readAsStringSync()) as Map;
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
    expect(canvas['h'], 844, reason: 'full page: the window keeps its size (as a browser\'s full-page capture)');
    expect(boxes.cast<Map>().map((b) => (b['y'] as num) + (b['h'] as num)).reduce(math.max), greaterThan(844),
        reason: 'the page\'s content below the window, where the PNG draws it');
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
    // Named after the screen it shows (the tap navigated to contact), not the one the run started on.
    expect(File('${out.path}/contact@1440x900-contact.png').existsSync(), isTrue);
    expect(File('${out.path}/home@1440x900-contact.png').existsSync(), isFalse);
  });

  testWidgets('the children of a node moved by its motion do not overflow it; a child laid out past its parent does', (tester) async {
    final report = await runRender(tester, RenderArgs(inputs: ['$fixtures/motion_overflow.json'], out: out.path, sizes: const [Size(390, 400)]));
    final overflowing = [
      for (final d in report.diagnostics)
        if (d['code'] == 'layout_overflow') d['nodeId'],
    ];
    expect(overflowing, ['b'], reason: '${report.diagnostics}');
  });

  testWidgets('overflow, offscreen and clipped text are reported as warnings', (tester) async {
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

  testWidgets('steps for another breakpoint\'s canvas are summarized in one warning', (tester) async {
    final report = await runRender(tester, RenderArgs(inputs: ['$fixtures/site'], out: out.path, sizes: const [Size(390, 844)], screens: const ['home'],
        steps: const [Step('tap', 'd-go'), Step('hover', 'd-go')]));
    final skipped = [for (final d in report.diagnostics) if (d['code'] == 'step_skipped') d];
    expect(skipped, hasLength(1), reason: '${report.diagnostics}');
    expect(skipped.single['severity'], 'warning');
    expect(skipped.single['message'], allOf(contains('--tap d-go'), contains('--hover d-go')));
  });

  testWidgets('a step may name a node by its name: the same name on each breakpoint canvas', (tester) async {
    final report = await runRender(tester, RenderArgs(inputs: ['$a0/named.json'], out: out.path, sizes: const [Size(390, 844), Size(1440, 900)],
        steps: const [Step('tap', 'go-button')], dumpLayout: true));
    expect(report.diagnostics.where((d) => d['severity'] == 'error' || d['code'] == 'step_skipped'), isEmpty, reason: '${report.diagnostics}');
  });

}


void _lateFonts() {
  testWidgets('a text whose font arrives late by name is measured in it, not in the fallback: no false text_clipped', (tester) async {
    final out = Directory.systemTemp.createTempSync('render_late_font');
    addTearDown(() => out.deleteSync(recursive: true));
    // The family is named by a binding (no layout lists it: it is asked for
    // by name when the text lays out) and its file takes a while to read.
    DirectoryFontFetcher.debugLatency = const Duration(milliseconds: 1500);
    addTearDown(() => DirectoryFontFetcher.debugLatency = Duration.zero);
    final report = await runRender(
        tester,
        RenderArgs(
          inputs: ['$fixtures/latefont/page'],
          out: out.path,
          sizes: const [Size(390, 844)],
          fontDirs: const ['$fixtures/latefont/fonts'],
        ));
    expect(codes(report), isNot(contains('text_clipped')), reason: '${report.diagnostics}');
    expect(codes(report), isNot(contains('font_fallback')), reason: '${report.diagnostics}');
  });
}

void _modalScreens() {
  testWidgets('with no --screen, canvases opened as modals are not rendered as screens: from a page or from inside a component',
      (tester) async {
    final out = Directory.systemTemp.createTempSync('render_modals');
    addTearDown(() => out.deleteSync(recursive: true));
    final report = await runRender(tester, RenderArgs(inputs: ['$fixtures/modals'], out: out.path, sizes: const [Size(390, 844)]));
    expect(report.errors, 0, reason: '${report.diagnostics}');
    final pngs = out.listSync().map((f) => f.uri.pathSegments.last).where((n) => n.endsWith('.png')).toSet();
    expect(pngs, {'home@390x844.png'});
    // Each is named, with how to capture it.
    final skipped = [for (final d in report.diagnostics) if (d['code'] == 'modal_screen_not_captured') d];
    expect(skipped, isNotEmpty);
    expect(skipped.every((d) => d['severity'] == 'info' && '${d['message']}'.contains('--modals')), isTrue);
    // --modals captures them too, each alone.
    final all = Directory.systemTemp.createTempSync('render_modals_all');
    addTearDown(() => all.deleteSync(recursive: true));
    final withModals = await runRender(tester, RenderArgs(inputs: ['$fixtures/modals'], out: all.path, sizes: const [Size(390, 844)], modals: true));
    expect(withModals.errors, 0, reason: '${withModals.diagnostics}');
    final shots = all.listSync().map((f) => f.uri.pathSegments.last).where((n) => n.endsWith('.png')).toSet();
    expect(shots, contains('home@390x844.png'));
    expect(shots.length, 1 + skipped.length);
    expect(parseArgs(['site', '--out', 'o', '--modals']).modals, isTrue);
  });
}
