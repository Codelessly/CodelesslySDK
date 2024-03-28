// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_http_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HttpApiData _$HttpApiDataFromJson(Map json) => HttpApiData(
      method: $enumDecodeNullable(_$HttpMethodEnumMap, json['method']) ??
          HttpMethod.get,
      url: json['url'] as String? ?? '',
      headers: (json['headers'] as List<dynamic>?)
              ?.map((e) => HttpKeyValuePair.fromJson(
                  Map<String, dynamic>.from(e as Map)))
              .toList() ??
          <HttpKeyValuePair>[],
      queryParams: (json['queryParams'] as List<dynamic>?)
              ?.map((e) => HttpKeyValuePair.fromJson(
                  Map<String, dynamic>.from(e as Map)))
              .toList() ??
          <HttpKeyValuePair>[],
      formFields: (json['formFields'] as List<dynamic>?)
              ?.map((e) => HttpKeyValuePair.fromJson(
                  Map<String, dynamic>.from(e as Map)))
              .toList() ??
          <HttpKeyValuePair>[],
      body: json['body'] as String?,
      bodyType:
          $enumDecodeNullable(_$RequestBodyTypeEnumMap, json['bodyType']) ??
              RequestBodyType.text,
      name: json['name'] as String,
      id: json['id'] as String? ?? '',
      project: json['project'] as String? ?? '',
      variables: (json['variables'] as List<dynamic>?)
              ?.map((e) =>
                  VariableData.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      isDeleted: json['deleted'] as bool? ?? false,
      lastUpdated:
          const DateTimeConverter().fromJson(json['lastUpdated'] as int?),
      requestBodyContentType: $enumDecodeNullable(
              _$RequestBodyTextTypeEnumMap, json['requestBodyContentType']) ??
          RequestBodyTextType.json,
      created: const DateTimeConverter().fromJson(json['created'] as int?),
      directory: json['directory'] as String?,
      teams: (json['teams'] as List<dynamic>?)?.map((e) => e as String).toSet(),
      users: (json['users'] as List<dynamic>?)?.map((e) => e as String).toSet(),
      roles: (json['roles'] as Map).map(
        (k, e) => MapEntry(k as String, $enumDecode(_$RoleEnumMap, e)),
      ),
      public: json['public'] as bool?,
    );

Map<String, dynamic> _$HttpApiDataToJson(HttpApiData instance) {
  final val = <String, dynamic>{
    'users': instance.users.toList(),
    'roles': instance.roles.map((k, e) => MapEntry(k, _$RoleEnumMap[e]!)),
    'teams': instance.teams.toList(),
    'public': instance.public,
  };

  void writeNotNull(
      String key, dynamic value, dynamic jsonValue, dynamic defaultValue) {
    final bool serialize =
        shouldSerialize(key, value, jsonValue, defaultValue, true);

    if (serialize) {
      val[key] = jsonValue;
    }
  }

  writeNotNull('id', instance.id, instance.id, '');
  val['name'] = instance.name;
  writeNotNull('project', instance.project, instance.project, '');
  writeNotNull('method', instance.method, _$HttpMethodEnumMap[instance.method]!,
      HttpMethod.get);
  writeNotNull('url', instance.url, instance.url, '');
  writeNotNull(
      'headers',
      instance.headers,
      instance.headers.map((e) => e.toJson()).toList(),
      const <HttpKeyValuePair>[]);
  writeNotNull(
      'queryParams',
      instance.queryParams,
      instance.queryParams.map((e) => e.toJson()).toList(),
      const <HttpKeyValuePair>[]);
  writeNotNull(
      'formFields',
      instance.formFields,
      instance.formFields.map((e) => e.toJson()).toList(),
      const <HttpKeyValuePair>[]);
  writeNotNull('body', instance.body, instance.body, null);
  writeNotNull('bodyType', instance.bodyType,
      _$RequestBodyTypeEnumMap[instance.bodyType]!, RequestBodyType.text);
  writeNotNull('deleted', instance.isDeleted, instance.isDeleted, false);
  writeNotNull('lastUpdated', instance.lastUpdated,
      const DateTimeConverter().toJson(instance.lastUpdated), null);
  writeNotNull(
      'requestBodyContentType',
      instance.requestBodyContentType,
      _$RequestBodyTextTypeEnumMap[instance.requestBodyContentType]!,
      RequestBodyTextType.json);
  writeNotNull('variables', instance.variables,
      instance.variables.map((e) => e.toJson()).toList(), const []);
  writeNotNull('created', instance.created,
      const DateTimeConverter().toJson(instance.created), null);
  writeNotNull('directory', instance.directory, instance.directory, null);
  return val;
}

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

const _$RoleEnumMap = {
  Role.owner: 'owner',
  Role.editor: 'editor',
  Role.viewer: 'viewer',
};

HttpKeyValuePair _$HttpKeyValuePairFromJson(Map json) => HttpKeyValuePair(
      key: json['key'] as String,
      value: json['value'] as String,
      isUsed: json['isUsed'] as bool? ?? true,
    );

Map<String, dynamic> _$HttpKeyValuePairToJson(HttpKeyValuePair instance) {
  final val = <String, dynamic>{
    'key': instance.key,
    'value': instance.value,
  };

  void writeNotNull(
      String key, dynamic value, dynamic jsonValue, dynamic defaultValue) {
    final bool serialize =
        shouldSerialize(key, value, jsonValue, defaultValue, true);

    if (serialize) {
      val[key] = jsonValue;
    }
  }

  writeNotNull('isUsed', instance.isUsed, instance.isUsed, true);
  return val;
}
