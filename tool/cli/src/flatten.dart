// Nested node trees to a flat layout document (schema 3), the form the validator and the renderer read.
//
//   tool/codelessly flatten <tree.json | -> [--out doc.json] [--size 390x844] [--screen name] [--keys-out keys.json]
//
// Writing a screen as one nested tree is how a model (and the editor's `layouts.*` and `nodes.insertTree`
// commands) naturally writes it; a layout document keeps every node in one flat `nodes` map. This turns one into
// the other, so a tree written for the editor renders headless with `tool/codelessly render` first.
//
// The input is any of:
//
// * a node tree: `{"type": "column", "children": [{"type": "text", ...}, ...]}`; a root that is not a `canvas` is
//   put in the `body` slot of one (`--size` gives its size, `--screen` its id);
// * trees per breakpoint, as `layouts.createResponsive` takes them: `{"trees": {"mobile": tree, "tablet": tree,
//   "desktop": tree}}` (optionally with `variables`, `conditions`, `scripts`, `canvasActions`): one canvas per
//   breakpoint, all one screen (`props.screen`, `props.breakpoint`);
// * a document whose nodes nest some children instead of naming their ids: those children are lifted out.
//
// In a tree, a node's `key` (or `id`) names it: that becomes its id, and any string `"@key"` anywhere in the tree
// (an action's target, a states patch, a variable's node) becomes that id, as the editor does. Each breakpoint's
// tree is one scope (the trees reuse keys). Nodes without one get `<type><n>` ids. `children` lists and `slots`
// maps may hold node objects or ids. `--keys-out` writes each breakpoint's {key: id}, as the editor answers.
import 'dart:convert';
import 'dart:io';

import 'common.dart';

const breakpointSizes = {'mobile': (390, 844), 'tablet': (834, 1112), 'desktop': (1440, 900)};

class _Flattener {
  _Flattener([Iterable<String> taken = const []]) : taken = {...taken};

  Map<String, Map<String, Object?>> nodes = {};
  final Set<String> taken;
  final Map<String, int> counts = {};
  Map<String, String> keys = {};

  String fresh(String base) {
    base = base.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    if (base.isEmpty) base = 'node';
    if (!taken.contains(base) && !nodes.containsKey(base)) return base;
    var n = counts[base] ?? 1;
    while (taken.contains('$base$n') || nodes.containsKey('$base$n')) {
      n++;
    }
    counts[base] = n + 1;
    return '$base$n';
  }

  Object? _child(Object? c) => c is Map ? add(c.cast<String, Object?>()) : c;

  String add(Map<String, Object?> tree, {String? prefer}) {
    final n = Map<String, Object?>.of(tree);
    final key = n.remove('key');
    final explicit = n.remove('id');
    final nid = fresh('${explicit ?? key ?? prefer ?? n['type'] ?? 'node'}');
    if (key != null) keys['$key'] = nid;
    if (explicit != null && '$explicit' != nid) keys['$explicit'] = nid;
    nodes[nid] = n; // before its children: the document lists parents first
    if (n['children'] case final List children) n['children'] = [for (final c in children) _child(c)];
    if (n['slots'] case final Map slots) n['slots'] = {for (final e in slots.entries) e.key: _child(e.value)};
    if (n['props'] case {'variants': final List variants}) {
      for (final v in variants) {
        if (v case final Map vm when vm['children'] is List) {
          vm['children'] = [for (final c in vm['children'] as List) _child(c)];
        }
      }
    }
    return nid;
  }

  /// `"@key"` strings (and keys of maps, as states patches name nodes) become ids.
  Object? resolve(Object? value) => switch (value) {
        final String s => s.startsWith('@') && keys.containsKey(s.substring(1)) ? keys[s.substring(1)] : s,
        final List l => [for (final v in l) resolve(v)],
        final Map m => {for (final e in m.entries) (e.key is String ? resolve(e.key) : e.key) as Object: resolve(e.value)},
        _ => value,
      };
}

bool _isNodeTree(Object? x) => x is Map && x['type'] is String && !x.containsKey('nodes');

Map<String, Object?> _canvas(String rootId, String name, (int, int)? size, {String? screen, String? breakpoint, Object? actions}) => {
      'type': 'canvas',
      'name': name,
      'slots': {'body': rootId},
      if (size != null) 'layout': {'width': size.$1, 'height': size.$2},
      if (screen != null && breakpoint != null) 'props': {'screen': screen, 'breakpoint': breakpoint},
      if (actions != null) 'actions': actions,
    };

/// The flat document for [data]. With trees per breakpoint, [keysOut] gets each breakpoint's {key: node id}.
Map<String, Object?> flatten(Object? data, {(int, int)? size, String? screen, Map<String, Map<String, String>>? keysOut}) {
  // A document: lift nested children out of its nodes.
  if (data is Map && data['nodes'] is Map && !data.containsKey('type')) {
    final doc = Map<String, Object?>.of(data.cast<String, Object?>());
    final nodesIn = (data['nodes'] as Map).cast<String, Object?>();
    final f = _Flattener(nodesIn.keys);
    final out = <String, Object?>{};
    for (final e in nodesIn.entries) {
      if (e.value is! Map) {
        out[e.key] = e.value;
        continue;
      }
      f.nodes = {};
      final n = Map<String, Object?>.of((e.value as Map).cast<String, Object?>());
      if (n['children'] case final List children) n['children'] = [for (final c in children) f._child(c)];
      if (n['slots'] case final Map slots) n['slots'] = {for (final s in slots.entries) s.key: f._child(s.value)};
      out[e.key] = n;
      out.addAll(f.nodes);
      f.taken.addAll(f.nodes.keys);
    }
    doc['nodes'] = f.resolve(out);
    for (final k in const ['variables', 'conditions', 'scripts']) {
      if (doc.containsKey(k)) doc[k] = f.resolve(doc[k]);
    }
    doc.putIfAbsent('schema', () => 3);
    return doc;
  }

  final f = _Flattener();
  final roots = <String>[];
  final extra = <String, Object?>{};
  if (data is Map && data['trees'] is Map) {
    final name = screen ?? (data['screen'] ?? data['name'] ?? 'screen') as String;
    for (final e in (data['trees'] as Map).entries) {
      final bp = '${e.key}';
      // Each breakpoint's tree is one scope, as the editor reads it: its "@key" names a node of that tree.
      f.keys = {};
      final before = f.nodes.keys.toSet();
      final body = f.add((e.value as Map).cast<String, Object?>(), prefer: '${bp}_root');
      for (final nid in f.nodes.keys.where((k) => !before.contains(k)).toList()) {
        f.nodes[nid] = (f.resolve(f.nodes[nid]) as Map).cast<String, Object?>();
      }
      keysOut?[bp] = Map.of(f.keys);
      final cid = f.fresh('${name}_$bp');
      f.nodes[cid] = _canvas(body, name, breakpointSizes[bp] ?? size,
          screen: name, breakpoint: bp, actions: data['canvasActions']);
      roots.add(cid);
    }
    for (final k in const ['variables', 'conditions', 'scripts', 'breakpoints']) {
      if (data.containsKey(k)) extra[k] = data[k];
    }
  } else if (_isNodeTree(data)) {
    final tree = (data as Map).cast<String, Object?>();
    if (tree['type'] == 'canvas') {
      roots.add(f.add(tree, prefer: screen ?? 'screen'));
    } else {
      final body = f.add(tree);
      final cid = f.fresh(screen ?? 'screen');
      f.nodes[cid] = _canvas(body, cid, size);
      roots.add(cid);
    }
  } else {
    throw const UsageError('Not a node tree, {"trees": {...}} or a document: see tool/codelessly flatten --help.');
  }
  // Canvases first, as documents list them.
  final ordered = <String, Object?>{for (final r in roots) r: f.nodes[r], ...f.nodes};
  final doc = <String, Object?>{'schema': 3, 'roots': roots, 'nodes': f.resolve(ordered)};
  if (extra['variables'] is List) extra['variables'] = {'page_variables': extra['variables']};
  doc.addAll((f.resolve(extra) as Map).cast<String, Object?>());
  return doc;
}

Future<int> flattenMain(List<String> argv) async {
  final a = Args(argv, valued: {'--out', '--size', '--screen', '--keys-out'});
  if (a.help || a.positional.isEmpty) return usage(_doc);
  final input = a.positional.first;
  final text = input == '-' ? await stdin.transform(utf8.decoder).join() : File(input).readAsStringSync();
  final size = parseSize(a['--size'] ?? '390x844');
  final keys = <String, Map<String, String>>{};
  final doc = flatten(jsonDecode(text), size: size, screen: a['--screen'], keysOut: keys);
  final json = const JsonEncoder.withIndent(' ').convert(doc);
  if (a['--keys-out'] case final String k) File(k).writeAsStringSync(jsonEncode(keys));
  if (a['--out'] case final String out) {
    File(out).writeAsStringSync('$json\n');
    stderr.writeln('wrote $out: ${(doc['nodes'] as Map).length} nodes, roots ${(doc['roots'] as List).join(', ')}');
  } else {
    stdout.writeln(json);
  }
  return 0;
}

const _doc = '''tool/codelessly flatten <tree.json | -> [--out doc.json] [--size 390x844] [--screen name] [--keys-out keys.json]

Nested node trees (one tree, trees per breakpoint {"trees": {...}}, or a document with nested children) to a flat
layout document. A node's "key" names it; "@key" elsewhere in its tree becomes its id. --keys-out writes each
breakpoint's {key: id}, as the editor's layouts.createResponsive answers.''';
