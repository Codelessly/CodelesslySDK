// A site for the render command (docs/design/06-sections-and-components.md
// §8.2): a directory with a `site.json` manifest (or any directory holding
// component documents) is the pages of one site plus its components. A
// document with a `widget` declaration is a component (its type is its file
// stem); every other document is a page. The manifest's variables are the
// project's, read by bare name in every page and component.
//
// `--component <Type>` renders one component alone: a generated page whose
// canvas holds one call to it, with the parameters `--props` gives (else
// each of its previews, else its defaults) and the slot content of a small
// fixture file (`--slots`).
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart';

/// One input document: its name in reports, its path and its text.
typedef Input = ({String name, String path, String text});

/// The documents of [inputs] and the site manifest among them: for a
/// directory with `site.json`, its pages (the manifest's, else the
/// directory's `.json` files) and its components (the manifest's, else the
/// files under `components/`); a component is named by its path relative to
/// the directory (`components/PlanCard.json`), a page by its file stem.
({List<Input> inputs, Json? manifest}) loadSite(List<String> inputs, List<Input> Function(List<String>) load) {
  Json? manifest;
  final out = <Input>[];
  final plain = <String>[];
  for (final input in inputs) {
    final file = File('$input/${SiteManifest.fileName}');
    if (FileSystemEntity.typeSync(input) != FileSystemEntityType.directory) {
      plain.add(input);
      continue;
    }
    var m = file.existsSync() ? _tryJson(file.readAsStringSync()) : null;
    // A design system the manifest names: its components join the site's,
    // its tokens are the theme the site's own is merged over, its fonts are
    // declared with paths from the site's folder.
    final dsRef = readString(m?['designSystem']);
    if (m != null && dsRef != null) {
      final dsDir = '$input/$dsRef';
      final dsFile = File('$dsDir/${DesignSystemManifest.fileName}');
      final ds = dsFile.existsSync() ? _tryJson(dsFile.readAsStringSync()) : null;
      if (ds == null) {
        designSystemProblems.add('designSystem "$dsRef": no readable ${DesignSystemManifest.fileName} at $dsDir');
      } else {
        final dsm = DesignSystemManifest.fromJson(ds);
        m = {
          ...m,
          'theme': dsm.theme.mergedWith(ThemeTokens.fromJson(m['theme'])).toJson(),
          'fonts': [
            for (final f in dsm.fonts)
              FontFamily(family: f.family, fonts: [
                for (final face in f.fonts) FontAsset(asset: '$dsRef/${face.asset}', weight: face.weight, style: face.style),
              ]).toJson(),
            ...?readList(m['fonts']),
          ],
        };
        for (final c in load([for (final c in dsm.components) '$dsDir/$c'])) {
          final rel = c.path.startsWith('$input/') ? c.path.substring(input.length + 1) : c.path;
          out.add((name: rel, path: c.path, text: c.text));
        }
      }
    }
    if (m != null) manifest = m;
    final listed = SiteManifest.fromJson(m);
    final pages = listed.pages.isEmpty ? load([input]) : load([for (final p in listed.pages) '$input/$p']);
    out.addAll(pages.where((p) => File(p.path).uri.pathSegments.last != SiteManifest.fileName));
    final components = listed.components.isNotEmpty
        ? [for (final c in listed.components) '$input/$c']
        : (Directory('$input/components').existsSync() ? ['$input/components'] : const <String>[]);
    for (final c in load(components)) {
      final rel = c.path.startsWith('$input/') ? c.path.substring(input.length + 1) : c.path;
      out.add((name: rel, path: c.path, text: c.text));
    }
  }
  out.addAll(load(plain));
  return (inputs: out, manifest: manifest);
}

/// Design systems a site names that could not be read (the render command
/// reports them).
final List<String> designSystemProblems = [];

Json? _tryJson(String text) {
  try {
    final j = jsonDecode(text);
    return j is Map ? j.cast<String, Object?>() : null;
  } catch (_) {
    return null;
  }
}

/// Whether [doc] is a component document.
bool isComponentJson(Json doc) => doc.containsKey(kWidgetKey);

/// The manifest's project variables as a publish model's `variables`.
Json publishVariables(Json? manifest) => {
      for (final v in SiteManifest.fromJson(manifest).variables) v.name: v.toJson(),
    };

/// The page that shows component [type] alone, once per parameter set: the
/// ad-hoc [props] (JSON text), else each of its previews (at the preview's
/// size), else its defaults. Each page has one canvas named after the set;
/// its call fills the canvas as the root's own design asks (its width and
/// height, fit included). [slots] is a fixture's JSON: `{"children":
/// [ids], "slots": {"name": id}, "nodes": {...}}`, the content the call
/// passes. A `variable` parameter names a page variable of the same key,
/// holding the parameter's value (or its default).
List<({String name, Json page, double? width, double? height})> componentPages(
  String type,
  Json definition, {
  String? props,
  Json? slots,
}) {
  final doc = LayoutDocument.fromJson(definition);
  final spec = doc.widget;
  final root = doc.componentRoot;
  if (spec == null || root == null) return const [];
  final rootLayout = readMap(readMap(readMap(definition['nodes'])?[root])?['layout']) ?? const {};
  final sets = <({String name, Json props, double? width, double? height})>[];
  if (props != null) {
    final p = _tryJson(props) ?? (throw FormatException('--props is not a JSON object: $props'));
    sets.add((name: type, props: p, width: null, height: null));
  } else if (doc.previews.isNotEmpty) {
    for (final pv in doc.previews) {
      final slug = pv.name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
      sets.add((name: slug.isEmpty ? type : '$type-$slug', props: pv.props, width: pv.width, height: pv.height));
    }
  } else {
    sets.add((name: type, props: const {}, width: null, height: null));
  }
  final out = <({String name, Json page, double? width, double? height})>[];
  for (final set in sets) {
    final variables = <Json>[];
    final callProps = <String, Object?>{...set.props};
    for (final p in spec.props) {
      if (!p.type.isVariable) continue;
      final of = p.type.variableOf!;
      final value = set.props[p.key] ?? _zero(of);
      variables.add({'name': p.key, 'type': _variableType(of), 'value': value});
      callProps[p.key] = p.key;
    }
    final canvas = set.name;
    out.add((
      name: set.name,
      width: set.width,
      height: set.height,
      page: {
        'schema': 2,
        'id': canvas,
        'roots': [canvas],
        if (variables.isNotEmpty) 'variables': {canvas: variables},
        if (definition['breakpoints'] != null) 'breakpoints': definition['breakpoints'],
        'nodes': {
          canvas: {
            'type': 'canvas',
            'name': canvas,
            'slots': {'body': 'preview'},
            'layout': {'width': set.width ?? 1440, 'height': set.height ?? 900},
          },
          'preview': {
            'type': 'column',
            'children': ['call'],
            'props': {'scrollable': true},
            'layout': {'width': {'fill': set.width ?? 1440}, 'height': {'fill': set.height ?? 900}},
          },
          'call': {
            'type': type,
            if (callProps.isNotEmpty) 'props': callProps,
            'layout': {
              for (final k in const ['width', 'height', 'constraints', 'aspectRatio'])
                if (rootLayout[k] != null) k: rootLayout[k],
            },
            if (slots?['children'] case final List<Object?> c) 'children': c,
            if (slots?['slots'] case final Map<String, Object?> s) 'slots': s,
          },
          ...?(slots?['nodes'] as Map?)?.cast<String, Object?>(),
        },
      },
    ));
  }
  return out;
}

Object? _zero(PropType t) => switch (t.kind) {
      PropKind.boolean => false,
      PropKind.integer || PropKind.number => 0,
      PropKind.list => const [],
      PropKind.object || PropKind.json => const {},
      _ => '',
    };

String _variableType(PropType t) => switch (t.kind) {
      PropKind.boolean => 'boolean',
      PropKind.integer => 'integer',
      PropKind.number => 'decimal',
      PropKind.list => 'list',
      PropKind.object || PropKind.json => 'map',
      _ => 'text',
    };
