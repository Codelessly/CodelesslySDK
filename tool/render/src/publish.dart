// Pages (layout documents, as the editor stores them) published into one
// bundle the SDK runs, as the editor's publish does: a page's canvases
// that share `props.screen` are one layout (one screen, a canvas per
// breakpoint); every other canvas is a layout of its own. A layout's id is
// its first canvas's id, so `navigate` may name any canvas of a screen.
import 'package:codelessly_api/codelessly_api.dart';

/// One page to publish: its name (the file it came from) and its JSON.
typedef Page = ({String name, Json json});

/// The published bundle of [pages], and each canvas's layout.
({PublishBundle bundle, Map<String, String> layoutOfCanvas, Map<String, List<String>> screens}) publishPages(
    List<Page> pages) {
  final layouts = <String, Json>{};
  final layoutOfCanvas = <String, String>{};
  final screens = <String, List<String>>{}; // layout id → its canvases
  final usedPaths = <String>{};
  Object? breakpoints;
  String? entry;
  final fonts = <String, Json>{};
  for (final page in pages) {
    final json = page.json;
    breakpoints ??= json[LayoutDocumentBreakpoints.key];
    final doc = LayoutDocument.fromJson(json);
    final rawNodes = readMap(json['nodes']) ?? const {};
    final canvases = [for (final r in doc.roots) if (doc[r]?.type == CanvasProps.spec.type) r];
    String layoutOf(String canvas) {
      final screen = doc[canvas]!.prop(CanvasProps.screen);
      if (screen.isEmpty) return canvas;
      return canvases.firstWhere((c) => doc[c]!.prop(CanvasProps.screen) == screen);
    }

    final groups = <String, List<String>>{};
    for (final c in canvases) {
      (groups[layoutOf(c)] ??= []).add(c);
      layoutOfCanvas[c] = layoutOf(c);
    }
    final variables = readMap(json['variables']) ?? const {};
    final conditions = readMap(json['conditions']) ?? const {};
    for (final g in groups.entries) {
      final id = g.key, cs = g.value;
      entry ??= id;
      screens[id] = cs;
      final nodes = <String, Object?>{
        for (final c in cs)
          for (final n in doc.subtree(c)) n.id: rawNodes[n.id],
      };
      final paths = <String, String>{};
      for (final c in cs) {
        final own = readString(readMap(rawNodes[c])?['path'])?.trim();
        final p = (own != null && own.isNotEmpty) ? own : (id == entry ? null : _slug(doc[c]!.name.isEmpty ? id : doc[c]!.name));
        if (p == null) continue;
        var candidate = p;
        for (var n = 2; usedPaths.contains(candidate) && !(paths.values.contains(candidate)); n++) {
          candidate = '$p-$n';
        }
        usedPaths.add(candidate);
        paths[c] = candidate;
      }
      final grouped = cs.length > 1 && cs.any((c) => doc[c]!.prop(CanvasProps.screen).isNotEmpty);
      final fontIds = <String>[];
      for (final f in fontsUsedBy(nodes.values)) {
        final key = '${f.family}/${f.weight}/${f.italic}';
        fonts[key] = {'family': f.family, 'weight': f.weight, if (f.italic) 'italic': true};
        fontIds.add(key);
      }
      layouts[id] = {
        'schema': kSchemaVersion,
        'id': id,
        'roots': cs,
        'nodes': nodes,
        'scripts': ?json['scripts'],
        'pageId': page.name,
        'projectId': 'render',
        if (grouped)
          'breakpoints': [
            for (final c in cs)
              CanvasBreakpoint(
                canvasId: c,
                breakpointId: doc[c]!.prop(CanvasProps.breakpoint).isEmpty ? null : doc[c]!.prop(CanvasProps.breakpoint),
                minWidth: doc[c]!.prop(CanvasProps.breakpointMinWidth),
              ).toJson(),
          ],
        if (paths.isNotEmpty) 'paths': paths,
        'variables': {
          for (final c in cs)
            if (variables[c] != null) c: variables[c],
          if (variables['page_variables'] != null) 'page_variables': variables['page_variables'],
        },
        'conditions': {
          for (final c in cs)
            if (conditions[c] != null) c: conditions[c],
        },
        if (fontIds.isNotEmpty) 'fonts': fontIds,
        'lastUpdated': 0,
      };
    }
  }
  final model = <String, Object?>{
    'schema': kPublishSchemaVersion,
    'projectId': 'render',
    'entryLayoutId': ?entry,
    'pages': [for (final p in pages) p.name],
    'layouts': {for (final e in layouts.entries) e.key: PublishLayoutInfo.of(PublishLayout.fromJson(e.value)).toJson()},
    'fonts': {
      for (final e in fonts.entries) e.key: {'id': e.key, ...e.value},
    },
    'breakpoints': ?breakpoints,
    'lastUpdated': 0,
  };
  return (
    bundle: PublishBundle.fromJson({'model': model, 'layouts': layouts}),
    layoutOfCanvas: layoutOfCanvas,
    screens: screens,
  );
}

/// The URL path of a screen named [name]: its words in lowercase joined by
/// `-` (as the editor names screens without a path of their own).
String _slug(String name) {
  final s = name.trim().toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  return s.isEmpty ? 'screen' : s;
}

/// The font families, weights and styles the text of [nodes] (node JSON)
/// names.
List<({String family, int weight, bool italic})> fontsUsedBy(Iterable<Object?> nodes) {
  final out = <String, ({String family, int weight, bool italic})>{};
  void style(Object? s) {
    final m = readMap(s);
    final family = readString(m?['fontFamily']);
    if (m == null || family == null || family.isEmpty) return;
    final weight = readInt(m['fontWeight']) ?? 400;
    final italic = m['fontStyle'] == 'italic';
    out['$family/$weight/$italic'] = (family: family, weight: weight, italic: italic);
  }

  void walk(Object? v) {
    if (v is Map) {
      for (final e in v.entries) {
        if (e.value is Map && (readMap(e.value)!.containsKey('fontFamily'))) style(e.value);
        walk(e.value);
      }
    } else if (v is List) {
      v.forEach(walk);
    }
  }

  nodes.forEach(walk);
  return [...out.values];
}
