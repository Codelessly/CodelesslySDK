// The layering of lib/src, checked from the import and export directives of
// its files (DESIGN.md §1, §5):
//
//   render    Nodes → Flutter render objects. Depends on nothing else here.
//   widgets   One recipe per widget type. Over render and runtime.
//   runtime   Bindings, formulas, conditions, actions. Over render.
//   services  Data sources, auth, storage.
//   scripting The script sandbox.
//   app       Codelessly, CodelesslyWidget. Over everything.
//
// The render core is what an app that only draws nodes needs: it imports
// Flutter, the model (`package:codelessly_api`) and a few pure drawing
// packages; what it needs from the layers above it takes through the
// interfaces it owns (render/contracts.dart). This test fails when a file
// under lib/src/render imports anything else, and prints the import matrix
// between the layers (`flutter test test/architecture_test.dart`).
//
// Debt is listed, not hidden: [renderExceptions] and [widgetsExceptions]
// name every import the rules would refuse (file → import), and the test
// also fails when a listed exception is no longer needed.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The layers: the directories of lib/src. A file directly in lib/src is in
/// the `leaf` layer (small utilities any layer may import).
const layers = ['render', 'widgets', 'runtime', 'services', 'scripting', 'app', 'leaf'];

/// The packages a render file may import: Flutter, the model, and pure
/// drawing or collection helpers. No network, storage or platform plugins.
const renderPackages = {
  'flutter', // package:flutter/* (rendering, widgets, material for islands)
  'codelessly_api', // the model
  'flutter_svg', // SVG pictures of image fills and icons
  'path_parsing', // SVG path data of shapes
  'collection', // list equality
};

/// The `dart:` libraries a render file may import.
const renderDartLibraries = {'dart:async', 'dart:collection', 'dart:convert', 'dart:math', 'dart:typed_data', 'dart:ui'};

/// The layers a render file may import: its own, and leaf utilities (which
/// obey the render rules themselves).
const renderLayers = {'render', 'leaf'};

/// Imports of render files the rules refuse, kept until they're removed:
/// file (under lib/src) → the imports it may still have, each with why.
const Map<String, Map<String, String>> renderExceptions = {
  'render/view_scroll.dart': {
    'runtime/actions/context.dart': 'writes scroll progress to a variable',
  },
  'render/flip_card.dart': {
    'runtime/actions/context.dart': 'writes its side to a variable',
    'runtime/contracts.dart': 'reads its scope',
    'runtime/expressions/node_scopes.dart': 'reads its scope',
    'runtime/expressions/scopes.dart': 'reads its scope',
  },
  'render/transform_gesture.dart': {
    'runtime/actions/context.dart': 'writes its pose to variables',
    'runtime/contracts.dart': 'reads its scope',
    'runtime/expressions/scopes.dart': 'reads its scope',
    'runtime/gestures/physics.dart': 'settle simulations',
  },
  'render/drag_track.dart': {
    'runtime/actions/context.dart': 'writes its value to a variable',
    'runtime/actions/variable_animator.dart': 'stops the animation of the variable it writes',
    'runtime/contracts.dart': 'reads its scope',
    'runtime/expressions/node_scopes.dart': 'reads its scope',
    'runtime/expressions/scopes.dart': 'reads its scope',
  },
  'render/behaviors.dart': {
    'runtime/actions/wiring.dart': 'the visible share of a box',
  },
  'render/node_tree.dart': {
    'runtime/gestures/drag_and_drop.dart': 'drag and drop layers',
    'runtime/gestures/drag_motion.dart': 'drag layers',
    'runtime/expressions/bindings.dart': 'the binder',
    'widgets/collections.dart': 'whether a list can be measured',
    'widgets/registry.dart': 'the built-in recipes',
    'widgets/inputs.dart': 'which types are inputs',
  },
  'render/paint/image_fill.dart': {
    'package:http/http.dart': 'fetches SVG images',
  },
};

/// The layers a widgets file may not import.
const widgetsForbiddenLayers = {'services', 'app', 'scripting'};

/// Imports of widgets files the rule refuses, kept until they're removed.
const Map<String, Map<String, String>> widgetsExceptions = {
  'widgets/collections_list_runtime.dart': {
    'services/cloud/database.dart': 'a cloud-bound list reads its pages from the cloud database',
    'services/cloud/resolve.dart': 'a cloud-bound list finds the cloud database of its services',
    'services/services.dart': 'a cloud-bound list finds the cloud database of its services',
  },
  'widgets/collections_data_list.dart': {
    'services/cloud/resolve.dart': 'a cloud-bound list finds the cloud database of its services',
  },
};

/// One import or export directive: [target] is `dart:x`, `package:x/...`, or
/// a path under lib/src (`render/convert.dart`) for a file of this package.
typedef Directive = ({String file, String target});

final _directive = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''');
final _conditional = RegExp(r'''^\s*if\s*\([^)]*\)\s*['"]([^'"]+)['"]''');

/// Every import and export (conditional ones included) of the files under
/// lib/src.
List<Directive> readDirectives() {
  final root = Directory('lib/src');
  final out = <Directive>[];
  for (final f in root.listSync(recursive: true).whereType<File>()) {
    if (!f.path.endsWith('.dart')) continue;
    final file = f.path.replaceAll(r'\', '/').substring('lib/src/'.length);
    for (final line in f.readAsLinesSync()) {
      final uri = _directive.firstMatch(line)?[1] ?? _conditional.firstMatch(line)?[1];
      if (uri == null) continue;
      out.add((file: file, target: _resolve(file, uri)));
    }
  }
  return out;
}

String _resolve(String file, String uri) {
  if (uri.startsWith('dart:')) return uri;
  const self = 'package:codelessly_sdk/src/';
  if (uri.startsWith(self)) return uri.substring(self.length);
  if (uri.startsWith('package:')) return uri;
  final parts = file.split('/')..removeLast();
  for (final p in uri.split('/')) {
    if (p == '..') {
      parts.removeLast();
    } else if (p != '.') {
      parts.add(p);
    }
  }
  return parts.join('/');
}

/// The layer of [path] (under lib/src), or null for a `dart:` or package
/// import.
String? layerOf(String path) {
  if (path.startsWith('dart:') || path.startsWith('package:')) return null;
  final i = path.indexOf('/');
  return i < 0 ? 'leaf' : path.substring(0, i);
}

String _packageOf(String uri) => uri.substring('package:'.length).split('/').first;

void main() {
  final directives = readDirectives();

  test('the import matrix between the layers of lib/src', () {
    final counts = <String, Map<String, int>>{};
    for (final d in directives) {
      final from = layerOf(d.file)!;
      final to = layerOf(d.target);
      if (to == null || to == from) continue;
      expect(layers, contains(to), reason: '${d.file} imports ${d.target}: an unknown layer');
      (counts[from] ??= {})[to] = (counts[from]![to] ?? 0) + 1;
    }
    final table = StringBuffer('imports (row imports column):\n${''.padRight(10)}');
    for (final to in layers) {
      table.write(to.padLeft(10));
    }
    for (final from in layers) {
      table.write('\n${from.padRight(10)}');
      for (final to in layers) {
        table.write((from == to ? '·' : '${counts[from]?[to] ?? 0}').padLeft(10));
      }
    }
    // ignore: avoid_print
    print(table);
    expect(directives, isNotEmpty);
  });

  /// What [file] imports that [allowed] refuses, less its [exceptions];
  /// the exceptions it no longer uses fail too.
  List<String> violations(
    bool Function(Directive d) inScope,
    bool Function(Directive d) allowed,
    Map<String, Map<String, String>> exceptions,
  ) {
    final out = <String>[];
    final used = <String>{};
    for (final d in directives.where(inScope)) {
      if (allowed(d)) continue;
      if (exceptions[d.file]?.containsKey(d.target) ?? false) {
        used.add('${d.file} → ${d.target}');
        continue;
      }
      out.add('${d.file} imports ${d.target}');
    }
    for (final e in exceptions.entries) {
      for (final target in e.value.keys) {
        if (!used.contains('${e.key} → $target')) out.add('${e.key} no longer imports $target: remove the exception');
      }
    }
    return out;
  }

  bool renderAllows(Directive d) {
    final t = d.target;
    if (t.startsWith('dart:')) return renderDartLibraries.contains(t);
    if (t.startsWith('package:')) return renderPackages.contains(_packageOf(t));
    return renderLayers.contains(layerOf(t));
  }

  test('render imports only Flutter, the model, drawing packages and itself', () {
    expect(violations((d) => layerOf(d.file) == 'render', renderAllows, renderExceptions), isEmpty);
  });

  test('leaf utilities (files directly in lib/src) obey the render rules', () {
    expect(violations((d) => layerOf(d.file) == 'leaf', renderAllows, const {}), isEmpty);
  });

  test('widgets import no services, app or scripting', () {
    expect(
      violations(
        (d) => layerOf(d.file) == 'widgets',
        (d) => !widgetsForbiddenLayers.contains(layerOf(d.target)),
        widgetsExceptions,
      ),
      isEmpty,
    );
  });
}
