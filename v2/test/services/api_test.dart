// Ported from SDK 8.x's api_call_result_test and api_call_outcome_test: the
// request an API definition builds and the value its response leaves.
import 'dart:convert';

import 'package:codelessly_sdk_v2/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

HttpApi api(String url, {List<HttpParam> query = const [], List<ApiInput> inputs = const []}) =>
    HttpApi(id: 'tides', name: 'Tides', url: url, query: query, inputs: inputs);

void main() {
  group('requests', () {
    test('an API URL gets its query parameters and inputs', () {
      final request = ApiRequest.build(
        api('https://api.example.com/data?format=json', query: const [
          HttpParam('station', r'${station}'),
          HttpParam('interval', 'hilo'),
          HttpParam('unused', 'x', enabled: false),
          HttpParam('', 'blank key'),
        ]),
        params: {'station': '9414131'},
      );
      final uri = Uri.parse(request.url);
      expect(uri.path, '/data');
      expect(uri.queryParameters, {'format': 'json', 'station': '9414131', 'interval': 'hilo'});
    });

    test('an API without query parameters keeps its URL', () {
      expect(ApiRequest.build(api(r'https://x.dev/a?d=${day}'), params: {'day': '2026-10-22'}).url,
          'https://x.dev/a?d=2026-10-22');
    });

    test('inputs fall back to their defaults; unknown placeholders stay', () {
      final definition = api(r'https://x.dev/${station}/${unknown}', inputs: const [
        ApiInput('station', defaultValue: '1'),
      ]);
      expect(ApiRequest.build(definition).url, r'https://x.dev/1/${unknown}');
      expect(ApiRequest.build(definition, params: {'station': ''}).url, r'https://x.dev/1/${unknown}');
      expect(ApiRequest.build(definition, params: {'station': 7}).url, r'https://x.dev/7/${unknown}');
    });

    test('headers, a JSON body and its content type', () {
      const definition = HttpApi(
        method: HttpMethod.post,
        url: 'https://x.dev',
        headers: [HttpParam('Authorization', r'Bearer ${token}')],
        body: r'{"filter": ${filter}}',
      );
      final request = ApiRequest.build(definition, params: {
        'token': 't0k',
        'filter': {'a': 1},
      });
      expect(request.headers, {'Authorization': 'Bearer t0k', 'Content-Type': 'application/json'});
      expect(jsonDecode(request.body! as String), {
        'filter': {'a': 1},
      });
      final explicit = ApiRequest.build(definition.copyWith(headers: const [HttpParam('content-type', 'text/csv')]));
      expect(explicit.headers, {'content-type': 'text/csv'});
    });

    test('form fields; GET sends no body', () {
      const definition = HttpApi(
        method: HttpMethod.put,
        url: 'https://x.dev',
        bodyType: HttpBodyType.form,
        form: [HttpParam('email', r'${email}'), HttpParam('off', '1', enabled: false)],
        body: 'ignored',
      );
      expect(ApiRequest.build(definition, params: {'email': 'a@b.c'}).body, {'email': 'a@b.c'});
      expect(ApiRequest.build(definition.copyWith(method: HttpMethod.get)).body, isNull);
    });
  });

  group('calls', () {
    test('a call leaves its response as the result value', () async {
      late http.Request sent;
      final service = HttpApiService(
        client: MockClient((request) async {
          sent = request;
          return http.Response('{"results": {"sunrise": "7:25"}}', 200, request: request);
        }),
      );
      final states = <ApiResponse>[];
      final response = await service.call(
        const HttpApi(method: HttpMethod.post, url: 'https://example.com/sun', body: '{}'),
        onState: states.add,
        previousData: 'old',
      );
      expect(sent.method, 'POST');
      expect(states.map((s) => s.status), [ApiStatus.loading, ApiStatus.success]);
      expect(states.first.data, 'old', reason: 'loading keeps the previous data');
      final value = response.toValue();
      expect(value['isSuccess'], true);
      expect(value['statusCode'], 200);
      expect((value['data']! as Map)['results'], {'sunrise': '7:25'});
    });

    test('an error response is a result, keeping the previous data', () async {
      final service = HttpApiService(client: MockClient((r) async => http.Response('{"message": "down"}', 503)));
      final response = await service.call(api('https://x.dev'), previousData: [1]);
      expect(response.isError, isTrue);
      expect(response.failed, isFalse);
      expect(response.toValue(), containsPair('error', {'message': 'down'}));
      expect(response.data, [1]);
      expect(response.toValue()['hasData'], isTrue);
    });

    test('a failed request leaves an error value and throws', () async {
      final service = HttpApiService(client: MockClient((request) async => throw http.ClientException('offline')));
      final states = <ApiResponse>[];
      Object? thrown;
      try {
        await service.call(api('https://example.com/sun'), onState: states.add);
      } catch (e) {
        thrown = e;
      }
      expect(thrown, isA<ApiRequestFailed>());
      final failure = (thrown! as ApiRequestFailed).response;
      expect(failure.toValue()['isError'], true);
      expect(failure.error, isA<http.ClientException>());
      expect(states.last, same(failure));
    });

    test('through a proxy', () async {
      final service = HttpApiService(
        proxy: Uri.parse('https://proxy.dev/makeApiRequest'),
        client: MockClient((request) async {
          expect(request.url.host, 'proxy.dev');
          final sent = jsonDecode(request.body) as Map;
          expect(sent['url'], 'https://x.dev');
          expect(sent['method'], 'GET');
          return http.Response(jsonEncode({'statusCode': 201, 'headers': {'a': 'b'}, 'body': {'ok': true}}), 200);
        }),
      );
      final response = await service.call(api('https://x.dev'));
      expect(response.statusCode, 201);
      expect(response.data, {'ok': true});
      expect(response.headers, {'a': 'b'});
    });
  });

  group('Services.callApi', () {
    test('calls a configured API by id', () async {
      final services = Services(
        config: ServiceConfig.fromJson({
          'apis': {
            'tides': {'url': r'https://x.dev/${station}', 'inputs': [{'name': 'station'}]},
          },
        }),
        api: HttpApiService(client: MockClient((r) async => http.Response('"${r.url.path}"', 200))),
        analytics: RecordingAnalytics(),
      );
      final value = await services.callApi('tides', params: {'station': '42'}) as Map;
      expect(value['data'], '/42');
    });

    test('an unknown API is reported and throws', () async {
      final analytics = RecordingAnalytics();
      final services = Services(analytics: analytics);
      await expectLater(services.callApi('nope'), throwsStateError);
      expect(analytics.errors, ['api_not_found']);
    });

    test('opens links', () async {
      final links = RecordingLinkOpener();
      final services = Services(links: links);
      expect(await services.openUrl(' https://x.dev '), isTrue);
      expect(await services.openUrl(''), isFalse);
      expect(links.opened, ['https://x.dev']);
    });
  });
}
