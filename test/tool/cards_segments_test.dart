// Cards' Segments at phone width: a long option ("Recommended") keeps
// within its cell (written in the notation, rendered with the render
// command, which reports an overflow as a render_exception).
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
  setUp(() => out = Directory('build/cards_segments_test')..createSync(recursive: true));
  tearDown(() => out.deleteSync(recursive: true));

  testWidgets('long options lay out with no overflow at 390 px', (tester) async {
    final problems = <String>[];
    final ds = (await tester.runAsync(() => api.DesignSystem.load((ref) async {
          final f = File('design_systems/cards/$ref');
          return f.existsSync() ? f.readAsStringSync() : null;
        }, problems: problems)))!;
    expect(problems, isEmpty);
    final catalog = ds.catalogOver(api.standardCatalog);
    final r = api.Catalog.run(
        catalog,
        () => parseNotation(
            'state sort="Recommended"\nColumn pad=24 gap=12\n  Segments @sort options=["Recommended", "Price", "Rating"]\n',
            catalog: catalog,
            options: NotationOptions.fromDesignSystem(ds, width: 390)));
    expect(r.issues, isEmpty);
    final site = Directory('${out.path}/site')..createSync();
    File('${site.path}/page.json').writeAsStringSync(jsonEncode(r.document));
    File('${site.path}/site.json').writeAsStringSync(jsonEncode({
      'designSystem': '../../../design_systems/cards',
      'pages': ['page.json'],
    }));
    final report = await runRender(tester, RenderArgs(inputs: [site.path], out: '${out.path}/o', sizes: const [Size(390, 844)]));
    expect([for (final d in report.diagnostics) if (d['code'] == 'render_exception' || d['code'] == 'layout_overflow') d['message']], isEmpty);
  });
}
