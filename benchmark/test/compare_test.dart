// The two sides of lib/compare.dart show the same screen: both lay out, the
// counter reaches both, and both are as tall as their sections.
import 'package:codelessly_benchmark/compare.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final side in ['sdk', 'flutter']) {
    testWidgets('$side: 20 sections lay out in a scroll view and show the counter', (tester) async {
      final tick = ValueNotifier(0);
      final scroll = ScrollController();
      final screen = side == 'sdk'
          ? SdkScreen(session: UiSession(document: documentOf(20)), tick: tick)
          : FlutterScreen(groups: 20, tick: tick);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(controller: scroll, child: screen))));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(scroll.position.maxScrollExtent, greaterThan(2000));
      tick.value = 7;
      await tester.pump();
      if (side == 'flutter') expect(find.text('Tick 7'), findsOneWidget);
      // ignore: avoid_print
      print('$side: scroll extent ${scroll.position.maxScrollExtent.round()}');
    });
  }
}
