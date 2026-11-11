import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:codelessly_sdk/src/runtime/actions/ui.dart';

void main() {
  testWidgets('screen dialogs stay in the runtime navigator and leave with it', (tester) async {
    final root = GlobalKey<NavigatorState>(), nested = GlobalKey<NavigatorState>();
    final showing = ValueNotifier(true);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: root,
        home: ValueListenableBuilder<bool>(
          valueListenable: showing,
          builder: (_, value, _) => value
              ? Navigator(
                  key: nested,
                  onGenerateRoute: (_) => MaterialPageRoute<void>(
                    builder: (context) => Scaffold(
                      body: TextButton(
                        onPressed: () {
                          showScreenModal(context, const Text('Export progress'), sheetBelowWidth: 0);
                        },
                        child: const Text('Export'),
                      ),
                    ),
                  ),
                )
              : const Text('Editor'),
        ),
      ),
    );
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
    expect(find.text('Export progress'), findsOneWidget);
    expect(nested.currentState!.canPop(), isTrue);
    expect(root.currentState!.canPop(), isFalse);
    showing.value = false;
    await tester.pumpAndSettle();
    expect(find.text('Export progress'), findsNothing);
    expect(find.text('Editor'), findsOneWidget);
  });
}
