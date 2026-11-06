import 'dart:io';

import 'package:codelessly_api/genscreen.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

/// Answers from a script and counts calls.
class ScriptedSource implements ScreenPlanSource {
  final List<String> answers;
  int calls = 0;
  final List<List<PlanTurn>> seen = [];
  ScriptedSource(this.answers);

  @override
  Future<String> complete({required String system, required List<PlanTurn> turns}) async {
    seen.add(List.of(turns));
    return answers[calls++];
  }
}

void main() {
  setUpAll(() {
    SvgIcon.httpClient = MockClient((_) async => http.Response(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><circle cx="12" cy="12" r="8"/></svg>',
      200,
    ));
  });
  final String kit = File('test/fixtures/genscreen/aurora.design.md').readAsStringSync();
  final String plan = File('test/fixtures/genscreen/album_details.json').readAsStringSync();

  test('generates once per prompt and kit version, then reads the cache', () async {
    final ScriptedSource source = ScriptedSource([plan]);
    final RuntimeScreenGenerator generator = RuntimeScreenGenerator(source: source, kits: {'aurora': kit});
    final CompiledScreen first = await generator.generate('Album details page');
    final CompiledScreen again = await generator.generate('  album DETAILS page ');
    expect(first.title, 'Album details');
    expect(again.title, 'Album details');
    expect(source.calls, 1);
  });

  test('a new kit version generates again', () async {
    final ScriptedSource source = ScriptedSource([plan, plan]);
    final GeneratedScreenCache cache = GeneratedScreenCache();
    await RuntimeScreenGenerator(source: source, kits: {'k': kit}, cache: cache).generate('Album');
    await RuntimeScreenGenerator(source: source, kits: {'k': kit.replaceFirst('version: 1.0.0', 'version: 1.1.0')}, cache: cache)
        .generate('Album');
    expect(source.calls, 2);
  });

  test('an invalid plan gets one fix round with the validator\'s words', () async {
    final ScriptedSource source = ScriptedSource(['{"title": "Broken", "sections": []}', plan]);
    final CompiledScreen screen = await RuntimeScreenGenerator(source: source, kits: {'k': kit}).generate('Album');
    expect(screen.title, 'Album details');
    expect(source.calls, 2);
    expect(source.seen.last.last.text, contains('A plan needs at least one section'));
  });

  test('persists plans through the host store', () async {
    final Map<String, String> store = {};
    GeneratedScreenCache cache() => GeneratedScreenCache(load: (k) => store[k], save: (k, v) => store[k] = v);
    final ScriptedSource source = ScriptedSource([plan]);
    await RuntimeScreenGenerator(source: source, kits: {'k': kit}, cache: cache()).generate('Album');
    await RuntimeScreenGenerator(source: source, kits: {'k': kit}, cache: cache()).generate('Album');
    expect(store, hasLength(1));
    expect(source.calls, 1);
  });

  testWidgets('generateScreen opens the screen and its actions run', (tester) async {
    final ScriptedSource source = ScriptedSource([plan]);
    final RuntimeScreenGenerator generator = RuntimeScreenGenerator(source: source, kits: {'aurora': kit});
    final CodelesslyContext context = CodelesslyContext.empty();
    generator.register(context);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: context,
        child: MaterialApp(
          home: Builder(
            builder: (c) => TextButton(
              onPressed: () => context.functions['generateScreen']!(c, context, {'prompt': 'Album details page'}),
              child: const Text('Make it'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Make it'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    // Text in a fixture font the test can't load still lays out by its data.
    expect(find.textContaining('Northbound', findRichText: true), findsWidgets);
    expect(find.textContaining('Glass Harbor', findRichText: true), findsWidgets);
    while (tester.takeException() != null) {}
  });

  testWidgets('a generated button reaches the app\'s functions', (tester) async {
    const String pingPlan = '''{
      "title": "Ping", "variables": [],
      "sections": [{"children": [
        {"type": "button", "label": "Ping", "action": {"type": "call", "name": "ping", "params": {"from": "generated"}}}
      ]}],
      "states": {"loading": {}, "error": {"title": "Oops"}}
    }''';
    final Map<String, dynamic> received = {};
    final RuntimeScreenGenerator generator = RuntimeScreenGenerator(source: ScriptedSource([pingPlan]), kits: {'k': kit});
    final CompiledScreen screen = (await tester.runAsync(() => generator.generate('Ping')))!;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GeneratedScreenView(
          screen: screen,
          functions: {'ping': (context, ref, params) => received.addAll(params)},
        ),
      ),
    ));
    await tester.pump();
    await tester.tap(find.textContaining('Ping', findRichText: true).last);
    await tester.pump(const Duration(milliseconds: 100));
    expect(received, {'from': 'generated'});
    while (tester.takeException() != null) {}
  });
}
