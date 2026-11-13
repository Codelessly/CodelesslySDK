// Hosted plugins: a plugin declared and implemented as data (a "rating" node
// type built from a row of icons whose glyphs bind to the node's `value`
// prop, and a "cheer" action type whose chain reads its `amount` field),
// loaded from a memory source as a publish would list it, renders and runs;
// a payload that doesn't match its digest is refused; an SDK older than the
// plugin's minSdk skips it.
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Json _packageJson() => jsonDecode(File('test/fixtures/acme_stars_plugin.json').readAsStringSync()) as Json;

/// The plugin's version 1 as stored, and what a publish lists for it.
(PluginVersion, PluginRef) _published([Json? package]) {
  final pkg = PluginPackage.fromJson(package ?? _packageJson())!;
  final unsigned = PluginVersion.of(pkg, version: 1);
  final digest = pluginDigest(unsigned.payload);
  final version = PluginVersion.of(pkg, version: 1, digest: digest);
  return (version, PluginRef(id: pkg.id, version: 1, semver: pkg.semver, digest: digest));
}

void main() {
  const host = standardCatalog;

  test('a listed plugin loads, is checked and installs; the cache serves it offline', () async {
    final (version, ref) = _published();
    final cache = MemoryPublishCache();
    final loads = await loadHostedPlugins([ref], source: MemoryPluginSource([version]), host: host, cache: cache);
    final installed = loads.single as HostedPluginInstalled;
    expect(installed.feature.catalog.widget('acme.rating'), isNotNull);
    expect(installed.feature.recipes.keys, ['acme.rating']);
    expect(installed.feature.actions.keys, ['acme.cheer']);
    expect(cache.entries.keys, [pluginCacheKey('acme.stars', 1)]);
    // Offline: nothing to load from, the cached copy (digest checked) serves.
    final again = await loadHostedPlugins([ref], source: MemoryPluginSource(const []), host: host, cache: cache);
    expect(again.single, isA<HostedPluginInstalled>());
  });

  test('a payload that does not match its digest is refused', () async {
    final (version, ref) = _published();
    final tampered = PluginVersion(
      id: version.id,
      version: 1,
      semver: version.semver,
      minSdk: version.minSdk,
      digest: version.digest,
      payload: version.payload.replaceFirst('star_border', 'circle'),
    );
    final loads = await loadHostedPlugins([ref], source: MemoryPluginSource([tampered]), host: host);
    expect(loads.single, isA<HostedPluginSkipped>().having((s) => s.reason, 'reason', contains('digest')));
    // A cached copy that no longer matches is not used either.
    final cache = MemoryPublishCache()..entries[pluginCacheKey('acme.stars', 1)] = tampered.toJson();
    final cached = await loadHostedPlugins([ref], source: MemoryPluginSource(const []), host: host, cache: cache);
    expect(cached.single, isA<HostedPluginSkipped>());
  });

  test('an SDK older than its minSdk skips it; so does a host without its types', () async {
    final (version, ref) = _published();
    final old = await loadHostedPlugins([ref], source: MemoryPluginSource([version]), host: host, sdkVersion: '23.9.0');
    expect(old.single, isA<HostedPluginSkipped>().having((s) => s.reason, 'reason', contains('24.0.0')));
    final missing = await loadHostedPlugins([const PluginRef(id: 'acme.none', version: 2)],
        source: MemoryPluginSource([version]), host: host);
    expect(missing.single, isA<HostedPluginSkipped>().having((s) => s.reason, 'reason', contains('does not exist')));
    // Its chain uses an API call it doesn't list in requires: refused.
    final json = _packageJson();
    (((json['implementation'] as Map)['actions'] as Map)['acme.cheer'] as Map)['chain'] = [
      {'type': 'callApi', 'api': 'x'},
    ];
    final (greedy, greedyRef) = _published(json);
    final refused = await loadHostedPlugins([greedyRef], source: MemoryPluginSource([greedy]), host: host);
    expect(refused.single, isA<HostedPluginSkipped>().having((s) => s.reason, 'reason', contains('requires')));
  });

  testWidgets('a hosted node type renders its tree with the node\'s props bound in', (tester) async {
    final (version, ref) = _published();
    final installed = (await loadHostedPlugins([ref], source: MemoryPluginSource([version]), host: host)).single
        as HostedPluginInstalled;
    final catalog = host + installed.feature.catalog;
    final source = DocumentSource(_page(catalog, value: 3));
    final tree = NodeTree(source, recipes: installed.feature.recipes);
    await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'c'))));
    await tester.pump();
    expect(_glyphs(tester), ['star', 'star', 'star', 'star_border', 'star_border']);
    source.document = _page(catalog, value: 5);
    await tester.pump();
    await tester.pump();
    expect(_glyphs(tester), ['star', 'star', 'star', 'star', 'star']);
  });

  test('a hosted action type runs its chain with its fields as params', () async {
    final (version, ref) = _published();
    final installed = (await loadHostedPlugins([ref], source: MemoryPluginSource([version]), host: host)).single
        as HostedPluginInstalled;
    final catalog = host + installed.feature.catalog;
    final node = Node.fromJson({
      'type': 'box',
      'actions': [
        {'trigger': {'type': 'click'}, 'actions': [{'type': 'acme.cheer', 'amount': 4}, {'type': 'acme.cheer'}]},
      ],
    }, id: 'b', catalog: catalog)!;
    expect(node.actions.single.actions.first, isA<DeclaredAction>());
    final scope = VariableScope([const Variable(name: 'cheers', type: VariableType.decimal, value: 0)]);
    final errors = <Object>[];
    final runner = CodelesslyActions(features: [...kFirstPartyFeatures, installed.feature]);
    expect(runner.catalog.action('acme.cheer'), isNotNull);
    await runner.run(node, 'click', RuntimeActionContext(scope: scope, onError: (e, s, a) => errors.add(e)));
    expect(errors, isEmpty);
    expect(scope.read('cheers'), 10, reason: '4 * 2, then the default 1 * 2');
  });
}

LayoutDocument _page(Catalog catalog, {required double value}) => LayoutDocument.fromJson({
      'roots': ['c'],
      'nodes': {
        'c': {'type': 'stack', 'children': ['r'], 'layout': {'width': 300, 'height': 100}},
        'r': {
          'type': 'acme.rating',
          'layout': {'width': {'fixed': 120}, 'height': {'fixed': 24}, 'x': {'start': 0}, 'y': {'start': 0}},
          'props': {'value': value},
        },
      },
    }, catalog: catalog);

/// The icon glyph names the plugin node's tree shows, in order.
List<String> _glyphs(WidgetTester tester) {
  final inner = tester.widget<NodeView>(find.byType(NodeView).last).tree;
  return [
    for (var i = 1; i <= 5; i++) '${inner.boxOf('s$i')?.node?.prop(IconProps.icon)['name']}',
  ];
}
