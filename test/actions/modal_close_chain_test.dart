// What follows a close in a modal's own chain (`close; skipping=true;
// delay ms=750; skipping=false; done=true`) is the screen's under it: it ran
// in the modal's scope, which went with the modal ("The script scope was
// disposed"), so the rest never ran and the screen kept skipping=true, with
// no word on a phone (NOCD parts 19 and 21). It is handed to the chain that
// opened the modal, which runs it once the modal has closed.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_api/notation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/render/src/args.dart';
import '../../tool/render/src/render.dart';

String _page(String overlay) => '''
state skipping=false
state done=false
Column#root w=fill h=fill gap=8
  Text#shown "skipping={skipping} done={done}"
  Button#openIt "Open" onTap={open dlg}
  $overlay#dlg "Skip"
    Button#confirm "Confirm" onTap={close; skipping=true; delay ms=750; skipping=false; done=true}
''';

void main() {
  late Directory out;
  setUp(() => out = Directory.systemTemp.createTempSync('modal_close_chain_test'));
  tearDown(() => out.deleteSync(recursive: true));

  for (final overlay in ['Dialog', 'Sheet']) {
    testWidgets('$overlay: the actions after a close run in the screen under it', (tester) async {
      final r = api.Catalog.run(api.standardCatalog, () => parseNotation(_page(overlay), options: const NotationOptions(width: 390)));
      expect(r.issues, isEmpty);
      final file = File('${out.path}/m.json')..writeAsStringSync(jsonEncode(r.document));
      final report = await runRender(tester, RenderArgs(
        inputs: [file.path],
        out: '${out.path}/o',
        sizes: const [Size(390, 844)],
        steps: const [Step('tap', 'openIt'), Step('tap', 'confirm'), Step('wait', '1500')],
        dumpLayout: true,
        screens: const ['screen'],
      ));
      expect(report.errors, 0, reason: '${report.diagnostics}');
      final boxes = jsonDecode(File('${out.path}/o/screen@390x844.layout.json').readAsStringSync()) as List;
      expect(boxes.cast<Map>().firstWhere((b) => b['id'] == 'shown')['text'], 'skipping=false done=true');
    });
  }
}
