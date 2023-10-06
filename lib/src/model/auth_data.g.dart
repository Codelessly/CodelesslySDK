// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AuthData _$AuthDataFromJson(Map json) => AuthData(
      authToken: json['authToken'] as String,
      projectId: json['projectId'] as String,
      ownerId: json['ownerId'] as String,
      timestamp: const DateTimeConverter().fromJson(json['timestamp'] as int?),
      isTemplate: json['isTemplate'] as bool? ?? false,
    );

Map<String, dynamic> _$AuthDataToJson(AuthData instance) {
  final val = <String, dynamic>{
    'authToken': instance.authToken,
    'projectId': instance.projectId,
    'ownerId': instance.ownerId,
  };

  void writeNotNull(
      String key, dynamic value, dynamic jsonValue, dynamic defaultValue) {
    final bool serialize = shouldSerialize(key, value, jsonValue, defaultValue);

    if (serialize) {
      val[key] = jsonValue;
    }
  }

  writeNotNull('isTemplate', instance.isTemplate, instance.isTemplate, false);
  writeNotNull('timestamp', instance.timestamp,
      const DateTimeConverter().toJson(instance.timestamp), null);
  return val;
}
