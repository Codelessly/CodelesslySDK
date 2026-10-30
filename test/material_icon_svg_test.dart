import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the SDK builds no IconData at runtime, so release web builds can tree-shake icons', () {
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final l = lines[i].trim();
        if (l.startsWith('//')) continue;
        if (RegExp(r'(?<!const )\bIconData\(').hasMatch(l) && !l.contains('const IconData')) {
          offenders.add('${f.path}:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty);
  });

  test('a Material icon with a codepoint is drawn from its SVG by name', () {
    const MaterialIcon icon = MaterialIcon(codepoint: 0xe8b6, name: 'search', style: MaterialIconStyle.filled, version: 12);
    expect(icon.toSvgUrl(), 'https://fonts.gstatic.com/s/i/materialicons/search/v12/24px.svg');
  });
}
