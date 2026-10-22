import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

void main() {
  late List<String> calls;
  late BuildContext context;

  Future<void> pump(WidgetTester tester) async {
    calls = [];
    final codelesslyContext = CodelesslyContext.empty()
      ..functions['record'] = (context, reference, params) =>
          calls.add('${params['what']}');
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: codelesslyContext,
        child: MaterialApp(
          home: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
  }

  ApiCallAction api() => ApiCallAction(
    apiId: 'tides',
    onSuccess: [
      CallFunctionAction(name: 'record', params: {'what': 'success'}),
    ],
    onError: [
      CallFunctionAction(name: 'record', params: {'what': 'error'}),
    ],
  );

  http.Response response(int status) => http.Response(
    '{}',
    status,
    request: http.Request('GET', Uri.parse('https://x.dev')),
  );

  testWidgets('onSuccess runs after a 2xx response', (tester) async {
    await pump(tester);
    await tester.runAsync(
      () => FunctionsRepository.handleApiOutcome(
        context,
        api(),
        response: response(200),
      ),
    );
    expect(calls, ['success']);
  });

  testWidgets('onError runs after an error response', (tester) async {
    await pump(tester);
    await tester.runAsync(
      () => FunctionsRepository.handleApiOutcome(
        context,
        api(),
        response: response(503),
      ),
    );
    expect(calls, ['error']);
  });

  testWidgets(
    'onError handles a failed request instead of stopping the chain',
    (tester) async {
      await pump(tester);
      await tester.runAsync(
        () => FunctionsRepository.handleApiOutcome(
          context,
          api(),
          failure: http.ClientException('offline'),
        ),
      );
      expect(calls, ['error']);
    },
  );

  testWidgets('without onError a failed request still throws', (tester) async {
    await pump(tester);
    Object? thrown;
    await tester.runAsync(() async {
      try {
        await FunctionsRepository.handleApiOutcome(
          context,
          ApiCallAction(apiId: 'tides'),
          failure: http.ClientException('offline'),
        );
      } catch (e) {
        thrown = e;
      }
    });
    expect(thrown, isA<http.ClientException>());
  });

  test('onSuccess and onError round-trip through JSON', () {
    final ApiCallAction action = ApiCallAction.fromJson(api().toJson());
    expect(action.onSuccess.single, isA<CallFunctionAction>());
    expect((action.onError.single as CallFunctionAction).params, {
      'what': 'error',
    });
  });
}
