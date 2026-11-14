// The layering of lib/src, checked from the import and export directives of
// its files (DESIGN.md §1, §5):
//
//   render    Nodes → Flutter render objects. Depends on nothing else here.
//   widgets   One recipe per widget type. Over render and runtime.
//   runtime   Bindings, formulas, conditions, actions. Over render.
//   services  Data sources, auth, storage.
//   scripting The script sandbox.
//   features  Auth, data, commerce, media, engage: plugins over the runtime
//             (their own rules: test/feature_isolation_test.dart).
//   session   UiSession, CodelesslyView: agent-written UI over the core
//             runtime (core-only: test/core_only_import_test.dart).
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
// name every import the rules would refuse (file → import), [renderStatics]
// every process-wide collection the render core still keeps, and the test
// also fails when a listed exception is no longer needed.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The layers: the directories of lib/src. A file directly in lib/src is in
/// the `leaf` layer (small utilities any layer may import).
const layers = ['render', 'widgets', 'runtime', 'services', 'scripting', 'features', 'session', 'app', 'leaf'];

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
const Map<String, Map<String, String>> renderExceptions = {};

/// Process-wide collections in render files (a static or top-level `final`
/// Map, Set or List): DESIGN.md keeps registries out of the render core, so
/// each one left is named here (file → name → why it's still there). State
/// kept per tree (an `Expando` keyed by the tree) isn't one. A new one fails
/// the test.
const Map<String, Map<String, String>> renderStatics = {
  // Registries: what plays or flies is found by node id or tag from the
  // actions (`ParticlePlayers.play(node, name)` has no tree to ask), and all
  // three are exported API. Per-tree state needs the action side to change.
  'render/play.dart': {
    '_records': 'FlightRegistry: where nodes last were, for flights between screens (exported)',
  },
  'render/particles.dart': {
    '_nodes': 'ParticlePlayers: the particle layers on screen by node id, played by an action',
  },
  'render/hero.dart': {
    '_byTree': 'HeroMarks: the shared elements of every tree on screen; a flight pairs marks of two trees (exported)',
  },
  // Caches of pure work, by its input.
  'render/control_theme.dart': {
    '_made': 'the controls\' ThemeData by tokens, mode and surface (64 at most): islands ask on every rebuild',
  },
  'render/paint/image_fill.dart': {
    '_entries': 'PaintImages: the loaded images by URL, shared by every tree as Flutter\'s image cache is (exported)',
    '_svgBytes': 'the bytes of the SVGs fetched, by URL',
  },
  'render/paint/path_paint.dart': {'_parsed': 'parsed SVG path data, by its text'},
  'render/paint/svg_path.dart': {'_cache': 'measured paths, by their data'},
  'render/convert.dart': {'_asked': 'FontDemand: the font families asked for, once each'},
  // Debug counters, off unless a tool turns them on.
  'render/node_tree.dart': {
    'debugApplyCounts': 'applies per node id while NodeBox.debugCountApplies',
    'debugInPlaceCounts': 'in-place updates per node id while NodeBox.debugCountApplies',
    'debugPaintCounts': 'paints per node id while NodeBox.debugCountPaints',
  },
};

/// The layers a widgets file may not import.
const widgetsForbiddenLayers = {'services', 'app', 'scripting'};

/// Imports of widgets files the rule refuses, kept until they're removed.
const Map<String, Map<String, String>> widgetsExceptions = {};

/// Milestone 3 (codelessly_api docs/design/11-no-widgets.md): the files under
/// lib that may still import `package:flutter/material.dart`,
/// `cupertino.dart` or `widgets.dart`. The list only shrinks: a file not on
/// it may not import them, and a file on it that no longer does fails until
/// its line is removed. It started at 60 files.
const widgetImportRatchet = {
  'src/app/back_guard.dart',
  'src/app/backdrop_screens.dart',
  'src/app/codelessly.dart',
  'src/app/codelessly_widget.dart',
  'src/app/overlay_screens.dart',
  'src/app/page_transitions.dart',
  'src/app/paywalls.dart',
  'src/app/presenter.dart',
  'src/app/viewport.dart',
  'src/features/engage/automations.dart',
  'src/features/media/embedded_player_native.dart',
  'src/features/media/embedded_player_web.dart',
  'src/features/media/players.dart',
  'src/features/media/recipes.dart',
  'src/render/control_theme.dart',
  'src/render/drag_track.dart',
  'src/render/hero.dart',
  'src/render/islands.dart',
  'src/render/layout/freeform.dart',
  'src/render/node_tree.dart',
  'src/render/node_view.dart',
  'src/render/recipe.dart',
  'src/render/reveal.dart',
  'src/render/typewriter.dart',
  'src/render/view_scroll.dart',
  'src/runtime/actions/capture.dart',
  'src/runtime/actions/confirm_dialog.dart',
  'src/runtime/actions/feedback_icon.dart',
  'src/runtime/actions/feedback_theme.dart',
  'src/runtime/actions/handlers.dart',
  'src/runtime/actions/hero_flights.dart',
  'src/runtime/actions/presentation_route.dart',
  'src/runtime/actions/presentation_scope.dart',
  'src/runtime/actions/route_transition.dart',
  'src/runtime/actions/toast.dart',
  'src/runtime/actions/ui.dart',
  'src/runtime/gestures/drag_and_drop.dart',
  'src/session/view.dart',
  'src/widgets/collections.dart',
  'src/widgets/collections_data_list.dart',
  'src/widgets/collections_list_runtime.dart',
  'src/widgets/collections_page_runtime.dart',
  'src/widgets/collections_pagination.dart',
  'src/widgets/collections_reorder.dart',
  'src/widgets/collections_swipe.dart',
  'src/widgets/collections_table.dart',
  'src/widgets/inputs.dart',
  'src/widgets/media.dart',
};

/// The render-object controls: never on the ratchet.
const widgetFreePaths = ['src/render/controls/', 'src/widgets/controls.dart'];

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

  test('render keeps no process-wide collections but the listed ones', () {
    final declaration = RegExp(r'^(?:\s+static\s+)?final\s+(?:Map|Set|List)<.*>\s+(\w+)\s*=');
    final found = <String>{};
    for (final f in Directory('lib/src/render').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final file = f.path.replaceAll(r'\', '/').substring('lib/src/'.length);
      for (final line in f.readAsLinesSync()) {
        final name = declaration.firstMatch(line)?[1];
        if (name != null) found.add('$file: $name');
      }
    }
    final listed = {
      for (final e in renderStatics.entries)
        for (final name in e.value.keys) '${e.key}: $name',
    };
    expect(found.difference(listed), isEmpty, reason: 'new process-wide state in render');
    expect(listed.difference(found), isEmpty, reason: 'listed, but gone: remove it from renderStatics');
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

  test('the files importing Flutter\'s widget libraries only shrink (the Milestone 3 ratchet)', () {
    final widgetLibrary = RegExp(r'''^\s*(?:import|export)\s+['"]package:flutter/(?:material|cupertino|widgets)\.dart['"]''');
    final importing = <String>{};
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final file = f.path.replaceAll(r'\', '/').substring('lib/'.length);
      if (f.readAsLinesSync().any(widgetLibrary.hasMatch)) importing.add(file);
    }
    expect(importing.difference(widgetImportRatchet), isEmpty, reason: 'new imports of material/cupertino/widgets');
    expect(widgetImportRatchet.difference(importing), isEmpty, reason: 'no longer imported: remove from widgetImportRatchet');
    for (final path in widgetFreePaths) {
      expect(importing.where((f) => f.startsWith(path)), isEmpty, reason: 'the render-object controls import no widget library');
    }
    // ignore: avoid_print
    print('widget-library imports: ${importing.length} files');
  });
}
