import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/functions/action_chain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

/// Pumps a context that has a [Codelessly] whose HTTP client is [client].
Future<BuildContext> pumpContext(
  WidgetTester tester,
  http.Client client,
) async {
  late BuildContext captured;
  await tester.pumpWidget(
    Provider<Codelessly>.value(
      value: Codelessly(client: client),
      child: ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty(),
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              captured = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    ),
  );
  return captured;
}

void main() {
  queryParamTests();

  testWidgets('An API call leaves its response as the chain result', (
    WidgetTester tester,
  ) async {
    final context = await pumpContext(
      tester,
      MockClient(
        (request) async => http.Response(
          '{"results": {"sunrise": "7:25"}}',
          200,
          request: request,
        ),
      ),
    );
    Object? result;
    await tester.runAsync(
      () => ActionChain.run(() async {
        await FunctionsRepository.makeApiRequest(
          method: HttpMethod.get,
          url: 'https://example.com/sun',
          headers: const {},
          body: null,
          context: context,
        );
        result = ActionChain.current?.result;
      }),
    );
    expect(result, isA<Map>());
    final Map map = result! as Map;
    expect(map['isSuccess'], true);
    expect(map['statusCode'], 200);
    expect((map['data'] as Map)['results'], {'sunrise': '7:25'});
  });

  testWidgets('A failed API call leaves an error result before it throws', (
    WidgetTester tester,
  ) async {
    final context = await pumpContext(
      tester,
      MockClient((request) async => throw http.ClientException('offline')),
    );
    Object? result;
    await tester.runAsync(
      () => ActionChain.run(() async {
        try {
          await FunctionsRepository.makeApiRequest(
            method: HttpMethod.get,
            url: 'https://example.com/sun',
            headers: const {},
            body: null,
            context: context,
          );
        } catch (_) {}
        result = ActionChain.current?.result;
      }),
    );
    expect((result! as Map)['isError'], true);
  });
}

HttpApiData api(String url, List<HttpKeyValuePair> query) =>
    HttpApiData.fromJson({
      'name': 'Tides',
      'directory': '',
      'owner': 'o',
      'teams': <String>[],
      'users': <String>[],
      'roles': <String, String>{},
      'public': false,
      'url': url,
      'queryParams': [for (final q in query) q.toJson()],
    });

void queryParamTests() {
  testWidgets('An API URL gets its query parameters and inputs', (
    WidgetTester tester,
  ) async {
    final context = await pumpContext(
      tester,
      MockClient((request) async => http.Response('', 200)),
    );
    final String url = FunctionsRepository.buildApiUrl(
      api('https://api.example.com/data?format=json', const [
        HttpKeyValuePair(key: 'station', value: r'${station}'),
        HttpKeyValuePair(key: 'interval', value: 'hilo'),
        HttpKeyValuePair(key: 'unused', value: 'x', isUsed: false),
        HttpKeyValuePair(key: '', value: 'blank key'),
      ]),
      {'station': '9414131'},
      ScopedValues.of(context),
    );
    final Uri uri = Uri.parse(url);
    expect(uri.path, '/data');
    expect(uri.queryParameters, {
      'format': 'json',
      'station': '9414131',
      'interval': 'hilo',
    });
  });

  testWidgets('An API without query parameters keeps its URL', (
    WidgetTester tester,
  ) async {
    final context = await pumpContext(
      tester,
      MockClient((request) async => http.Response('', 200)),
    );
    expect(
      FunctionsRepository.buildApiUrl(
        api(r'https://x.dev/a?d=${day}', const []),
        {'day': '2026-10-22'},
        ScopedValues.of(context),
      ),
      'https://x.dev/a?d=2026-10-22',
    );
  });
}
