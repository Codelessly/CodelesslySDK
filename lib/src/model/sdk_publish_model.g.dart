// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sdk_publish_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SDKPublishModel _$SDKPublishModelFromJson(Map json) => SDKPublishModel(
      projectId: json['projectId'] as String,
      updates: json['updates'] == null
          ? null
          : SDKPublishUpdates.fromJson(
              Map<String, dynamic>.from(json['updates'] as Map)),
      pages:
          (json['pages'] as List<dynamic>?)?.map((e) => e as String).toList(),
      layoutIDMap: (json['layoutIDMap'] as Map?)?.map(
        (k, e) => MapEntry(k as String, e as String),
      ),
      fonts: SDKPublishModel.deserializeFonts(
          SDKPublishModel.readLookupMap(json, 'fonts') as Map),
      layouts: SDKPublishModel.deserializeLayouts(
          SDKPublishModel.readLookupMap(json, 'layouts') as Map),
      variables: SDKPublishModel.deserializeVariables(
          SDKPublishModel.readLookupMap(json, 'variables') as Map),
      conditions: SDKPublishModel.deserializeConditions(
          SDKPublishModel.readLookupMap(json, 'conditions') as Map),
      apis: (json['apis'] as Map?)?.map(
        (k, e) => MapEntry(k as String,
            HttpApiData.fromJson(Map<String, dynamic>.from(e as Map))),
      ),
      entryLayoutId: json['entryLayoutId'] as String?,
      entryPageId: json['entryPageId'] as String?,
      entryCanvasId: json['entryCanvasId'] as String?,
      lastUpdated:
          const DateTimeConverter().fromJson(json['lastUpdated'] as int?),
      disabledLayouts: (json['disabledLayouts'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      hiddenLayouts: (json['hiddenLayouts'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      teams: (json['teams'] as List<dynamic>?)?.map((e) => e as String).toSet(),
      users: (json['users'] as List<dynamic>?)?.map((e) => e as String).toSet(),
      roles: (json['roles'] as Map).map(
        (k, e) => MapEntry(k as String, $enumDecode(_$RoleEnumMap, e)),
      ),
      public: json['public'] as bool?,
    );

Map<String, dynamic> _$SDKPublishModelToJson(SDKPublishModel instance) {
  final val = <String, dynamic>{
    'users': instance.users.toList(),
    'roles': instance.roles.map((k, e) => MapEntry(k, _$RoleEnumMap[e]!)),
    'teams': instance.teams.toList(),
    'public': instance.public,
    'projectId': instance.projectId,
    'fonts': SDKPublishModel.serializeLookupMapFonts(instance.fonts),
    'layouts': SDKPublishModel.serializeLookupMapLayouts(instance.layouts),
    'pages': instance.pages,
    'updates': instance.updates.toJson(),
    'apis': instance.apis.map((k, e) => MapEntry(k, e.toJson())),
    'variables':
        SDKPublishModel.serializeLookupMapVariables(instance.variables),
    'conditions':
        SDKPublishModel.serializeLookupMapConditions(instance.conditions),
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
      'entryLayoutId', instance.entryLayoutId, instance.entryLayoutId, null);
  writeNotNull('entryPageId', instance.entryPageId, instance.entryPageId, null);
  writeNotNull(
      'entryCanvasId', instance.entryCanvasId, instance.entryCanvasId, null);
  writeNotNull('lastUpdated', instance.lastUpdated,
      const DateTimeConverter().toJson(instance.lastUpdated), null);
  val['layoutIDMap'] = instance.layoutIDMap;
  val['disabledLayouts'] = instance.disabledLayouts;
  val['hiddenLayouts'] = instance.hiddenLayouts;
  return val;
}

const _$RoleEnumMap = {
  Role.owner: 'owner',
  Role.editor: 'editor',
  Role.viewer: 'viewer',
};

SDKPublishLayout _$SDKPublishLayoutFromJson(Map json) => SDKPublishLayout(
      id: json['id'] as String,
      pageId: json['pageId'] as String,
      projectId: json['projectId'] as String,
      canvases: const CanvasesMapConverter()
          .fromJson(json['canvases'] as Map<String, dynamic>),
      lastUpdated:
          const DateTimeConverter().fromJson(json['lastUpdated'] as int?),
      breakpoints: (json['breakpoints'] as List<dynamic>?)
          ?.map((e) => Breakpoint.fromJson(e as Map))
          .toList(),
      teams: (json['teams'] as List<dynamic>?)?.map((e) => e as String).toSet(),
      users: (json['users'] as List<dynamic>?)?.map((e) => e as String).toSet(),
      roles: (json['roles'] as Map).map(
        (k, e) => MapEntry(k as String, $enumDecode(_$RoleEnumMap, e)),
      ),
      public: json['public'] as bool?,
    );

Map<String, dynamic> _$SDKPublishLayoutToJson(SDKPublishLayout instance) {
  final val = <String, dynamic>{
    'users': instance.users.toList(),
    'roles': instance.roles.map((k, e) => MapEntry(k, _$RoleEnumMap[e]!)),
    'teams': instance.teams.toList(),
    'public': instance.public,
    'id': instance.id,
    'pageId': instance.pageId,
    'projectId': instance.projectId,
    'canvases': const CanvasesMapConverter().toJson(instance.canvases),
    'breakpoints': instance.breakpoints.map((e) => e.toJson()).toList(),
  };

  void writeNotNull(
      String key, dynamic value, dynamic jsonValue, dynamic defaultValue) {
    final bool serialize =
        shouldSerialize(key, value, jsonValue, defaultValue, true);

    if (serialize) {
      val[key] = jsonValue;
    }
  }

  writeNotNull('lastUpdated', instance.lastUpdated,
      const DateTimeConverter().toJson(instance.lastUpdated), null);
  return val;
}

SDKPublishFont _$SDKPublishFontFromJson(Map json) => SDKPublishFont(
      id: json['id'] as String?,
      url: json['url'] as String,
      family: json['family'] as String,
      weight: json['weight'] as String,
      style: json['style'] as String?,
      teams: (json['teams'] as List<dynamic>?)?.map((e) => e as String).toSet(),
      users: (json['users'] as List<dynamic>?)?.map((e) => e as String).toSet(),
      roles: (json['roles'] as Map).map(
        (k, e) => MapEntry(k as String, $enumDecode(_$RoleEnumMap, e)),
      ),
      public: json['public'] as bool?,
    );

Map<String, dynamic> _$SDKPublishFontToJson(SDKPublishFont instance) {
  final val = <String, dynamic>{
    'users': instance.users.toList(),
    'roles': instance.roles.map((k, e) => MapEntry(k, _$RoleEnumMap[e]!)),
    'teams': instance.teams.toList(),
    'public': instance.public,
    'id': instance.id,
    'url': instance.url,
    'family': instance.family,
    'weight': instance.weight,
  };

  void writeNotNull(
      String key, dynamic value, dynamic jsonValue, dynamic defaultValue) {
    final bool serialize =
        shouldSerialize(key, value, jsonValue, defaultValue, true);

    if (serialize) {
      val[key] = jsonValue;
    }
  }

  writeNotNull('style', instance.style, instance.style, null);
  return val;
}

SDKPublishUpdates _$SDKPublishUpdatesFromJson(Map json) => SDKPublishUpdates(
      fonts: json['fonts'] == null
          ? const {}
          : const DateTimeMapConverter()
              .fromJson(json['fonts'] as Map<String, dynamic>),
      layouts: json['layouts'] == null
          ? const {}
          : const DateTimeMapConverter()
              .fromJson(json['layouts'] as Map<String, dynamic>),
      apis: json['apis'] == null
          ? const {}
          : const DateTimeMapConverter()
              .fromJson(json['apis'] as Map<String, dynamic>),
      variables: json['variables'] == null
          ? const {}
          : const DateTimeMapConverter()
              .fromJson(json['variables'] as Map<String, dynamic>),
      conditions: json['conditions'] == null
          ? const {}
          : const DateTimeMapConverter()
              .fromJson(json['conditions'] as Map<String, dynamic>),
      layoutFonts: (json['layoutFonts'] as Map?)?.map(
            (k, e) => MapEntry(k as String,
                (e as List<dynamic>).map((e) => e as String).toSet()),
          ) ??
          {},
      layoutApis: (json['layoutApis'] as Map?)?.map(
            (k, e) => MapEntry(k as String,
                (e as List<dynamic>).map((e) => e as String).toSet()),
          ) ??
          {},
    );

Map<String, dynamic> _$SDKPublishUpdatesToJson(SDKPublishUpdates instance) {
  final val = <String, dynamic>{};

  void writeNotNull(
      String key, dynamic value, dynamic jsonValue, dynamic defaultValue) {
    final bool serialize =
        shouldSerialize(key, value, jsonValue, defaultValue, true);

    if (serialize) {
      val[key] = jsonValue;
    }
  }

  writeNotNull('fonts', instance.fonts,
      const DateTimeMapConverter().toJson(instance.fonts), const {});
  writeNotNull('layouts', instance.layouts,
      const DateTimeMapConverter().toJson(instance.layouts), const {});
  writeNotNull('apis', instance.apis,
      const DateTimeMapConverter().toJson(instance.apis), const {});
  writeNotNull('variables', instance.variables,
      const DateTimeMapConverter().toJson(instance.variables), const {});
  writeNotNull('conditions', instance.conditions,
      const DateTimeMapConverter().toJson(instance.conditions), const {});
  writeNotNull('layoutFonts', instance.layoutFonts,
      instance.layoutFonts.map((k, e) => MapEntry(k, e.toList())), const {});
  writeNotNull('layoutApis', instance.layoutApis,
      instance.layoutApis.map((k, e) => MapEntry(k, e.toList())), const {});
  return val;
}

SDKLayoutVariables _$SDKLayoutVariablesFromJson(Map json) => SDKLayoutVariables(
      id: json['id'] as String,
      variables: (json['variables'] as Map).map(
        (k, e) => MapEntry(
            k as String,
            (e as Map).map(
              (k, e) => MapEntry(k as String,
                  VariableData.fromJson(Map<String, dynamic>.from(e as Map))),
            )),
      ),
      teams: (json['teams'] as List<dynamic>?)?.map((e) => e as String).toSet(),
      users: (json['users'] as List<dynamic>?)?.map((e) => e as String).toSet(),
      roles: (json['roles'] as Map).map(
        (k, e) => MapEntry(k as String, $enumDecode(_$RoleEnumMap, e)),
      ),
      public: json['public'] as bool?,
    );

Map<String, dynamic> _$SDKLayoutVariablesToJson(SDKLayoutVariables instance) =>
    <String, dynamic>{
      'users': instance.users.toList(),
      'roles': instance.roles.map((k, e) => MapEntry(k, _$RoleEnumMap[e]!)),
      'teams': instance.teams.toList(),
      'public': instance.public,
      'id': instance.id,
      'variables': instance.variables
          .map((k, e) => MapEntry(k, e.map((k, e) => MapEntry(k, e.toJson())))),
    };

SDKLayoutConditions _$SDKLayoutConditionsFromJson(Map json) =>
    SDKLayoutConditions(
      id: json['id'] as String,
      conditions: (json['conditions'] as Map).map(
        (k, e) => MapEntry(
            k as String,
            (e as Map).map(
              (k, e) => MapEntry(k as String,
                  BaseCondition.fromJson(Map<String, dynamic>.from(e as Map))),
            )),
      ),
      teams: (json['teams'] as List<dynamic>?)?.map((e) => e as String).toSet(),
      users: (json['users'] as List<dynamic>?)?.map((e) => e as String).toSet(),
      roles: (json['roles'] as Map).map(
        (k, e) => MapEntry(k as String, $enumDecode(_$RoleEnumMap, e)),
      ),
      public: json['public'] as bool?,
    );

Map<String, dynamic> _$SDKLayoutConditionsToJson(
        SDKLayoutConditions instance) =>
    <String, dynamic>{
      'users': instance.users.toList(),
      'roles': instance.roles.map((k, e) => MapEntry(k, _$RoleEnumMap[e]!)),
      'teams': instance.teams.toList(),
      'public': instance.public,
      'id': instance.id,
      'conditions': instance.conditions
          .map((k, e) => MapEntry(k, e.map((k, e) => MapEntry(k, e.toJson())))),
    };
