import 'dart:convert';
import 'dart:io';

import 'package:codelessly_genui/codelessly_genui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('weight loss surface renders and recomputes', (tester) async {
    tester.view.physicalSize = const Size(440, 1000);
    tester.view.devicePixelRatio = 1;
    final session = GenUiSession(theme: const GenUiTheme(fontFamily: 'GenUiTestSans'));
    final List messages = jsonDecode(File('test/fixtures/weight_loss.json').readAsStringSync());
    final issues = session.apply(messages);
    print('issues: $issues');
    print('check: ${session.check(messages)}');
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(12), child: GenUiSurfaceView(surface: session.surfaces.value.single)))));
    await tester.pumpAndSettle();
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/smoke.png'));
    print(session.dataModelOf('wl'));
  });
}
