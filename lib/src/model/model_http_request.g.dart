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
          const <HttpKeyValuePair>[],
      queryParams: (json['queryParams'] as List<dynamic>?)
              ?.map((e) => HttpKeyValuePair.fromJson(
                  Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const <HttpKeyValuePair>[],
      formFields: (json['formFields'] as List<dynamic>?)
              ?.map((e) => HttpKeyValuePair.fromJson(
                  Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const <HttpKeyValuePair>[],
      body: json['body'] as String?,
      bodyType:
          $enumDecodeNullable(_$RequestBodyTypeEnumMap, json['bodyType']) ??
              RequestBodyType.text,
      owner: json['owner'] as String? ?? '',
      name: json['name'] as String,
      id: json['id'] as String? ?? '',
      project: json['project'] as String? ?? '',
      variables: (json['variables'] as List<dynamic>?)
              ?.map((e) =>
                  VariableData.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      isDeleted: json['deleted'] as bool? ?? false,
      lastUpdated:
          const DateTimeConverter().fromJson(json['lastUpdated'] as int?),
      requestBodyContentType: $enumDecodeNullable(
              _$RequestBodyTextTypeEnumMap, json['requestBodyContentType']) ??
          RequestBodyTextType.json,
      created: const DateTimeConverter().fromJson(json['created'] as int?),
      directory: json['directory'] as String?,
    );

Map<String, dynamic> _$HttpApiDataToJson(HttpApiData instance) {
  final val = <String, dynamic>{};

  /// Code from: https://github.com/google/quiver-dart/blob/master/lib/src/collection/utils.dart
  bool listsEqual(List? a, List? b) {
    if (a == b) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;

    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }

    return true;
  }

  /// Code from: https://github.com/google/quiver-dart/blob/master/lib/src/collection/utils.dart
  bool mapsEqual(Map? a, Map? b) {
    if (a == b) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;

    for (final k in a.keys) {
      var bValue = b[k];
      if (bValue == null && !b.containsKey(k)) return false;
      if (bValue != a[k]) return false;
    }

    return true;
  }

  /// Code from: https://github.com/google/quiver-dart/blob/master/lib/src/collection/utils.dart
  bool setsEqual(Set? a, Set? b) {
    if (a == b) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;

    return a.containsAll(b);
  }

  void writeNotNull(
      String key, dynamic value, dynamic jsonValue, dynamic defaultValue) {
    if (value == null) return;
    bool areEqual = false;
    if (value is List) {
      areEqual = listsEqual(value, defaultValue);
    } else if (value is Map) {
      areEqual = mapsEqual(value, defaultValue);
    } else if (value is Set) {
      areEqual = setsEqual(value, defaultValue);
    } else {
      areEqual = value == defaultValue;
    }

    if (!areEqual) {
      val[key] = jsonValue;
    }
  }

  writeNotNull('id', instance.id, instance.id, '');
  val['name'] = instance.name;
  writeNotNull('project', instance.project, instance.project, '');
  writeNotNull('owner', instance.owner, instance.owner, '');
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

  /// Code from: https://github.com/google/quiver-dart/blob/master/lib/src/collection/utils.dart
  bool listsEqual(List? a, List? b) {
    if (a == b) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;

    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }

    return true;
  }

  /// Code from: https://github.com/google/quiver-dart/blob/master/lib/src/collection/utils.dart
  bool mapsEqual(Map? a, Map? b) {
    if (a == b) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;

    for (final k in a.keys) {
      var bValue = b[k];
      if (bValue == null && !b.containsKey(k)) return false;
      if (bValue != a[k]) return false;
    }

    return true;
  }

  /// Code from: https://github.com/google/quiver-dart/blob/master/lib/src/collection/utils.dart
  bool setsEqual(Set? a, Set? b) {
    if (a == b) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;

    return a.containsAll(b);
  }

  void writeNotNull(
      String key, dynamic value, dynamic jsonValue, dynamic defaultValue) {
    if (value == null) return;
    bool areEqual = false;
    if (value is List) {
      areEqual = listsEqual(value, defaultValue);
    } else if (value is Map) {
      areEqual = mapsEqual(value, defaultValue);
    } else if (value is Set) {
      areEqual = setsEqual(value, defaultValue);
    } else {
      areEqual = value == defaultValue;
    }

    if (!areEqual) {
      val[key] = jsonValue;
    }
  }

  writeNotNull('isUsed', instance.isUsed, instance.isUsed, true);
  return val;
}
