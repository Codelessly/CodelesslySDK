// What the render command does to documents before publishing them, so
// they render offline in a test environment as they would in an app:
//
// * images given as paths relative to the document (`assets/hero.jpg`)
//   become data: URLs of the files (an app would load uploaded URLs);
// * text styles that name no font family get the default family (an app
//   draws them in the platform's font, Roboto on Android and the web; the
//   test environment's own fallback draws boxes);
// * Material icons named without a codepoint get the MaterialIcons font's
//   (an app fetches the icon's SVG; offline the SDK draws the font glyph).
//
// It also lists the images: which failed and which are on the network.
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart';

/// An image a document refers to, and what became of it.
typedef ImageRef = ({String nodeId, String path, String url, String status, String? detail});

final class Prepared {
  Prepared(this.json, this.images);
  final Json json;
  final List<ImageRef> images;
}

const _imageExtensions = {
  '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.gif': 'image/gif', '.webp': 'image/webp', //
  '.svg': 'image/svg+xml', '.bmp': 'image/bmp',
};

String? _mimeOf(String path) {
  final lower = path.toLowerCase();
  for (final e in _imageExtensions.entries) {
    if (lower.endsWith(e.key)) return e.value;
  }
  return null;
}

/// [doc] (a page's JSON) prepared to render: see the file comment. [dir] is
/// the document's directory; [codepoints] the MaterialIcons codepoints.
///
/// In a site, [dir] is the site's folder (image paths start there, as a
/// published site reads them) and [docDir] the document's own: a path that
/// names a file only from there is reported with the path to write.
Prepared prepare(Json doc, {required String dir, String? docDir, required String defaultFamily, required Map<String, int> codepoints}) {
  final images = <ImageRef>[];
  final nodes = readMap(doc['nodes']) ?? const {};
  final out = <String, Object?>{};
  for (final e in nodes.entries) {
    final raw = readMap(e.value);
    if (raw == null) {
      out[e.key] = e.value;
      continue;
    }
    final spec = Widgets.of(readString(raw['type']) ?? '');
    String at = '/nodes/${e.key}';
    Object? strings(Object? v, String path) {
      if (v is String) return _image(v, path, e.key, dir, images, docDir: docDir);
      if (v is List) return [for (var i = 0; i < v.length; i++) strings(v[i], '$path/$i')];
      if (v is Map) return {for (final x in v.entries) '${x.key}': strings(x.value, '$path/${x.key}')};
      return v;
    }

    var node = strings(raw, at) as Json;
    // Typed walk of props: text styles and icons.
    final props = readMap(node['props']);
    if (props != null && spec != null) {
      node = {
        ...node,
        'props': {
          for (final p in props.entries)
            p.key: spec.prop(p.key) == null ? p.value : _typed(spec.prop(p.key)!.type, p.value, defaultFamily, codepoints),
        },
      };
      // Material widgets draw an unstyled label without a family: give
      // their style one (a ButtonStyle's textStyle, a TextStyle prop).
      _labelStyles(spec, node['props'] as Json, defaultFamily);
      // A text node with no style still gets the default family.
      if (spec.type == TextProps.spec.type && readMap(node['props'])!['style'] == null) {
        (node['props'] as Json)['style'] = {'fontFamily': defaultFamily};
      }
    } else if (spec?.type == TextProps.spec.type) {
      node = {...node, 'props': {'style': {'fontFamily': defaultFamily}}};
    } else if (spec != null) {
      final props = <String, Object?>{};
      _labelStyles(spec, props, defaultFamily);
      if (props.isNotEmpty) node = {...node, 'props': props};
    }
    out[e.key] = node;
  }
  return Prepared({...doc, 'nodes': out}, images);
}

/// Props of [spec] that style a Material widget's label, added to [props]
/// with the default family when absent.
void _labelStyles(WidgetSpec spec, Json props, String family) {
  for (final def in spec.props) {
    if (props.containsKey(def.key)) continue;
    if (def.type.name == 'ButtonStyle') {
      props[def.key] = {'textStyle': {'fontFamily': family}};
    } else if (def.type.name == 'TextStyle' && spec.type != TextProps.spec.type && def.key != 'style') {
      props[def.key] = {'fontFamily': family};
    } else if (def.key.endsWith('FontFamily') && def.type.kind == PropKind.string) {
      // A chart's axis labels, a gauge's label: a family of their own.
      props[def.key] = family;
    }
  }
}

/// [json] of [type] with default families and icon codepoints filled in.
Object? _typed(PropType type, Object? json, String family, Map<String, int> codepoints) {
  if (json == null) return null;
  switch (type.kind) {
    case PropKind.object when type.name == 'TextRun':
      return json; // a run's style is merged over the text's: no family of its own
    case PropKind.object:
      final m = readMap(json);
      if (m == null) return json;
      final fields = {for (final f in type.fields) f.key: f};
      final next = {
        for (final e in m.entries) e.key: fields[e.key] == null ? e.value : _typed(fields[e.key]!.type, e.value, family, codepoints),
      };
      // A style starting from a named one takes its family from there (the
      // theme's styles get the default: [prepareTheme]).
      if (type.name == 'TextStyle' && next['fontFamily'] == null && next['from'] == null) next['fontFamily'] = family;
      if (type.name == 'ButtonStyle' && readMap(next['textStyle']) == null) next['textStyle'] = {'fontFamily': family};
      return next;
    case PropKind.list:
      return json is List ? [for (final v in json) _typed(type.item!, v, family, codepoints)] : json;
    case PropKind.value when type.name == 'IconData':
      final icon = json is String ? materialIconNamed(json) : readMap(json);
      if (icon == null || icon['type'] != 'MATERIAL_ICON' || icon['codepoint'] != null) return json;
      final style = readString(icon['style']) ?? 'filled';
      final name = readString(icon['name']) ?? '';
      // Flutter's codepoints name the filled style `_baseline`.
      final cp = codepoints[style == 'filled' ? '${name}_baseline' : '${name}_$style'] ?? codepoints[name];
      return cp == null ? json : {...icon, 'codepoint': cp};
    default:
      return json;
  }
}

/// [text] with a local image path made a data: URL; records every image.
String _image(String text, String path, String nodeId, String dir, List<ImageRef> images, {String? docDir}) {
  final t = text.trim();
  if (t.startsWith('http://') || t.startsWith('https://')) {
    if (_mimeOf(Uri.tryParse(t)?.path ?? '') != null || path.contains('/image')) {
      images.add((nodeId: nodeId, path: path, url: t, status: 'network', detail: null));
    }
    return text;
  }
  if (t.startsWith('data:')) {
    if (!t.startsWith('data:image/')) return text;
    try {
      UriData.parse(t).contentAsBytes();
      images.add((nodeId: nodeId, path: path, url: '${t.substring(0, t.length.clamp(0, 40))}...', status: 'inline', detail: null));
    } catch (e) {
      images.add((nodeId: nodeId, path: path, url: '${t.substring(0, t.length.clamp(0, 40))}...', status: 'failed', detail: 'not a valid data: URL ($e)'));
    }
    return text;
  }
  final mime = _mimeOf(t);
  if (mime == null || t.contains(r'${') || t.contains('\n')) return text;
  final rel = t.startsWith('file://') ? Uri.parse(t).toFilePath() : t;
  final file = File(rel.startsWith('/') ? rel : '$dir/$rel');
  if (!file.existsSync()) {
    // Written from the document's own folder (a component's
    // `../images/x.svg`): say what the site-relative path is.
    final fromDoc = docDir == null || rel.startsWith('/') ? null : File('$docDir/$rel');
    String? fix;
    if (fromDoc != null && docDir != dir && fromDoc.existsSync()) {
      final site = Directory(dir).absolute.uri.normalizePath().path;
      final at = fromDoc.absolute.uri.normalizePath().path;
      if (at.startsWith(site)) fix = at.substring(site.length);
    }
    images.add((nodeId: nodeId, path: path, url: t, status: 'failed', detail: fix == null
        ? 'no file ${file.path}'
        : 'no file ${file.path}. Image paths are relative to the site folder (the one with site.json) in every document, '
            'components included, as a published site reads them: write "$fix"'));
    return text;
  }
  images.add((nodeId: nodeId, path: path, url: t, status: 'local', detail: file.path));
  return 'data:$mime;base64,${base64Encode(file.readAsBytesSync())}';
}

/// A theme's JSON (a site manifest's `theme`) with the default family given
/// to every text style that names none and starts from no other, as a text
/// style in a page gets it, and as the theme's own `fontFamily` when it has
/// none (the controls' font: an app's platform font, which a layout's
/// controls no longer take from the app's theme).
Json prepareTheme(Json theme, {required String defaultFamily}) {
  if (theme['fontFamily'] == null) theme = {...theme, 'fontFamily': defaultFamily};
  final styles = readMap(theme['textStyles']);
  if (styles == null) return theme;
  return {
    ...theme,
    'textStyles': {
      for (final e in styles.entries)
        e.key: switch (readMap(e.value)) {
          final Json m when m['fontFamily'] == null && m['from'] == null => {...m, 'fontFamily': defaultFamily},
          _ => e.value,
        },
    },
  };
}
