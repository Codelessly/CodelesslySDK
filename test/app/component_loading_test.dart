// Published components (codelessly_api docs/design/06 §4.7): a publish lists
// its components (version, digest, fonts) and each layout the closure it
// calls; `Codelessly` loads a screen's closure through its PublishLoader
// before the screen shows, caches each component by its digest, opens on the
// cache offline, follows a republished component (every instance updates in
// place), and renders a missing component's calls empty until it arrives.
// Every loader: memory, asset bundle, HTTP (bundle and files), Firestore.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart' show GZipEncoder;

import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/firebase.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../tool/render/src/publish.dart';
import 'support.dart';

Json badge() => {
      'schema': 2,
      'id': 'Badge',
      'roots': ['b'],
      'widget': {
        'type': 'Badge',
        'props': [
          {'key': 'text', 'type': {'kind': 'string'}, 'default': ''},
        ],
      },
      'nodes': {
        'b': {
          'type': 'text',
          'props': {'text': r'${props.text}', 'style': {'fontFamily': 'Inter', 'fontWeight': 600}},
          'layout': {'width': {'hug': 40}, 'height': {'hug': 20}},
        },
      },
    };

Json card({String prefix = 'Card'}) => {
      'schema': 2,
      'id': 'Card',
      'roots': ['card'],
      'widget': {
        'type': 'Card',
        'props': [
          {'key': 'title', 'type': {'kind': 'string'}, 'default': ''},
        ],
      },
      'nodes': {
        'card': {
          'type': 'column',
          'children': ['t', 'tag'],
          'layout': {'width': 300, 'height': {'hug': 60}},
        },
        't': {
          'type': 'text',
          'props': {'text': '$prefix: \${props.title}'},
          'layout': {'width': {'hug': 40}, 'height': {'hug': 20}},
        },
        'tag': {'type': 'Badge', 'props': {'text': 'new'}, 'layout': {'width': 40, 'height': 20}},
      },
    };

Json home({List<String> calls = const ['c1', 'c2'], String type = 'Card'}) => {
      'schema': 2,
      'roots': ['home'],
      'nodes': {
        'home': {
          'type': 'canvas',
          'name': 'Home',
          'slots': {'body': 'col'},
          'layout': {'width': 390, 'height': 844},
        },
        'col': {
          'type': 'column',
          'children': calls,
          'layout': {'width': {'fill': 390}, 'height': {'fill': 844}},
        },
        for (final (i, c) in calls.indexed)
          c: {'type': type, 'props': {'title': 'T${i + 1}'}, 'layout': {'width': 300, 'height': {'hug': 60}}},
      },
    };

/// A published site: [pages] and [components], as the publish writes them.
PublishBundle publish(List<Json> pages, List<Json> components, {int version = 1}) => publishPages(
      [for (final (i, p) in pages.indexed) (name: 'page$i', json: p)],
      components: components,
      componentVersion: version,
      projectId: 'p',
    ).bundle;

/// The config of project `p` (what the cache keys name), recording
/// [analytics].
CodelesslyConfig cfg({AnalyticsService? analytics, bool liveUpdates = true}) =>
    CodelesslyConfig(projectId: 'p', liveUpdates: liveUpdates, services: analytics == null ? null : Services(analytics: analytics));

/// A cache whose reads and writes are counted.
class CountingCache extends MemoryPublishCache {
  final List<String> writes = [];
  @override
  Future<void> write(String key, Json value) {
    writes.add(key);
    return super.write(key, value);
  }
}

/// A loader that fails every call while [offline].
class FlakyLoader implements LivePublishLoader {
  FlakyLoader(this.inner);
  PublishLoader inner;
  bool offline = false;
  final Set<String> failing = {};

  /// Calls that fail the first time only.
  final Set<String> failOnce = {};
  final List<String> calls = [];
  final StreamController<PublishModel> models = StreamController.broadcast();

  Future<T> _go<T>(String call, Future<T> Function() f) {
    calls.add(call);
    if (offline || failing.contains(call) || failOnce.remove(call)) return Future.error(PublishLoadException('offline: $call'));
    return f();
  }

  @override
  Future<PublishModel> loadModel(PublishSource source) => _go('model', () => inner.loadModel(source));
  @override
  Future<PublishLayout> loadLayout(PublishSource source, String layoutId) => _go('layout:$layoutId', () => inner.loadLayout(source, layoutId));
  @override
  Future<PublishComponent> loadComponent(PublishSource source, String type) => _go('component:$type', () => inner.loadComponent(source, type));
  @override
  Stream<PublishModel> watchModel(PublishSource source) => models.stream;
}

/// The text of the first paragraph under the box at [path].
String textAt(CodelesslyWidgetController controller, String path) {
  final box = controller.tree!.boxAtPath(path);
  expect(box, isNotNull, reason: 'no box at $path: ${controller.tree!.boxes.map((b) => controller.tree!.pathOf(b.id, b.instance)).toList()}');
  RenderParagraph? found;
  void visit(RenderObject o) {
    if (o is RenderParagraph) found ??= o;
    o.visitChildren(visit);
  }

  visit(box!);
  return found?.text.toPlainText() ?? '';
}

Future<CodelesslyWidgetController> pumpApp(WidgetTester tester, Codelessly codelessly) async {
  final controller = CodelesslyWidgetController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(MaterialApp(home: CodelesslyWidget(codelessly: codelessly, controller: controller)));
  await settle(tester);
  return controller;
}

void main() {
  test('the publish lists each component (version, digest, fonts) and each layout its closure', () {
    final bundle = publish([home()], [card(), badge()]);
    final model = bundle.model;
    expect(model.components.keys, unorderedEquals(['Card', 'Badge']));
    final c = bundle.components['Card']!;
    expect(c.version, 1);
    expect(c.digest, componentDigest(c));
    expect(model.components['Card']!.digest, c.digest);
    expect(model.layouts['home']!.components, ['Card', 'Badge']);
    expect(model.components['Badge']!.fonts, ['Inter/600/false']);
    expect([for (final f in model.fontsOf('home')) f.family], contains('Inter'), reason: 'the fonts of called components load with the layout');
    // The bundle round-trips as JSON (what a slug serves).
    final again = PublishBundle.fromJson(jsonDecode(jsonEncode(bundle.toJson())));
    expect(again.components['Card']!.digest, c.digest);
    expect(componentIntact(again.components['Card']!), isTrue);
  });

  testWidgets('a published site with components just works: its closure loads with the screen, then serves from the cache', (tester) async {
    setScreen(tester, const Size(390, 844));
    final bundle = publish([home()], [card(), badge()]);
    final loader = MemoryPublishLoader(bundle);
    final cache = CountingCache();
    final app = Codelessly(loader: loader, cache: cache, fonts: const NoFontFetcher(), config: cfg());
    addTearDown(app.dispose);
    final controller = await pumpApp(tester, app);
    expect(textAt(controller, 'c1'), 'Card: T1');
    expect(textAt(controller, 'c2/t'), 'Card: T2');
    expect(textAt(controller, 'c2/tag'), 'new');
    expect(loader.calls.where((c) => c.startsWith('component:')), unorderedEquals(['component:publish:Card', 'component:publish:Badge']),
        reason: 'each component loads once for its two instances');
    expect(app.components.missing, isEmpty);
    expect(cache.entries.keys, containsAll(['publish/p/components/Card', 'publish/p/components/Badge']));

    // Offline, next run: the model, the layout and its components from the cache.
    final offline = FlakyLoader(loader)..offline = true;
    final again = Codelessly(loader: offline, cache: cache, fonts: const NoFontFetcher(), config: cfg());
    addTearDown(again.dispose);
    final c2 = await pumpApp(tester, again);
    expect(textAt(c2, 'c1/t'), 'Card: T1');
    expect(textAt(c2, 'c1/tag'), 'new');
    expect(offline.calls.where((c) => c.startsWith('component:')), isEmpty, reason: 'fresh by digest: not fetched');
    expect(again.components.missing, isEmpty);
  });

  test('a cached component with another digest than the model lists is fetched again; a tampered one is refused', () async {
    final v1 = publish([home()], [card(), badge()]);
    final v2 = publish([home()], [card(prefix: 'New'), badge()], version: 2);
    final cache = MemoryPublishCache();
    final first = Codelessly(loader: MemoryPublishLoader(v1), cache: cache, fonts: const NoFontFetcher(), config: cfg());
    addTearDown(first.dispose);
    await first.loadLayout('home');
    expect(first.publishedComponents['Card']!.version, 1);
    // The next run opens on the cached (v1) model, refreshes it in the
    // background and finds Card republished.
    final loader = MemoryPublishLoader(v2);
    final second = Codelessly(loader: loader, cache: cache, fonts: const NoFontFetcher(), config: cfg());
    addTearDown(second.dispose);
    await second.loadComponent('Card');
    await pumpEventQueue(times: 50);
    expect(second.publishedComponents['Card']!.version, 2);
    expect(second.components['Card']!.document['t']!.prop(TextProps.text), startsWith('New'));
    expect(loader.calls, contains('component:publish:Card'));
    expect(loader.calls, isNot(contains('component:publish:Badge')), reason: 'its digest did not change');

    // A stored component whose document isn't what its digest says.
    final tampered = v1.components['Card']!.copyWith(document: LayoutDocument.fromJson(card(prefix: 'Evil')));
    final bad = PublishBundle(model: v1.model, layouts: v1.layouts, components: {...v1.components, 'Card': tampered});
    final analytics = RecordingAnalytics();
    final third = Codelessly(loader: MemoryPublishLoader(bad), fonts: const NoFontFetcher(), config: cfg(analytics: analytics));
    addTearDown(third.dispose);
    expect(await third.loadComponent('Card'), isNull);
    expect(third.components['Card'], isNull);
    expect(analytics.errors, contains('component_missing'));
  });

  testWidgets('live: a republished component updates every instance in place', (tester) async {
    setScreen(tester, const Size(390, 844));
    final v1 = publish([home()], [card(), badge()]);
    final v2 = publish([home()], [card(prefix: 'Fresh'), badge()], version: 2);
    final loader = FlakyLoader(MemoryPublishLoader(v1));
    final app = Codelessly(loader: loader, fonts: const NoFontFetcher(), config: cfg());
    addTearDown(app.dispose);
    final controller = await pumpApp(tester, app);
    final box = controller.tree!.boxAtPath('c1/t');
    expect(textAt(controller, 'c1/t'), 'Card: T1');
    // The publish of a new version of Card: the model's entry changes.
    loader.inner = MemoryPublishLoader(v2);
    loader.models.add(v2.model);
    await settle(tester);
    expect(textAt(controller, 'c1/t'), 'Fresh: T1');
    expect(textAt(controller, 'c2/t'), 'Fresh: T2');
    expect(identical(controller.tree!.boxAtPath('c1/t'), box), isTrue, reason: 'updated in place, not rebuilt');
    expect(loader.calls.where((c) => c == 'component:Badge'), hasLength(1), reason: 'Badge did not change');
    expect(loader.calls.where((c) => c.startsWith('layout:')), hasLength(1), reason: 'the page calling it did not reload');
  });

  testWidgets('a component that fails to load: its calls render empty and are logged; they render when it arrives', (tester) async {
    setScreen(tester, const Size(390, 844));
    final bundle = publish([home()], [card(), badge()]);
    final loader = FlakyLoader(MemoryPublishLoader(bundle))..failing.add('component:Badge');
    final analytics = RecordingAnalytics();
    final app = Codelessly(loader: loader, fonts: const NoFontFetcher(), config: cfg(analytics: analytics));
    addTearDown(app.dispose);
    final controller = await pumpApp(tester, app);
    expect(textAt(controller, 'c1/t'), 'Card: T1');
    expect(app.components.missing.keys, contains('Badge'));
    expect(analytics.errors, contains('component_missing'));
    expect(controller.tree!.boxAtPath('c1/tag')!.size, isNot(Size.zero), reason: "the call's empty box of its size");
    // The network is back.
    loader.failing.clear();
    await app.loadComponent('Badge');
    await settle(tester);
    expect(textAt(controller, 'c1/tag'), 'new');
    expect(textAt(controller, 'c2/tag'), 'new');
  });

  testWidgets('a call rendered without its definition fetches it when the publish lists it, and renders when it arrives', (tester) async {
    setScreen(tester, const Size(390, 844));
    final bundle = publish([home()], [card(), badge()]);
    // A model whose layout entry doesn't list its closure (an older publish
    // writer): Card is found in the layout, Badge in Card; Badge fails once.
    final model = bundle.model.copyWith(layouts: {
      for (final e in bundle.model.layouts.entries)
        e.key: PublishLayoutInfo.fromJson({...e.value.toJson()..remove('components')}, id: e.key)!,
    });
    final loader = FlakyLoader(MemoryPublishLoader(PublishBundle(model: model, layouts: bundle.layouts, components: bundle.components)))
      ..failOnce.add('component:Badge');
    final analytics = RecordingAnalytics();
    final app = Codelessly(loader: loader, fonts: const NoFontFetcher(), config: cfg(analytics: analytics));
    addTearDown(app.dispose);
    final controller = await pumpApp(tester, app);
    await settle(tester);
    expect(textAt(controller, 'c1/t'), 'Card: T1');
    expect(textAt(controller, 'c1/tag'), 'new');
    expect(textAt(controller, 'c2/tag'), 'new');
    expect(loader.calls.where((c) => c == 'component:Badge'), hasLength(2));
    expect(analytics.errors, contains('component_missing'), reason: 'the first failure is logged');
  });

  test('the asset loader reads the components of a bundle shipped with the app', () async {
    final bundle = publish([home()], [card(), badge()]);
    final assets = _Assets({'assets/site.json': utf8.encode(jsonEncode(bundle.toJson()))});
    final app = Codelessly(loader: AssetPublishLoader('assets/site.json', bundle: assets), fonts: const NoFontFetcher(), config: cfg());
    addTearDown(app.dispose);
    await app.loadLayout('home');
    expect(app.components['Card'], isNotNull);
    expect(app.components['Badge'], isNotNull);
    expect(app.publishedComponents['Card']!.digest, bundle.components['Card']!.digest);
  });

  test('HTTP: a slug\'s bundle, and the files of a self-hosted mirror', () async {
    final bundle = publish([home()], [card(), badge()]);
    final requested = <String>[];
    final files = <String, Object?>{
      'publish/site.json': bundle.toJson(),
      'publish/p.json': bundle.model.toJson(),
      for (final l in bundle.layouts.values) 'publish/p/layouts/${l.id}.json': l.toJson(),
      for (final c in bundle.components.values) 'publish/p/components/${c.id}.json': c.toJson(),
    };
    final client = MockClient((req) async {
      final path = req.url.path.substring(1);
      requested.add(path);
      final body = files[path];
      return body == null ? http.Response('', 404) : http.Response(jsonEncode(body), 200);
    });
    final slug = Codelessly(
        loader: HttpPublishLoader(projectId: 'site', baseUrl: 'https://cdn.test/', bundle: true, client: client), fonts: const NoFontFetcher(), config: cfg());
    addTearDown(slug.dispose);
    await slug.loadLayout('home');
    expect(slug.components['Badge'], isNotNull);
    expect(requested, ['publish/site.json'], reason: 'one file');

    requested.clear();
    final mirror = Codelessly(loader: HttpPublishLoader(projectId: 'p', baseUrl: 'https://cdn.test/', client: client), fonts: const NoFontFetcher(), config: cfg());
    addTearDown(mirror.dispose);
    await mirror.loadLayout('home');
    expect(mirror.components['Card'], isNotNull);
    expect(requested, containsAll(['publish/p.json', 'publish/p/layouts/home.json', 'publish/p/components/Card.json', 'publish/p/components/Badge.json']));
    expect(
        () => HttpPublishLoader(projectId: 'p', baseUrl: 'https://cdn.test/', client: client).loadComponent(PublishSource.publish, 'Nope'),
        throwsA(isA<PublishLoadException>()));
  });

  test('Firestore: each component at publish/{p}/components/{type}, a large one compressed', () async {
    final bundle = publish([home()], [card(), badge()]);
    final FirebaseFirestore db = FakeFirebaseFirestore();
    await db.doc('publish/p').set({...bundle.model.toJson(), 'schema': 2});
    for (final l in bundle.layouts.values) {
      await db.doc('publish/p/layouts/${l.id}').set({...l.toJson(), 'schema': 2});
    }
    await db.doc('publish/p/components/Card').set(bundle.components['Card']!.toJson());
    // The editor compresses a document too large for Firestore as it does a
    // layout's nodes.
    final b = bundle.components['Badge']!.toJson();
    final doc = b.remove('document');
    b['compressedDocument'] = base64Encode(gzipJson(doc));
    await db.doc('publish/p/components/Badge').set(b);

    final loader = FirestorePublishLoader(db, projectId: 'p');
    final card0 = await loader.loadComponent(PublishSource.publish, 'Card');
    expect(card0.id, 'Card');
    expect(componentIntact(card0), isTrue);
    final badge0 = await loader.loadComponent(PublishSource.publish, 'Badge');
    expect(componentIntact(badge0), isTrue);
    expect(badge0.document.componentRoot, 'b');
    await expectLater(loader.loadComponent(PublishSource.publish, 'Nope'), throwsA(isA<PublishLoadException>()));
    await db.doc('publish/p/components/Old').set({'id': 'Old', 'document': card()});
    await expectLater(loader.loadComponent(PublishSource.publish, 'Old'), throwsA(isA<PublishLoadException>()),
        reason: 'not in the current format (no schema)');

    final app = Codelessly(loader: loader, fonts: const NoFontFetcher(), config: cfg());
    addTearDown(app.dispose);
    await app.loadLayout('home');
    expect(app.components['Card'], isNotNull);
    expect(app.components['Badge'], isNotNull);
  });

  test('a component the app defines itself wins over the published one', () async {
    final bundle = publish([home()], [card(), badge()]);
    final loader = MemoryPublishLoader(bundle);
    final own = ComponentRegistry([LayoutDocument.fromJson(card(prefix: 'Mine'))]);
    final app = Codelessly(loader: loader, components: own, fonts: const NoFontFetcher(), config: cfg());
    addTearDown(app.dispose);
    await app.loadLayout('home');
    expect(loader.calls, isNot(contains('component:publish:Card')));
    expect(loader.calls, contains('component:publish:Badge'));
    expect(own['Card']!.document['t']!.prop(TextProps.text), startsWith('Mine'));
  });
}

List<int> gzipJson(Object? json) => const GZipEncoder().encodeBytes(utf8.encode(jsonEncode(json)));

class _Assets extends CachingAssetBundle {
  _Assets(this.files);
  final Map<String, List<int>> files;
  @override
  Future<ByteData> load(String key) async {
    final f = files[key];
    if (f == null) throw FlutterError('no asset $key');
    return ByteData.sublistView(Uint8List.fromList(f));
  }
}
