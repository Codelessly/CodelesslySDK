import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_json_annotation/codelessly_json_annotation.dart';

import '../../codelessly_sdk.dart';

part 'markdown_document_model.g.dart';

@JsonSerializable()
class MarkdownDocumentModel extends PrivacyBase {
  /// The id of the document.
  final String id;

  /// The user-facing label of the document.
  final String name;

  /// Date and time when the document was created.
  @DateTimeConverter()
  final DateTime createdAt;

  @DateTimeConverter()
  final DateTime lastOpened;

  @DateTimeConverter()
  final DateTime lastUpdated;

  /// The markdown data of the document.
  final String data;

  /// Creates a new document model.
  MarkdownDocumentModel({
    required this.id,
    required this.name,
    required this.data,
    required this.lastOpened,
    required this.lastUpdated,
    required this.createdAt,

    // Privacy
    required super.teams,
    required super.users,
    required super.roles,
    required super.public,
  });

  MarkdownDocumentModel.auto({
    required this.name,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastOpened,

    // Privacy
    required super.teams,
    required super.users,
    required super.roles,
    required super.public,
  })  : id = generateId(),
        createdAt = createdAt ?? DateTime.now(),
        lastUpdated = updatedAt ?? DateTime.now(),
        lastOpened = lastOpened ?? DateTime.now(),
        data = '';

  MarkdownDocumentModel.private({
    required this.id,
    required this.name,
    required this.data,
    required this.lastOpened,
    required this.lastUpdated,
    required this.createdAt,

    // Privacy
    required super.privacy,
  }) : super.private();

  /// Creates a copy of this document model but with the given fields replaced
  /// with the new values.
  MarkdownDocumentModel copyWith({
    String? id,
    String? name,
    String? data,
    DateTime? createdAt,
    DateTime? lastOpened,
    DateTime? lastUpdated,

    // Privacy
    PrivacyBase? privacy,
  }) =>
      MarkdownDocumentModel.private(
        id: id ?? this.id,
        name: name ?? this.name,
        data: data ?? this.data,
        createdAt: createdAt ?? this.createdAt,
        lastOpened: lastOpened ?? this.lastOpened,
        lastUpdated: lastUpdated ?? this.lastUpdated,
        privacy: privacy ?? super.privacy,
      );

  /// Creates a new document model from a json map.
  factory MarkdownDocumentModel.fromJson(Map<String, dynamic> json) =>
      _$MarkdownDocumentModelFromJson(json);

  /// Converts this document model to a json map.
  @override
  Map<String, dynamic> toJson() => _$MarkdownDocumentModelToJson(this);

  @override
  List<Object?> get props => [
        ...super.props,
        id,
        name,
        createdAt,
        data,
      ];
}
