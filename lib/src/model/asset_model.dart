import 'package:codelessly_api/codelessly_api.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'asset_model.g.dart';

/// Defines an asset that is utilized throughout node data as an id and
/// looked up for information about the asset based on that id.
@JsonSerializable()
class AssetModel with EquatableMixin {
  /// The id of the asset.
  final String id;

  /// The user-facing label of the asset.
  final String name;

  /// The url of the asset.
  final String url;

  /// The source width of the asset.
  final double sourceWidth;

  /// The source height of the asset.
  final double sourceHeight;

  /// Date and time when the asset was created.
  @DateTimeConverter()
  final DateTime createdAt;

  final String blurHash;

  double get aspectRatio => sourceWidth / sourceHeight;

  /// Creates a new asset model.
  AssetModel({
    required this.id,
    required this.name,
    required this.url,
    this.blurHash = '',
    required this.sourceWidth,
    required this.sourceHeight,
    required this.createdAt,
  });

  /// Creates a copy of this asset model but with the given fields replaced
  /// with the new values.
  AssetModel copyWith({
    String? id,
    String? name,
    String? url,
    String? blurHash,
    double? sourceWidth,
    double? sourceHeight,
    DateTime? createdAt,
  }) {
    return AssetModel(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      blurHash: blurHash ?? this.blurHash,
      sourceWidth: sourceWidth ?? this.sourceWidth,
      sourceHeight: sourceHeight ?? this.sourceHeight,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Creates a new asset model from a json map.
  factory AssetModel.fromJson(Map<String, dynamic> json) =>
      _$AssetModelFromJson(json);

  /// Converts this asset model to a json map.
  Map<String, dynamic> toJson() => _$AssetModelToJson(this);

  @override
  List<Object?> get props => [
        id,
        name,
        url,
        blurHash,
        sourceWidth,
        sourceHeight,
        createdAt,
      ];
}
