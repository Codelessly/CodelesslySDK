import 'dart:convert';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

import 'model_http_request.dart';

part 'sdk_publish_model.g.dart';

/// A model that represents the collection of published layouts.
///
/// This class also holds common data that is shared across all layouts.
@JsonSerializable()
class SDKPublishModel with EquatableMixin {
  /// The project's id.
  final String projectId;

  /// The project's owner id.
  final String owner;

  /// A lazily loaded map of fonts. This map is populated during
  /// initialization of the SDK.
  final Map<String, SDKPublishFont> fonts;

  /// A lazily loaded map of layouts. This map is populated during
  /// initialization of the SDK.
  ///
  /// Key is the layout's id.
  /// Value is the layout.
  final Map<String, SDKPublishLayout> layouts;

  /// Contains information about the state of the published project.
  /// This is used to determine whether fonts and layouts should be updated.
  final SDKPublishUpdates updates;

  /// Contains information about the apis used in the published project.
  final Map<String, HttpApiData> apis;

  /// Creates a new instance of [SDKPublishModel].
  SDKPublishModel({
    required this.projectId,
    required this.owner,
    Map<String, SDKPublishFont>? fonts,
    Map<String, SDKPublishLayout>? layouts,
    SDKPublishUpdates? updates,
    Map<String, HttpApiData>? apis,
  })  : layouts = layouts ?? {},
        fonts = fonts ?? {},
        updates = updates ?? SDKPublishUpdates(),
        apis = apis ?? {};

  /// Creates a new instance of [SDKPublishModel] from a JSON map.
  factory SDKPublishModel.fromJson(Map<String, dynamic> json) =>
      _$SDKPublishModelFromJson(json);

  /// Converts this instance to a JSON map.
  Map<String, dynamic> toJson() => _$SDKPublishModelToJson(this)
    ..remove('fonts')
    ..remove('layouts')
    ..remove('apis');

  /// Converts this instance to a JSON map.
  Map<String, dynamic> toFullJson() => _$SDKPublishModelToJson(this);

  /// Creates a copy of this instance with the provided parameters.
  SDKPublishModel copyWith({
    String? projectId,
    String? owner,
    Map<String, SDKPublishFont>? fonts,
    Map<String, SDKPublishLayout>? layouts,
    SDKPublishUpdates? updates,
    Map<String, HttpApiData>? apis,
  }) {
    return SDKPublishModel(
      projectId: projectId ?? this.projectId,
      owner: owner ?? this.owner,
      fonts: fonts ?? this.fonts,
      layouts: layouts ?? this.layouts,
      updates: updates ?? this.updates,
      apis: apis ?? this.apis,
    );
  }

  @override
  List<Object?> get props => [
        projectId,
        owner,
        fonts,
        layouts,
        apis,
        updates,
      ];
}

@JsonSerializable()
class SDKPublishLayout with EquatableMixin {
  /// The layout's unique id.
  final String id;

  /// The layout's canvas id.
  final String canvasId;

  /// The layout's page id.
  final String pageId;

  /// The layout's project id.
  final String projectId;

  /// The layout's owner id.
  final String owner;

  /// A list of the nodes that makes up this layout.
  @JsonKey(fromJson: jsonToNodes, toJson: nodesToJson)
  final Map<String, BaseNode> nodes;

  /// The last time this layout was updated. Used for cache validation.
  @JsonKey(fromJson: jsonToDate, toJson: dateToJson)
  final DateTime lastUpdated;

  /// The layout's version.
  @Deprecated('Future use')
  final int? version;

  /// The layout's password.
  @Deprecated('Future use')
  final String? password;

  /// The layout's subdomain.
  @Deprecated('Future use')
  final String? subdomain;

  /// The layout's breakpoint.
  @Deprecated('Future use')
  final Breakpoint? breakpoint;

  /// Creates a new instance of [SDKPublishLayout].
  const SDKPublishLayout({
    required this.id,
    required this.canvasId,
    required this.pageId,
    required this.projectId,
    required this.owner,
    required this.nodes,
    required this.lastUpdated,
    this.version,
    this.password,
    this.subdomain,
    this.breakpoint,
  });

  /// Returns true if the layout is expired.
  @JsonKey(includeFromJson: false, includeToJson: false)
  bool get isExpired => lastUpdated.isAfter(DateTime.now());

  /// Creates a new instance of [SDKPublishLayout] from a JSON map.
  factory SDKPublishLayout.fromJson(Map<String, dynamic> json) =>
      _$SDKPublishLayoutFromJson(json);

  /// Converts this instance to a JSON map.
  Map<String, dynamic> toJson() => _$SDKPublishLayoutToJson(this);

  /// Creates a copy of this instance with the provided parameters.
  SDKPublishLayout copyWith({
    String? id,
    String? canvasId,
    String? pageId,
    String? projectId,
    String? owner,
    Map<String, BaseNode>? nodes,
    int? version,
    String? password,
    DateTime? lastUpdated,
    String? subdomain,
    Breakpoint? breakpoint,
    bool forceSubdomain = false,
    bool forcePassword = false,
  }) {
    return SDKPublishLayout(
      id: id ?? this.id,
      canvasId: canvasId ?? this.canvasId,
      pageId: pageId ?? this.pageId,
      projectId: projectId ?? this.projectId,
      owner: owner ?? this.owner,
      nodes: nodes ?? this.nodes,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      version: version ?? this.version,
      password: forcePassword ? password : password ?? this.password,
      subdomain: subdomain ?? this.subdomain,
      breakpoint: breakpoint ?? this.breakpoint,
    );
  }

  @override
  List<Object?> get props => [
        id,
        canvasId,
        pageId,
        projectId,
        owner,
        nodes,
        lastUpdated,
        version,
        password,
        subdomain,
        breakpoint,
      ];
}

/// Represents a single variation of a common font.
@JsonSerializable()
class SDKPublishFont with EquatableMixin {
  /// The font's unique id. To keep this unique but seeded, we generate
  /// the id by base64 encoding the font's full name.
  ///
  /// The font's full name is formatted in such a way that Flutter can use it
  /// to load the font, for convenience.
  ///
  /// It's often in the format of:
  /// `${family} ${what makes this variation unique}`
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
  }) : id = id ?? family;

  /// Creates a copy of this instance with the provided parameters.
  SDKPublishFont copyWith({
    String? id,
    String? url,
    String? family,
    String? weight,
    String? style,
  }) {
    return SDKPublishFont(
      id: id ?? this.id,
      url: url ?? this.url,
      family: family ?? this.family,
      weight: weight ?? this.weight,
      style: style ?? this.style,
    );
  }

  @override
  List<Object?> get props => [url, family, weight, style];

  /// Creates a new instance of [SDKPublishFont] from a JSON map.
  factory SDKPublishFont.fromJson(Map<String, dynamic> json) =>
      _$SDKPublishFontFromJson(json);

  /// Converts this instance to a JSON map.
  Map<String, dynamic> toJson() => _$SDKPublishFontToJson(this);
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
  @JsonKey(fromJson: jsonMapToDateValues, toJson: dateValuesToJsonMap)
  final Map<String, DateTime> fonts;

  /// A map that holds a set of layout ids as keys, and the last time
  /// the layout was updated as the value.
  @JsonKey(fromJson: jsonMapToDateValues, toJson: dateValuesToJsonMap)
  final Map<String, DateTime> layouts;

  /// A map that holds a set of layout ids as keys, and the last time
  /// the layout was updated as the value.
  @JsonKey(fromJson: jsonMapToDateValues, toJson: dateValuesToJsonMap)
  final Map<String, DateTime> apis;

  /// A map that holds a mapping of layout ids -> font ids.
  ///
  /// This allows the SDK to optimize its data flow by only downloading
  /// the minimum necessary fonts for a given layout without downloading
  /// all of the fonts of a given project.
  final Map<String, Set<String>> layoutFonts;

  /// A map that holds a mapping of layout ids -> api ids.
  ///
  /// This allows the SDK to optimize its data flow by only downloading
  /// the minimum necessary apis for a given layout without downloading
  /// all of the apis of a given project.
  final Map<String, Set<String>> layoutApis;

  /// Creates a new instance of [SDKPublishUpdates].
  SDKPublishUpdates({
    this.fonts = const {},
    this.layouts = const {},
    this.apis = const {},
    this.layoutFonts = const {},
    this.layoutApis = const {},
  });

  /// Creates a copy of this instance with the provided parameters.
  SDKPublishUpdates copyWith({
    Map<String, DateTime>? fonts,
    Map<String, DateTime>? layouts,
    Map<String, DateTime>? apis,
    Map<String, Set<String>>? layoutFonts,
    Map<String, Set<String>>? layoutApis,
  }) {
    return SDKPublishUpdates(
      fonts: fonts ?? this.fonts,
      layouts: layouts ?? this.layouts,
      apis: apis ?? this.apis,
      layoutFonts: layoutFonts ?? this.layoutFonts,
      layoutApis: layoutApis ?? this.layoutApis,
    );
  }

  @override
  List<Object?> get props => [fonts, layouts, apis, layoutFonts, layoutApis];

  /// Creates a new instance of [SDKPublishUpdates] from a JSON map.
  factory SDKPublishUpdates.fromJson(Map<String, dynamic> json) =>
      _$SDKPublishUpdatesFromJson(json);

  /// Converts this instance to a JSON map.
  Map<String, dynamic> toJson() => _$SDKPublishUpdatesToJson(this);
}
