// Cards' Composer: Enter sends what was written, Shift+Enter starts a new
// line in it (written in the notation, driven with the render command's
// steps).
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
  setUp(() => out = Directory('build/cards_composer_test')..createSync(recursive: true));
  tearDown(() => out.deleteSync(recursive: true));

  testWidgets('Enter sends, Shift+Enter writes a new line', (tester) async {
    final problems = <String>[];
    final ds = (await tester.runAsync(() => api.DesignSystem.load((ref) async {
          final f = File('design_systems/cards/$ref');
          return f.existsSync() ? f.readAsStringSync() : null;
        }, problems: problems)))!;
    expect(problems, isEmpty);
    final catalog = ds.catalogOver(api.standardCatalog);
    final vocabulary = loadVocabulary(dir: 'design_systems/cards');
    final r = api.Catalog.run(
        catalog,
        () => parseNotation('state sent=""\nColumn pad=16 gap=12\n  Text#out "sent [{sent}]"\n  Composer onSend={sent=result}\n',
            catalog: catalog, options: NotationOptions.fromDesignSystem(ds, width: 390).open(vocabulary: vocabulary)));
    expect(r.issues, isEmpty);
    final site = Directory('${out.path}/site')..createSync();
    File('${site.path}/page.json').writeAsStringSync(jsonEncode(r.document));
    File('${site.path}/site.json').writeAsStringSync(jsonEncode({
      'designSystem': '../../../design_systems/cards',
      'pages': ['page.json'],
    }));
    final field = ((r.document['nodes']! as Map).entries.firstWhere((e) => (e.value as Map)['type'] == 'textField')).key as String;
    Future<List<String>> texts(List<Step> steps) async {
      final report = await runRender(
          tester, RenderArgs(inputs: [site.path], out: '${out.path}/o', sizes: const [Size(390, 844)], steps: steps, dumpLayout: true));
      expect(report.errors, 0, reason: '${report.diagnostics}');
      final boxes = (jsonDecode(File(report.images.single.replaceFirst('.png', '.layout.json')).readAsStringSync()) as List).cast<Map>();
      return [for (final b in boxes) if (b['text'] != null) '${b['text']}'];
    }

    expect(await texts([Step('type', field, 'hi'), const Step('key', 'shift+Enter'), const Step('key', 'o')]), containsAll(['sent []', 'hi\no']));
    expect(await texts([Step('type', field, 'hi'), const Step('key', 'Enter')]), contains('sent [hi]'));
  });
}
