// The render command (tool/render) on whole pages: the guide's responsive
// and band examples, full-page captures, focus and key steps, comparing
// renders, and media rules. Run in-process on the fixtures next to this file.
import 'dart:convert';
import 'dart:io';
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
  setUp(() => out = Directory.systemTemp.createTempSync('render_command_pages_test'));
  tearDown(() => out.deleteSync(recursive: true));

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
