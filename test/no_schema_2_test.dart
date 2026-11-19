// Schema 3 is the only schema: nothing under lib/ or tool/ reads an older one
// or mentions migrating one, and no document checked in here is of another.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Words of the schema-2 reading.
final _older = RegExp(
    r'''migrate2to3|migrateSchema|migratePublish|migrateJson|migrateNode|MigrationReport|kOldestSchemaVersion|schemaOf\(|schema[- ]2\b|schema2|["']schema["']\s*:\s*2\b|schema:\s*2\b|["']legacy\.|core/migrate''',
    caseSensitive: false);

Iterable<File> _files(String dir, bool Function(String) take) sync* {
  if (!Directory(dir).existsSync()) return;
  for (final f in Directory(dir).listSync(recursive: true).whereType<File>()) {
    final p = f.path.replaceAll(r'\', '/');
    if (p.contains('/build/') || p.contains('/.dart_tool/') || p.contains('/node_modules/')) continue;
    if (take(p)) yield f;
  }
}

void main() {
  test('nothing under lib/ or tool/ reads an older schema or mentions migrating one', () {
    final found = <String>[];
    for (final dir in ['lib', 'tool']) {
      for (final f in _files(dir, (p) => p.endsWith('.dart') || p.endsWith('.sh'))) {
        final p = f.path.replaceAll(r'\', '/');
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final hit = _older.hasMatch(lines[i]) || RegExp('migrat', caseSensitive: false).hasMatch(lines[i]);
          if (hit) found.add('$p:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(found, isEmpty);
  });

  test('every layout document checked in is of schema 3', () {
    final older = <String>[];
    for (final dir in ['test', 'examples', 'example', 'design_systems', 'benchmark', 'tool', 'docs']) {
      for (final f in _files(dir, (p) => p.endsWith('.json'))) {
        final Object? json;
        try {
          json = jsonDecode(f.readAsStringSync());
        } on Object {
          continue;
        }
        void walk(Object? v, String at) {
          if (v is Map) {
            final nodes = v['nodes'];
            final isDocument = v['roots'] is List && nodes is Map && nodes.values.any((n) => n is Map && n['type'] is String);
            if (isDocument && v['schema'] != 3) older.add('${f.path}$at: "schema": ${v['schema']}');
            if (v['schema'] == 2) older.add('${f.path}$at: "schema": 2');
            for (final e in v.entries) {
              walk(e.value, '$at/${e.key}');
            }
          } else if (v is List) {
            for (var i = 0; i < v.length; i++) {
              walk(v[i], '$at/$i');
            }
          }
        }

        walk(json, '');
      }
    }
    expect(older.toSet(), isEmpty);
  });
}
