// The shell runs the generated screens as one app: the store's values reach
// every screen, a screen's events navigate, a finished session changes what
// the next screen shows, and the person switch changes the screen and its look.
import 'dart:io';

import 'package:codelessly_sdk/codelessly_sdk.dart' show UiEvent;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skip_shell/main.dart';
import 'package:skip_shell/skip_app.dart';
import 'package:soft_saas_ui/soft_saas_ui.dart';

String _painted(WidgetTester tester) {
  final out = StringBuffer();
  void visit(RenderObject o) {
    if (o is RenderParagraph) out.writeln(o.text.toPlainText());
    o.visitChildren(visit);
  }

  visit(tester.renderObject(find.byType(SoftSaaSApp)));
  return out.toString();
}

void main() {
  test('the store: a finished session is added, and the streak and the week follow', () async {
    final app = SkipApp((key) => File(key).readAsString());
    await app.start();
    expect(app.screen, 'home');
    expect(app.data['streak'], 4);
    app.handle(const UiEvent(event: 'start_session'));
    expect(app.screen, 'session');
    app.handle(const UiEvent(event: 'finish_session', value: 25));
    expect(app.data['streak'], 5);
    expect(app.data['sessionsThisWeek'], 4);
    expect(((app.data['sessions']! as List).first as Map)['jumps'], 25);
    app.handle(const UiEvent(event: 'open_history'));
    expect(app.screen, 'history');
    expect(app.log.map((l) => l.text), ['open_history', 'finish_session 25', 'start_session']);
    app.dispose();
  });

  testWidgets('the screens show the store, and each person gets their own screen', (tester) async {
    // The test font draws every glyph a full em wide, so a row of a generated
    // screen that fits in the real fonts overflows here: only that is let by.
    final old = FlutterError.onError;
    FlutterError.onError = (d) => d.exceptionAsString().contains('overflowed') ? null : old?.call(d);
    addTearDown(() => FlutterError.onError = old);
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(ShellApp(loadAsset: (key) => File(key).readAsString()));
      for (var i = 0; i < 100 && find.byType(SoftSaaSSpinner).evaluate().isNotEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      }
    });
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(_painted(tester), contains('Streak 4 · 4 sessions in the store'));
    final home = _painted(tester);
    await tester.tap(find.text('Kid'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(_painted(tester), isNot(home), reason: 'the kid has their own Home');
    await tester.tap(find.text('History'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });
}
