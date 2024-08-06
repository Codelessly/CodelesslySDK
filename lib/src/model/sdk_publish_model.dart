import 'dart:convert';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_json_annotation/codelessly_json_annotation.dart';
import 'package:equatable/equatable.dart';

import 'model_http_request.dart';
import 'privacy_base.dart';

part 'sdk_publish_model.g.dart';

/// A record typedef that holds a lookup map and a data map.
/// This is used to create a [LookupMap] extension type.
///
/// The [lookupMap] is a map that maps a custom id to the original id.
/// The [dataMap] is the actual data map that holds the data.
typedef LookupMapRecord<T> = ({
  Map<String, String> lookupMap,
  Map<String, T> dataMap
});

/// An extension type that allows for automatic correction of custom ids to
/// the original id.
///
/// This is used to automatically correct the id when accessing the data.
class LookupMap<T> {
  final LookupMapRecord<T> value;

  LookupMap(this.value);

  /// Takes a [key] and outputs either itself or the looked-up key associated
  /// by the [value.lookupMap].
  String correctedKey(String key) => value.lookupMap[key] ?? key;

  /// Returns the data associated with the corrected key.
  T? operator [](String key) => value.dataMap[correctedKey(key)];

  /// Sets the data associated with the corrected key.
  operator []=(String key, T data) => value.dataMap[correctedKey(key)] = data;

  /// Removes the data associated with the corrected key.
  void remove(String customID) => value.dataMap.remove(correctedKey(customID));

  /// Returns true if the corrected key is in the data map.
  bool containsKey(String customID) =>
      value.dataMap.containsKey(correctedKey(customID));

  /// Returns true if the data map is empty.
  bool get isEmpty => value.dataMap.isEmpty;

  /// Returns true if the data map is not empty.
  bool get isNotEmpty => value.dataMap.isNotEmpty;

  /// Returns the keys of the data map.
  Iterable<String> get keys => value.dataMap.keys;

  /// Returns the values of the data map.
  Iterable<T> get values => value.dataMap.values;

  /// Returns the data map.
  Map<String, T> get dataMap => value.dataMap;

  /// Returns the lookup map.
  Map<String, String> get lookupMap => value.lookupMap;
}

/// A model that represents the collection of published layouts.
///
/// This class also holds common data that is shared across all layouts.
@JsonSerializable()
class SDKPublishModel extends PrivacyBase {
  /// The project's id.
  final String projectId;

  /// A lazily loaded map of fonts. This map is populated during initialization
  /// of the SDK.
  @JsonKey(
    toJson: serializeLookupMapFonts,
    fromJson: deserializeFonts,
    readValue: readLookupMap,
    includeToJson: true,
  )
  final LookupMap<SDKPublishFont> fonts;

  /// A lazily loaded map of layouts. This map is populated during
  /// initialization of the SDK.
  ///
  /// Key is the layout's id.
  /// Value is the layout.
  @JsonKey(
    toJson: serializeLookupMapLayouts,
    fromJson: deserializeLayouts,
    readValue: readLookupMap,
    includeToJson: true,
  )
  final LookupMap<SDKPublishLayout> layouts;

  /// A list containing all of the pages that contain any of the layouts in
  /// [layouts] map.
  ///
  /// [SDKPublishLayout] already stores the page id, but it is not available
  /// without loading the data from Firestore. This list is used to avoid
  /// needing an extra step to access the page ids of the layouts.
  final List<String> pages;

  /// Contains information about the state of the published project.
  /// This is used to determine whether fonts and layouts should be updated.
  final SDKPublishUpdates updates;

  /// A map of apiId -> HttpApiData.
  ///
  /// Contains information about the apis used in the published project.
  final Map<String, HttpApiData> apis;

  /// Contains information about the variables used in the published project.
  @JsonKey(
    toJson: serializeLookupMapVariables,
    fromJson: deserializeVariables,
    readValue: readLookupMap,
    includeToJson: true,
  )
  final LookupMap<SDKLayoutVariables> variables;

  /// Contains information about the conditions used in the published project.
  @JsonKey(
    toJson: serializeLookupMapConditions,
    fromJson: deserializeConditions,
    readValue: readLookupMap,
    includeToJson: true,
  )
  final LookupMap<SDKLayoutConditions> conditions;

  /// The id of the layout that should be used as the entry point when viewing
  /// from site.codelessly.com or the Codelessly template gallery.
  final String? entryLayoutId;

  /// The id of the page that should be used as the entry point when viewing
  /// from site.codelessly.com or the Codelessly template gallery.
  final String? entryPageId;

  /// The id of the canvas that should be used as the entry point when viewing
  /// from site.codelessly.com or the Codelessly template gallery.
  final String? entryCanvasId;

  @DateTimeConverter()
  final DateTime lastUpdated;

  /// This map is a map of CustomLayoutID -> OriginalLayoutID.
  ///
  /// [SDKPublishLayouts] may be associated with a custom developer-friendly
  /// id instead of the original randomly generated string of characters.
  ///
  /// To avoid destructive changes to the publish flow and to the SDK, as well
  /// as to maintain compatibility and restoration of the original layout id,
  /// we keep this map to map the custom id to the original id if available.
  ///
  /// If, in the editor, an [SDKPublishLayout] is renamed with a friendlier
  /// id, that mapping is stored here. For automatic usage, we use a
  /// [LookupMap] for all [layouts], [fonts], [variables], and
  /// [conditions] to automatically correct the id when accessing the data.
  ///
  /// So whether the original layout id or a custom id is used, the SDK will
  /// always return the correct data from this [SDKPublishModel].
  ///
  /// The original layoutID is always used in all of the fields, but when a
  /// [CodelesslyWidget] tries to access the data, the developer may use
  /// a custom id. This map will modify that usage without being destructive.
  final Map<String, String> layoutIDMap;

  /// A list of layout ids that are explicitly disabled from the server's side.
  final List<String> disabledLayouts;

  static Map<String, dynamic> serializeLookupMapFonts(
          LookupMap<SDKPublishFont> map) =>
      map.dataMap.map((key, value) => MapEntry(key, value.toJson()));

  static Map<String, dynamic> serializeLookupMapLayouts(
          LookupMap<SDKPublishLayout> map) =>
      map.dataMap.map((key, value) => MapEntry(key, value.toJson()));

  static Map<String, dynamic> serializeLookupMapConditions(
          LookupMap<SDKLayoutConditions> map) =>
      map.dataMap.map((key, value) => MapEntry(key, value.toJson()));

  static Map<String, dynamic> serializeLookupMapVariables(
          LookupMap<SDKLayoutVariables> map) =>
      map.dataMap.map((key, value) => MapEntry(key, value.toJson()));

  static Object? readLookupMap(Map json, String key) {
    return {'layoutIDMap': json['layoutIDMap'], key: json[key]};
  }

  static Map<String, String> deserializeLookupMap(Map json) {
    return (json['layoutIDMap'] as Map? ?? {}).map(
      (k, e) => MapEntry(k as String, e as String),
    );
  }

  static LookupMap<SDKPublishLayout> deserializeLayouts(Map json) {
    final Map<String, String> layoutIDMap = deserializeLookupMap(json);
    final Map<String, dynamic> data = (json['layouts'] ?? <String, dynamic>{});
    return LookupMap((
      lookupMap: layoutIDMap,
      dataMap: {
        for (final item in data.entries)
          item.key: SDKPublishLayout.fromJson(item.value)
      }
    ));
  }

  static LookupMap<SDKPublishFont> deserializeFonts(Map json) {
    final Map<String, String> layoutIDMap = deserializeLookupMap(json);
    final Map<String, dynamic> data = (json['fonts'] ?? <String, dynamic>{});
    return LookupMap((
      lookupMap: layoutIDMap,
      dataMap: {
        for (final item in data.entries)
          item.key: SDKPublishFont.fromJson(item.value)
      }
    ));
  }

  static LookupMap<SDKLayoutVariables> deserializeVariables(Map json) {
    final Map<String, String> layoutIDMap = deserializeLookupMap(json);
    final Map<String, dynamic> data =
        (json['variables'] ?? <String, dynamic>{});
    return LookupMap((
      lookupMap: layoutIDMap,
      dataMap: {
        for (final item in data.entries)
          item.key: SDKLayoutVariables.fromJson(item.value)
      }
    ));
  }

  static LookupMap<SDKLayoutConditions> deserializeConditions(Map json) {
    final Map<String, String> layoutIDMap = deserializeLookupMap(json);
    final Map<String, dynamic> data =
        (json['conditions'] ?? <String, dynamic>{});
    return LookupMap((
      lookupMap: layoutIDMap,
      dataMap: {
        for (final item in data.entries)
          item.key: SDKLayoutConditions.fromJson(item.value)
      }
    ));
  }

  /// Creates a new instance of [SDKPublishModel].
  SDKPublishModel({
    required this.projectId,

    // Conditional
    SDKPublishUpdates? updates,
    List<String>? pages,
    Map<String, String>? layoutIDMap,
    LookupMap<SDKPublishFont>? fonts,
    LookupMap<SDKPublishLayout>? layouts,
    LookupMap<SDKLayoutVariables>? variables,
    LookupMap<SDKLayoutConditions>? conditions,
    Map<String, HttpApiData>? apis,
    this.entryLayoutId,
    this.entryPageId,
    this.entryCanvasId,
    DateTime? lastUpdated,
    List<String>? disabledLayouts,

    // Privacy
    required super.teams,
    required super.users,
    required super.roles,
    required super.public,
  })  : layoutIDMap = layoutIDMap ?? {},
        pages = pages ?? [],
        updates = updates ?? SDKPublishUpdates(),
        layouts = layouts ??
            LookupMap<SDKPublishLayout>(
              (lookupMap: layoutIDMap ?? {}, dataMap: {}),
            ),
        fonts = fonts ??
            LookupMap<SDKPublishFont>(
              (lookupMap: layoutIDMap ?? {}, dataMap: {}),
            ),
        variables = variables ??
            LookupMap<SDKLayoutVariables>(
              (lookupMap: layoutIDMap ?? {}, dataMap: {}),
            ),
        conditions = conditions ??
            LookupMap<SDKLayoutConditions>(
              (lookupMap: layoutIDMap ?? {}, dataMap: {}),
            ),
        apis = apis ?? {},
        lastUpdated = lastUpdated ?? DateTime.now(),
        disabledLayouts = disabledLayouts ?? [];

  /// Creates a new instance of [SDKPublishModel] with privacy inherited from
  /// another [PrivacyBase].
  SDKPublishModel.private({
    required this.projectId,

    // Conditional
    SDKPublishUpdates? updates,
    List<String>? pages,
    Map<String, String>? layoutIDMap,
    Map<String, SDKPublishFont>? fonts,
    Map<String, SDKPublishLayout>? layouts,
    Map<String, SDKLayoutVariables>? variables,
    Map<String, SDKLayoutConditions>? conditions,
    Map<String, HttpApiData>? apis,
    this.entryLayoutId,
    this.entryPageId,
    this.entryCanvasId,
    DateTime? lastUpdated,
    List<String>? disabledLayouts,

    // Privacy
    required super.privacy,
  })  : layoutIDMap = layoutIDMap ?? {},
        pages = pages ?? [],
        updates = updates ?? SDKPublishUpdates(),
        layouts = LookupMap<SDKPublishLayout>(
          (lookupMap: layoutIDMap ?? {}, dataMap: layouts ?? {}),
        ),
        fonts = LookupMap<SDKPublishFont>(
          (lookupMap: layoutIDMap ?? {}, dataMap: fonts ?? {}),
        ),
        variables = LookupMap<SDKLayoutVariables>(
          (lookupMap: layoutIDMap ?? {}, dataMap: variables ?? {}),
        ),
        conditions = LookupMap<SDKLayoutConditions>(
          (lookupMap: layoutIDMap ?? {}, dataMap: conditions ?? {}),
        ),
        lastUpdated = lastUpdated ?? DateTime.now(),
        apis = apis ?? {},
        disabledLayouts = disabledLayouts ?? [],
        super.private();

  /// Creates a new instance of [SDKPublishModel] from a JSON map.
  factory SDKPublishModel.fromJson(Map<String, dynamic> json) {
    return _$SDKPublishModelFromJson(json);
  }

  /// Converts this instance to a JSON map without the fonts, layouts, and apis.
  @override
  Map<String, dynamic> toJson() => _$SDKPublishModelToJson(this)
    ..remove('fonts')
    ..remove('layouts')
    ..remove('apis')
    ..remove('variables')
    ..remove('conditions');

  /// Converts this instance to a JSON map.
  Map<String, dynamic> toFullJson() => _$SDKPublishModelToJson(this);

  /// Creates a copy of this instance with the provided parameters.
  SDKPublishModel copyWith({
    String? projectId,
    List<String>? pages,
    SDKPublishUpdates? updates,
    Map<String, String>? layoutIDMap,
    Map<String, SDKPublishFont>? fonts,
    Map<String, SDKPublishLayout>? layouts,
    Map<String, HttpApiData>? apis,
    Map<String, SDKLayoutVariables>? variables,
    Map<String, SDKLayoutConditions>? conditions,
    String? entryLayoutId,
    String? entryPageId,
    String? entryCanvasId,
    DateTime? lastUpdated,
    List<String>? disabledLayouts,

    // Privacy
    PrivacyBase? privacy,
  }) {
    return SDKPublishModel.private(
      projectId: projectId ?? this.projectId,
      layoutIDMap: layoutIDMap ?? this.layoutIDMap,
      pages: pages ?? this.pages,
      updates: updates ?? this.updates,
      fonts: fonts ?? this.fonts.dataMap,
      layouts: layouts ?? this.layouts.dataMap,
      apis: apis ?? this.apis,
      variables: variables ?? this.variables.dataMap,
      conditions: conditions ?? this.conditions.dataMap,
      entryLayoutId: entryLayoutId ?? this.entryLayoutId,
      entryPageId: entryPageId ?? this.entryPageId,
      entryCanvasId: entryCanvasId ?? this.entryCanvasId,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      disabledLayouts: disabledLayouts ?? this.disabledLayouts,

      // Privacy
      privacy: privacy ?? this,
    );
  }

  @override
  List<Object?> get props => [
        ...super.props,
        projectId,
        fonts,
        pages,
        updates,
        layoutIDMap,
        layouts,
        apis,
        variables,
        conditions,
        entryLayoutId,
        entryPageId,
        entryCanvasId,
        lastUpdated,
        disabledLayouts,
      ];
}

@JsonSerializable()
class SDKPublishLayout extends PrivacyBase {
  /// The layout's unique id.
  final String id;

  /// The layout's page id.
  final String pageId;

  /// The layout's project id.
  final String projectId;

  /// A list of the nodes that makes up this layout.
  /// CanvasID -> <NodeID -> Node>
  @CanvasesMapConverter()
  final Map<String, Map<String, BaseNode>> canvases;

  /// A list of breakpoints that are used in this layout, indicating to the
  /// UI at what width the layout should change to a different canvas.
  final List<Breakpoint> breakpoints;

  /// The last time this layout was updated. Used for cache validation.
  @DateTimeConverter()
  final DateTime lastUpdated;

  /// Extracted canvas ids from the [canvases] map. This is available for
  /// convenience. Do not modify this set directly.
  final Set<String> canvasIds;

  /// Returns true if the layout is hidden from Codelessly's CloudUI dashboard.
  final bool hidden;

  /// Creates a new instance of [SDKPublishLayout].
  SDKPublishLayout({
    required this.id,
    required this.pageId,
    required this.projectId,
    required this.canvases,
    required this.lastUpdated,
    List<Breakpoint>? breakpoints,
    bool? hidden,

    // Privacy
    required super.teams,
    required super.users,
    required super.roles,
    required super.public,
  })  : breakpoints = breakpoints ?? [],
        canvasIds = canvases.keys.toSet(),
        hidden = hidden ?? false;

  /// Creates a new instance of [SDKPublishLayout] with privacy inherited from
  /// another [PrivacyBase].
  SDKPublishLayout.private({
    required this.id,
    required this.pageId,
    required this.projectId,
    required this.canvases,
    required this.lastUpdated,
    List<Breakpoint>? breakpoints,
    bool? hidden,

    // Privacy
    required super.privacy,
  })  : breakpoints = breakpoints ?? [],
        canvasIds = canvases.keys.toSet(),
        hidden = hidden ?? false,
        super.private();

  /// Returns true if the layout is expired.
  @JsonKey(includeFromJson: false, includeToJson: false)
  bool get isExpired => lastUpdated.isAfter(DateTime.now());

  /// Creates a new instance of [SDKPublishLayout] from a JSON map.
  factory SDKPublishLayout.fromJson(Map<String, dynamic> json) =>
      _$SDKPublishLayoutFromJson(json);

  /// Converts this instance to a JSON map.
  @override
  Map<String, dynamic> toJson() =>
      _$SDKPublishLayoutToJson(this)..['canvasIds'] = canvases.keys.toList();

  /// Creates a copy of this instance with the provided parameters.
  SDKPublishLayout copyWith({
    String? id,
    String? pageId,
    String? projectId,
    Map<String, Map<String, BaseNode>>? canvases,
    DateTime? lastUpdated,
    List<Breakpoint>? breakpoints,
    bool? hidden,

    // Privacy
    PrivacyBase? privacy,
  }) {
    return SDKPublishLayout.private(
      id: id ?? this.id,
      pageId: pageId ?? this.pageId,
      projectId: projectId ?? this.projectId,
      canvases: canvases ?? this.canvases,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      breakpoints: breakpoints ?? this.breakpoints,
      hidden: hidden ?? this.hidden,
      // Privacy
      privacy: privacy ?? this,
    );
  }

  @override
  List<Object?> get props => [
        ...super.props,
        id,
        pageId,
        projectId,
        canvases,
        lastUpdated,
        breakpoints,
        hidden,
      ];
}

/// Represents a single variation of a common font.
@JsonSerializable()
class SDKPublishFont extends PrivacyBase {
  /// The font's unique id. To keep this unique but seeded, we generate
  /// the id by base64 encoding the font's full name.
  ///
  /// The font's full name is formatted in such a way that Flutter can use it
  /// to load the font, for convenience.
  ///
  /// It's in the format of:
  /// `${family} ${variant}`
  final String id;

  /// The font's url to download the font file from.
  final String url;

  /// The font's common family name.
  final String family;

  /// The font's weight. (bold)
  final String weight;

  /// The font's style. (italics)
  final String? style;

  /// Returns the font's full name, decoded from the id.
  String get fullFontName => utf8.decode(base64Decode(id));

  /// Creates a new instance of [SDKPublishFont].
  const SDKPublishFont({
    String? id,
    required this.url,
    required this.family,
    required this.weight,
    this.style,

    // Privacy
    required super.teams,
    required super.users,
    required super.roles,
    required super.public,
  }) : id = id ?? family;

  /// Creates a new instance of [SDKPublishFont] with privacy inherited from
  /// another [PrivacyBase].
  SDKPublishFont.private(
      {String? id,
      required this.url,
      required this.family,
      required this.weight,
      this.style,

      // Privacy
      required super.privacy})
      : id = id ?? family,
        super.private();

  /// Creates a copy of this instance with the provided parameters.
  SDKPublishFont copyWith({
    String? id,
    String? url,
    String? family,
    String? weight,
    String? style,
    // Privacy
    PrivacyBase? privacy,
  }) {
    return SDKPublishFont.private(
      id: id ?? this.id,
      url: url ?? this.url,
      family: family ?? this.family,
      weight: weight ?? this.weight,
      style: style ?? this.style,
      // Privacy
      privacy: privacy ?? this,
    );
  }

  /// Creates a new instance of [SDKPublishFont] from a JSON map.
  factory SDKPublishFont.fromJson(Map<String, dynamic> json) =>
      _$SDKPublishFontFromJson(json);

  /// Converts this instance to a JSON map.
  @override
  Map<String, dynamic> toJson() => _$SDKPublishFontToJson(this);

  @override
  List<Object?> get props => [
        ...super.props,
        url,
        family,
        weight,
        style,
      ];
}

/// Defines an interpretation of what kind of update has been made to a given
/// layout or font.
///
/// This is used inside the data managers directly.
enum UpdateType {
  delete,
  add,
  update,
}

@JsonSerializable()
class SDKPublishUpdates with EquatableMixin {
  /// The last time the fonts collection received an update.
  @DateTimeMapConverter()
  final Map<String, DateTime> fonts;

  /// A map that holds a set of layout ids as keys, and the last time
  /// the layout was updated as the value.
  @DateTimeMapConverter()
  final Map<String, DateTime> layouts;

  /// A map that holds a set of layout ids as keys, and the last time
  /// the layout was updated as the value.
  @DateTimeMapConverter()
  final Map<String, DateTime> apis;

  /// A map that holds a set of layout ids as keys, and the last time
  /// the layout was updated as the value.
  @DateTimeMapConverter()
  final Map<String, DateTime> variables;

  /// A map that holds a set of layout ids as keys, and the last time
  /// the layout was updated as the value.
  @DateTimeMapConverter()
  final Map<String, DateTime> conditions;

  /// A map that holds a mapping of layout ids -> font ids.
  ///
  /// This allows the SDK to optimize its data flow by only downloading the
  /// minimum necessary fonts for a given layout without downloading all of the
  /// fonts of a given project.
  final Map<String, Set<String>> layoutFonts;

  /// A map that holds a mapping of layout ids -> api ids.
  ///
  /// This allows the SDK to optimize its data flow by only downloading the
  /// minimum necessary apis for a given layout without downloading all of the
  /// apis of a given project.
  final Map<String, Set<String>> layoutApis;

  /// Creates a new instance of [SDKPublishUpdates].
  SDKPublishUpdates({
    this.fonts = const {},
    this.layouts = const {},
    this.apis = const {},
    this.variables = const {},
    this.conditions = const {},
    this.layoutFonts = const {},
    this.layoutApis = const {},
  });

  /// Creates a copy of this instance with the provided parameters.
  SDKPublishUpdates copyWith({
    Map<String, DateTime>? fonts,
    Map<String, DateTime>? layouts,
    Map<String, DateTime>? apis,
    Map<String, DateTime>? variables,
    Map<String, DateTime>? conditions,
    Map<String, Set<String>>? layoutFonts,
    Map<String, Set<String>>? layoutApis,
  }) {
    return SDKPublishUpdates(
      fonts: fonts ?? this.fonts,
      layouts: layouts ?? this.layouts,
      apis: apis ?? this.apis,
      variables: variables ?? this.variables,
      conditions: conditions ?? this.conditions,
      layoutFonts: layoutFonts ?? this.layoutFonts,
      layoutApis: layoutApis ?? this.layoutApis,
    );
  }

  @override
  List<Object?> get props => [
        fonts,
        layouts,
        apis,
        variables,
        conditions,
        layoutFonts,
        layoutApis,
      ];

  /// Creates a new instance of [SDKPublishUpdates] from a JSON map.
  factory SDKPublishUpdates.fromJson(Map<String, dynamic> json) =>
      _$SDKPublishUpdatesFromJson(json);

  /// Converts this instance to a JSON map.
  Map<String, dynamic> toJson() => _$SDKPublishUpdatesToJson(this);
}

/// A model that defines variables for a layout.
@JsonSerializable()
class SDKLayoutVariables extends PrivacyBase {
  /// The id of the layout.
  final String id;

  /// The variables that are defined for this layout.
  /// CanvasID -> (VariableID -> VariableData)
  final Map<String, Map<String, VariableData>> variables;

  /// Creates a new instance of [SDKLayoutVariables].
  const SDKLayoutVariables({
    required this.id,
    required this.variables,

    // Privacy
    required super.teams,
    required super.users,
    required super.roles,
    required super.public,
  });

  /// Creates a new instance of [SDKLayoutVariables] with privacy inherited from
  /// another [PrivacyBase].
  SDKLayoutVariables.private({
    required this.id,
    required this.variables,

    // Privacy
    required super.privacy,
  }) : super.private();

  /// copyWith
  SDKLayoutVariables copyWith({
    String? id,
    Map<String, Map<String, VariableData>>? variables,

    // Privacy
    PrivacyBase? privacy,
  }) {
    return SDKLayoutVariables.private(
      id: id ?? this.id,
      variables: variables ?? this.variables,
      // Privacy
      privacy: privacy ?? this,
    );
  }

  @override
  List<Object?> get props => [...super.props, id, variables];

  /// Creates a new instance of [SDKLayoutVariables] from a JSON map.
  factory SDKLayoutVariables.fromJson(Map<String, dynamic> json) =>
      _$SDKLayoutVariablesFromJson(json);

  /// Converts this instance to a JSON map.
  @override
  Map<String, dynamic> toJson() => _$SDKLayoutVariablesToJson(this);
}

/// A model that defines variables for a layout.
@JsonSerializable()
class SDKLayoutConditions extends PrivacyBase {
  /// The id of the layout.
  final String id;

  /// The conditions that are defined for this layout.
  /// CanvasID -> (ConditionID -> ConditionData)
  final Map<String, Map<String, BaseCondition>> conditions;

  /// Creates a new instance of [SDKLayoutConditions].
  const SDKLayoutConditions({
    required this.id,
    required this.conditions,

    // Privacy
    required super.teams,
    required super.users,
    required super.roles,
    required super.public,
  });

  /// Creates a new instance of [SDKLayoutConditions] with privacy inherited
  /// from another [PrivacyBase].
  SDKLayoutConditions.private({
    required this.id,
    required this.conditions,

    // Privacy
    required super.privacy,
  }) : super.private();

  /// copyWith
  SDKLayoutConditions copyWith({
    String? id,
    Map<String, Map<String, BaseCondition>>? conditions,
    // Privacy
    PrivacyBase? privacy,
  }) {
    return SDKLayoutConditions.private(
      id: id ?? this.id,
      conditions: conditions ?? this.conditions,
      // Privacy
      privacy: privacy ?? this,
    );
  }

  @override
  List<Object?> get props => [...super.props, id, conditions];

  /// Creates a new instance of [SDKLayoutVariables] from a JSON map.
  factory SDKLayoutConditions.fromJson(Map<String, dynamic> json) =>
      _$SDKLayoutConditionsFromJson(json);

  /// Converts this instance to a JSON map.
  @override
  Map<String, dynamic> toJson() => _$SDKLayoutConditionsToJson(this);
}
