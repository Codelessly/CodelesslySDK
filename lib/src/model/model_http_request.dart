import 'package:codelessly_api/api.dart';
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

import 'variables_model.dart';

part 'model_http_request.g.dart';

enum HttpMethod {
  get,
  post,
  put,
  delete,
}

enum RequestBodyType { text, form }

enum RequestBodyTextType { text, json, xml, html }

extension RequestBodyTextTypeExt on RequestBodyTextType {
  String get value {
    switch (this) {
      case RequestBodyTextType.text:
        return 'text/plain';
      case RequestBodyTextType.json:
        return 'application/json';
      case RequestBodyTextType.xml:
        return 'application/xml';
      case RequestBodyTextType.html:
        return 'text/html';
    }
  }
}

extension HttpMethodExt on HttpMethod {
  String get shortName {
    switch (this) {
      case HttpMethod.get:
        return 'GET';
      case HttpMethod.post:
        return 'POST';
      case HttpMethod.put:
        return 'PUT';
      case HttpMethod.delete:
        return 'DEL';
    }
  }

  bool get hasBody => this == HttpMethod.post || this == HttpMethod.put;
}

@JsonSerializable()
class HttpApiData extends EqualityBy<HttpApiData, String> {
  final String id;
  final String name;
  final String project;
  final String owner;
  final HttpMethod method;
  final String url;
  final List<HttpKeyValuePair> headers;
  final List<HttpKeyValuePair> queryParams;
  final List<HttpKeyValuePair> formFields;
  final String? body;
  final RequestBodyType bodyType;
  @JsonKey(name: 'deleted')
  final bool isDeleted;
  @JsonKey(fromJson: jsonToDate, toJson: dateToJson)
  final DateTime lastUpdated;
  final RequestBodyTextType requestBodyContentType;
  final List<VariableData> variables;
  @JsonKey(includeFromJson: false, includeToJson: false)
  bool isDraft;
  @JsonKey(fromJson: jsonToDate, toJson: dateToJson)
  final DateTime created;

  HttpApiData({
    this.method = HttpMethod.get,
    this.url = '',
    this.headers = const <HttpKeyValuePair>[],
    this.queryParams = const <HttpKeyValuePair>[],
    this.formFields = const <HttpKeyValuePair>[],
    this.body,
    this.bodyType = RequestBodyType.text,
    this.owner = '',
    required this.name,
    this.id = '',
    required this.project,
    List<VariableData> variables = const [],
    this.isDeleted = false,
    DateTime? lastUpdated,
    this.requestBodyContentType = RequestBodyTextType.json,
    this.isDraft = false,
    DateTime? created,
  })  : variables = List.of(variables),
        lastUpdated = lastUpdated ?? DateTime.now(),
        created = created ?? DateTime.now(),
        super((e) => e.id);

  HttpApiData copyWith({
    HttpMethod? method,
    String? url,
    List<HttpKeyValuePair>? headers,
    List<HttpKeyValuePair>? queryParams,
    List<HttpKeyValuePair>? formFields,
    List<VariableData>? variables,
    String? body,
    String? owner,
    String? name,
    String? id,
    String? project,
    bool? isDeleted,
    DateTime? lastUpdated,
    DateTime? created,
    RequestBodyType? bodyType,
    RequestBodyTextType? requestBodyContentType,
    bool? isDraft,
  }) =>
      HttpApiData(
        method: method ?? this.method,
        url: url ?? this.url,
        headers: headers ?? this.headers,
        queryParams: queryParams ?? this.queryParams,
        body: body ?? this.body,
        formFields: formFields ?? this.formFields,
        variables: variables ?? this.variables,
        name: name ?? this.name,
        project: project ?? this.project,
        owner: owner ?? this.owner,
        id: id ?? this.id,
        isDeleted: isDeleted ?? this.isDeleted,
        lastUpdated: lastUpdated ?? this.lastUpdated,
        created: created ?? this.created,
        bodyType: bodyType ?? this.bodyType,
        isDraft: isDraft ?? this.isDraft,
        requestBodyContentType:
            requestBodyContentType ?? this.requestBodyContentType,
      );

  factory HttpApiData.fromJson(Map<String, dynamic> json) =>
      _$HttpApiDataFromJson(json);

  Map<String, dynamic> toJson() => _$HttpApiDataToJson(this);
}

@JsonSerializable()
class HttpKeyValuePair extends Equatable {
  final String key;
  final String value;
  final bool isUsed;

  @override
  List<Object?> get props => [key, value, isUsed];

  HttpKeyValuePair(
      {required this.key, required this.value, this.isUsed = true});

  HttpKeyValuePair copyWidth({String? key, String? value, bool? isUsed}) =>
      HttpKeyValuePair(
        key: key ?? this.key,
        value: value ?? this.value,
        isUsed: isUsed ?? this.isUsed,
      );

  factory HttpKeyValuePair.fromJson(Map<String, dynamic> json) =>
      _$HttpKeyValuePairFromJson(json);

  Map<String, dynamic> toJson() => _$HttpKeyValuePairToJson(this);
}
