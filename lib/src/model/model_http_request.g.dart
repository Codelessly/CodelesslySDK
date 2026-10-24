// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_http_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HttpApiData _$HttpApiDataFromJson(Map json) => HttpApiData(
  directory: json['directory'] as String? ?? '',
  method:
      $enumDecodeNullable(_$HttpMethodEnumMap, json['method']) ??
      HttpMethod.get,
  url: json['url'] as String? ?? '',
  headers:
      (json['headers'] as List<dynamic>?)
          ?.map(
            (e) =>
                HttpKeyValuePair.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList() ??
      const <HttpKeyValuePair>[],
  queryParams:
      (json['queryParams'] as List<dynamic>?)
          ?.map(
            (e) =>
                HttpKeyValuePair.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList() ??
      const <HttpKeyValuePair>[],
  formFields:
      (json['formFields'] as List<dynamic>?)
          ?.map(
            (e) =>
                HttpKeyValuePair.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList() ??
      const <HttpKeyValuePair>[],
  body: json['body'] as String?,
  bodyType:
      $enumDecodeNullable(_$RequestBodyTypeEnumMap, json['bodyType']) ??
      RequestBodyType.text,
  name: json['name'] as String,
  id: json['id'] as String? ?? '',
  project: json['project'] as String? ?? '',
  variables:
      (json['variables'] as List<dynamic>?)
          ?.map(
            (e) => VariableData.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList() ??
      const [],
  isDeleted: json['deleted'] as bool? ?? false,
  lastUpdated: const DateTimeConverter().fromJson(
    (json['lastUpdated'] as num?)?.toInt(),
  ),
  requestBodyContentType:
      $enumDecodeNullable(
        _$RequestBodyTextTypeEnumMap,
        json['requestBodyContentType'],
      ) ??
      RequestBodyTextType.json,
  created: const DateTimeConverter().fromJson(
    (json['created'] as num?)?.toInt(),
  ),
  owner: json['owner'] as String,
  teams: (json['teams'] as List<dynamic>?)?.map((e) => e as String).toSet(),
  users: (json['users'] as List<dynamic>?)?.map((e) => e as String).toSet(),
  roles: (json['roles'] as Map).map(
    (k, e) => MapEntry(k as String, Role.fromJson(e as String)),
  ),
  public: json['public'] as bool?,
);

Map<String, dynamic> _$HttpApiDataToJson(HttpApiData instance) =>
    <String, dynamic>{
      'owner': instance.owner,
      'users': instance.users.toList(),
      'roles': instance.roles.map((k, e) => MapEntry(k, e.toJson())),
      'teams': instance.teams.toList(),
      'public': instance.public,
      'id': instance.id,
      'name': instance.name,
      'project': instance.project,
      'method': _$HttpMethodEnumMap[instance.method]!,
      'url': instance.url,
      'headers': instance.headers.map((e) => e.toJson()).toList(),
      'queryParams': instance.queryParams.map((e) => e.toJson()).toList(),
      'formFields': instance.formFields.map((e) => e.toJson()).toList(),
      'body': ?instance.body,
      'bodyType': _$RequestBodyTypeEnumMap[instance.bodyType]!,
      'deleted': instance.isDeleted,
      'lastUpdated': ?const DateTimeConverter().toJson(instance.lastUpdated),
      'requestBodyContentType':
          _$RequestBodyTextTypeEnumMap[instance.requestBodyContentType]!,
      'variables': instance.variables.map((e) => e.toJson()).toList(),
      'created': ?const DateTimeConverter().toJson(instance.created),
      'directory': instance.directory,
    };

const _$HttpMethodEnumMap = {
  HttpMethod.get: 'get',
  HttpMethod.post: 'post',
  HttpMethod.put: 'put',
  HttpMethod.delete: 'delete',
};

const _$RequestBodyTypeEnumMap = {
  RequestBodyType.text: 'text',
  RequestBodyType.form: 'form',
};

const _$RequestBodyTextTypeEnumMap = {
  RequestBodyTextType.text: 'text',
  RequestBodyTextType.json: 'json',
  RequestBodyTextType.xml: 'xml',
  RequestBodyTextType.html: 'html',
};

HttpKeyValuePair _$HttpKeyValuePairFromJson(Map json) => HttpKeyValuePair(
  key: json['key'] as String,
  value: json['value'] as String,
  isUsed: json['isUsed'] as bool? ?? true,
);

Map<String, dynamic> _$HttpKeyValuePairToJson(HttpKeyValuePair instance) =>
    <String, dynamic>{
      'key': instance.key,
      'value': instance.value,
      'isUsed': instance.isUsed,
    };
