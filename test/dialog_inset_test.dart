import 'package:codelessly_sdk/src/ui/codelessly_dialog_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a dialog taller than the screen stops short of its edges', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: CodelesslyDialogWidget(
          showCloseButton: false,
          useDefaultInset: true,
          builder: (_) =>
              const SizedBox(key: Key('form'), width: 640, height: 2000),
        ),
      ),
    );
    final Rect form = tester.getRect(find.byKey(const Key('form')));
    expect(form.top, CodelesslyDialogWidget.inset);
    expect(form.bottom, 900 - CodelesslyDialogWidget.inset);
    expect(form.width, 640);
  });

  testWidgets('a short dialog stays centered at its size', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: CodelesslyDialogWidget(
          showCloseButton: false,
          useDefaultInset: true,
          builder: (_) =>
              const SizedBox(key: Key('form'), width: 400, height: 300),
        ),
      ),
    );
    expect(
      tester.getRect(find.byKey(const Key('form'))),
      Rect.fromCenter(center: const Offset(720, 450), width: 400, height: 300),
    );
  });
}
