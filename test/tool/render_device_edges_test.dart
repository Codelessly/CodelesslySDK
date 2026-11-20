// The render command's device edges: --insets (the safe area), --text-scale
// and the --keyboard step, read by a page as screen.insets, screen.textScale
// and screen.keyboard. The fixture is a chat thread whose composer bar sits on
// a box `h={screen.keyboard + screen.insets.bottom}` tall.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import '../../tool/render/src/args.dart';
import '../../tool/render/src/render.dart';

const _page = 'test/tool/fixtures/device_edges/composer.json';

Map<String, Map> _boxes(String file) =>
    {for (final b in (jsonDecode(File(file).readAsStringSync()) as List).cast<Map>()) '${b['id']}': b};

void main() {
  late Directory out;
  setUp(() => out = Directory.systemTemp.createTempSync('render_device_edges_test'));
  tearDown(() => out.deleteSync(recursive: true));

  test('the options: insets as top,bottom or four sides, a text scale, the keyboard a step', () {
    final a = parseArgs([_page, '--out', 'o', '--insets', '47,34', '--text-scale', '1.3', '--focus', 'composer', '--keyboard', '336']);
    expect(a.insets, [47, 0, 34, 0]);
    expect(a.textScale, 1.3);
    expect(a.steps.map((s) => '$s'), ['--focus composer', '--keyboard 336']);
    expect(parseArgs([_page, '--out', 'o', '--insets', '0,44,21,44']).insets, [0, 44, 21, 44]);
    expect(() => parseArgs([_page, '--out', 'o', '--insets', '47']), throwsFormatException);
    expect(() => parseArgs([_page, '--out', 'o', '--keyboard', 'tall']), throwsFormatException);
  });

  testWidgets('a bottom-pinned composer rides above the keyboard and clears the home indicator', (tester) async {
    Future<Map<String, Map>> capture(String label, List<Step> steps) async {
      final report = await runRender(
          tester,
          RenderArgs(
              inputs: [_page],
              out: out.path,
              sizes: const [Size(390, 844)],
              insets: const [47, 0, 34, 0],
              steps: steps,
              label: label,
              dumpLayout: true));
      expect(report.errors, 0, reason: '${report.diagnostics}');
      final layout = out.listSync().whereType<File>().firstWhere((f) => f.path.endsWith('-$label.layout.json'));
      return _boxes(layout.path);
    }

    final closed = await capture('closed', const []);
    expect(closed['keyboardRoom']!['h'], 34, reason: 'the home indicator');
    final bar = closed['composerBar']!;
    expect((bar['y'] as num) + (bar['h'] as num), 844 - 34);

    // The page lays out above the keyboard (the SDK makes room), so nothing
    // still covers it: screen.keyboard reads 0, and the home indicator is
    // under the keyboard (insets.bottom 0). The bar rests on the keyboard.
    final open = await capture('open', const [Step('focus', 'composer'), Step('keyboard', '336')]);
    expect(open['keyboardRoom']!['h'], 0, reason: 'room made: nothing of the keyboard still covers the page');
    final lifted = open['composerBar']!;
    expect((lifted['y'] as num) + (lifted['h'] as num), 844 - 336);

    final shut = await capture('shut', const [Step('focus', 'composer'), Step('keyboard', '336'), Step('keyboard', '0')]);
    expect(shut['keyboardRoom']!['h'], 34, reason: 'closed again');
  });

  testWidgets('never lifted twice: a page that pads its composer by the keyboard and one that writes nothing end the same', (tester) async {
    // The same page without the room under the bar: it writes nothing of
    // the keyboard or the insets.
    final json = jsonDecode(File(_page).readAsStringSync()) as Map<String, Object?>;
    final nodes = json['nodes'] as Map<String, Object?>;
    nodes.remove('keyboardRoom');
    for (final n in nodes.values) {
      if (n is Map && n['children'] is List) (n['children'] as List).remove('keyboardRoom');
    }
    final plain = File('${out.path}/plain.json')..writeAsStringSync(jsonEncode(json));
    Future<Map<String, Map>> capture(String page, String label) async {
      final report = await runRender(
          tester,
          RenderArgs(
              inputs: [page],
              out: '${out.path}/o',
              sizes: const [Size(390, 844)],
              insets: const [47, 0, 34, 0],
              steps: const [Step('focus', 'composer'), Step('keyboard', '336')],
              label: label,
              dumpLayout: true));
      expect(report.errors, 0, reason: '${report.diagnostics}');
      final layout = Directory('${out.path}/o').listSync().whereType<File>().firstWhere((f) => f.path.endsWith('-$label.layout.json'));
      return _boxes(layout.path);
    }

    double bottomOf(Map<String, Map> boxes) => ((boxes['composerBar']!['y'] as num) + (boxes['composerBar']!['h'] as num)).toDouble();
    final padded = await capture(_page, 'padded');
    final bare = await capture(plain.path, 'bare');
    expect(bottomOf(padded), 844 - 336, reason: 'on the keyboard, not above it by the keyboard again');
    expect(bottomOf(bare), 844 - 336, reason: 'on the keyboard: the SDK made room');
  });
}
