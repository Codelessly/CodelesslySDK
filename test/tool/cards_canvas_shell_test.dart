// Cards' CanvasShell called as a container where nothing limits its height
// (in an app's Main, which scrolls): its surface is as tall as what it
// holds, not the 120 px of its preview (written in the notation, rendered
// with the render command).
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_api/notation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/render/src/args.dart';
import '../../tool/render/src/render.dart';

void main() {
  // Under the checkout, so that the site names the design system by a
  // relative folder.
  late Directory out;
  setUp(() => out = Directory('build/cards_canvas_shell_test')..createSync(recursive: true));
  tearDown(() => out.deleteSync(recursive: true));

  testWidgets('a CanvasShell in an app\'s Main (no height limit) holds all of its content', (tester) async {
    final problems = <String>[];
    final ds = (await tester.runAsync(() => api.DesignSystem.load((ref) async {
          final f = File('design_systems/cards/$ref');
          return f.existsSync() ? f.readAsStringSync() : null;
        }, problems: problems)))!;
    expect(problems, isEmpty);
    final catalog = ds.catalogOver(api.standardCatalog);
    final r = api.Catalog.run(
        catalog,
        // In an app's Main, which scrolls: what is in it has no height limit.
        () => parseNotation('App\n  Main\n    Column gap=0\n      Text "Workspace"\n      CanvasShell grow\n        Box#plan w=300 h=420 fill="#FF93C5FD"\n',
            catalog: catalog, options: NotationOptions.fromDesignSystem(ds, width: 1440)));
    expect(r.issues, isEmpty);
    final site = Directory('${out.path}/site')..createSync();
    File('${site.path}/page.json').writeAsStringSync(jsonEncode(r.document));
    File('${site.path}/site.json').writeAsStringSync(jsonEncode({
      'designSystem': '../../../design_systems/cards',
      'pages': ['page.json'],
    }));
    final report = await runRender(tester, RenderArgs(inputs: [site.path], out: '${out.path}/o', sizes: const [Size(1440, 900)], dumpLayout: true));
    expect([for (final d in report.diagnostics) if (d['code'] == 'fill_fallback') d['message']], isEmpty);
    final boxes = (jsonDecode(File(report.images.single.replaceFirst('.png', '.layout.json')).readAsStringSync()) as List).cast<Map>();
    final canvas = boxes.firstWhere((b) => b['path'] == 'CanvasShell1/canvas');
    final plan = boxes.firstWhere((b) => b['id'] == 'plan');
    expect(canvas['h'], greaterThanOrEqualTo(420 + 2 * 20));
    expect((plan['y'] as num) + (plan['h'] as num), lessThanOrEqualTo((canvas['y'] as num) + (canvas['h'] as num)));
  });
}
