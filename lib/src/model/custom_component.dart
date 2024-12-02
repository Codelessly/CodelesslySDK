// Copyright (c) 2022, Codelessly.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE.md file.

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_json_annotation/codelessly_json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'custom_component.g.dart';

/// A model to hold custom component data.
@JsonSerializable()
class CustomComponent with EquatableMixin, SerializableMixin {
  /// Unique identifier for the component.
  final String id;

  /// Name of the component.
  final String name;

  /// Node data of the component. This is the data that is used to render the
  /// component.
  final ComponentData data;

  /// Date and time when the component was created.
  @DateTimeConverter()
  final DateTime createdAt;

  /// The thumbnail URL for the component preview.
  final String? previewUrl;

  /// Blur-hash for the thumbnail preview.
  final String blurhash;

  /// The ID of the parent node of all the nodes that make up this component.
  final String parentId;

  /// The ID of the project where this component is located.
  final String projectId;

  /// The ID of the page where this component is located.
  final String pageId;

  /// JSON schema for the customizable properties of the component.
  final Map<String, dynamic> schema;

  final int version;

  /// Default constructor to create a new component.
  CustomComponent({
    required this.id,
    this.name = '',
    required this.data,
    DateTime? createdAt,
    this.previewUrl,
    this.blurhash = '',
    required this.projectId,
    required this.pageId,
    required this.parentId,
    Map<String, dynamic>? schema,
    required int? version,
  })  : createdAt = createdAt ?? DateTime.now(),
        // parentId = parentId ?? getTopMostParentIDs(data.nodes).first,
        version = version ?? 1,
        schema = schema ?? {};

  /// Duplicate this [CustomComponent] instance with the given data overrides.
  CustomComponent copyWith({
    String? id,
    String? name,
    ComponentData? data,
    String? previewUrl,
    String? blurhash,
    String? parentId,
    String? pageId,
    String? projectId,
    int? version,
  }) =>
      CustomComponent(
        id: id ?? this.id,
        name: name ?? this.name,
        data: data ?? this.data,
        createdAt: DateTime.now(),
        previewUrl: previewUrl ?? this.previewUrl,
        blurhash: blurhash ?? this.blurhash,
        parentId: parentId ?? this.parentId,
        projectId: projectId ?? this.projectId,
        pageId: pageId ?? this.pageId,
        version: version ?? this.version,
      );

  /// Factory constructor for creating a new instance of this class from
  /// a JSON object.
  factory CustomComponent.fromJson(Map<String, dynamic> json) =>
      _$CustomComponentFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$CustomComponentToJson(this);

  @override
  List<Object?> get props => [
        id,
        name,
        data,
        createdAt,
        previewUrl,
        blurhash,
        parentId,
        projectId,
        pageId,
        version,
      ];
}

/// Holds component's node data and containing rect size data.
@JsonSerializable()
class ComponentData with EquatableMixin, SerializableMixin {
  /// Width of the containing rect for [nodes].
  final double width;

  /// Height of the containing rect for [nodes].
  final double height;

  /// JSON data of all the nodes of the component where key is the ID of the
  /// node and value is actual node JSON that is used to recreate a [BaseNode]
  /// instance.
  final Map<String, dynamic> nodes;

  /// Node ID -> variables.
  final Map<String, Set<VariableData>> variables;

  /// Node ID -> conditions.
  final Map<String, Set<BaseCondition>> conditions;

  /// Returns containing rect of the component.
  RectC get rect => RectC.fromLTWH(0, 0, width, height);

  /// Returns aspect ratio of the component.
  double get aspectRatio => width / height;

  /// Default constructor to create new instances.
  ComponentData({
    required this.width,
    required this.height,
    required this.nodes,
    this.variables = const {},
    this.conditions = const {},
  }) : assert(width > 0 && height > 0);

  @override
  List<Object?> get props => [width, height, nodes, variables, conditions];

  @override
  Map toJson() => _$ComponentDataToJson(this);

  /// Factory constructor for creating a new instance of this class from
  /// a JSON object.
  factory ComponentData.fromJson(Map<String, dynamic> json) =>
      _$ComponentDataFromJson(json);

  /// Duplicate this [ComponentData] instance with the given data overrides.
  ComponentData copyWith({
    double? width,
    double? height,
    Map<String, dynamic>? nodes,
    Map<String, Set<VariableData>>? variables,
    Map<String, Set<BaseCondition>>? conditions,
  }) =>
      ComponentData(
        width: width ?? this.width,
        height: height ?? this.height,
        nodes: nodes ?? this.nodes,
        variables: variables ?? this.variables,
        conditions: conditions ?? this.conditions,
      );
}
