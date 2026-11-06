// Writes catalog/codelessly_genui_catalog.json, the catalog document agents
// are prompted with. Run: dart run tool/generate_catalog.dart
// (test/catalog_test.dart fails when the file is out of date.)
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_genui/src/catalog/catalog_spec.dart';

void main() {
  File('catalog/codelessly_genui_catalog.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(buildGenUiCatalogJson())}\n',
  );
  stdout.writeln('Wrote catalog/codelessly_genui_catalog.json');
}
