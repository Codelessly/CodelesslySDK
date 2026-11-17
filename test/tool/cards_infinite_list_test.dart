// Cards' InfiniteList: its Load more button shows while there is more to
// load, and hasMore=false takes it away (written in the notation, rendered
// with the render command).
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_api/notation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/notation/vocabulary.dart' show loadVocabulary;
import '../../tool/render/src/args.dart';
import '../../tool/render/src/render.dart';

void main() {
  // Under the checkout, so that the site names the design system by a
  // relative folder.
  late Directory out;
  setUp(() => out = Directory('build/cards_infinite_list_test')..createSync(recursive: true));
  tearDown(() => out.deleteSync(recursive: true));

  testWidgets('hasMore=false: no Load more under the rows', (tester) async {
    final problems = <String>[];
    final ds = (await tester.runAsync(() => api.DesignSystem.load((ref) async {
          final f = File('design_systems/cards/$ref');
          return f.existsSync() ? f.readAsStringSync() : null;
        }, problems: problems)))!;
    expect(problems, isEmpty);
    final catalog = ds.catalogOver(api.standardCatalog);
    final vocabulary = loadVocabulary(dir: 'design_systems/cards');
    Future<int> loadMores(String hasMore) async {
      final r = api.Catalog.run(
          catalog,
          () => parseNotation('state rows=["one","two"]\nColumn pad=16\n  InfiniteList items={rows}$hasMore onLoadMore={}\n    each r in rows\n      Text "{r}"\n',
              catalog: catalog, options: NotationOptions.fromDesignSystem(ds, width: 390).open(vocabulary: vocabulary)));
      expect(r.issues, isEmpty);
      final site = Directory('${out.path}/site')..createSync(recursive: true);
      File('${site.path}/page.json').writeAsStringSync(jsonEncode(r.document));
      File('${site.path}/site.json').writeAsStringSync(jsonEncode({
        'designSystem': '../../../design_systems/cards',
        'pages': ['page.json'],
      }));
      final report = await runRender(tester, RenderArgs(inputs: [site.path], out: '${out.path}/o', sizes: const [Size(390, 844)], dumpLayout: true));
      expect(report.errors, 0, reason: '${report.diagnostics}');
      final boxes = (jsonDecode(File(report.images.single.replaceFirst('.png', '.layout.json')).readAsStringSync()) as List).cast<Map>();
      return boxes.where((b) => b['text'] == 'Load more').length;
    }

    expect(await loadMores(''), 1);
    expect(await loadMores(' hasMore={length(rows) < 2}'), 0);
  });
}
