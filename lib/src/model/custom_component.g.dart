// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'custom_component.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CustomComponent _$CustomComponentFromJson(Map json) => CustomComponent(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      data: ComponentData.fromJson(
          Map<String, dynamic>.from(json['data'] as Map)),
      createdAt: const DateTimeConverter()
          .fromJson((json['createdAt'] as num?)?.toInt()),
      previewUrl: json['previewUrl'] as String?,
      blurhash: json['blurhash'] as String? ?? '',
    );

Map<String, dynamic> _$CustomComponentToJson(CustomComponent instance) {
  final val = <String, dynamic>{
    'id': instance.id,
  };

  void writeNotNull(
      String key, dynamic value, dynamic jsonValue, dynamic defaultValue) {
    final bool serialize =
        shouldSerialize(key, value, jsonValue, defaultValue, true);

    if (serialize) {
      val[key] = jsonValue;
    }
  }

  writeNotNull('name', instance.name, instance.name, '');
  val['data'] = instance.data.toJson();
  writeNotNull('createdAt', instance.createdAt,
      const DateTimeConverter().toJson(instance.createdAt), null);
  writeNotNull('previewUrl', instance.previewUrl, instance.previewUrl, null);
  writeNotNull('blurhash', instance.blurhash, instance.blurhash, '');
  return val;
}

ComponentData _$ComponentDataFromJson(Map json) => ComponentData(
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      nodes: Map<String, dynamic>.from(json['nodes'] as Map),
      variables: (json['variables'] as Map?)?.map(
            (k, e) => MapEntry(
                k as String,
                (e as List<dynamic>)
                    .map((e) => VariableData.fromJson(
                        Map<String, dynamic>.from(e as Map)))
                    .toSet()),
          ) ??
          {},
      conditions: (json['conditions'] as Map?)?.map(
            (k, e) => MapEntry(
                k as String,
                (e as List<dynamic>)
                    .map((e) => BaseCondition.fromJson(
                        Map<String, dynamic>.from(e as Map)))
                    .toSet()),
          ) ??
          {},
    );

Map<String, dynamic> _$ComponentDataToJson(ComponentData instance) {
  final val = <String, dynamic>{
    'width': instance.width,
    'height': instance.height,
    'nodes': instance.nodes,
  };

  void writeNotNull(
      String key, dynamic value, dynamic jsonValue, dynamic defaultValue) {
    final bool serialize =
        shouldSerialize(key, value, jsonValue, defaultValue, true);

    if (serialize) {
      val[key] = jsonValue;
    }
  }

  writeNotNull(
      'variables',
      instance.variables,
      instance.variables
          .map((k, e) => MapEntry(k, e.map((e) => e.toJson()).toList())),
      const {});
  writeNotNull(
      'conditions',
      instance.conditions,
      instance.conditions
          .map((k, e) => MapEntry(k, e.map((e) => e.toJson()).toList())),
      const {});
  return val;
}
