// HTTP API calls: an HttpApi definition plus input values → a request →
// a response value (`${result}`, an API's variable).
import 'dart:async';
import 'dart:convert';

import 'package:codelessly_api/codelessly_api.dart' show HttpApi, HttpBodyType, HttpMethod, HttpParam;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// `${name}` placeholders of an API's inputs.
final RegExp apiInputPattern = RegExp(r'\$\{([a-zA-Z]+[a-zA-Z0-9_]*)\}');

/// A request built from an [HttpApi] and its input values.
@immutable
class ApiRequest {
  const ApiRequest({required this.method, required this.url, this.headers = const {}, this.body});

  final HttpMethod method;
  final String url;
  final Map<String, String> headers;

  /// Text, form fields (`Map<String, String>`) or null.
  final Object? body;

  /// Builds [api]'s request: every `${input}` in its URL, headers, query,
  /// form and body replaced by [params]' value for it (text as is, lists
  /// and maps as JSON, null as empty), else the input's default. Unknown
  /// placeholders stay. Enabled query parameters with a key are added to
  /// the URL's, winning over them; the content type is sent unless a header
  /// sets one.
  factory ApiRequest.build(HttpApi api, {Map<String, Object?> params = const {}}) {
    final values = <String, String>{
      for (final input in api.inputs) input.name: input.defaultValue,
      for (final e in params.entries)
        if (_text(e.value) case final String v when v.isNotEmpty || !api.inputs.any((i) => i.name == e.key)) e.key: v,
    };
    String apply(String text) => text.replaceAllMapped(apiInputPattern, (m) => values[m[1]] ?? m[0]!);
    Map<String, String> pairs(List<HttpParam> list) => {
          for (final p in list)
            if (p.isSent) apply(p.key): apply(p.value),
        };

    var url = apply(api.url).trim();
    final query = pairs(api.query);
    if (query.isNotEmpty) {
      final uri = Uri.tryParse(url);
      if (uri != null) url = uri.replace(queryParameters: {...uri.queryParameters, ...query}).toString();
    }
    final headers = pairs(api.headers);
    Object? body;
    if (api.method.hasBody) {
      if (api.bodyType == HttpBodyType.form) {
        body = pairs(api.form);
      } else if (api.body.isNotEmpty) {
        body = apply(api.body);
        if (!headers.keys.any((k) => k.toLowerCase() == 'content-type')) {
          headers['Content-Type'] = api.contentType.mimeType;
        }
      }
    }
    return ApiRequest(method: api.method, url: url, headers: headers, body: body);
  }

  static String _text(Object? v) => switch (v) {
        null => '',
        final String s => s,
        Map() || List() => jsonEncode(v),
        _ => '$v',
      };

  @override
  String toString() => 'ApiRequest(${method.verb} $url)';
}

/// The state of an API call, as the `${result}` of an API call action and
/// an API's variable read it: [toValue].
@immutable
class ApiResponse {
  const ApiResponse({
    required this.url,
    this.status = ApiStatus.success,
    this.statusCode,
    this.headers = const {},
    this.data,
    this.error,
  });

  /// Before the first call.
  const ApiResponse.idle(this.url)
      : status = ApiStatus.idle,
        statusCode = null,
        headers = const {},
        data = null,
        error = null;

  /// While a call runs; [data] is the previous call's, still shown.
  const ApiResponse.loading(this.url, {this.data})
      : status = ApiStatus.loading,
        statusCode = null,
        headers = const {},
        error = null;

  /// A call that didn't complete (no network, bad URL); [data] is the
  /// previous call's.
  const ApiResponse.failed(this.url, Object this.error, {this.data})
      : status = ApiStatus.error,
        statusCode = null,
        headers = const {};

  /// A completed call: a 2xx [statusCode] is a success, with [body] (JSON
  /// decoded when it is JSON) as [data]; anything else an error with the
  /// body as [error], keeping [previousData].
  factory ApiResponse.fromHttp(String url, int statusCode, String body,
      {Map<String, String> headers = const {}, Object? previousData}) {
    final ok = statusCode >= 200 && statusCode < 300;
    final decoded = _tryJson(body) ?? body;
    return ApiResponse(
      url: url,
      status: ok ? ApiStatus.success : ApiStatus.error,
      statusCode: statusCode,
      headers: headers,
      data: ok ? decoded : previousData,
      error: ok ? null : decoded,
    );
  }

  final String url;
  final ApiStatus status;
  final int? statusCode;
  final Map<String, String> headers;
  final Object? data;
  final Object? error;

  bool get isSuccess => status == ApiStatus.success;
  bool get isError => status == ApiStatus.error;
  bool get isLoading => status == ApiStatus.loading;

  /// Whether the request didn't complete (no status code).
  bool get failed => isError && statusCode == null;

  /// The response as a value: `url`, `status`, `isIdle`, `isLoading`,
  /// `isSuccess`, `isError`, `hasData`, `data`, `error`, `statusCode`,
  /// `headers`.
  Map<String, Object?> toValue() => {
        'url': url,
        'status': status.name,
        'isIdle': status == ApiStatus.idle,
        'isLoading': isLoading,
        'isSuccess': isSuccess,
        'isError': isError,
        'hasData': data != null,
        'data': data,
        if (error != null) 'error': error is Map || error is List || error is String ? error : '$error',
        'statusCode': ?statusCode,
        if (headers.isNotEmpty) 'headers': headers,
      };

  static Object? _tryJson(String body) {
    if (body.trim().isEmpty) return null;
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

  @override
  String toString() => 'ApiResponse(${status.name} $statusCode $url)';
}

enum ApiStatus { idle, loading, success, error }

/// Thrown by a call whose request didn't complete; [response] is its error
/// state, which the chain reads as `${result}`.
class ApiRequestFailed implements Exception {
  const ApiRequestFailed(this.response);

  final ApiResponse response;
  Object? get error => response.error;

  @override
  String toString() => 'ApiRequestFailed(${response.url}): ${response.error}';
}

/// Calls HTTP APIs.
abstract interface class ApiService {
  /// Sends [api]'s request with input values [params]. [onState] gets the
  /// loading state first (with [previousData]) and then the result.
  /// Completes with the response (2xx or not); a request that didn't
  /// complete throws [ApiRequestFailed].
  Future<ApiResponse> call(HttpApi api,
      {Map<String, Object?> params = const {}, Object? previousData, void Function(ApiResponse state)? onState});
}

/// Sends API requests with an [http.Client]. With a [proxy] (a CORS proxy
/// for the web), the request is posted to it as `{url, method, headers,
/// body}` and its reply, `{statusCode, headers, body}`, is the response.
class HttpApiService implements ApiService {
  HttpApiService({http.Client? client, this.proxy, this.log}) : client = client ?? http.Client();

  final http.Client client;
  final Uri? proxy;

  /// Logs requests and responses (debug builds).
  final void Function(String message)? log;

  @override
  Future<ApiResponse> call(HttpApi api,
      {Map<String, Object?> params = const {}, Object? previousData, void Function(ApiResponse state)? onState}) async {
    final request = ApiRequest.build(api, params: params);
    onState?.call(ApiResponse.loading(request.url, data: previousData));
    log?.call('${request.method.verb} ${request.url}');
    ApiResponse response;
    try {
      response = await send(request, previousData: previousData);
    } catch (error) {
      final failed = ApiResponse.failed(request.url, error, data: previousData);
      onState?.call(failed);
      log?.call('${request.method.verb} ${request.url} failed: $error');
      throw ApiRequestFailed(failed);
    }
    log?.call('${request.method.verb} ${request.url} → ${response.statusCode}');
    onState?.call(response);
    return response;
  }

  /// Sends [request] and reads its response.
  Future<ApiResponse> send(ApiRequest request, {Object? previousData}) async {
    if (proxy case final Uri proxy) {
      final reply = await client.post(proxy,
          headers: const {'content-type': 'application/json'},
          body: jsonEncode({
            'url': request.url,
            'method': request.method.verb,
            'headers': request.headers,
            'body': request.body,
          }));
      final json = jsonDecode(reply.body);
      if (json is! Map) throw const FormatException('Unexpected proxy reply');
      final body = json['body'];
      return ApiResponse.fromHttp(
        request.url,
        int.tryParse('${json['statusCode']}') ?? reply.statusCode,
        body is String ? body : jsonEncode(body ?? ''),
        headers: {for (final e in (json['headers'] as Map? ?? const {}).entries) '${e.key}': '${e.value}'},
        previousData: previousData,
      );
    }
    final uri = Uri.parse(request.url);
    final r = await switch (request.method) {
      HttpMethod.get => client.get(uri, headers: request.headers),
      HttpMethod.post => client.post(uri, headers: request.headers, body: request.body),
      HttpMethod.put => client.put(uri, headers: request.headers, body: request.body),
      HttpMethod.patch => client.patch(uri, headers: request.headers, body: request.body),
      HttpMethod.delete => client.delete(uri, headers: request.headers, body: request.body),
    };
    return ApiResponse.fromHttp(request.url, r.statusCode, r.body, headers: r.headers, previousData: previousData);
  }

  void close() => client.close();
}
