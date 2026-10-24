import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/ui/layout_presentation_route.dart';
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

  Future<void> open(
    WidgetTester tester,
    ConfirmAction action,
    Size size,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
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
  }

  final Finder bottomSheet = find.byKey(
    const ValueKey('Codelessly bottom sheet'),
  );
  final Finder sideSheet = find.byKey(const ValueKey('Codelessly side sheet'));

  testWidgets('the built-in confirm can be a bottom sheet', (tester) async {
    bool? result;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await AppConfirmDialog.show(
              context,
              action.copyWith(presentation: DialogPresentation.bottomSheet),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(Dialog), findsNothing);
    final Rect sheet = tester.getRect(bottomSheet);
    expect(sheet.left, 0);
    expect(sheet.width, 390);
    expect(sheet.bottom, 844);
    expect(sheet.height, lessThan(400));
    expect(find.text('Leave album?'), findsOneWidget);

    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(bottomSheet, findsNothing);
  });

  testWidgets('dismissing a bottom sheet confirm cancels', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await AppConfirmDialog.show(
              context,
              action.copyWith(presentation: DialogPresentation.bottomSheet),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('the built-in confirm can be a side sheet', (tester) async {
    await open(
      tester,
      action.copyWith(
        presentation: DialogPresentation.sideSheet,
        sheetWidth: 440,
      ),
      const Size(1440, 900),
    );
    expect(tester.takeException(), isNull);
    final Rect sheet = tester.getRect(sideSheet);
    expect(sheet.right, 1440);
    expect(sheet.width, 440);
    expect(sheet.height, 900);
    expect(find.text('You can join again later.'), findsOneWidget);
  });

  test('presentation round-trips through JSON and defaults to dialog', () {
    final ConfirmAction sheet = ConfirmAction.fromJson({
      'type': 'confirm',
      'title': 'Reopen?',
      'dialogId': 'reopen',
      'presentation': 'bottomSheet',
      'maxHeightFactor': 0.8,
    });
    expect(sheet.presentation, DialogPresentation.bottomSheet);
    expect(sheet.maxHeightFactor, 0.8);
    expect(ConfirmAction.fromJson(sheet.toJson()), sheet);
    final ConfirmAction plain = ConfirmAction(title: 'Sure?');
    expect(plain.presentation, DialogPresentation.dialog);
    expect(plain.toJson().containsKey('presentation'), isFalse);
    expect(LayoutPresentationRoute.defaultSheetWidth, 400);
  });

  testWidgets('a styled dialog takes its border, stamped shadows, fonts and '
      'outlined buttons', (tester) async {
    const Color ink = Color(0xFF1F2B2E);
    const Color paper = Color(0xFFF3ECDD);
    const Color card = Color(0xFFFBF7EE);
    const Color inkSoft = Color(0xFF4A5558);
    const Color danger = Color(0xFFB3392B);
    Map<String, dynamic> stamp(double d) => {
      'type': 'dropShadow',
      'radius': 0,
      'spread': 0,
      'color': '#1F2B2E',
      'offset': {'x': d, 'y': d},
    };
    final ConfirmAction styled = ActionModel.fromJson({
      'type': 'confirm',
      'title': 'Delete this sighting?',
      'message': 'It leaves your log for good.',
      'confirmLabel': 'Delete',
      'destructive': true,
      'backgroundColor': '#F3ECDD',
      'textColor': '#1F2B2E',
      'cornerRadius': 6,
      'border': {'color': '#1F2B2E', 'width': 1.5},
      'shadows': [stamp(6)],
      'titleStyle': {
        'fontFamily': 'Fraunces',
        'fontWeight': 'w600',
        'fontSize': 19,
      },
      'messageStyle': {'fontFamily': 'Work Sans', 'color': '#4A5558'},
      'buttonStyle': {'fontFamily': 'Work Sans', 'fontWeight': 'w600'},
      'buttonRadius': 4,
      'buttonBorder': {'color': '#1F2B2E', 'width': 1.5},
      'buttonShadows': [stamp(3)],
      'confirmColor': '#B3392B',
      'confirmTextColor': '#F3ECDD',
      'cancelColor': '#FBF7EE',
      'cancelTextColor': '#1F2B2E',
    }) as ConfirmAction;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => AppConfirmDialog.show(context, styled),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // A paper card with an ink outline and a hard shadow, no elevation.
    final Dialog dialog = tester.widget<Dialog>(find.byType(Dialog));
    expect(dialog.elevation, 0);
    final BoxDecoration surface =
        tester
                .widget<DecoratedBox>(
                  find.byKey(const ValueKey('codelessly-confirm-surface')),
                )
                .decoration
            as BoxDecoration;
    expect(surface.color, paper);
    expect(surface.borderRadius, BorderRadius.circular(6));
    expect(
      surface.border,
      const Border.fromBorderSide(BorderSide(color: ink, width: 1.5)),
    );
    expect(surface.boxShadow, const [
      BoxShadow(color: ink, offset: Offset(6, 6)),
    ]);

    TextStyle styleOf(String text) => tester
        .widget<RichText>(
          find.descendant(of: find.text(text), matching: find.byType(RichText)),
        )
        .text
        .style!;
    String? family(String name, FontWeightNumeric weight) =>
        TextUtils.retrieveTextStyle(
          fontName: FontName(family: name, weight: weight),
        ).fontFamily;
    final TextStyle title = styleOf('Delete this sighting?');
    expect(title.fontFamily, family('Fraunces', FontWeightNumeric.w600));
    expect(title.fontSize, 19);
    expect(title.color, ink);
    final TextStyle message = styleOf('It leaves your log for good.');
    expect(message.fontFamily, family('Work Sans', FontWeightNumeric.w400));
    expect(message.color, inkSoft);
    expect(
      styleOf('Delete').fontFamily,
      family('Work Sans', FontWeightNumeric.w600),
    );

    // Both buttons are outlined with a 4 radius; the confirm is danger red
    // and the cancel a card, each with a stamped shadow.
    final ButtonStyle ok = tester
        .widget<FilledButton>(
          find.byKey(const ValueKey('codelessly-confirm-ok')),
        )
        .style!;
    final ButtonStyle cancel = tester
        .widget<TextButton>(
          find.byKey(const ValueKey('codelessly-confirm-cancel')),
        )
        .style!;
    expect(ok.backgroundColor!.resolve({}), danger);
    expect(ok.foregroundColor!.resolve({}), paper);
    expect(cancel.backgroundColor!.resolve({}), card);
    expect(cancel.foregroundColor!.resolve({}), ink);
    for (final ButtonStyle style in [ok, cancel]) {
      expect(style.side!.resolve({}), const BorderSide(color: ink, width: 1.5));
      expect(
        (style.shape!.resolve({})! as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(4),
      );
    }
    for (final String key in [
      'codelessly-confirm-ok',
      'codelessly-confirm-cancel',
    ]) {
      final BoxDecoration shadow =
          tester
                  .widget<DecoratedBox>(
                    find
                        .ancestor(
                          of: find.byKey(ValueKey(key)),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      expect(shadow.boxShadow, const [
        BoxShadow(color: ink, offset: Offset(3, 3)),
      ]);
    }

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });
}
