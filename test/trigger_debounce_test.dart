import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('a debounced trigger runs once after a burst', (tester) async {
    final List<Object?> calls = [];
    late BuildContext context;
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty()
          ..functions = {
            'search': (context, reference, params) => calls.add('search'),
          },
        child: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    final List<Reaction> reactions = [
      Reaction(
        action: CallFunctionAction(name: 'search'),
        trigger: TriggerModel(type: TriggerType.changed, debounceMs: 300),
      ),
    ];
    for (int i = 0; i < 3; i++) {
      FunctionsRepository.triggerAction(
        context,
        TriggerType.changed,
        reactions: reactions,
        value: 'q$i',
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(calls, isEmpty);
    await tester.pump(const Duration(milliseconds: 300));
    expect(calls, ['search']);

    // Without a debounce, each trigger runs.
    final List<Reaction> immediate = [
      Reaction(
        action: CallFunctionAction(name: 'search'),
        trigger: TriggerModel(type: TriggerType.changed),
      ),
    ];
    FunctionsRepository.triggerAction(
      context,
      TriggerType.changed,
      reactions: immediate,
    );
    await tester.pump();
    expect(calls, ['search', 'search']);
  });
}
