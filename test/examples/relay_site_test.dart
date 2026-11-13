// The Relay site (examples/relay-pricing: three pages sharing header, menu,
// footer, call to action, button and card components, and a theme) published
// as an app publishes it, served as a slug's bundle over HTTP, loaded by a
// real Codelessly + CodelesslyWidget (components through the loader, cached),
// then shown again offline from the cache alone.
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../tool/render/src/publish.dart';
import '../../tool/render/src/site.dart' show publishVariables;
import '../app/support.dart';

const dir = 'examples/relay-pricing';

Json read(String path) => jsonDecode(File('$dir/$path').readAsStringSync()) as Json;

/// The site published as written (schema 2), or its files rewritten as
/// schema 3 or 4 first ([schema] 4: what `tool/migrate.dart --write` does to
/// them).
PublishBundle publishRelay({int schema = 2}) {
  Json load(Json j) => switch (schema) {
        3 => migrateJson2to3(j)! as Json,
        4 => migrateJson(j)! as Json,
        _ => j,
      };
  final site = load(read('site.json'));
  final pages = [for (final p in (site['pages']! as List).cast<String>()) (name: p, json: load(read(p)))];
  final components = [
    for (final f in Directory('$dir/components').listSync().whereType<File>().toList()..sort((a, b) => a.path.compareTo(b.path)))
      load(jsonDecode(f.readAsStringSync()) as Json),
  ];
  return publishPages(pages,
          variables: publishVariables(site), components: components, theme: site['theme'] as Json?, projectId: 'relay')
      .bundle;
}

String textUnder(RenderObject box) {
  final out = <String>[];
  void visit(RenderObject o) {
    if (o is RenderParagraph) out.add(o.text.toPlainText());
    o.visitChildren(visit);
  }

  visit(box);
  return out.join(' | ');
}

void main() {
  testWidgets('published with its components, loaded over HTTP, then shown offline from the cache', (tester) async {
    setScreen(tester, const Size(390, 844));
    ignoreOverflows();
    final bundle = publishRelay();
    expect(bundle.model.components.keys, hasLength(14));
    expect(bundle.model.layouts['home']!.components, containsAll(['SiteHeader', 'MobileMenu', 'PageHero', 'Button', 'FeatureCard', 'Metric', 'FinalCta', 'SiteFooter']));
    final body = jsonEncode(bundle.toJson());
    var online = true;
    final requested = <String>[];
    final client = MockClient((req) async {
      requested.add(req.url.path);
      if (!online) throw const SocketException('offline');
      return req.url.path == '/publish/relay.json' ? http.Response.bytes(utf8.encode(body), 200) : http.Response('', 404);
    });
    final cache = MemoryPublishCache();
    Codelessly app() => Codelessly(
          config: const CodelesslyConfig(slug: 'relay'),
          loader: HttpPublishLoader(projectId: 'relay', baseUrl: 'https://cdn.test/', bundle: true, client: client),
          cache: cache,
          fonts: const NoFontFetcher(),
        );

    Future<CodelesslyWidgetController> show(Codelessly codelessly, String layout) async {
      final controller = CodelesslyWidgetController(layoutId: layout);
      addTearDown(controller.dispose);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(MaterialApp(home: CodelesslyWidget(codelessly: codelessly, controller: controller, layoutId: layout)));
      await settle(tester);
      return controller;
    }

    final first = app();
    addTearDown(first.dispose);
    var c = await show(first, 'home');
    expect(c.isLoaded, isTrue, reason: '${c.error}');
    expect(textUnder(c.tree!.boxAtPath('homeHero/phTitle')!), 'When systems break, teams move as one.');
    expect(textUnder(c.tree!.boxAtPath('homeFeature#1/fcTitle')!), 'Keep every handoff moving.');
    expect(textUnder(c.tree!.boxAtPath('homeSales')!), contains('Talk to sales'));
    expect(first.components.missing, isEmpty);
    expect(first.publishedComponents.keys, containsAll(['PageHero', 'FeatureCard', 'Button', 'SiteFooter']));
    expect(cache.entries.keys, contains('publish/relay/components/FeatureCard'));
    // Another page: the shared header and footer are not loaded again.
    final loadedBefore = Map.of(first.publishedComponents);
    c = await show(first, 'contact');
    expect(textUnder(c.tree!.boxAtPath('contactHero/phTitle')!), 'Plan a calmer response.');
    expect(identical(first.publishedComponents['SiteHeader'], loadedBefore['SiteHeader']), isTrue);

    // Offline, a new run: everything from the cache.
    online = false;
    requested.clear();
    final second = app();
    addTearDown(second.dispose);
    c = await show(second, 'home');
    expect(c.isLoaded, isTrue, reason: '${c.error}');
    expect(textUnder(c.tree!.boxAtPath('homeMetric#2/mValue')!), '100%');
    expect(textUnder(c.tree!.boxAtPath('homeFooter')!), contains('Stay ready for what comes next.'));
    expect(second.components.missing, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('schema 2 through the migrations, and schema 3 and 4 rewritten, render the same', (tester) async {
    setScreen(tester, const Size(390, 844));
    ignoreOverflows();
    Future<Map<String, String>> render(PublishBundle bundle, String layout) async {
      final codelessly = Codelessly(
          config: const CodelesslyConfig(slug: 'relay'), loader: MemoryPublishLoader(bundle), fonts: const NoFontFetcher());
      addTearDown(codelessly.dispose);
      final controller = CodelesslyWidgetController(layoutId: layout);
      addTearDown(controller.dispose);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(MaterialApp(home: CodelesslyWidget(codelessly: codelessly, controller: controller, layoutId: layout)));
      await settle(tester);
      expect(controller.isLoaded, isTrue, reason: '${controller.error}');
      final view = tester.renderObject(find.byType(CodelesslyWidget));
      final tree = controller.tree!;
      return {
        for (final b in tree.boxes.toList())
          if (b.rectIn(view) case final r?) '${b.key}': '$r',
        'text': textUnder(view),
      };
    }

    final two = publishRelay(), three = publishRelay(schema: 3), four = publishRelay(schema: 4);
    expect(three.toJson()['schema'], 3);
    for (final layout in two.model.layouts.keys) {
      final a = await render(two, layout);
      expect(a.length, greaterThan(20));
      expect(await render(three, layout), a, reason: layout);
      expect(await render(four, layout), a, reason: layout);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });
}
