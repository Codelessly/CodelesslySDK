// The render command (tool/render): strict validation, rendering every
// screen at each size, interactions, and the runtime checks, run in-process
// on the fixtures next to this file.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import '../../tool/render/src/args.dart';
import '../../tool/render/src/compare.dart';
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
    expect(canvas['h'], 844, reason: 'full page: the window keeps its size (as a browser\'s full-page capture)');
    expect(boxes.cast<Map>().map((b) => (b['y'] as num) + (b['h'] as num)).reduce(math.max), greaterThan(844),
        reason: 'the page\'s content below the window, where the PNG draws it');
    final bytes = File('${out.path}/home@390x844.png').readAsBytesSync();
    // PNG height (big-endian at 20..23) is the full page.
    expect((bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23], greaterThan(844));
  });

  testWidgets('a tap that copies to the clipboard runs the rest of its chain', (tester) async {
    final report = await runRender(
      tester,
      RenderArgs(inputs: ['$fixtures/clipboard.json'], out: out.path, sizes: const [Size(390, 300)],
          steps: const [Step('tap', 'copy')], dumpLayout: true),
    ).timeout(const Duration(seconds: 30));
    expect(report.errors, 0, reason: '${report.diagnostics}');
    final boxes = jsonDecode(File('${out.path}/home@390x300.layout.json').readAsStringSync()) as List;
    final done = boxes.cast<Map>().firstWhere((b) => b['id'] == 'done');
    expect(done['h'], greaterThan(0), reason: 'the variable set after the copy shows "Copied"');
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

  testWidgets('a document with mistakes gets validation codes with paths and suggestions, and an error exit status', (tester) async {
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

    testWidgets('a tap step reveals its target below an overlaid header and hits it', (tester) async {
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

    testWidgets('a type step types into a text field, and its bound variable and the text showing it follow', (tester) async {
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

    testWidgets('a full-page capture takes the page\'s own scroll height, and a bar fixed to the window is drawn in the first window', (tester) async {
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

  // The guide's responsive example (codelessly_api tool/reference/examples/
  // responsive_web.json, copied): the four web patterns at three widths.
  testWidgets('the guide\'s responsive example: header, 3-2-1 grid from one list, stacking split, type scale', (tester) async {
    final report = await runRender(tester, RenderArgs(inputs: ['$a0/responsive_web.json'], out: out.path, dumpLayout: true));
    expect(report.diagnostics, isEmpty, reason: '${report.diagnostics}');
    Map<String, List<Map>> boxes(String size) {
      final out0 = <String, List<Map>>{};
      for (final b in jsonDecode(File('${out.path}/home@$size.layout.json').readAsStringSync()) as List) {
        (out0[(b as Map)['id'] as String] ??= []).add(b);
      }
      return out0;
    }
    int columns(Map<String, List<Map>> b) => b['plan']!.where((p) => p['y'] == b['plan']!.first['y']).length;
    final m = boxes('390x844'), t = boxes('834x1112'), d = boxes('1440x900');
    expect([columns(m), columns(t), columns(d)], [1, 2, 3], reason: 'auto-fit columns from one bound list');
    expect(d['plan']!.map((p) => p['h']).toSet(), hasLength(1), reason: 'equal heights per row');
    // Desktop: text and photo side by side; phone: stacked, photo first.
    expect(d['split-text']!.single['x'], lessThan(d['split-photo']!.single['x'] as num));
    expect(m['split-photo']!.single['y'], lessThan(m['split-text']!.single['y'] as num));
    expect(m['split-photo']!.single['w'], 358);
    // Nav collapses to the menu icon below desktop: the hidden one takes no room.
    expect(d['nav']!.single['w'], greaterThan(0));
    expect(m['nav']!.single['w'], 0);
    // The content column is capped at 1200 and centered.
    expect(d['content']!.single['w'], 1200);
    expect(d['content']!.single['x'], 120);
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

    testWidgets('a call to a component the site lacks: validation names it, the render reports it', (tester) async {
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
      expect(codes(report), containsAll(['unknown_component', 'component_missing']));
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

    testWidgets('an unknown name is an error naming the nearest', (tester) async {
      final dir = Directory('${out.path}/site')..createSync();
      File('$t/named/site.json').copySync('${dir.path}/site.json');
      File('${dir.path}/home.json').writeAsStringSync(File('$t/named/home.json').readAsStringSync().replaceFirst('"style": "body"', '"style": "bdy"'));
      final r = await runRender(tester, RenderArgs(inputs: [dir.path], out: '${out.path}/o', sizes: const [Size(390, 844)], validateOnly: true));
      final d = r.diagnostics.singleWhere((d) => d['code'] == 'unknown_theme_name');
      expect(d['suggestion'], 'body');
    });
  });

  group('more authoring fixes', () {
    const f = '$fixtures/fix3';
    testWidgets('a fill with no room to fill is reported; a page id and a component id never collide', (tester) async {
      final r = await runRender(tester, RenderArgs(inputs: [f], out: out.path, sizes: const [Size(390, 844)]));
      expect(codes(r), ['fill_fallback'], reason: '${r.diagnostics}');
      final d = r.diagnostics.single;
      expect(d['nodeId'], 'cardBody');
      expect(d['message'], contains('parent "card" (column) hugs its height'));
      expect(d['message'], contains('280 px'));
    });

    testWidgets('an action naming a node of a component acts on its own instance', (tester) async {
      final r = await runRender(tester, RenderArgs(inputs: [f], out: out.path, sizes: const [Size(390, 844)], dumpLayout: true,
          steps: const [Step('tap', 'p2/go'), Step('wait', '12000')]));
      expect(codes(r, 'error'), isEmpty, reason: '${r.diagnostics}');
      final boxes = (jsonDecode(File('${out.path}/home@390x844.layout.json').readAsStringSync()) as List).cast<Map>();
      Map at(String path) => boxes.singleWhere((b) => b['path'] == path);
      bool shows(String panel) {
        final list = at('$panel/list'), end = at('$panel/end');
        return (end['y'] as num) >= (list['y'] as num) && (end['y'] as num) + (end['h'] as num) <= (list['y'] as num) + (list['h'] as num) + 0.5;
      }
      expect(shows('p2'), isTrue, reason: 'the tapped instance scrolled its own list: $boxes');
      expect(shows('p1'), isFalse, reason: 'the other instance did not move');
    });
  });

  testWidgets('a full-page capture keeps the window, so a drawer pinned to its top and bottom covers the first window only', (tester) async {
    final r = await runRender(tester, RenderArgs(inputs: ['$fixtures/fix3-drawer.json'], out: out.path, sizes: const [Size(390, 844)],
        fullPage: true, dumpLayout: true));
    expect(r.errors, 0, reason: '${r.diagnostics}');
    final boxes = (jsonDecode(File('${out.path}/drawerScreen@390x844.layout.json').readAsStringSync()) as List).cast<Map>();
    final drawer = boxes.singleWhere((b) => b['id'] == 'drawer');
    expect([drawer['y'], drawer['h']], [72, 772]);
    final bytes = File(r.images.single).readAsBytesSync();
    final image = await tester.runAsync(() async {
      final frame = await (await ui.instantiateImageCodec(bytes)).getNextFrame();
      return (await frame.image.toByteData(), frame.image.width, frame.image.height);
    });
    int px(int x, int y, int c) => image!.$1!.getUint8((y * image.$2 + x) * 4 + c);
    expect(image!.$3, 2400);
    expect([px(195, 500, 0), px(195, 500, 1)], [255, 0], reason: 'the drawer over the first window');
    expect([px(195, 1500, 0), px(195, 1500, 1)], [0, 255], reason: 'the page below it');
  });

  testWidgets('an unfocus step takes the focus from a field, and a key step presses a key on what has the focus', (tester) async {
    Future<double> moved(List<Step> steps) async {
      final o = Directory('${out.path}/${steps.length}-${steps.first.kind}')..createSync();
      final r = await runRender(tester, RenderArgs(inputs: ['$fixtures/fix3-keys.json'], out: o.path, sizes: const [Size(390, 844)],
          dumpLayout: true, steps: steps));
      expect(r.errors, 0, reason: '${r.diagnostics}');
      final boxes = (jsonDecode(File('${o.path}/keys@390x844.layout.json').readAsStringSync()) as List).cast<Map>();
      return (boxes.singleWhere((b) => b['id'] == 'moved')['h'] as num).toDouble();
    }

    expect(await moved(const [Step('key', 'ArrowRight')]), 40, reason: 'the screen\'s keyDown reaction ran');
    expect(await moved(const [Step('type', 'field', 'abc'), Step('key', 'ArrowRight')]), 0, reason: 'the focused field took the key');
    expect(await moved(const [Step('type', 'field', 'abc'), Step('unfocus', ''), Step('key', 'ArrowRight')]), 40);
    expect(parseArgs(['k.json', '--out', 'o', '--unfocus', '--key', 'shift+Tab']).steps.map((s) => s.kind), ['unfocus', 'key']);
  });

  testWidgets('comparing renders matches the same page and finds one pushed down, saying by how much', (tester) async {
    final r = await runRender(tester, RenderArgs(inputs: ['$fixtures/fix3-drawer.json'], out: out.path, sizes: const [Size(390, 844)],
        fullPage: true, compare: '$fixtures/fix3-drawer.json'.replaceFirst('fix3-drawer.json', 'none.png')));
    expect(codes(r), ['compare_failed'], reason: '${r.diagnostics}');
    final capture = r.images.single;
    // A reference: the capture 20 px lower under a 20 px band.
    final reference = '${out.path}/ref.png';
    await tester.runAsync(() async {
      final img = await decodePng(File(capture).readAsBytesSync());
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 390, 20), ui.Paint()..color = const ui.Color(0xFF000000));
      final c = Completer<ui.Image>();
      ui.decodeImageFromPixels(img.rgba, img.width, img.height, ui.PixelFormat.rgba8888, c.complete);
      canvas.drawImage(await c.future, const ui.Offset(0, 20), ui.Paint());
      final out = await recorder.endRecording().toImage(390, img.height + 20);
      File(reference).writeAsBytesSync((await out.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());
    });
    final same = (await tester.runAsync(() => compareImages(capture, capture)))!;
    expect(same.matching, 1.0);
    expect(same.bands, isEmpty);
    final shifted = (await tester.runAsync(() => compareImages(capture, reference)))!;
    expect(shifted.referenceHeight - shifted.captureHeight, 20);
    expect(shifted.bands.any((b) => b.shift == 20), isTrue, reason: shifted.summary());
    expect(shifted.summary(), contains('20 px shorter than the reference'));
    expect(File(capture.replaceFirst('.png', '.compare.png')).existsSync() && File(capture.replaceFirst('.png', '.diff.png')).existsSync(), isTrue);
  });

  testWidgets('overlapping a neighbour: motion moves what is painted, not the layout; a media rule patches it', (tester) async {
    final r = await runRender(tester, RenderArgs(inputs: ['$fixtures/fix3-overlap.json'], out: out.path, sizes: const [Size(390, 844), Size(1440, 900)]));
    expect(r.diagnostics, isEmpty, reason: '${r.diagnostics}');
    Future<List<int>> column(String png, int x, List<int> ys) async => (await tester.runAsync(() async {
          final img = await decodePng(File('${out.path}/$png').readAsBytesSync());
          return [for (final y in ys) img.rgba[(y * img.width + x) * 4] << 16 | img.rgba[(y * img.width + x) * 4 + 1] << 8 | img.rgba[(y * img.width + x) * 4 + 2]];
        }))!;
    // On a phone the card is drawn 36 px up, over the hero's bottom; its
    // slot (and the box after it, at 300) do not move.
    expect(await column('overlap@390x844.png', 195, [160, 170, 260, 270, 310]), [0x00FF00, 0xFF0000, 0xFF0000, 0xFFFFFF, 0x0000FF]);
    // At desktop width the media rule puts it back.
    expect(await column('overlap@1440x900.png', 720, [180, 280, 310]), [0x00FF00, 0xFF0000, 0x0000FF]);
  });

  testWidgets('a media rule may bind: visible on phones only while a variable allows, hidden elsewhere', (tester) async {
    Future<Map<String, double>> heights(List<Step> steps) async {
      final o = Directory('${out.path}/${steps.length}')..createSync();
      final r = await runRender(tester, RenderArgs(inputs: ['$fixtures/fix3-media-bind.json'], out: o.path,
          sizes: const [Size(390, 844), Size(1440, 900)], dumpLayout: true, steps: steps));
      expect(r.diagnostics, isEmpty, reason: '${r.diagnostics}');
      return {
        for (final w in ['390x844', '1440x900'])
          w: ((jsonDecode(File('${o.path}/mb@$w.layout.json').readAsStringSync()) as List).cast<Map>().singleWhere((b) => b['id'] == 'bar')['h'] as num)
              .toDouble(),
      };
    }

    expect(await heights(const []), {'390x844': 60, '1440x900': 0});
    expect(await heights(const [Step('set', 'open', 'true')]), {'390x844': 0, '1440x900': 0});
  });

  // The guide's band example (codelessly_api tool/reference/examples/band.json, copied): a full-width band whose
  // content is capped at 1200 and centered, and a table from one row and one cell template.
  testWidgets('the guide\'s band example: full-width band, content capped and centered, a table from one template', (tester) async {
    final r = await runRender(tester, RenderArgs(inputs: ['$a0/band.json'], out: out.path, sizes: const [Size(390, 844), Size(1700, 900)],
        dumpLayout: true));
    expect(r.diagnostics, isEmpty, reason: '${r.diagnostics}');
    List<Map> boxes(String size) => (jsonDecode(File('${out.path}/home@$size.layout.json').readAsStringSync()) as List).cast<Map>();
    final wide = boxes('1700x900');
    final band = wide.singleWhere((b) => b['id'] == 'band'), rail = wide.singleWhere((b) => b['id'] == 'rail');
    expect([band['x'], band['w']], [0, 1700.0]);
    expect([rail['x'], rail['w']], [250, 1200.0]);
    expect(wide.where((b) => b['id'] == 'cell'), hasLength(9), reason: 'three rows of three cells from one cell node');
    final narrow = boxes('390x844').singleWhere((b) => b['id'] == 'rail');
    expect([narrow['x'], narrow['w']], [24, 342.0]);
  });
}
