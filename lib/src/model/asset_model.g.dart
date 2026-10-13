// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'asset_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AssetModel _$AssetModelFromJson(Map json) => AssetModel(
  id: json['id'] as String,
  name: json['name'] as String,
  url: json['url'] as String,
  blurHash: json['blurHash'] as String? ?? '',
  sourceWidth: (json['sourceWidth'] as num).toDouble(),
  sourceHeight: (json['sourceHeight'] as num).toDouble(),
  createdAt: const DateTimeConverter().fromJson(
    (json['createdAt'] as num?)?.toInt(),
  ),
);

Map<String, dynamic> _$AssetModelToJson(AssetModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'url': instance.url,
      'sourceWidth': instance.sourceWidth,
      'sourceHeight': instance.sourceHeight,
      'createdAt': ?const DateTimeConverter().toJson(instance.createdAt),
      'blurHash': instance.blurHash,
    };
