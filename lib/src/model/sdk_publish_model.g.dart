// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sdk_publish_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SDKPublishModel _$SDKPublishModelFromJson(Map json) => SDKPublishModel(
      projectId: json['projectId'] as String,
      fonts: (json['fonts'] as Map?)?.map(
        (k, e) => MapEntry(k as String,
            SDKPublishFont.fromJson(Map<String, dynamic>.from(e as Map))),
      ),
      layouts: (json['layouts'] as Map?)?.map(
        (k, e) => MapEntry(k as String,
            SDKPublishLayout.fromJson(Map<String, dynamic>.from(e as Map))),
      ),
      updates: json['updates'] == null
          ? null
          : SDKPublishUpdates.fromJson(
              Map<String, dynamic>.from(json['updates'] as Map)),
      apis: (json['apis'] as Map?)?.map(
        (k, e) => MapEntry(k as String,
            HttpApiData.fromJson(Map<String, dynamic>.from(e as Map))),
      ),
      variables: (json['variables'] as Map?)?.map(
        (k, e) => MapEntry(k as String,
            SDKLayoutVariables.fromJson(Map<String, dynamic>.from(e as Map))),
      ),
      conditions: (json['conditions'] as Map?)?.map(
        (k, e) => MapEntry(k as String,
            SDKLayoutConditions.fromJson(Map<String, dynamic>.from(e as Map))),
      ),
      pages:
          (json['pages'] as List<dynamic>?)?.map((e) => e as String).toList(),
      entryLayoutId: json['entryLayoutId'] as String?,
      entryPageId: json['entryPageId'] as String?,
      entryCanvasId: json['entryCanvasId'] as String?,
      owner: json['owner'] as String,
      editors:
          (json['editors'] as List<dynamic>?)?.map((e) => e as String).toSet(),
      viewers:
          (json['viewers'] as List<dynamic>?)?.map((e) => e as String).toSet(),
      public: json['public'] as bool? ?? false,
    );

Map<String, dynamic> _$SDKPublishModelToJson(SDKPublishModel instance) {
  final val = <String, dynamic>{
    'owner': instance.owner,
    'editors': instance.editors.toList(),
    'viewers': instance.viewers.toList(),
    'public': instance.public,
    'projectId': instance.projectId,
    'fonts': instance.fonts.map((k, e) => MapEntry(k, e.toJson())),
    'layouts': instance.layouts.map((k, e) => MapEntry(k, e.toJson())),
    'pages': instance.pages,
    'updates': instance.updates.toJson(),
    'apis': instance.apis.map((k, e) => MapEntry(k, e.toJson())),
    'variables': instance.variables.map((k, e) => MapEntry(k, e.toJson())),
    'conditions': instance.conditions.map((k, e) => MapEntry(k, e.toJson())),
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('entryLayoutId', instance.entryLayoutId);
  writeNotNull('entryPageId', instance.entryPageId);
  writeNotNull('entryCanvasId', instance.entryCanvasId);
  return val;
}

SDKPublishLayout _$SDKPublishLayoutFromJson(Map json) => SDKPublishLayout(
      id: json['id'] as String,
      canvasId: json['canvasId'] as String,
      pageId: json['pageId'] as String,
      projectId: json['projectId'] as String,
      nodes: const NodesMapConverter()
          .fromJson(json['nodes'] as Map<String, dynamic>),
      lastUpdated:
          const DateTimeConverter().fromJson(json['lastUpdated'] as int?),
      version: json['version'] as int?,
      password: json['password'] as String?,
      subdomain: json['subdomain'] as String?,
      breakpoint: json['breakpoint'] == null
          ? null
          : Breakpoint.fromJson(json['breakpoint'] as Map),
      owner: json['owner'] as String,
      editors:
          (json['editors'] as List<dynamic>?)?.map((e) => e as String).toSet(),
      viewers:
          (json['viewers'] as List<dynamic>?)?.map((e) => e as String).toSet(),
      public: json['public'] as bool? ?? false,
    );

Map<String, dynamic> _$SDKPublishLayoutToJson(SDKPublishLayout instance) {
  final val = <String, dynamic>{
    'owner': instance.owner,
    'editors': instance.editors.toList(),
    'viewers': instance.viewers.toList(),
    'public': instance.public,
    'id': instance.id,
    'canvasId': instance.canvasId,
    'pageId': instance.pageId,
    'projectId': instance.projectId,
    'nodes': const NodesMapConverter().toJson(instance.nodes),
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull(
      'lastUpdated', const DateTimeConverter().toJson(instance.lastUpdated));
  writeNotNull('version', instance.version);
  writeNotNull('password', instance.password);
  writeNotNull('subdomain', instance.subdomain);
  writeNotNull('breakpoint', instance.breakpoint?.toJson());
  return val;
}

SDKPublishFont _$SDKPublishFontFromJson(Map json) => SDKPublishFont(
      id: json['id'] as String?,
      url: json['url'] as String,
      family: json['family'] as String,
      weight: json['weight'] as String,
      style: json['style'] as String?,
      owner: json['owner'] as String,
      editors:
          (json['editors'] as List<dynamic>?)?.map((e) => e as String).toSet(),
      viewers:
          (json['viewers'] as List<dynamic>?)?.map((e) => e as String).toSet(),
      public: json['public'] as bool? ?? false,
    );

Map<String, dynamic> _$SDKPublishFontToJson(SDKPublishFont instance) {
  final val = <String, dynamic>{
    'owner': instance.owner,
    'editors': instance.editors.toList(),
    'viewers': instance.viewers.toList(),
    'public': instance.public,
    'id': instance.id,
    'url': instance.url,
    'family': instance.family,
    'weight': instance.weight,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('style', instance.style);
  return val;
}

SDKPublishUpdates _$SDKPublishUpdatesFromJson(Map json) => SDKPublishUpdates(
      fonts: json['fonts'] == null
          ? const {}
          : const DateTimeMapConverter()
              .fromJson(json['fonts'] as Map<String, int>),
      layouts: json['layouts'] == null
          ? const {}
          : const DateTimeMapConverter()
              .fromJson(json['layouts'] as Map<String, int>),
      apis: json['apis'] == null
          ? const {}
          : const DateTimeMapConverter()
              .fromJson(json['apis'] as Map<String, int>),
      variables: json['variables'] == null
          ? const {}
          : const DateTimeMapConverter()
              .fromJson(json['variables'] as Map<String, int>),
      conditions: json['conditions'] == null
          ? const {}
          : const DateTimeMapConverter()
              .fromJson(json['conditions'] as Map<String, int>),
      layoutFonts: (json['layoutFonts'] as Map?)?.map(
            (k, e) => MapEntry(k as String,
                (e as List<dynamic>).map((e) => e as String).toSet()),
          ) ??
          const {},
      layoutApis: (json['layoutApis'] as Map?)?.map(
            (k, e) => MapEntry(k as String,
                (e as List<dynamic>).map((e) => e as String).toSet()),
          ) ??
          const {},
    );

Map<String, dynamic> _$SDKPublishUpdatesToJson(SDKPublishUpdates instance) =>
    <String, dynamic>{
      'fonts': const DateTimeMapConverter().toJson(instance.fonts),
      'layouts': const DateTimeMapConverter().toJson(instance.layouts),
      'apis': const DateTimeMapConverter().toJson(instance.apis),
      'variables': const DateTimeMapConverter().toJson(instance.variables),
      'conditions': const DateTimeMapConverter().toJson(instance.conditions),
      'layoutFonts':
          instance.layoutFonts.map((k, e) => MapEntry(k, e.toList())),
      'layoutApis': instance.layoutApis.map((k, e) => MapEntry(k, e.toList())),
    };

SDKLayoutVariables _$SDKLayoutVariablesFromJson(Map json) => SDKLayoutVariables(
      id: json['id'] as String,
      variables: (json['variables'] as Map).map(
        (k, e) => MapEntry(k as String,
            VariableData.fromJson(Map<String, dynamic>.from(e as Map))),
      ),
      owner: json['owner'] as String,
      editors:
          (json['editors'] as List<dynamic>?)?.map((e) => e as String).toSet(),
      viewers:
          (json['viewers'] as List<dynamic>?)?.map((e) => e as String).toSet(),
      public: json['public'] as bool? ?? false,
    );

Map<String, dynamic> _$SDKLayoutVariablesToJson(SDKLayoutVariables instance) =>
    <String, dynamic>{
      'owner': instance.owner,
      'editors': instance.editors.toList(),
      'viewers': instance.viewers.toList(),
      'public': instance.public,
      'id': instance.id,
      'variables': instance.variables.map((k, e) => MapEntry(k, e.toJson())),
    };

SDKLayoutConditions _$SDKLayoutConditionsFromJson(Map json) =>
    SDKLayoutConditions(
      id: json['id'] as String,
      conditions: (json['conditions'] as Map).map(
        (k, e) => MapEntry(k as String,
            BaseCondition.fromJson(Map<String, dynamic>.from(e as Map))),
      ),
      owner: json['owner'] as String,
      editors:
          (json['editors'] as List<dynamic>?)?.map((e) => e as String).toSet(),
      viewers:
          (json['viewers'] as List<dynamic>?)?.map((e) => e as String).toSet(),
      public: json['public'] as bool? ?? false,
    );

Map<String, dynamic> _$SDKLayoutConditionsToJson(
        SDKLayoutConditions instance) =>
    <String, dynamic>{
      'owner': instance.owner,
      'editors': instance.editors.toList(),
      'viewers': instance.viewers.toList(),
      'public': instance.public,
      'id': instance.id,
      'conditions': instance.conditions.map((k, e) => MapEntry(k, e.toJson())),
    };
