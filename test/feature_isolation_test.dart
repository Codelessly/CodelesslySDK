// Feature isolation, checked on the import graph (pure Dart: it parses the
// import/export directives under lib/).
//
// The core is the renderer and the core runtime (lib/src/render,
// lib/src/widgets, lib/src/runtime, lib/src/scripting); the feature layers
// (lib/src/features/<name>: auth, data, commerce, media, engage) sit on top
// and reach the core only through the plugin seam
// (runtime/actions/feature.dart). So:
//
// (a) nothing in the core imports a feature, directly or through any file it
//     imports;
// (b) one feature doesn't import another (shared needs go through runtime
//     contracts, or the service interfaces in lib/src/services);
// (c) the heavy native plugins are imported only by the feature and service
//     implementations that own them.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _directive = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]([^;]*);''', multiLine: true);
final _conditional = RegExp(r'''if\s*\([^)]*\)\s*['"]([^'"]+)['"]''');

/// lib-relative path -> the URIs it imports or exports (conditional ones too).
final Map<String, List<String>> _uris = {
  for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')))
    f.path.replaceAll(r'\', '/'): [
      for (final m in _directive.allMatches(f.readAsStringSync())) ...[
        m[1]!,
        for (final c in _conditional.allMatches(m[2]!)) c[1]!,
      ],
    ],
};

/// The lib file [uri] names from [file], or null for another package's.
String? _resolve(String file, String uri) {
  if (uri.startsWith('package:codelessly_sdk/')) return 'lib/${uri.substring('package:codelessly_sdk/'.length)}';
  if (uri.contains(':')) return null;
  return File(file).parent.uri.resolve(uri).path.replaceFirst(RegExp(r'^.*?(?=lib/)'), '');
}

Iterable<String> _imports(String file) => [for (final u in _uris[file] ?? const <String>[]) ?_resolve(file, u)];

/// The feature (`auth`, `media`...) [file] belongs to, if any. Files right
/// under lib/src/features (first_party.dart, context.dart) assemble the
/// features and belong to none.
String? _featureOf(String file) => RegExp(r'^lib/src/features/([^/]+)/').firstMatch(file)?[1];

bool _core(String file) =>
    file.startsWith('lib/src/render/') ||
    file.startsWith('lib/src/widgets/') ||
    file.startsWith('lib/src/runtime/') ||
    file.startsWith('lib/src/scripting/');

/// Feature-to-feature imports that could not be untangled. Empty.
const Set<(String, String)> _crossFeatureExceptions = {};

/// Where each native plugin may be imported. Everything under
/// lib/src/features is allowed already; these are the rest.
const List<String> _pluginHomes = [
  'lib/src/features/',
  'lib/src/services/firebase/',
  'lib/src/services/store/',
  'lib/firebase.dart',
  'lib/store.dart',
  // The media node widgets: the players a layout's audio, video and embed
  // nodes show. Part of the renderer today.
  'lib/src/features/media/players.dart',
  'lib/src/features/media/embedded_player_native.dart',
];

final _plugin = RegExp(r'^package:(just_audio|in_app_purchase\w*|firebase\w*|cloud_firestore|cloud_functions|webview\w*|video_player)/');

void main() {
  test('the import graph was read', () {
    expect(_uris.length, greaterThan(150));
    expect(_uris.keys, contains('lib/src/features/first_party.dart'));
    expect(_imports('lib/src/features/first_party.dart'), contains('lib/src/features/auth/auth.dart'));
  });

  test('(a) the core imports no feature, directly', () {
    final bad = [
      for (final file in _uris.keys.where(_core))
        for (final to in _imports(file))
          if (to.startsWith('lib/src/features/')) '$file -> $to',
    ];
    expect(bad, isEmpty);
  });

  test('(a) the core action runtime reaches no feature through anything it imports', () {
    // What a core-only app compiles in for its actions: CoreActions, the
    // core handlers, the action context and wiring.
    final seen = <String>{};
    final from = <String, String>{};
    final queue = ['lib/src/runtime/actions/actions.dart', 'lib/src/runtime/contracts.dart'];
    while (queue.isNotEmpty) {
      final file = queue.removeLast();
      if (!seen.add(file)) continue;
      for (final to in _imports(file)) {
        from.putIfAbsent(to, () => file);
        queue.add(to);
      }
    }
    String path(String file) => [for (String? f = file; f != null; f = from[f]) f].reversed.join(' -> ');
    expect([for (final f in seen) if (f.startsWith('lib/src/features/')) path(f)], isEmpty);
    // Nor the Services struct, which holds every feature's service.
    expect([for (final f in seen) if (f == 'lib/src/services/services.dart') path(f)], isEmpty);
  });

  test('(b) a feature imports no other feature', () {
    final bad = [
      for (final file in _uris.keys)
        if (_featureOf(file) case final String feature)
          for (final to in _imports(file))
            if (_featureOf(to) case final String other when other != feature)
              if (!_crossFeatureExceptions.contains((file, to))) '$file -> $to',
    ];
    expect(bad, isEmpty);
  });

  test('(c) native plugins are imported only where they belong', () {
    final bad = [
      for (final e in _uris.entries)
        if (!_pluginHomes.any(e.key.startsWith))
          for (final uri in e.value)
            if (_plugin.hasMatch(uri)) '${e.key} -> $uri',
    ];
    expect(bad, isEmpty);
  });

  test('every first-party feature is a module with a plugin object', () {
    for (final name in ['auth', 'data', 'commerce', 'media', 'engage']) {
      final sources = [
        for (final f in _uris.keys.where((f) => _featureOf(f) == name)) File(f).readAsStringSync(),
      ].join('\n');
      expect(sources, contains('const CodelesslyFeature ${name}Feature'), reason: name);
    }
  });
}
