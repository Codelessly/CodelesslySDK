import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

TextFieldNode field(String id, {bool submitOnUnfocus = true}) => TextFieldNode(
  id: id,
  name: id,
  basicBoxLocal: NodeBox(0, 0, 300, 48),
  properties: TextFieldProperties(submitOnUnfocus: submitOnUnfocus),
);

/// Two fields: [reading] and a second one to move the focus to.
Future<List<String>> pumpForm(
  WidgetTester tester, {
  required bool submitOnUnfocus,
}) async {
  final List<String> submitted = [];
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: CodelesslyContext.empty(),
      child: MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SizedBox(
                height: 48,
                child: PassiveTextFieldWidget(
                  key: const ValueKey('reading'),
                  node: field('reading', submitOnUnfocus: submitOnUnfocus),
                  settings: const WidgetBuildSettings(debugLabel: 'test'),
                  onSubmitted: (context, value) => submitted.add(value),
                ),
              ),
              SizedBox(
                height: 48,
                child: PassiveTextFieldWidget(
                  key: const ValueKey('note'),
                  node: field('note'),
                  settings: const WidgetBuildSettings(debugLabel: 'test'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return submitted;
}

Finder input(String key) => find.descendant(
  of: find.byKey(ValueKey(key)),
  matching: find.byType(EditableText),
);

void main() {
  testWidgets('Enter submits once; leaving afterwards does not repeat it', (
    WidgetTester tester,
  ) async {
    final List<String> submitted = await pumpForm(
      tester,
      submitOnUnfocus: true,
    );
    await tester.enterText(input('reading'), '2489');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(submitted, ['2489']);
    await tester.tap(input('note'));
    await tester.pump();
    expect(submitted, ['2489']);
  });

  testWidgets('leaving the field submits it by default', (
    WidgetTester tester,
  ) async {
    final List<String> submitted = await pumpForm(
      tester,
      submitOnUnfocus: true,
    );
    await tester.enterText(input('reading'), '2489');
    await tester.tap(input('note'));
    await tester.pump();
    expect(submitted, ['2489']);
  });

  testWidgets('with submitOnUnfocus off, only Enter submits', (
    WidgetTester tester,
  ) async {
    final List<String> submitted = await pumpForm(
      tester,
      submitOnUnfocus: false,
    );
    await tester.enterText(input('reading'), '2489');
    await tester.tap(input('note'));
    await tester.pump();
    expect(submitted, isEmpty);
    await tester.tap(input('reading'));
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(submitted, ['2489']);
  });
}
