// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'document_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DocumentModel _$DocumentModelFromJson(Map json) => DocumentModel(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: const DateTimeConverter().fromJson(json['createdAt'] as int?),
      data: json['data'] as String,
    );

Map<String, dynamic> _$DocumentModelToJson(DocumentModel instance) {
  final val = <String, dynamic>{
    'id': instance.id,
    'name': instance.name,
  };

  void writeNotNull(
      String key, dynamic value, dynamic jsonValue, dynamic defaultValue) {
    final bool serialize =
        shouldSerialize(key, value, jsonValue, defaultValue, true);

    if (serialize) {
      val[key] = jsonValue;
    }
  }

  writeNotNull('createdAt', instance.createdAt,
      const DateTimeConverter().toJson(instance.createdAt), null);
  val['data'] = instance.data;
  return val;
}
