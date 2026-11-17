// Expands recorded notation answers again with the current parser: for each
// `<cell>.notation[.retryN].jsonl` in a folder, the last turn's text becomes
// `<out>/<cell>.json`, and a line says what the parser could not read. No model is called.
//
//   dart run tool/reexpand_notation.dart <recordings dir> <out dir>
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_api/notation.dart';

void main(List<String> args) {
  final dir = Directory(args[0]), out = Directory(args[1])..createSync(recursive: true);
  final last = <String, File>{};
  for (final f in dir.listSync().whereType<File>().where((f) => f.path.endsWith('.jsonl')).toList()..sort((a, b) => a.path.compareTo(b.path))) {
    final name = f.uri.pathSegments.last;
    last[name.split('.notation').first] = f;
  }
  var ok = 0;
  for (final e in last.entries) {
    final meta = (jsonDecode(e.value.readAsLinesSync().first) as Map)['meta'] as Map;
    final r = Catalog.run(standardCatalog, () => parseNotation(meta['text'] as String, catalog: standardCatalog));
    File('${out.path}/${e.key}.json').writeAsStringSync(jsonEncode(r.document));
    final clean = r.issues.isEmpty;
    if (clean) ok++;
    stdout.writeln('${clean ? 'ok ' : 'ERR'} ${e.key}${clean ? '' : '  ${r.issues.take(2).join(' | ')}'}');
  }
  stdout.writeln('$ok of ${last.length} clean');
}
