// What a render drew, as text: every node's type, id, box and text, indented as the tree, with the render's
// problems next to the node they are about.
//
//   tool/codelessly outline <render out dir> <document.json | site dir>... [--capture name] [--depth n] [--json]
//   tool/codelessly render <documents> --out <dir> --outline       (the same, right after rendering)
//
// A PNG answers "does it look right"; this answers "where is everything and why": the box each node got
// (`x,y wxh`), the text it shows, nodes that drew nothing (`empty`), and the warnings (`!`) and errors (`x`) of
// `diagnostics*.json` tied to their node. It reads the `*.layout.json` files the render command writes with
// `--dump-layout` and the documents for the tree and the types.
import 'dart:convert';
import 'dart:io';

import 'common.dart';

/// Every node's type and parent over the documents named (pages, components, a site's folder).
class DocumentTree {
  final Map<String, String> types = {};
  final Map<String, String> parents = {};

  static DocumentTree load(List<String> paths) {
    final t = DocumentTree();
    final files = <File>[];
    for (final p in paths) {
      if (FileSystemEntity.isDirectorySync(p)) {
        final root = Directory(p).absolute.path;
        for (final f in Directory(p).listSync(recursive: true).whereType<File>()) {
          final rel = f.absolute.path.substring(root.length + 1);
          final name = f.uri.pathSegments.last;
          if (!name.endsWith('.json') || name.startsWith('_') || name.startsWith('diagnostics') || name.contains('.layout')) continue;
          if (rel.split('/').any((s) => s.startsWith('.'))) continue;
          files.add(f);
        }
      } else if (p.endsWith('.json') && File(p).existsSync()) {
        files.add(File(p));
      }
    }
    files.sort((a, b) => a.path.compareTo(b.path));
    for (final f in files) {
      Object? doc;
      try {
        doc = jsonDecode(f.readAsStringSync());
      } catch (_) {
        continue;
      }
      if (doc is! Map || doc['nodes'] is! Map) continue;
      for (final e in (doc['nodes'] as Map).entries) {
        final n = e.value;
        if (n is! Map) continue;
        t.types.putIfAbsent('${e.key}', () => '${n['type'] ?? '?'}');
        final kids = [
          ...?(n['children'] as List?),
          ...?(n['slots'] as Map?)?.values,
          if (n['props'] case {'variants': final List vs})
            for (final v in vs)
              if (v is Map) ...?(v['children'] as List?),
        ];
        for (final k in kids) {
          if (k is String) t.parents.putIfAbsent(k, () => '${e.key}');
        }
      }
    }
    return t;
  }
}

/// `call/inner#2` -> `inner`: the id inside its own document.
String baseId(String layoutId) => layoutId.split('/').last.replaceFirst(RegExp(r'#\d+$'), '');

bool _contains(Map a, Map b, [double slack = 0.5]) {
  num v(Map m, String k) => m[k] as num;
  return v(a, 'x') - slack <= v(b, 'x') &&
      v(a, 'y') - slack <= v(b, 'y') &&
      v(b, 'x') + v(b, 'w') <= v(a, 'x') + v(a, 'w') + slack &&
      v(b, 'y') + v(b, 'h') <= v(a, 'y') + v(a, 'h') + slack;
}

String _fmt(num v) => v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);

String _pad(String s, int width) => s.length >= width ? s : s + ' ' * (width - s.length);

/// One capture's outline lines from its layout dump [entries] and its diagnostics [diags].
List<String> outlineCapture(List entries, DocumentTree tree, List<Map> diags, {int? maxDepth}) {
  final byNode = <String, List<Map>>{};
  for (final d in diags) {
    if (d['nodeId'] case final String id when id.isNotEmpty) (byNode[id] ??= []).add(d);
  }
  final shown = <String>{};
  final stack = <Map>[];
  final lines = <String>[];
  for (final e in entries.cast<Map>()) {
    final lid = '${e['id']}';
    final bid = baseId(lid);
    final docParent = tree.parents[bid];
    // The parent on screen: the nearest open entry that is this node's parent in the document, else the nearest
    // that contains its box (component instances, list copies).
    final parentOpen = docParent != null && stack.any((s) => baseId('${s['id']}') == docParent);
    while (stack.isNotEmpty) {
      final top = stack.last;
      if (parentOpen ? baseId('${top['id']}') == docParent : _contains(top, e)) break;
      stack.removeLast();
    }
    final depth = stack.length;
    stack.add(e);
    if (maxDepth != null && depth > maxDepth) continue;
    final kind = tree.types[bid] ?? '?';
    final box = '${_fmt(e['x'] as num)},${_fmt(e['y'] as num)} ${_fmt(e['w'] as num)}x${_fmt(e['h'] as num)}';
    var tail = '';
    if (e['text'] != null) {
      final t = '${e['text']}'.replaceAll('\n', r'\n');
      tail = '  "${t.length > 70 ? '${t.substring(0, 70)}...' : t}"';
    }
    if (e['w'] == 0 || e['h'] == 0) tail += '  (empty: draws nothing)';
    lines.add('${_pad('${'  ' * depth}$kind $lid', 44)} ${_pad(box, 22)}$tail'.trimRight());
    for (final key in {lid, bid}) {
      if (byNode.containsKey(key) && shown.add(key)) {
        for (final d in byNode[key]!) {
          final msg = '${d['message'] ?? ''}'.replaceAll('\n', ' ');
          lines.add('${'  ' * (depth + 1)}${d['severity'] == 'error' ? 'x' : '!'} ${d['code']}: ${msg.length > 400 ? msg.substring(0, 400) : msg}');
        }
      }
    }
  }
  // Problems of nodes this capture did not draw. Problems without a size, of nodes not on this capture at all
  // (another breakpoint's canvas), belong to the capture that draws them.
  for (final e in byNode.entries) {
    if (shown.contains(e.key)) continue;
    for (final d in e.value) {
      if (d['size'] == null) continue;
      final msg = '${d['message'] ?? ''}';
      lines.add('${d['severity'] == 'error' ? 'x' : '!'} ${d['code']} (node ${d['nodeId']}, not drawn): '
          '${msg.length > 400 ? msg.substring(0, 400) : msg}');
    }
  }
  return lines;
}

/// The diagnostics of one capture (`home@390x844`, `home@390x844-saved`...) in a render's [out] folder.
List<Map> captureDiagnostics(String out, String capture) {
  final found = <Map>[];
  final files = Directory(out).listSync().whereType<File>().where((f) {
    final n = f.uri.pathSegments.last;
    return n.startsWith('diagnostics') && n.endsWith('.json');
  }).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final at = capture.indexOf('@');
  final screen = at < 0 ? capture : capture.substring(0, at);
  final size = at < 0 ? '' : capture.substring(at + 1).split('-').first;
  for (final f in files) {
    final stem = f.uri.pathSegments.last.replaceFirst(RegExp(r'\.json$'), '');
    final label = stem.startsWith('diagnostics-') ? stem.substring('diagnostics-'.length) : null;
    if (label != null && !capture.endsWith('-$label') && !capture.contains('-$label')) continue;
    Object? data;
    try {
      data = jsonDecode(f.readAsStringSync());
    } catch (_) {
      continue;
    }
    for (final d in ((data as Map?)?['diagnostics'] as List? ?? const []).cast<Map>()) {
      if (d['size'] != null && d['size'] != size) continue;
      if (d['screen'] != null && !screen.startsWith('${d['screen']}')) continue;
      found.add(d);
    }
  }
  return found;
}

/// The name of the capture a `*.layout.json` file is for.
String captureOf(String layoutFile) {
  final n = layoutFile.split('/').last;
  return n.endsWith('.png.layout.json') ? n.substring(0, n.length - '.png.layout.json'.length) : n.replaceFirst('.layout.json', '');
}

List<File> layoutFiles(String out) => (Directory(out).existsSync() ? Directory(out).listSync() : <FileSystemEntity>[])
    .whereType<File>()
    .where((f) => f.path.endsWith('.layout.json'))
    .toList()
  ..sort((a, b) => a.path.compareTo(b.path));

/// Every capture's outline in [out], as text (or JSON).
String outlineText(String out, List<String> documents, {List<String> only = const [], int? depth, bool json = false}) {
  final tree = DocumentTree.load(documents);
  final result = <String, List<String>>{};
  final text = StringBuffer();
  for (final f in layoutFiles(out)) {
    final capture = captureOf(f.path);
    if (only.isNotEmpty && !only.any(capture.contains)) continue;
    final entries = jsonDecode(f.readAsStringSync()) as List;
    final diags = captureDiagnostics(out, capture);
    final lines = outlineCapture(entries, tree, diags, maxDepth: depth);
    result[capture] = lines;
    final errors = diags.where((d) => d['severity'] == 'error').length;
    text
      ..writeln('== $capture  (${entries.length} nodes, $errors errors, ${diags.length - errors} warnings)')
      ..writeln(lines.join('\n'))
      ..writeln();
  }
  return json ? prettyJson(result) : text.toString();
}

Future<int> outlineMain(List<String> argv) async {
  final a = Args(argv, valued: {'--capture', '--depth'});
  if (a.help || a.positional.isEmpty) return usage(_doc, asked: a.help);
  final out = a.positional.first;
  if (layoutFiles(out).isEmpty) {
    stderr.writeln('No *.layout.json in $out: render with --dump-layout (or tool/codelessly render ... --outline).');
    return 2;
  }
  stdout.write(outlineText(out, a.positional.sublist(1),
      only: a.all('--capture'), depth: a['--depth'] == null ? null : int.parse(a['--depth']!), json: a.has('--json')));
  return 0;
}

const _doc = '''tool/codelessly outline <render out dir> <document.json | site dir>... [--capture name] [--depth n] [--json]

What a render drew, as text: each node's type, id, box (x,y wxh) and text, indented as the tree, with its problems
(! warning, x error) under it; nodes that drew nothing are marked. Reads the *.layout.json files a render writes
with --dump-layout (tool/codelessly render --outline passes it) and the documents for the tree and the types.''';
