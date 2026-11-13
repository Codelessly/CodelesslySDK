// The JSON documents in this repository (test fixtures, benchmark bundles)
// decode and encode byte for byte as they did before catalogs existed
// (codelessly_api without the catalog work, at the base it merged onto): each line of fixtures/catalog_corpus.digests is
// `file#pointer kind digest`, the digest of a value's encoding after a decode
// (tool/corpus_roundtrip.dart in codelessly_api makes the same lines).
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter_test/flutter_test.dart';

String _digest(Object? json) {
  final s = jsonEncode(json);
  var h = 0xcbf29ce484222325;
  for (final c in utf8.encode(s)) {
    h ^= c;
    h = (h * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
  }
  return '${h.toUnsigned(64).toRadixString(16)}:${s.length}';
}

/// Schema-2 reaction [r] migrated (as a box's reaction).
Json _migrated(Map r) =>
    readMap((migrateNode2to3({'type': 'box', 'actions': [r]})['actions'] as List).single)!;

/// What a file's documents, nodes, reactions and actions encode to, as the
/// digest lines.
List<String> _lines(String path, Catalog catalog) {
  final out = <String>[];
  void walk(Object? v, String at) {
    if (v is Map) {
      final nodes = v['nodes'];
      if (nodes is Map && nodes.values.any((n) => n is Map && n['type'] is String)) {
        // The digests were taken in schema 2: a document now encodes as
        // schema 3, and (migrated when it decodes) otherwise the same.
        final doc = LayoutDocument.fromJson(v, catalog: catalog).toJson();
        if (doc['schema'] == kSchemaVersion) doc['schema'] = 2;
        // Schema 2's line height, which the migration writes on the
        // top-level nodes (step text.lineHeight), is what it drew anyway.
        for (final e in (doc['nodes'] as Map).entries) {
          final n = e.value as Map;
          if (jsonEncode(n['defaultTextStyle']) == '{"height":1.33}' && (nodes[e.key] as Map?)?['defaultTextStyle'] == null) {
            n.remove('defaultTextStyle');
          }
        }
        out.add('$path#$at doc ${_digest(doc)}');
      }
      // A node, reaction or action alone is schema 2 too: migrated first.
      if (v['type'] is String && v['layout'] is Map) {
        out.add('$path#$at node ${_digest(Node.fromJson(migrateNode2to3(readMap(v)!), catalog: catalog)?.toJson())}');
      }
      final acts = v['actions'];
      if (acts is List) {
        for (var i = 0; i < acts.length; i++) {
          final a = acts[i];
          if (a is Map && a['trigger'] != null) {
            out.add('$path#$at/actions/$i reaction ${_digest(Reaction.fromJson(_migrated(a), catalog: catalog)?.toJson())}');
          } else if (a is Map && a['type'] is String) {
            final r = _migrated({'trigger': {'type': 'click'}, 'actions': [a]});
            out.add('$path#$at/actions/$i action ${_digest(ActionDef.fromJson((r['actions'] as List).single, catalog: catalog)?.toJson())}');
          }
        }
      }
      for (final e in v.entries) {
        walk(e.value, '$at/${e.key}');
      }
    } else if (v is List) {
      for (var i = 0; i < v.length; i++) {
        walk(v[i], '$at/$i');
      }
    } else if (v is String && v.length > 20 && v.trimLeft().startsWith('{') && v.contains('"nodes"')) {
      try {
        walk(jsonDecode(v), '$at(text)');
      } catch (_) {}
    }
  }

  walk(jsonDecode(File(path).readAsStringSync()), '');
  return out;
}

void main() {
  test('every document in the repository encodes as it did before catalogs', () {
    final expected = File('test/fixtures/catalog_corpus.digests').readAsLinesSync().where((l) => l.isNotEmpty).toList();
    final files = {for (final l in expected) l.substring(0, l.indexOf('#'))};
    expect(files.length, greaterThanOrEqualTo(10));
    final actual = [for (final f in files) ..._lines(f, standardCatalog)];
    expect(actual.length, expected.length);
    final mismatched = [
      for (var i = 0; i < actual.length; i++)
        if (actual[i] != expected[i]) actual[i],
    ];
    expect(mismatched, isEmpty);
  });
}
