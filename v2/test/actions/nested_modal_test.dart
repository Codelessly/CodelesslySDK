import 'package:codelessly_sdk_v2/src/runtime/actions/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('screen dialogs stay inside the hosted navigator and its localizations', (tester) async {
    final outer = GlobalKey<NavigatorState>(), inner = GlobalKey<NavigatorState>();
    Object? result;
    await tester.pumpWidget(WidgetsApp(
      color: Colors.black,
      navigatorKey: outer,
      onGenerateRoute: (_) => PageRouteBuilder<void>(pageBuilder: (context, _, _) =>
        Localizations.override(
          context: context,
          delegates: const [DefaultMaterialLocalizations.delegate],
          child: Theme(data: ThemeData(), child: Navigator(
            key: inner,
            onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (context) => Material(
              child: TextButton(onPressed: () async {
                result = await showScreenModal(context,
                  const SizedBox(width: 280, height: 100, child: TextField()), sheetBelowWidth: 600);
              }, child: const Text('Open')),
            )),
          )),
        )),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsOneWidget);
    expect(inner.currentState!.canPop(), isTrue);
    expect(outer.currentState!.canPop(), isFalse);
    inner.currentState!.pop('saved');
    await tester.pumpAndSettle();
    expect(result, 'saved');
  });
}
