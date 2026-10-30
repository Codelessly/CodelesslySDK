import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  Future<List<String>> run(
    WidgetTester tester, {
    required bool submitOnUnfocus,
    required Future<void> Function() act,
  }) async {
    final List<String> submitted = <String>[];
    final TextFieldNode node = TextFieldNode(
      id: 'field',
      name: 'Field',
      basicBoxLocal: NodeBox(0, 0, 300, 48),
      properties: TextFieldProperties(submitOnUnfocus: submitOnUnfocus),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty(),
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                PassiveTextFieldWidget(
                  node: node,
                  settings: const WidgetBuildSettings(debugLabel: 'test'),
                  onSubmitted: (context, value) => submitted.add(value),
                ),
                const SizedBox(height: 40),
                const TextButton(onPressed: null, child: Text('Elsewhere')),
                const Focus(child: SizedBox(key: Key('other'))),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'mia');
    await act();
    await tester.pump();
    return submitted;
  }

  Future<void> unfocus(WidgetTester tester) async {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  testWidgets('by default leaving the field submits it, once', (tester) async {
    expect(
      await run(tester, submitOnUnfocus: true, act: () => unfocus(tester)),
      ['mia'],
    );
  });

  testWidgets('submitOnUnfocus off: leaving the field does not submit', (
    tester,
  ) async {
    expect(
      await run(tester, submitOnUnfocus: false, act: () => unfocus(tester)),
      isEmpty,
    );
  });

  testWidgets('submitOnUnfocus off: Enter submits, once', (tester) async {
    expect(
      await run(
        tester,
        submitOnUnfocus: false,
        act: () => tester.testTextInput.receiveAction(TextInputAction.done),
      ),
      ['mia'],
    );
  });

  testWidgets('by default Enter submits once, not twice', (tester) async {
    expect(
      await run(
        tester,
        submitOnUnfocus: true,
        act: () => tester.testTextInput.receiveAction(TextInputAction.done),
      ),
      ['mia'],
    );
  });

  test('submitOnUnfocus round-trips and defaults on', () {
    expect(TextFieldProperties().submitOnUnfocus, isTrue);
    final json = TextFieldProperties(submitOnUnfocus: false).toJson();
    expect(json['submitOnUnfocus'], isFalse);
    expect(TextFieldProperties.fromJson(json).submitOnUnfocus, isFalse);
    expect(
      TextFieldProperties().toJson().containsKey('submitOnUnfocus'),
      isFalse,
    );
  });
}
