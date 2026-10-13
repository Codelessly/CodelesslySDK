// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'custom_component.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CustomComponent _$CustomComponentFromJson(Map json) => CustomComponent(
  id: json['id'] as String,
  name: json['name'] as String? ?? '',
  data: ComponentData.fromJson(Map<String, dynamic>.from(json['data'] as Map)),
  createdAt: const DateTimeConverter().fromJson(
    (json['createdAt'] as num?)?.toInt(),
  ),
  previewUrl: json['previewUrl'] as String?,
  blurhash: json['blurhash'] as String? ?? '',
  projectId: json['projectId'] as String,
  pageId: json['pageId'] as String,
  version: (json['version'] as num?)?.toInt(),
);

Map<String, dynamic> _$CustomComponentToJson(CustomComponent instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'data': instance.data.toJson(),
      'createdAt': ?const DateTimeConverter().toJson(instance.createdAt),
      'previewUrl': ?instance.previewUrl,
      'blurhash': instance.blurhash,
      'projectId': instance.projectId,
      'pageId': instance.pageId,
      'version': instance.version,
    };

ComponentData _$ComponentDataFromJson(Map json) => ComponentData(
  width: (json['width'] as num).toDouble(),
  height: (json['height'] as num).toDouble(),
  nodes: Map<String, dynamic>.from(json['nodes'] as Map),
  variables:
      (json['variables'] as Map?)?.map(
        (k, e) => MapEntry(
          k as String,
          (e as List<dynamic>)
              .map(
                (e) =>
                    VariableData.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toSet(),
        ),
      ) ??
      const {},
  conditions:
      (json['conditions'] as Map?)?.map(
        (k, e) => MapEntry(
          k as String,
          (e as List<dynamic>)
              .map(
                (e) =>
                    BaseCondition.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toSet(),
        ),
      ) ??
      const {},
  parentId: json['parentId'] as String,
  originalParentId: json['originalParentId'] as String,
);

Map<String, dynamic> _$ComponentDataToJson(ComponentData instance) =>
    <String, dynamic>{
      'width': instance.width,
      'height': instance.height,
      'nodes': instance.nodes,
      'variables': instance.variables.map(
        (k, e) => MapEntry(k, e.map((e) => e.toJson()).toList()),
      ),
      'conditions': instance.conditions.map(
        (k, e) => MapEntry(k, e.map((e) => e.toJson()).toList()),
      ),
      'parentId': instance.parentId,
      'originalParentId': instance.originalParentId,
    };
