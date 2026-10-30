import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Close Modal closes every dialog presentation, including full-screen and
/// popover dialogs, which open with showGeneralDialog.
void main() {
  Future<void> openAndClose(
    WidgetTester tester,
    Future<void> Function(BuildContext context, WidgetBuilder content) open,
  ) async {
    late BuildContext home;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            home = context;
            return const SizedBox();
          },
        ),
      ),
    );
    BuildContext? inside;
    open(home, (context) {
      inside = context;
      return const Text('dialog');
    });
    await tester.pumpAndSettle();
    expect(find.text('dialog'), findsOneWidget);
    FunctionsRepository.performAction(inside!, CloseModalAction());
    await tester.pumpAndSettle();
    expect(find.text('dialog'), findsNothing);
  }

  testWidgets('a dialog', (tester) async {
    await openAndClose(
      tester,
      (context, content) => showDialog(context: context, builder: content),
    );
  });

  testWidgets('a full-screen dialog', (tester) async {
    await openAndClose(
      tester,
      (context, content) => showGeneralDialog(
        context: context,
        pageBuilder: (context, _, _) => Builder(builder: content),
      ),
    );
  });
}
