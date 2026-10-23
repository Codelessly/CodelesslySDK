import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Future<void> show(
  WidgetTester tester,
  ShowToastAction action,
  Size size,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  late BuildContext context;
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: CodelesslyContext.empty(),
      child: MaterialApp(
        home: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    ),
  );
  FunctionsRepository.triggerAction(
    context,
    TriggerType.click,
    reactions: [
      Reaction(
        action: action,
        trigger: TriggerModel(type: TriggerType.click),
      ),
    ],
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

Rect toastRect(WidgetTester tester) => tester.getRect(
  find
      .ancestor(of: find.text('Dump logged'), matching: find.byType(Container))
      .first,
);

void main() {
  testWidgets('an end-aligned toast sits against the right margin', (
    tester,
  ) async {
    await show(
      tester,
      ShowToastAction(
        message: 'Dump logged',
        alignment: ToastAlignment.end,
        sideMargin: 24,
        maxWidth: 420,
        bottomOffset: 24,
        cornerRadius: 4,
        showCloseButton: true,
        fontSize: 13,
        duration: 5000,
      ),
      const Size(1440, 900),
    );
    final Rect rect = toastRect(tester);
    expect(rect.right, closeTo(1440 - 24, 0.5));
    expect(rect.bottom, closeTo(900 - 24, 0.5));
    expect(rect.width, lessThanOrEqualTo(420));
    expect(
      find.byKey(const ValueKey('codelessly-toast-close')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('codelessly-toast-close')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Dump logged'), findsNothing);
  });

  testWidgets('a stretched toast spans the margins', (tester) async {
    await show(
      tester,
      ShowToastAction(
        message: 'Dump logged',
        alignment: ToastAlignment.stretch,
        bottomOffset: 76,
        duration: 1000,
      ),
      const Size(390, 844),
    );
    final Rect rect = toastRect(tester);
    expect(rect.left, closeTo(16, 0.5));
    expect(rect.right, closeTo(390 - 16, 0.5));
    expect(rect.bottom, closeTo(844 - 76, 0.5));
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('the button label takes the action color', (tester) async {
    await show(
      tester,
      ShowToastAction(
        message: 'Dump logged',
        actionLabel: 'UNDO',
        actionColor: const ColorRGBA(r: 0.76, g: 0.33, b: 0, a: 1),
        duration: 1000,
      ),
      const Size(390, 844),
    );
    final TextButton button = tester.widget(find.byType(TextButton));
    expect(
      button.style!.foregroundColor!.resolve({})!.toARGB32(),
      const ColorRGBA(r: 0.76, g: 0.33, b: 0, a: 1).toFlutterColor().toARGB32(),
    );
    await tester.pump(const Duration(seconds: 2));
  });
}
