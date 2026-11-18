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

  /// The name of each canvas that has one: for an overlay site expansion made a page's own (`nav--board`), the id
  /// as written on that page (`nav`: tool/notation/site_overlays.dart).
  final Map<String, String> canvasNames = {};

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
        if (n['type'] == 'canvas' && n['name'] is String) t.canvasNames.putIfAbsent('${e.key}', () => n['name'] as String);
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
    // A word that stood in (the vocabulary record): marked with the word.
    for (final d in [...?byNode[lid], if (bid != lid) ...?byNode[bid]]) {
      if (d['code'] == 'placeholder_word') tail += '  [placeholder: ${RegExp(r'^"([^"]+)"').firstMatch('${d['message']}')?[1] ?? '?'}]';
    }
    // An overlay made the page's own: the id its page wrote, which steps may name.
    if (tree.canvasNames[bid] case final String name when kind == 'canvas' && name.isNotEmpty && bid.startsWith('$name--')) {
      tail += '  (#$name as written on page ${bid.substring(name.length + 2)}: its own, as two pages draw "$name" differently)';
    }
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

/// The diagnostics of one capture (`home@390x844`, `home@390x844-saved`...) in a render's [out] folder: those of
/// the diagnostics file whose `images` list it (else, a file of no capture, the one whose label the capture
/// ends with), at its size and of its screen (or of the screen its run started on, for a capture named after the
/// screen it navigated to). [fresh]: only the files it accepts (one invocation's: [writtenAfter]).
List<Map> captureDiagnostics(String out, String capture, {bool Function(File)? fresh}) {
  final found = <Map>[];
  final files = Directory(out).listSync().whereType<File>().where((f) {
    final n = f.uri.pathSegments.last;
    return n.startsWith('diagnostics') && n.endsWith('.json') && (fresh == null || fresh(f));
  }).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final at = capture.indexOf('@');
  final screen = at < 0 ? capture : capture.substring(0, at);
  final size = at < 0 ? '' : capture.substring(at + 1).split('-').first;
  for (final f in files) {
    Object? data;
    try {
      data = jsonDecode(f.readAsStringSync());
    } catch (_) {
      continue;
    }
    if (data is! Map) continue;
    final images = (data['images'] as List?)?.map((i) => '$i').toList() ?? const <String>[];
    if (images.isNotEmpty) {
      if (!images.contains('$capture.png')) continue;
    } else {
      final stem = f.uri.pathSegments.last.replaceFirst(RegExp(r'\.json$'), '');
      final label = stem.startsWith('diagnostics-') ? stem.substring('diagnostics-'.length) : null;
      if (label != null && !capture.endsWith('-$label') && !capture.contains('-$label')) continue;
    }
    final started = (data['startedOn'] as Map?)?['$capture.png'];
    for (final d in (data['diagnostics'] as List? ?? const []).cast<Map>()) {
      if (d['size'] != null && d['size'] != size) continue;
      if (d['screen'] != null && !screen.startsWith('${d['screen']}') && d['screen'] != started) continue;
      found.add(d);
    }
  }
  return found;
}

/// The files in [out] and when each was last written: what a run found there, to tell afterwards which files it
/// wrote ([writtenAfter]).
Map<String, DateTime> snapshotOf(String out) => {
      if (Directory(out).existsSync())
        for (final f in Directory(out).listSync().whereType<File>()) f.path: f.lastModifiedSync(),
    };

/// Whether a file is one written after [snapshot] was taken: new, or written again since. (Not by the clock: a run
/// that ended a moment before another began wrote in the same second.)
bool Function(File) writtenAfter(Map<String, DateTime> snapshot) => (f) {
      final before = snapshot[f.path];
      return before == null || f.lastModifiedSync() != before;
    };

/// The name of the capture a `*.layout.json` file is for.
String captureOf(String layoutFile) {
  final n = layoutFile.replaceAll(r'\', '/').split('/').last;
  return n.endsWith('.png.layout.json') ? n.substring(0, n.length - '.png.layout.json'.length) : n.replaceFirst('.layout.json', '');
}

/// The `*.layout.json` files in [out]; with [fresh], only those it accepts (one invocation's, not those earlier
/// runs left in the folder: [writtenAfter]).
List<File> layoutFiles(String out, {bool Function(File)? fresh}) => (Directory(out).existsSync() ? Directory(out).listSync() : <FileSystemEntity>[])
    .whereType<File>()
    .where((f) => f.path.endsWith('.layout.json') && (fresh == null || fresh(f)))
    .toList()
  ..sort((a, b) => a.path.compareTo(b.path));

/// Every capture's outline in [out], as text (or JSON).
/// [fresh]: only the captures it accepts (`tool/codelessly render --outline`: that invocation's, [writtenAfter]).
String outlineText(String out, List<String> documents, {List<String> only = const [], int? depth, bool json = false, bool Function(File)? fresh}) {
  final tree = DocumentTree.load(documents);
  final result = <String, List<String>>{};
  final text = StringBuffer();
  for (final f in layoutFiles(out, fresh: fresh)) {
    final capture = captureOf(f.path);
    if (only.isNotEmpty && !only.any(capture.contains)) continue;
    final entries = jsonDecode(f.readAsStringSync()) as List;
    final diags = captureDiagnostics(out, capture, fresh: fresh);
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
