// Core-only, proven across both packages: everything the SDK's core (the
// renderer, the widgets, the core runtime, scripting) compiles, followed
// into codelessly_api through its import directives, contains no API
// feature library (lib/src/features/** of codelessly_api) and not the API's
// umbrella (codelessly_api.dart, the standard catalog). The other half of
// the proof is codelessly_api's test/library_boundaries_test.dart (its core
// imports no feature).
//
// And the joining of the halves: every action type a first-party feature's
// catalog declares has a handler in that feature, and the default runner
// decodes with every type of the standard catalog.
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

final _directive = RegExp(r'''^\s*(?:import|export|part)\s+['"]([^'"]+)['"]([^;]*);''', multiLine: true);
final _conditional = RegExp(r'''if\s*\([^)]*\)\s*['"]([^'"]+)['"]''');

/// The root directory of package [name], from the package config.
String _packageRoot(String name) {
  final config = jsonDecode(File('.dart_tool/package_config.json').readAsStringSync()) as Map<String, Object?>;
  for (final p in (config['packages']! as List).cast<Map<String, Object?>>()) {
    if (p['name'] == name) {
      final root = Uri.parse(p['rootUri']! as String);
      final base = Directory('.dart_tool').absolute.uri;
      final path = base.resolveUri(root).toFilePath();
      return path.endsWith('/') ? path : '$path/';
    }
  }
  throw StateError('No package $name');
}

final _sdkRoot = Directory.current.absolute.path;
final _apiRoot = _packageRoot('codelessly_api');

/// The files [file] (an absolute path) imports, exports or includes, among
/// this package's and codelessly_api's (others are left out).
List<String> _targets(String file) {
  final text = File(file).readAsStringSync();
  final out = <String>[];
  for (final m in _directive.allMatches(text)) {
    for (final uri in [m[1]!, for (final c in _conditional.allMatches(m[2]!)) c[1]!]) {
      String? path;
      if (uri.startsWith('package:codelessly_sdk/')) {
        path = '$_sdkRoot/lib/${uri.substring('package:codelessly_sdk/'.length)}';
      } else if (uri.startsWith('package:codelessly_api/')) {
        path = '${_apiRoot}lib/${uri.substring('package:codelessly_api/'.length)}';
      } else if (!uri.contains(':')) {
        path = File(file).parent.uri.resolve(uri).toFilePath();
      }
      if (path != null) out.add(File(path).absolute.path.replaceAll(RegExp(r'/\./'), '/'));
    }
  }
  return out;
}

/// The closure of [entries], and for each file the one that first imported
/// it (to print a path).
(Set<String>, Map<String, String>) _closure(Iterable<String> entries) {
  final seen = <String>{};
  final from = <String, String>{};
  final queue = [...entries];
  while (queue.isNotEmpty) {
    final f = queue.removeLast();
    if (!seen.add(f)) continue;
    for (final t in _targets(f)) {
      from.putIfAbsent(t, () => f);
      queue.add(t);
    }
  }
  return (seen, from);
}

bool _sdkCore(String path) => ['render', 'widgets', 'runtime', 'scripting']
    .any((d) => path.startsWith('$_sdkRoot/lib/src/$d/'));

void main() {
  final sdkFiles = [
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>())
      if (f.path.endsWith('.dart')) f.absolute.path,
  ];

  test('the API package was found', () {
    expect(File('${_apiRoot}lib/core.dart').existsSync(), isTrue, reason: _apiRoot);
    expect(sdkFiles.where(_sdkCore).length, greaterThan(100));
  });

  test('the SDK core imports codelessly_api through core.dart only', () {
    final bad = [
      for (final f in sdkFiles.where(_sdkCore))
        for (final m in _directive.allMatches(File(f).readAsStringSync()))
          if (m[1]!.startsWith('package:codelessly_api/') && m[1] != 'package:codelessly_api/core.dart')
            '${f.substring(_sdkRoot.length + 1)} -> ${m[1]}',
    ];
    expect(bad, isEmpty);
  });

  test('a core-only build (CoreActions, NodeTree, the core catalog) compiles no API feature library', () {
    final (seen, from) = _closure(sdkFiles.where(_sdkCore));
    String path(String f) => [for (String? x = f; x != null; x = from[x]) x.replaceFirst(_sdkRoot, 'sdk').replaceFirst(_apiRoot, 'api/')]
        .reversed
        .join(' -> ');
    final api = seen.where((f) => f.startsWith(_apiRoot)).toList();
    expect(api, isNotEmpty, reason: 'the closure reaches into codelessly_api');
    expect([for (final f in api) if (f.startsWith('${_apiRoot}lib/src/features/')) path(f)], isEmpty);
    expect([for (final f in api) if (!f.startsWith('${_apiRoot}lib/src/core/') && f != '${_apiRoot}lib/core.dart') path(f)],
        isEmpty);
    // Nor the SDK's own features.
    expect([for (final f in seen) if (f.startsWith('$_sdkRoot/lib/src/features/')) path(f)], isEmpty);
  });

  test('agent UI (UiSession, CodelesslyView) is core-only: it compiles no feature of either package', () {
    final session = sdkFiles.where((f) => f.startsWith('$_sdkRoot/lib/src/session/')).toList();
    expect(session, isNotEmpty);
    final (seen, from) = _closure(session);
    String path(String f) => [for (String? x = f; x != null; x = from[x]) x.replaceFirst(_sdkRoot, 'sdk').replaceFirst(_apiRoot, 'api/')]
        .reversed
        .join(' -> ');
    expect([for (final f in seen) if (f.startsWith('${_apiRoot}lib/') && !f.startsWith('${_apiRoot}lib/src/core/') && f != '${_apiRoot}lib/core.dart') path(f)],
        isEmpty);
    expect([for (final f in seen) if (f.startsWith('$_sdkRoot/lib/src/features/')) path(f)], isEmpty);
    // It imports the model through core.dart only.
    for (final f in session) {
      for (final m in _directive.allMatches(File(f).readAsStringSync())) {
        if (m[1]!.startsWith('package:codelessly_api/')) expect(m[1], 'package:codelessly_api/core.dart', reason: f);
      }
    }
  });

  test('every action type a first-party feature declares has a handler in it', () {
    for (final feature in kFirstPartyFeatures) {
      expect(feature.catalog.actions, isNotEmpty, reason: feature.name);
      for (final spec in feature.catalog.actions) {
        expect(feature.actions, contains(spec.type), reason: '${feature.name} declares ${spec.type}');
      }
    }
    // Every declared type of the standard catalog is the core's (handled in
    // the exhaustive CoreAction switch) or a first-party feature's.
    final featureTypes = {for (final f in kFirstPartyFeatures) ...f.actions.keys};
    for (final spec in standardCatalog.actions) {
      expect(Catalog.core.action(spec.type) != null || featureTypes.contains(spec.type), isTrue, reason: spec.type);
    }
  });

  test('the default runner decodes with every standard type; a core-only one with the core', () {
    const runner = CodelesslyActions();
    expect(runner.catalog.includes(standardCatalog), isTrue);
    expect(standardCatalog.includes(runner.catalog), isTrue);
    expect(const CoreActions().catalog, same(Catalog.core));
    expect(runner.recipes.keys, containsAll(['video', 'embeddedVideo', 'audioPlayer', 'webView']));
    expect(const CodelesslyConfig().catalog.includes(standardCatalog), isTrue);
    expect(const CodelesslyConfig(actions: CoreActions()).allRecipes, isEmpty);
  });
}
