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
      lastUpdated:
          const DateTimeConverter().fromJson(json['lastUpdated'] as int?),
    );

Map<String, dynamic> _$SDKPublishModelToJson(SDKPublishModel instance) {
  final val = <String, dynamic>{
    'owner': instance.owner,
    'editors': instance.editors.toList(),
    'viewers': instance.viewers.toList(),
  };

  void writeNotNull(
      String key, dynamic value, dynamic jsonValue, dynamic defaultValue) {
    final bool serialize =
        shouldSerialize(key, value, jsonValue, defaultValue, true);

    if (serialize) {
      val[key] = jsonValue;
    }
  }

  writeNotNull('public', instance.public, instance.public, false);
  val['projectId'] = instance.projectId;
  val['fonts'] = instance.fonts.map((k, e) => MapEntry(k, e.toJson()));
  val['layouts'] = instance.layouts.map((k, e) => MapEntry(k, e.toJson()));
  val['pages'] = instance.pages;
  val['updates'] = instance.updates.toJson();
  val['apis'] = instance.apis.map((k, e) => MapEntry(k, e.toJson()));
  val['variables'] = instance.variables.map((k, e) => MapEntry(k, e.toJson()));
  val['conditions'] =
      instance.conditions.map((k, e) => MapEntry(k, e.toJson()));
  writeNotNull(
      'entryLayoutId', instance.entryLayoutId, instance.entryLayoutId, null);
  writeNotNull('entryPageId', instance.entryPageId, instance.entryPageId, null);
  writeNotNull(
      'entryCanvasId', instance.entryCanvasId, instance.entryCanvasId, null);
  writeNotNull('lastUpdated', instance.lastUpdated,
      const DateTimeConverter().toJson(instance.lastUpdated), null);
  return val;
}

SDKPublishLayout _$SDKPublishLayoutFromJson(Map json) => SDKPublishLayout(
      id: json['id'] as String,
      pageId: json['pageId'] as String,
      projectId: json['projectId'] as String,
      canvases: const CanvasesMapConverter().fromJson(
          SDKPublishLayout.nodesOrCanvasesReader(json, 'canvases')
              as Map<String, dynamic>),
      lastUpdated:
          const DateTimeConverter().fromJson(json['lastUpdated'] as int?),
      breakpoints: (json['breakpoints'] as List<dynamic>?)
          ?.map((e) => Breakpoint.fromJson(e as Map))
          .toList(),
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
  };

  void writeNotNull(
      String key, dynamic value, dynamic jsonValue, dynamic defaultValue) {
    final bool serialize =
        shouldSerialize(key, value, jsonValue, defaultValue, true);

    if (serialize) {
      val[key] = jsonValue;
    }
  }

  writeNotNull('public', instance.public, instance.public, false);
  val['id'] = instance.id;
  val['pageId'] = instance.pageId;
  val['projectId'] = instance.projectId;
  val['canvases'] = const CanvasesMapConverter().toJson(instance.canvases);
  val['breakpoints'] = instance.breakpoints.map((e) => e.toJson()).toList();
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
  };

  void writeNotNull(
      String key, dynamic value, dynamic jsonValue, dynamic defaultValue) {
    final bool serialize =
        shouldSerialize(key, value, jsonValue, defaultValue, true);

    if (serialize) {
      val[key] = jsonValue;
    }
  }

  writeNotNull('public', instance.public, instance.public, false);
  val['id'] = instance.id;
  val['url'] = instance.url;
  val['family'] = instance.family;
  val['weight'] = instance.weight;
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

Map<String, dynamic> _$SDKLayoutVariablesToJson(SDKLayoutVariables instance) {
  final val = <String, dynamic>{
    'owner': instance.owner,
    'editors': instance.editors.toList(),
    'viewers': instance.viewers.toList(),
  };

  void writeNotNull(
      String key, dynamic value, dynamic jsonValue, dynamic defaultValue) {
    final bool serialize =
        shouldSerialize(key, value, jsonValue, defaultValue, true);

    if (serialize) {
      val[key] = jsonValue;
    }
  }

  writeNotNull('public', instance.public, instance.public, false);
  val['id'] = instance.id;
  val['variables'] = instance.variables.map((k, e) => MapEntry(k, e.toJson()));
  return val;
}

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

Map<String, dynamic> _$SDKLayoutConditionsToJson(SDKLayoutConditions instance) {
  final val = <String, dynamic>{
    'owner': instance.owner,
    'editors': instance.editors.toList(),
    'viewers': instance.viewers.toList(),
  };

  void writeNotNull(
      String key, dynamic value, dynamic jsonValue, dynamic defaultValue) {
    final bool serialize =
        shouldSerialize(key, value, jsonValue, defaultValue, true);

    if (serialize) {
      val[key] = jsonValue;
    }
  }

  writeNotNull('public', instance.public, instance.public, false);
  val['id'] = instance.id;
  val['conditions'] =
      instance.conditions.map((k, e) => MapEntry(k, e.toJson()));
  return val;
}
