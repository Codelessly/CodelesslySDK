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
      createdAt: const DateTimeConverter().fromJson(json['createdAt'] as int?),
    );

Map<String, dynamic> _$AssetModelToJson(AssetModel instance) {
  final val = <String, dynamic>{
    'id': instance.id,
    'name': instance.name,
    'url': instance.url,
    'sourceWidth': instance.sourceWidth,
    'sourceHeight': instance.sourceHeight,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull(
      'createdAt', const DateTimeConverter().toJson(instance.createdAt));
  val['blurHash'] = instance.blurHash;
  return val;
}
