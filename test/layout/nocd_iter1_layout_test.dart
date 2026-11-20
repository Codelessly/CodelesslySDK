// Layouts the NOCD rebuild (30 parts written from the reference alone)
// found drawn wrongly, end to end from the notation: a Stack child written
// `align=center` sat at 0,0 (12 parts); a Column centered along itself with
// `mainAxisAlignment=center` stood at the left; a hugging Row with a
// `minHeight` (2 parts; held since 40.1.0, kept here); a checkbox whose
// long label was cut to one line with an ellipsis (2 parts).
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_api/notation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/render/src/args.dart';
import '../../tool/render/src/render.dart';

const _page = '''
Stack#root w=fill h=fill
  Box#box w=206 h=206 align=center fill=#FFDBEAFE
  Text#label "Share your progress" align=center
  Box#corner w=20 h=20 align=bottomRight fill=#FF2563EB
  Column#loader w=fill h=fill mainAxisAlignment=center
    Box#spinner w=40 h=40 fill=#FF2563EB
  Column#rows w=fill pad=16
    Row#cardRow w=fill minHeight=52 pad=[16,12,16,12] fill=#FFE5E7EB
      Text "One-line title"
    Checkbox#longCheck "I agree to receive transactional messages about my appointments, reminders, billing and account updates by text" w=fill
    Checkbox#shortCheck "Remember me" w=fill
''';

void main() {
  late Directory out;
  setUp(() => out = Directory.systemTemp.createTempSync('nocd_iter1_layout_test'));
  tearDown(() => out.deleteSync(recursive: true));

  testWidgets('align=center in a Stack, mainAxisAlignment=center on a full Column, minHeight on a hugging Row', (tester) async {
    final r = api.Catalog.run(api.standardCatalog, () => parseNotation(_page, options: const NotationOptions(width: 390)));
    expect(r.issues, isEmpty);
    final file = File('${out.path}/m.json')..writeAsStringSync(jsonEncode(r.document));
    final report = await runRender(tester, RenderArgs(inputs: [file.path], out: '${out.path}/o', sizes: const [Size(390, 844)], dumpLayout: true, screens: const ['screen']));
    expect(report.errors, 0, reason: '${report.diagnostics}');
    final boxes = {
      for (final b in (jsonDecode(File('${out.path}/o/screen@390x844.layout.json').readAsStringSync()) as List).cast<Map>()) '${b['id']}': b,
    };
    Map rect(String id) => boxes[id]!;
    num x(String id) => rect(id)['x'] as num;
    num y(String id) => rect(id)['y'] as num;
    num w(String id) => rect(id)['w'] as num;
    num h(String id) => rect(id)['h'] as num;

    expect([x('box'), y('box')], [92, 319]);
    expect(x('label') + w('label') / 2, closeTo(195, 1));
    expect(y('label') + h('label') / 2, closeTo(422, 1));
    expect([x('corner'), y('corner')], [370, 824]);
    expect(x('spinner'), 175);
    expect(y('spinner'), 402);
    expect(h('cardRow'), 52);
    // A long label wraps and the control grows with it; a short one stays one line.
    expect(h('longCheck'), greaterThanOrEqualTo(58));
    expect(h('shortCheck'), 20);
  });
}
