// The playground reads what is typed and shows it: a sample renders, an
// edit redraws, a line that cannot be read is reported with the rest still
// shown, and another design system redraws the same text.
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playground/main.dart';
import 'package:soft_saas_ui/soft_saas_ui.dart';

/// Every text painted under [root], render objects included (the SDK draws
/// text without a Text widget).
String _painted(WidgetTester tester) {
  final out = StringBuffer();
  void visit(RenderObject o) {
    if (o is RenderParagraph) out.writeln(o.text.toPlainText());
    if (o is RenderEditable) out.writeln(o.text?.toPlainText() ?? '');
    o.visitChildren(visit);
  }

  visit(tester.renderObject(find.byType(SoftSaaSApp)));
  return out.toString();
}

void main() {
  testWidgets('a sample renders, an edit redraws, an unreadable line is reported, a design system switches', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(PlaygroundApp(loadAsset: (key) => File(key).readAsString()));
      // The three design systems load from files; wait for the first reading.
      for (var i = 0; i < 100 && find.byKey(const Key('stats')).evaluate().isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      }
    });
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(_painted(tester), contains('Start here'));
    expect(_painted(tester), contains('Every line was read'));
    expect(tester.widget<Text>(find.byKey(const Key('stats'))).data, matches(r'^\d+ nodes · \d+ characters written · \d+ as a document$'));

    // An edit redraws after the pause.
    final editor = find.byKey(const Key('editor'));
    final text = tester.widget<SoftSaaSCodeField>(editor).controller!;
    text.text = text.text.replaceFirst('"Start here"', '"Edited title"');
    await tester.pump(const Duration(milliseconds: 300));
    expect(_painted(tester), contains('Edited title'));

    // A line that cannot be read is said; the rest is still shown.
    text.text = '${text.text}\n  Button.nope "Odd"\n';
    await tester.pump(const Duration(milliseconds: 300));
    expect(_painted(tester), contains('1 not read'));
    expect(_painted(tester), contains('No Button.nope'));
    expect(_painted(tester), contains('Edited title'));

    // Another design system, the same text.
    await tester.tap(find.text('Paper'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(_painted(tester), contains('Edited title'));

    // The document it expands to.
    await tester.tap(find.text('Document'));
    await tester.pump();
    expect(_painted(tester), contains('"schema": 3'));
  });
}
