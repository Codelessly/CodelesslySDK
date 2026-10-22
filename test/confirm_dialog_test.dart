import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<bool?> showAndAnswer(
    WidgetTester tester,
    ConfirmAction action,
    String answer,
  ) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                result = await AppConfirmDialog.show(context, action),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(answer));
    await tester.pumpAndSettle();
    return result;
  }

  final ConfirmAction action = ConfirmAction(
    title: 'Leave album?',
    message: 'You can join again later.',
    confirmLabel: 'Leave',
    destructive: true,
  );

  testWidgets('confirming completes with true', (tester) async {
    expect(await showAndAnswer(tester, action, 'Leave'), isTrue);
  });

  testWidgets('cancelling completes with false', (tester) async {
    expect(await showAndAnswer(tester, action, 'Cancel'), isFalse);
  });

  testWidgets('shows the title and message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => AppConfirmDialog.show(context, action),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Leave album?'), findsOneWidget);
    expect(find.text('You can join again later.'), findsOneWidget);
  });
}
