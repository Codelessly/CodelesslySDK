import 'dart:convert';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_json_annotation/codelessly_json_annotation.dart';
import 'package:equatable/equatable.dart';

import 'model_http_request.dart';
import 'privacy_base.dart';

part 'sdk_publish_model.g.dart';

/// A model that represents the collection of published layouts.
///
/// This class also holds common data that is shared across all layouts.
@JsonSerializable()
class SDKPublishModel extends PrivacyBase {
  /// The project's id.
  final String projectId;

  /// A lazily loaded map of fonts. This map is populated during initialization
  /// of the SDK.
  final Map<String, SDKPublishFont> fonts;

  /// A lazily loaded map of layouts. This map is populated during
  /// initialization of the SDK.
  ///
  /// Key is the layout's id.
  /// Value is the layout.
  final Map<String, SDKPublishLayout> layouts;

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

  /// Contains information about the apis used in the published project.
  final Map<String, HttpApiData> apis;

  /// Contains information about the variables used in the published project.
  final Map<String, SDKLayoutVariables> variables;

  /// Contains information about the conditions used in the published project.
  final Map<String, SDKLayoutConditions> conditions;

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

  /// Creates a new instance of [SDKPublishModel].
  SDKPublishModel({
    required this.projectId,

    // Conditional
    Map<String, SDKPublishFont>? fonts,
    Map<String, SDKPublishLayout>? layouts,
    SDKPublishUpdates? updates,
    Map<String, HttpApiData>? apis,
    Map<String, SDKLayoutVariables>? variables,
    Map<String, SDKLayoutConditions>? conditions,
    List<String>? pages,
    this.entryLayoutId,
    this.entryPageId,
    this.entryCanvasId,

    // Privacy
    required super.owner,
    super.editors,
    super.viewers,
    super.public,
    DateTime? lastUpdated,
  })  : layouts = layouts ?? {},
        fonts = fonts ?? {},
        pages = pages ?? [],
        updates = updates ?? SDKPublishUpdates(),
        apis = apis ?? {},
        variables = variables ?? {},
        conditions = conditions ?? {},
        lastUpdated = lastUpdated ?? DateTime.now();

  /// Creates a new instance of [SDKPublishModel] from a JSON map.
  factory SDKPublishModel.fromJson(Map<String, dynamic> json) =>
      _$SDKPublishModelFromJson(json);

  /// Converts this instance to a JSON map without the fonts, layouts, and apis.
  @override
  Map<String, dynamic> toJson() => _$SDKPublishModelToJson(this)
    ..remove('fonts')
    ..remove('layouts')
    ..remove('apis')
    ..remove('variables')
    ..remove('conditions')
    ..['whitelistedUsers'] = [...whitelistedUsers];

  /// Converts this instance to a JSON map.
  Map<String, dynamic> toFullJson() => _$SDKPublishModelToJson(this)
    ..['whitelistedUsers'] = [...whitelistedUsers];

  /// Creates a copy of this instance with the provided parameters.
  SDKPublishModel copyWith({
    String? projectId,
    Map<String, SDKPublishFont>? fonts,
    Map<String, SDKPublishLayout>? layouts,
    List<String>? pages,
    SDKPublishUpdates? updates,
    Map<String, HttpApiData>? apis,
    Map<String, SDKLayoutVariables>? variables,
    Map<String, SDKLayoutConditions>? conditions,
    String? entryLayoutId,
    String? entryPageId,
    String? entryCanvasId,
    String? owner,
    Set<String>? editors,
    Set<String>? viewers,
    bool? public,
    DateTime? lastUpdated,
  }) {
    return SDKPublishModel(
      projectId: projectId ?? this.projectId,
      fonts: fonts ?? this.fonts,
      layouts: layouts ?? this.layouts,
      pages: pages ?? this.pages,
      updates: updates ?? this.updates,
      apis: apis ?? this.apis,
      variables: variables ?? this.variables,
      conditions: conditions ?? this.conditions,
      entryLayoutId: entryLayoutId ?? this.entryLayoutId,
      entryPageId: entryPageId ?? this.entryPageId,
      entryCanvasId: entryCanvasId ?? this.entryCanvasId,
      owner: owner ?? this.owner,
      editors: editors ?? this.editors,
      viewers: viewers ?? this.viewers,
      public: public ?? this.public,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  List<Object?> get props => [
        ...super.props,
        projectId,
        fonts,
        pages,
        layouts,
        apis,
        variables,
        conditions,
        updates,
        entryLayoutId,
        entryPageId,
        entryCanvasId,
        lastUpdated,
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
  @JsonKey(readValue: nodesOrCanvasesReader)
  final Map<String, Map<String, BaseNode>> canvases;

  final List<Breakpoint> breakpoints;

  /// The last time this layout was updated. Used for cache validation.
  @DateTimeConverter()
  final DateTime lastUpdated;

  /// Extracted canvas ids from the [canvases] map. This is available for
  /// convenience. Do not modify this set directly.
  final Set<String> canvasIds;

  /// Creates a new instance of [SDKPublishLayout].
  SDKPublishLayout({
    required this.id,
    required this.pageId,
    required this.projectId,
    required this.canvases,
    required this.lastUpdated,
    List<Breakpoint>? breakpoints,

    // Privacy
    required super.owner,
    super.editors,
    super.viewers,
    super.public,
  })  : breakpoints = breakpoints ?? [],
        canvasIds = canvases.keys.toSet();

  /// Returns true if the layout is expired.
  @JsonKey(includeFromJson: false, includeToJson: false)
  bool get isExpired => lastUpdated.isAfter(DateTime.now());

  /// Creates a new instance of [SDKPublishLayout] from a JSON map.
  factory SDKPublishLayout.fromJson(Map<String, dynamic> json) =>
      _$SDKPublishLayoutFromJson(json);

  /// Converts this instance to a JSON map.
  @override
  Map<String, dynamic> toJson() => _$SDKPublishLayoutToJson(this)
    ..['whitelistedUsers'] = [...whitelistedUsers]
    ..['canvasIds'] = canvases.keys.toList();

  /// Creates a copy of this instance with the provided parameters.
  SDKPublishLayout copyWith({
    String? id,
    String? pageId,
    String? projectId,
    Map<String, Map<String, BaseNode>>? canvases,
    DateTime? lastUpdated,
    List<Breakpoint>? breakpoints,
    String? owner,
    Set<String>? editors,
    Set<String>? viewers,
    bool? public,
  }) {
    return SDKPublishLayout(
      id: id ?? this.id,
      pageId: pageId ?? this.pageId,
      projectId: projectId ?? this.projectId,
      canvases: canvases ?? this.canvases,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      owner: owner ?? this.owner,
      editors: editors ?? this.editors,
      viewers: viewers ?? this.viewers,
      public: public ?? this.public,
      breakpoints: breakpoints ?? this.breakpoints,
    );
  }

  @override
  List<Object?> get props => [
        ...super.props,
        id,
        pageId,
        projectId,
        owner,
        canvases,
        lastUpdated,
        breakpoints,
      ];

  // For backwards compatibility
  static Map<String, dynamic> nodesOrCanvasesReader(
      Map<dynamic, dynamic> json, String key) {
    if (json.containsKey('nodes') && json.containsKey('canvasId')) {
      // backwards compatibility
      return {json['canvasId']: json['nodes']};
    }
    assert(json.containsKey('canvases'));
    return json[key];
  }
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
    required super.owner,
    super.editors,
    super.viewers,
    super.public,
  }) : id = id ?? family;

  /// Creates a copy of this instance with the provided parameters.
  SDKPublishFont copyWith({
    String? id,
    String? url,
    String? family,
    String? weight,
    String? style,
    String? owner,
    Set<String>? editors,
    Set<String>? viewers,
    bool? public,
  }) {
    return SDKPublishFont(
      id: id ?? this.id,
      url: url ?? this.url,
      family: family ?? this.family,
      weight: weight ?? this.weight,
      style: style ?? this.style,
      owner: owner ?? this.owner,
      editors: editors ?? this.editors,
      viewers: viewers ?? this.viewers,
      public: public ?? this.public,
    );
  }

  /// Creates a new instance of [SDKPublishFont] from a JSON map.
  factory SDKPublishFont.fromJson(Map<String, dynamic> json) =>
      _$SDKPublishFontFromJson(json);

  /// Converts this instance to a JSON map.
  @override
  Map<String, dynamic> toJson() => _$SDKPublishFontToJson(this)
    ..['whitelistedUsers'] = [...whitelistedUsers];

  @override
  List<Object?> get props => [
        ...super.props,
        url,
        owner,
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
  /// The id of the canvas. Can be layout id for backwards compatibility.
  final String id;

  /// The variables that are defined for this layout.
  final Map<String, VariableData> variables;

  /// Creates a new instance of [SDKLayoutVariables].
  const SDKLayoutVariables({
    required this.id,
    required this.variables,

    // Privacy
    required super.owner,
    super.editors,
    super.viewers,
    super.public,
  });

  /// copyWith
  SDKLayoutVariables copyWith({
    String? id,
    Map<String, VariableData>? variables,
    String? owner,
    Set<String>? editors,
    Set<String>? viewers,
    bool? public,
  }) {
    return SDKLayoutVariables(
      id: id ?? this.id,
      variables: variables ?? this.variables,
      owner: owner ?? this.owner,
      editors: editors ?? this.editors,
      viewers: viewers ?? this.viewers,
      public: public ?? this.public,
    );
  }

  @override
  List<Object?> get props => [...super.props, id, owner, variables];

  /// Creates a new instance of [SDKLayoutVariables] from a JSON map.
  factory SDKLayoutVariables.fromJson(Map<String, dynamic> json) =>
      _$SDKLayoutVariablesFromJson(json);

  /// Converts this instance to a JSON map.
  @override
  Map<String, dynamic> toJson() => _$SDKLayoutVariablesToJson(this)
    ..['whitelistedUsers'] = [...whitelistedUsers];
}

/// A model that defines variables for a layout.
@JsonSerializable()
class SDKLayoutConditions extends PrivacyBase {
  /// The id of the canvas. Can be layout id for backwards compatibility.
  final String id;

  /// The conditions that are defined for this layout.
  final Map<String, BaseCondition> conditions;

  /// Creates a new instance of [SDKLayoutConditions].
  const SDKLayoutConditions({
    required this.id,
    required this.conditions,

    // Privacy
    required super.owner,
    super.editors,
    super.viewers,
    super.public,
  });

  /// copyWith
  SDKLayoutConditions copyWith({
    String? id,
    Map<String, BaseCondition>? conditions,
    String? owner,
    Set<String>? editors,
    Set<String>? viewers,
    bool? public,
  }) {
    return SDKLayoutConditions(
      id: id ?? this.id,
      owner: owner ?? this.owner,
      conditions: conditions ?? this.conditions,
      editors: editors ?? this.editors,
      viewers: viewers ?? this.viewers,
      public: public ?? this.public,
    );
  }

  @override
  List<Object?> get props => [...super.props, id, conditions];

  /// Creates a new instance of [SDKLayoutVariables] from a JSON map.
  factory SDKLayoutConditions.fromJson(Map<String, dynamic> json) =>
      _$SDKLayoutConditionsFromJson(json);

  /// Converts this instance to a JSON map.
  @override
  Map<String, dynamic> toJson() => _$SDKLayoutConditionsToJson(this)
    ..['whitelistedUsers'] = [...whitelistedUsers];
}
