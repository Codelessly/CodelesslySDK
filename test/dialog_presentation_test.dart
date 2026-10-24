import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> open(
  WidgetTester tester, {
  required double width,
  required DialogPresentation presentation,
  AlignmentGeometry alignment = Alignment.center,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => FunctionsRepository.presentCanvas<void>(
            context,
            presentation: presentation,
            alignment: alignment,
            builder: (context) =>
                const SizedBox(key: Key('content'), width: 200, height: 100),
          ),
          child: const Text('Open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a dialog is centered by default', (tester) async {
    await open(tester, width: 1024, presentation: DialogPresentation.dialog);
    expect(find.byType(BottomSheet), findsNothing);
    expect(
      tester.getCenter(find.byKey(const Key('content'))),
      const Offset(512, 400),
    );
  });

  testWidgets('a dialog can sit elsewhere, like a menu', (tester) async {
    await open(
      tester,
      width: 1024,
      presentation: DialogPresentation.dialog,
      alignment: Alignment.topRight,
    );
    expect(
      tester.getTopRight(find.byKey(const Key('content'))),
      const Offset(1024, 0),
    );
  });

  testWidgets('a bottom sheet sits on the bottom edge', (tester) async {
    await open(
      tester,
      width: 1024,
      presentation: DialogPresentation.bottomSheet,
    );
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(tester.getBottomLeft(find.byKey(const Key('content'))).dy, 800);
  });

  testWidgets('adaptive is a sheet on phones and a dialog on wider screens', (
    tester,
  ) async {
    await open(tester, width: 390, presentation: DialogPresentation.adaptive);
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('adaptive is a dialog from 600 px', (tester) async {
    await open(tester, width: 834, presentation: DialogPresentation.adaptive);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byKey(const Key('content')), findsOneWidget);
  });

  test('the action keeps presentation and alignment in JSON', () {
    final action = ShowDialogAction(
      destinationId: 'c',
      presentation: DialogPresentation.adaptive,
      alignment: AlignmentModel.topRight,
    );
    final decoded = ShowDialogAction.fromJson(action.toJson());
    expect(decoded.presentation, DialogPresentation.adaptive);
    expect(decoded.alignment, AlignmentModel.topRight);
  });
}
