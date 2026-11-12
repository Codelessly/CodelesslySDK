// Northstar v2's Event screen at desktop: a start-aligned row (content and
// a side panel) whose content column holds a row that hugs its height and
// stretches its children (the observing tip). With a two-line tip the tip
// row must be as tall as its text: no overflow.
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('desktop event: a two-line tip fits its hugging row', (tester) async {
    tester.view.physicalSize = const Size(1440, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final json = jsonDecode(File('test/fixtures/event_desktop_tip.json').readAsStringSync()) as Map<String, Object?>;
    final tree = NodeTree(DocumentSource(LayoutDocument.fromJson(json)));
    addTearDown(tree.dispose);
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    await tester.pumpWidget(MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 1360, height: 800, child: NodeView(tree: tree, rootId: (json['roots'] as List).first as String)),
      ),
    ));
    await tester.pump();
    FlutterError.onError = previous;
    expect(errors.map((e) => e.exceptionAsString()).where((m) => m.contains('overflowed')), isEmpty);
  });

  for (final midLayout in [false, true]) {
    testWidgets('desktop event: the tip grows to two lines${midLayout ? ' mid-layout' : ''}, its row follows', (tester) async {
      tester.view.physicalSize = const Size(1440, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final long = jsonDecode(File('test/fixtures/event_desktop_tip.json').readAsStringSync()) as Map<String, Object?>;
      Map<String, Object?> withTip(String tip) {
        final copy = jsonDecode(jsonEncode(long)) as Map<String, Object?>;
        for (final n in (copy['nodes'] as Map).values.cast<Map>()) {
          final props = n['props'];
          if (props is Map && '${props['text']}'.startsWith('Lie back')) props['text'] = tip;
        }
        return copy;
      }
      final source = DocumentSource(LayoutDocument.fromJson(withTip("It moves steadily and never blinks. If it flashes, it's a plane.")));
      final tree = NodeTree(source);
      addTearDown(tree.dispose);
      final errors = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = errors.add;
      var change = false;
      await tester.pumpWidget(MaterialApp(
        home: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 1360, height: 800, child: NodeView(tree: tree, rootId: (long['roots'] as List).first as String)),
          LayoutBuilder(builder: (context, _) {
            if (change) {
              change = false;
              source.document = LayoutDocument.fromJson(long);
            }
            return const SizedBox.shrink();
          }),
        ]),
      ));
      if (midLayout) {
        change = true;
        tester.element(find.byType(LayoutBuilder)).markNeedsBuild();
      } else {
        source.document = LayoutDocument.fromJson(long);
      }
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      FlutterError.onError = previous;
      expect(errors.map((e) => e.exceptionAsString()).where((m) => m.contains('overflowed')), isEmpty);
    });
  }

  for (final start in ['none', 'iss']) {
    testWidgets('desktop event, bound: ev from $start to the Leonids, the tip row follows', (tester) async {
      tester.view.physicalSize = const Size(1440, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final fx = jsonDecode(File('test/fixtures/event_desktop_bound.json').readAsStringSync()) as Map<String, Object?>;
      final doc = fx['doc'] as Map<String, Object?>;
      final vars = ValuesScope({
        'pal': fx['pal'],
        'screen': {...screenValues(1360, 800), 'backdrop': false},
        'ev': start == 'iss' ? fx['iss'] : null,
        'favIds': const <Object?>[],
        'locked': false,
        'loadState': 'ready',
      });
      addTearDown(vars.dispose);
      final tree = NodeTree(DocumentSource(LayoutDocument.fromJson(doc)), binder: NodeBinder(scope: vars));
      addTearDown(tree.dispose);
      final errors = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = errors.add;
      await tester.pumpWidget(MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 1360, height: 800, child: NodeView(tree: tree, rootId: (doc['roots'] as List).first as String)),
        ),
      ));
      vars.set('ev', fx['leonids']);
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      FlutterError.onError = previous;
      expect(errors.map((e) => e.exceptionAsString()).where((m) => m.contains('overflowed')), isEmpty);
      final view = tester.renderObject(find.byType(NodeView));
      final row = tree.boxOf('ho204jxrko-6w')!.rectIn(view)!;
      final tip = tree.boxOf('ho204jxrko-72')!.rectIn(view)!;
      expect(tip.height, greaterThan(30), reason: 'two lines');
      expect(tip.bottom, lessThanOrEqualTo(row.bottom), reason: 'the tip row holds its text');
    });
  }
}
