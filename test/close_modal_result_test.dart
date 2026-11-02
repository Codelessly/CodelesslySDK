import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  Future<Object?> closeWith(WidgetTester tester, CloseModalAction close) async {
    Object? result = 'not closed';
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty(),
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showDialog<Object?>(
                  context: context,
                  builder: (dialogContext) => TextButton(
                    onPressed: () =>
                        FunctionsRepository.performAction(dialogContext, close),
                    child: const Text('Close'),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Close'), findsNothing);
    return result;
  }

  testWidgets('closeModal hands its params back to the opener', (
    tester,
  ) async {
    expect(
      await closeWith(
        tester,
        CloseModalAction(params: {'passed': true, 'answer': 12}),
      ),
      {'passed': true, 'answer': 12},
    );
  });

  testWidgets('closeModal without params returns nothing', (tester) async {
    expect(await closeWith(tester, CloseModalAction()), isNull);
  });
}
