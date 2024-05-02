import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_json_annotation/codelessly_json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'document_model.g.dart';

@JsonSerializable()
class DocumentModel with EquatableMixin {
  /// The id of the document.
  final String id;

  /// The user-facing label of the document.
  final String name;

  /// Date and time when the document was created.
  @DateTimeConverter()
  final DateTime createdAt;

  /// The markdown data of the document.
  final String data;

  /// Creates a new document model.
  DocumentModel({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.data,
  });

  /// Creates a copy of this document model but with the given fields replaced
  /// with the new values.
  DocumentModel copyWith({
    String? id,
    String? name,
    String? data,
    DateTime? createdAt,
  }) =>
      DocumentModel(
        id: id ?? this.id,
        name: name ?? this.name,
        data: data ?? this.data,
        createdAt: createdAt ?? this.createdAt,
      );

  /// Creates a new document model from a json map.
  factory DocumentModel.fromJson(Map<String, dynamic> json) =>
      _$DocumentModelFromJson(json);

  /// Converts this document model to a json map.
  Map<String, dynamic> toJson() => _$DocumentModelToJson(this);

  @override
  List<Object?> get props => [
        id,
        name,
        createdAt,
        data,
      ];
}
