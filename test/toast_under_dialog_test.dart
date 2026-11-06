import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A toast is up when the layout opens a dialog in its own navigator
/// (nested under the app's, as a Codelessly layout is). The toast lives in
/// the root overlay, above that navigator, so the dialog's barrier can't
/// cover it in paint order: it paints the barrier over itself instead, as
/// an app's toast layer under its dialogs would look, and lets taps through
/// to the barrier until the dialog closes.
void main() {
  Future<BuildContext> pumpPage(WidgetTester tester) async {
    late BuildContext page;
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty(),
        child: MaterialApp(
          home: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (c) {
                page = c;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      ),
    );
    return page;
  }

  /// The barrier colours painted over the toast's card.
  List<Color> coversOnToast(WidgetTester tester) => [
    for (final DecoratedBox box in tester.widgetList<DecoratedBox>(
      find.ancestor(
        of: find.text('Saved'),
        matching: find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              w.position == DecorationPosition.foreground &&
              (w.decoration as BoxDecoration).color != null,
        ),
      ),
    ))
      (box.decoration as BoxDecoration).color!,
  ];

  bool toastIgnoresTaps(WidgetTester tester) => tester
      .widgetList<IgnorePointer>(
        find.ancestor(
          of: find.text('Saved'),
          matching: find.byType(IgnorePointer),
        ),
      )
      .any((w) => w.ignoring);

  testWidgets('a dialog opened after a toast covers it until it closes', (
    tester,
  ) async {
    final BuildContext page = await pumpPage(tester);
    AppToast.show(
      page,
      ShowToastAction(
        message: 'Saved',
        duration: 4000,
        actionLabel: 'Undo',
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Saved'), findsOneWidget);
    expect(coversOnToast(tester), isEmpty);

    FunctionsRepository.presentCanvas<void>(
      page,
      builder: (_) =>
          const SizedBox(width: 200, height: 100, child: Text('Dialog')),
      barrierColor: const Color(0x99000000),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.text('Dialog'), findsOneWidget);

    // Covered by the barrier's colour, faded fully in, and taps go past it.
    final List<Color> covers = coversOnToast(tester);
    expect(covers, hasLength(1));
    expect(covers.single.a, closeTo(0x99 / 255, 0.01));
    expect(toastIgnoresTaps(tester), isTrue);

    // Closing the dialog uncovers the toast, which is still up.
    Navigator.of(page).pop();
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.text('Dialog'), findsNothing);
    expect(find.text('Saved'), findsOneWidget);
    expect(coversOnToast(tester), isEmpty);
    expect(toastIgnoresTaps(tester), isFalse);
    AppToast.hide();
  });

  testWidgets('a dialog without a barrier colour leaves the toast as it is', (
    tester,
  ) async {
    final BuildContext page = await pumpPage(tester);
    AppToast.show(page, ShowToastAction(message: 'Saved', duration: 4000));
    await tester.pump(const Duration(milliseconds: 300));
    FunctionsRepository.presentCanvas<void>(
      page,
      builder: (_) => const Text('Dialog'),
      barrierColor: const Color(0x00000000),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.text('Dialog'), findsOneWidget);
    expect(coversOnToast(tester), isEmpty);
    AppToast.hide();
  });
}
