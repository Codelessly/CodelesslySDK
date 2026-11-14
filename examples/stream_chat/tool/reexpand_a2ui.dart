// Expands recorded A2UI answers again with the current parser: for each
// `<cell>.a2ui[.retryN].jsonl` in a folder, the last turn's text becomes
// `<out>/<cell>.json`, and a line says how it validates. No model is called.
//
//   dart run tool/reexpand_a2ui.dart <recordings dir> <out dir>
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_api/notation.dart';
import 'package:codelessly_api/validate.dart';

void main(List<String> args) {
  final dir = Directory(args[0]), out = Directory(args[1])..createSync(recursive: true);
  final last = <String, File>{};
  for (final f in dir.listSync().whereType<File>().where((f) => f.path.endsWith('.jsonl')).toList()..sort((a, b) => a.path.compareTo(b.path))) {
    final name = f.uri.pathSegments.last;
    last[name.split('.a2ui').first] = f;
  }
  var ok = 0;
  for (final e in last.entries) {
    final meta = (jsonDecode(e.value.readAsLinesSync().first) as Map)['meta'] as Map;
    final r = Catalog.run(standardCatalog, () => parseA2ui(meta['text'] as String, catalog: standardCatalog));
    final errors = Catalog.run(standardCatalog, () => validateDocument(r.document)).where((d) => d.severity == Severity.error).toList();
    File('${out.path}/${e.key}.json').writeAsStringSync(jsonEncode(r.document));
    final clean = r.issues.isEmpty && errors.isEmpty;
    if (clean) ok++;
    stdout.writeln('${clean ? 'ok ' : 'ERR'} ${e.key}${clean ? '' : '  ${[...r.issues.take(2), ...errors.take(2).map((d) => '${d.code.name} ${d.path}')].join(' | ')}'}');
  }
  stdout.writeln('$ok of ${last.length} clean');
}
