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
}
