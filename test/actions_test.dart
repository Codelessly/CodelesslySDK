import 'dart:async';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Reaction callFunction(String name, {bool nonBlocking = false}) => Reaction(
  action: CallFunctionAction(name: name, nonBlocking: nonBlocking),
  trigger: TriggerModel(type: TriggerType.click),
);

/// Pumps a tree with [functions] and returns a context inside it.
Future<BuildContext> pumpContext(
  WidgetTester tester,
  Map<String, CodelesslyFunction> functions,
) async {
  late BuildContext context;
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: CodelesslyContext.empty()..functions = functions,
      child: Builder(
        builder: (c) {
          context = c;
          return const SizedBox();
        },
      ),
    ),
  );
  return context;
}

void main() {
  testWidgets('blocking functions run in order and are awaited', (
    tester,
  ) async {
    final calls = <String>[];
    final first = Completer<void>();
    final context = await pumpContext(tester, {
      'first': (context, reference, params) {
        calls.add('first started');
        return first.future.then((_) => calls.add('first done'));
      },
      'second': (context, reference, params) => calls.add('second'),
    });

    final done = FunctionsRepository.triggerAction(
      context,
      TriggerType.click,
      reactions: [callFunction('first'), callFunction('second')],
    );
    await tester.pump();
    expect(calls, ['first started']);

    first.complete();
    await tester.runAsync(() => done);
    expect(calls, ['first started', 'first done', 'second']);
  });

  testWidgets('a failing function stops the chain without escaping', (
    tester,
  ) async {
    final calls = <String>[];
    final context = await pumpContext(tester, {
      'fails': (context, reference, params) async => throw StateError('x'),
      'throwsSync': (context, reference, params) => throw StateError('y'),
      'next': (context, reference, params) => calls.add('next'),
    });

    for (final failing in ['fails', 'throwsSync']) {
      expect(
        await FunctionsRepository.triggerAction(
          context,
          TriggerType.click,
          reactions: [callFunction(failing), callFunction('next')],
        ),
        isTrue,
      );
    }
    expect(calls, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failing non-blocking function does not stop the chain', (
    tester,
  ) async {
    final calls = <String>[];
    final context = await pumpContext(tester, {
      'fails': (context, reference, params) async => throw StateError('x'),
      'next': (context, reference, params) => calls.add('next'),
    });

    await FunctionsRepository.triggerAction(
      context,
      TriggerType.click,
      reactions: [
        callFunction('fails', nonBlocking: true),
        callFunction('next'),
      ],
    );
    await tester.pump();
    expect(calls, ['next']);
    expect(tester.takeException(), isNull);
  });
}
