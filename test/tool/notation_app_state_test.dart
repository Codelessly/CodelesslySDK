// A site's shared state in app.txt (state lines, as a page writes them) and
// a site with no site.json: `expand <folder>` reads both, writes the manifest
// a render reads its variables from, and the render shows them.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:codelessly_api/notation_site.dart' show notationBuiltKey;
import 'package:flutter_test/flutter_test.dart';

import '../../tool/notation/expand.dart' as expand;
import '../../tool/notation/notation_site.dart';
import '../../tool/render/src/args.dart';
import '../../tool/render/src/render.dart';

void main() {
  late Directory root;
  void write(String path, String text) => File('${root.path}/$path')
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(text);
  Map<String, Object?> manifest([String path = 'site/site.json']) => (jsonDecode(File('${root.path}/$path').readAsStringSync()) as Map).cast<String, Object?>();

  setUp(() {
    root = Directory.systemTemp.createTempSync('notation_app_state_test');
    write('pages/home.txt', 'Column#col pad=24\n  Text#label "{plan}: {length(txns)} rows, left {left}"\n  Button "Budgets" onTap={go budgets}\n');
    write('pages/budgets.txt', 'Text "Budgets for {plan}"\n');
    write('app.txt', '// Shared.\nstate plan="pro" saved\nstate income=100\nstate txns=[\n  {"merchant":"A","amount":30},\n  {"merchant":"B","amount":20},\n]\nstate left={income-sum(txns,t=>t.amount)}\n');
    exitCode = 0;
  });
  tearDown(() {
    exitCode = 0;
    root.deleteSync(recursive: true);
  });

  test('a folder of pages and app.txt is a site: found from the folder, a page and app.txt', () {
    final String at = '${root.path}/site/site.json'.replaceAll(r'\', '/');
    String? found({String? site, String? file}) => findSiteManifest(site: site, file: file)?.replaceAll(r'\', '/');
    expect(isSiteFolder(root.path), isTrue);
    expect(found(site: root.path), at);
    expect(found(file: '${root.path}/pages/home.txt'), endsWith('/site/site.json'));
    write('notes/draft.txt', 'Text "x"\n');
    expect(found(file: '${root.path}/notes/draft.txt'), endsWith('/site/site.json'));
    // A folder with nothing of a site is none.
    final Directory empty = Directory('${root.path}/empty')..createSync();
    expect(isSiteFolder(empty.path), isFalse);
  });

  testWidgets('expand writes the pages and a manifest a render reads the state from; again changes nothing', (tester) async {
    await tester.runAsync(() => expand.main([root.path, '--no-record', '--width', '390', '--no-reflow']));
    expect(exitCode, 0);
    expect(File('${root.path}/site/home.json').existsSync(), isTrue);
    expect(File('${root.path}/site.json').existsSync(), isFalse);
    final Map<String, Object?> built = manifest();
    expect(built['pages'], ['home.json', 'budgets.json']);
    expect(built[notationBuiltKey], {'all': true});
    expect((built['variables']! as Map)['plan'], {'type': 'text', 'value': 'pro', 'persist': true});
    expect((built['variables']! as Map).keys, ['plan', 'income', 'txns']);

    final String first = File('${root.path}/site/site.json').readAsStringSync();
    await tester.runAsync(() => expand.main([root.path, '--no-record', '--width', '390', '--no-reflow']));
    expect(exitCode, 0);
    expect(File('${root.path}/site/site.json').readAsStringSync(), first);
    // The manifest expand wrote is not the site's own: the site still has none.
    final NotationSite site = (await tester.runAsync(() => NotationSite.load('${root.path}/site/site.json')))!;
    expect(site.hasManifest, isFalse);
    expect(site.appStateIssues, isEmpty);

    final report = await runRender(tester, RenderArgs(inputs: ['${root.path}/site'], out: '${root.path}/o', sizes: const [Size(390, 400)], dumpLayout: true));
    expect(report, isNotNull);
    final List<Object?> boxes = jsonDecode(File('${root.path}/o/home@390x400.layout.json').readAsStringSync()) as List<Object?>;
    final String text = boxes.cast<Map<Object?, Object?>>().where((b) => b['id'] == 'label').map((b) => '${b['text']}').first;
    expect(text, 'pro: 2 rows, left 50');
  });

  testWidgets('a site.json of the site\'s own keeps what it says; app.txt\'s state is added and marked', (tester) async {
    write('site/site.json', jsonEncode({
      'schema': 3,
      'pages': ['budgets.json', 'home.json'],
      'theme': {'primary': '#FF0B6B3A'},
      'variables': {'locale': 'en'},
    }));
    await tester.runAsync(() => expand.main([root.path, '--no-record', '--width', '390', '--no-reflow']));
    expect(exitCode, 0);
    Map<String, Object?> built = manifest();
    expect(built['pages'], ['budgets.json', 'home.json']);
    expect(built['theme'], {'primary': '#FF0B6B3A'});
    expect((built['variables']! as Map).keys, ['locale', 'plan', 'income', 'txns']);
    expect(built[notationBuiltKey], {'variables': ['plan', 'income', 'txns']});
    // A name app.txt no longer declares leaves the manifest with the next expand; the site's own stays.
    write('app.txt', 'state plan="team"\n');
    write('pages/home.txt', 'Text#label "{plan} {locale}"\n');
    await tester.runAsync(() => expand.main([root.path, '--no-record', '--width', '390', '--no-reflow']));
    expect(exitCode, 0);
    built = manifest();
    expect(built['variables'], {'locale': 'en', 'plan': {'type': 'text', 'value': 'team'}});
    expect(built[notationBuiltKey], {'variables': ['plan']});
  });

  testWidgets('what app.txt has that is not state, and a name site.json declares too, are issues with its line', (tester) async {
    write('site/site.json', jsonEncode({'schema': 3, 'variables': {'plan': 'free'}}));
    write('app.txt', 'state plan="pro"\nstate income=100\nstate txns=[]\nstate left=0\nColumn\n');
    final NotationSite site = (await tester.runAsync(() => NotationSite.load('${root.path}/site/site.json')))!;
    expect([for (final i in site.appStateIssues) i.line], [1, 5]);
    expect(site.appStateIssues.first.message, contains('declared here and in site.json'));
    expect(site.variables['plan']!['value'], 'pro');
    await tester.runAsync(() => expand.main([root.path, '--no-record', '--width', '390', '--no-reflow']));
    expect(exitCode, 1);
  });
}
