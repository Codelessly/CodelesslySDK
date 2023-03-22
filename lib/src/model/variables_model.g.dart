// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'variables_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VariableData _$VariableDataFromJson(Map json) => VariableData(
      id: json['id'] as String,
      name: json['name'] as String,
      value: json['value'] as String? ?? '',
      isUsed: json['isUsed'] as bool? ?? true,
      type: $enumDecodeNullable(_$VariableTypeEnumMap, json['type']) ??
          VariableType.text,
      nodes: (json['nodes'] as List<dynamic>?)?.map((e) => e as String).toSet(),
    );

Map<String, dynamic> _$VariableDataToJson(VariableData instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'nodes': instance.nodes.toList(),
      'value': instance.value,
      'type': _$VariableTypeEnumMap[instance.type]!,
      'isUsed': instance.isUsed,
    };

const _$VariableTypeEnumMap = {
  VariableType.integer: 'integer',
  VariableType.text: 'text',
  VariableType.decimal: 'decimal',
  VariableType.boolean: 'boolean',
  VariableType.list: 'list',
};

ProjectVariables _$ProjectVariablesFromJson(Map json) => ProjectVariables(
      id: json['id'] as String,
      owner: json['owner'] as String? ?? '',
      globalVariables: (json['globalVariables'] as Map?)?.map(
        (k, e) => MapEntry(k as String,
            VariableData.fromJson(Map<String, dynamic>.from(e as Map))),
      ),
      pageVariables:
          pageVariablesFromJson(json['pageVariables'] as Map<String, dynamic>),
      lastUpdated: jsonToDate(json['lastUpdated'] as int?),
    );

Map<String, dynamic> _$ProjectVariablesToJson(ProjectVariables instance) =>
    <String, dynamic>{
      'globalVariables':
          instance.globalVariables.map((k, e) => MapEntry(k, e.toJson())),
      'pageVariables': pageVariablesToJson(instance.pageVariables),
      'id': instance.id,
      'owner': instance.owner,
      'lastUpdated': dateToJson(instance.lastUpdated),
    };

PageVariables _$PageVariablesFromJson(Map json) => PageVariables(
      id: json['id'] as String,
      variables:
          canvasVariablesFromJson(json['variables'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$PageVariablesToJson(PageVariables instance) =>
    <String, dynamic>{
      'id': instance.id,
      'variables': canvasVariablesToJson(instance.variables),
    };

CanvasVariables _$CanvasVariablesFromJson(Map json) => CanvasVariables(
      id: json['id'] as String,
      variables: (json['variables'] as Map).map(
        (k, e) => MapEntry(k as String,
            CanvasVariableData.fromJson(Map<String, dynamic>.from(e as Map))),
      ),
    );

Map<String, dynamic> _$CanvasVariablesToJson(CanvasVariables instance) =>
    <String, dynamic>{
      'id': instance.id,
      'variables': instance.variables.map((k, e) => MapEntry(k, e.toJson())),
    };

CanvasVariableData _$CanvasVariableDataFromJson(Map json) => CanvasVariableData(
      id: json['id'] as String,
      canvasId: json['canvasId'] as String,
      name: json['name'] as String,
      type: $enumDecodeNullable(_$VariableTypeEnumMap, json['type']) ??
          VariableType.text,
      value: json['value'] as String? ?? '',
      isUsed: json['isUsed'] as bool? ?? true,
      nodes: (json['nodes'] as List<dynamic>?)?.map((e) => e as String).toSet(),
    );

Map<String, dynamic> _$CanvasVariableDataToJson(CanvasVariableData instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'nodes': instance.nodes.toList(),
      'value': instance.value,
      'type': _$VariableTypeEnumMap[instance.type]!,
      'isUsed': instance.isUsed,
      'canvasId': instance.canvasId,
    };
