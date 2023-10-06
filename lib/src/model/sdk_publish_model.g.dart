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

  writeNotNull('public', instance.public, instance.public, false);
  val['id'] = instance.id;
  val['canvasId'] = instance.canvasId;
  val['pageId'] = instance.pageId;
  val['projectId'] = instance.projectId;
  val['nodes'] = const NodesMapConverter().toJson(instance.nodes);
  writeNotNull('lastUpdated', instance.lastUpdated,
      const DateTimeConverter().toJson(instance.lastUpdated), null);
  writeNotNull('version', instance.version, instance.version, null);
  writeNotNull('password', instance.password, instance.password, null);
  writeNotNull('subdomain', instance.subdomain, instance.subdomain, null);
  writeNotNull(
      'breakpoint', instance.breakpoint, instance.breakpoint?.toJson(), null);
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
          const {},
      layoutApis: (json['layoutApis'] as Map?)?.map(
            (k, e) => MapEntry(k as String,
                (e as List<dynamic>).map((e) => e as String).toSet()),
          ) ??
          const {},
    );

Map<String, dynamic> _$SDKPublishUpdatesToJson(SDKPublishUpdates instance) {
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

  writeNotNull('public', instance.public, instance.public, false);
  val['id'] = instance.id;
  val['conditions'] =
      instance.conditions.map((k, e) => MapEntry(k, e.toJson()));
  return val;
}
