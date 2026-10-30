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
          Map<String, dynamic>.from(json['updates'] as Map),
        ),
  pages: (json['pages'] as List<dynamic>?)?.map((e) => e as String).toList(),
  layoutIDMap: (json['layoutIDMap'] as Map?)?.map(
    (k, e) => MapEntry(k as String, e as String),
  ),
  fonts: SDKPublishModel.readLookupMap(json, 'fonts') == null
      ? null
      : SDKPublishModel.deserializeFonts(
          SDKPublishModel.readLookupMap(json, 'fonts') as Map,
        ),
  layouts: SDKPublishModel.readLookupMap(json, 'layouts') == null
      ? null
      : SDKPublishModel.deserializeLayouts(
          SDKPublishModel.readLookupMap(json, 'layouts') as Map,
        ),
  variables: SDKPublishModel.readLookupMap(json, 'variables') == null
      ? null
      : SDKPublishModel.deserializeVariables(
          SDKPublishModel.readLookupMap(json, 'variables') as Map,
        ),
  conditions: SDKPublishModel.readLookupMap(json, 'conditions') == null
      ? null
      : SDKPublishModel.deserializeConditions(
          SDKPublishModel.readLookupMap(json, 'conditions') as Map,
        ),
  apis: (json['apis'] as Map?)?.map(
    (k, e) => MapEntry(
      k as String,
      HttpApiData.fromJson(Map<String, dynamic>.from(e as Map)),
    ),
  ),
  entryLayoutId: json['entryLayoutId'] as String?,
  entryPageId: json['entryPageId'] as String?,
  entryCanvasId: json['entryCanvasId'] as String?,
  lastUpdated: const DateTimeConverter().fromJson(
    (json['lastUpdated'] as num?)?.toInt(),
  ),
  disabledLayouts: (json['disabledLayouts'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  owner: json['owner'] as String,
  teams: (json['teams'] as List<dynamic>?)?.map((e) => e as String).toSet(),
  users: (json['users'] as List<dynamic>?)?.map((e) => e as String).toSet(),
  roles: (json['roles'] as Map).map(
    (k, e) => MapEntry(k as String, Role.fromJson(e as String)),
  ),
  public: json['public'] as bool?,
);

Map<String, dynamic> _$SDKPublishModelToJson(
  SDKPublishModel instance,
) => <String, dynamic>{
  'owner': instance.owner,
  'users': instance.users.toList(),
  'roles': instance.roles.map((k, e) => MapEntry(k, e.toJson())),
  'teams': instance.teams.toList(),
  'public': instance.public,
  'projectId': instance.projectId,
  'fonts': SDKPublishModel.serializeLookupMapFonts(instance.fonts),
  'layouts': SDKPublishModel.serializeLookupMapLayouts(instance.layouts),
  'pages': instance.pages,
  'updates': instance.updates.toJson(),
  'apis': instance.apis.map((k, e) => MapEntry(k, e.toJson())),
  'variables': SDKPublishModel.serializeLookupMapVariables(instance.variables),
  'conditions': SDKPublishModel.serializeLookupMapConditions(
    instance.conditions,
  ),
  'entryLayoutId': ?instance.entryLayoutId,
  'entryPageId': ?instance.entryPageId,
  'entryCanvasId': ?instance.entryCanvasId,
  'lastUpdated': ?const DateTimeConverter().toJson(instance.lastUpdated),
  'layoutIDMap': instance.layoutIDMap,
  'disabledLayouts': instance.disabledLayouts,
};

SDKPublishLayout _$SDKPublishLayoutFromJson(Map json) => SDKPublishLayout(
  id: json['id'] as String,
  pageId: json['pageId'] as String,
  projectId: json['projectId'] as String,
  canvases: const CanvasesMapConverter().fromJson(
    json['canvases'] as Map<String, dynamic>,
  ),
  lastUpdated: const DateTimeConverter().fromJson(
    (json['lastUpdated'] as num?)?.toInt(),
  ),
  breakpoints: (json['breakpoints'] as List<dynamic>?)
      ?.map((e) => Breakpoint.fromJson(e as Map))
      .toList(),
  hidden: json['hidden'] as bool?,
  theme: json['theme'] == null
      ? null
      : ThemeTokens.fromJson(json['theme'] as Map),
  owner: json['owner'] as String,
  teams: (json['teams'] as List<dynamic>?)?.map((e) => e as String).toSet(),
  users: (json['users'] as List<dynamic>?)?.map((e) => e as String).toSet(),
  roles: (json['roles'] as Map).map(
    (k, e) => MapEntry(k as String, Role.fromJson(e as String)),
  ),
  public: json['public'] as bool?,
);

Map<String, dynamic> _$SDKPublishLayoutToJson(SDKPublishLayout instance) =>
    <String, dynamic>{
      'owner': instance.owner,
      'users': instance.users.toList(),
      'roles': instance.roles.map((k, e) => MapEntry(k, e.toJson())),
      'teams': instance.teams.toList(),
      'public': instance.public,
      'id': instance.id,
      'pageId': instance.pageId,
      'projectId': instance.projectId,
      'canvases': const CanvasesMapConverter().toJson(instance.canvases),
      'breakpoints': instance.breakpoints.map((e) => e.toJson()).toList(),
      'lastUpdated': ?const DateTimeConverter().toJson(instance.lastUpdated),
      'hidden': instance.hidden,
      'theme': ?instance.theme?.toJson(),
    };

SDKPublishFont _$SDKPublishFontFromJson(Map json) => SDKPublishFont(
  id: json['id'] as String?,
  url: json['url'] as String,
  family: json['family'] as String,
  weight: json['weight'] as String,
  style: json['style'] as String?,
  owner: json['owner'] as String,
  teams: (json['teams'] as List<dynamic>?)?.map((e) => e as String).toSet(),
  users: (json['users'] as List<dynamic>?)?.map((e) => e as String).toSet(),
  roles: (json['roles'] as Map).map(
    (k, e) => MapEntry(k as String, Role.fromJson(e as String)),
  ),
  public: json['public'] as bool?,
);

Map<String, dynamic> _$SDKPublishFontToJson(SDKPublishFont instance) =>
    <String, dynamic>{
      'owner': instance.owner,
      'users': instance.users.toList(),
      'roles': instance.roles.map((k, e) => MapEntry(k, e.toJson())),
      'teams': instance.teams.toList(),
      'public': instance.public,
      'id': instance.id,
      'url': instance.url,
      'family': instance.family,
      'weight': instance.weight,
      'style': ?instance.style,
    };

SDKPublishUpdates _$SDKPublishUpdatesFromJson(Map json) => SDKPublishUpdates(
  fonts: json['fonts'] == null
      ? const {}
      : const DateTimeMapConverter().fromJson(
          json['fonts'] as Map<String, dynamic>,
        ),
  layouts: json['layouts'] == null
      ? const {}
      : const DateTimeMapConverter().fromJson(
          json['layouts'] as Map<String, dynamic>,
        ),
  apis: json['apis'] == null
      ? const {}
      : const DateTimeMapConverter().fromJson(
          json['apis'] as Map<String, dynamic>,
        ),
  variables: json['variables'] == null
      ? const {}
      : const DateTimeMapConverter().fromJson(
          json['variables'] as Map<String, dynamic>,
        ),
  conditions: json['conditions'] == null
      ? const {}
      : const DateTimeMapConverter().fromJson(
          json['conditions'] as Map<String, dynamic>,
        ),
  layoutFonts:
      (json['layoutFonts'] as Map?)?.map(
        (k, e) => MapEntry(
          k as String,
          (e as List<dynamic>).map((e) => e as String).toSet(),
        ),
      ) ??
      const {},
  layoutApis:
      (json['layoutApis'] as Map?)?.map(
        (k, e) => MapEntry(
          k as String,
          (e as List<dynamic>).map((e) => e as String).toSet(),
        ),
      ) ??
      const {},
  layoutCanvases:
      (json['layoutCanvases'] as Map?)?.map(
        (k, e) => MapEntry(
          k as String,
          (e as List<dynamic>).map((e) => e as String).toSet(),
        ),
      ) ??
      const {},
  canvasPaths:
      (json['canvasPaths'] as Map?)?.map(
        (k, e) => MapEntry(k as String, e as String),
      ) ??
      const {},
);

Map<String, dynamic> _$SDKPublishUpdatesToJson(
  SDKPublishUpdates instance,
) => <String, dynamic>{
  'fonts': const DateTimeMapConverter().toJson(instance.fonts),
  'layouts': const DateTimeMapConverter().toJson(instance.layouts),
  'apis': const DateTimeMapConverter().toJson(instance.apis),
  'variables': const DateTimeMapConverter().toJson(instance.variables),
  'conditions': const DateTimeMapConverter().toJson(instance.conditions),
  'layoutFonts': instance.layoutFonts.map((k, e) => MapEntry(k, e.toList())),
  'layoutApis': instance.layoutApis.map((k, e) => MapEntry(k, e.toList())),
  'layoutCanvases': instance.layoutCanvases.map(
    (k, e) => MapEntry(k, e.toList()),
  ),
  'canvasPaths': instance.canvasPaths,
};

SDKLayoutVariables _$SDKLayoutVariablesFromJson(Map json) => SDKLayoutVariables(
  id: json['id'] as String,
  variables: (json['variables'] as Map).map(
    (k, e) => MapEntry(
      k as String,
      (e as Map).map(
        (k, e) => MapEntry(
          k as String,
          VariableData.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      ),
    ),
  ),
  owner: json['owner'] as String,
  teams: (json['teams'] as List<dynamic>?)?.map((e) => e as String).toSet(),
  users: (json['users'] as List<dynamic>?)?.map((e) => e as String).toSet(),
  roles: (json['roles'] as Map).map(
    (k, e) => MapEntry(k as String, Role.fromJson(e as String)),
  ),
  public: json['public'] as bool?,
);

Map<String, dynamic> _$SDKLayoutVariablesToJson(SDKLayoutVariables instance) =>
    <String, dynamic>{
      'owner': instance.owner,
      'users': instance.users.toList(),
      'roles': instance.roles.map((k, e) => MapEntry(k, e.toJson())),
      'teams': instance.teams.toList(),
      'public': instance.public,
      'id': instance.id,
      'variables': instance.variables.map(
        (k, e) => MapEntry(k, e.map((k, e) => MapEntry(k, e.toJson()))),
      ),
    };

SDKLayoutConditions _$SDKLayoutConditionsFromJson(Map json) =>
    SDKLayoutConditions(
      id: json['id'] as String,
      conditions: (json['conditions'] as Map).map(
        (k, e) => MapEntry(
          k as String,
          (e as Map).map(
            (k, e) => MapEntry(
              k as String,
              BaseCondition.fromJson(Map<String, dynamic>.from(e as Map)),
            ),
          ),
        ),
      ),
      owner: json['owner'] as String,
      teams: (json['teams'] as List<dynamic>?)?.map((e) => e as String).toSet(),
      users: (json['users'] as List<dynamic>?)?.map((e) => e as String).toSet(),
      roles: (json['roles'] as Map).map(
        (k, e) => MapEntry(k as String, Role.fromJson(e as String)),
      ),
      public: json['public'] as bool?,
    );

Map<String, dynamic> _$SDKLayoutConditionsToJson(
  SDKLayoutConditions instance,
) => <String, dynamic>{
  'owner': instance.owner,
  'users': instance.users.toList(),
  'roles': instance.roles.map((k, e) => MapEntry(k, e.toJson())),
  'teams': instance.teams.toList(),
  'public': instance.public,
  'id': instance.id,
  'conditions': instance.conditions.map(
    (k, e) => MapEntry(k, e.map((k, e) => MapEntry(k, e.toJson()))),
  ),
};
