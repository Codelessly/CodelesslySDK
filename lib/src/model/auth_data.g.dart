// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AuthData _$AuthDataFromJson(Map json) => AuthData(
      authToken: json['authToken'] as String,
      projectId: json['projectId'] as String,
      ownerId: json['ownerId'] as String,
      timestamp: jsonToDate(json['timestamp'] as int?),
      isTemplate: json['isTemplate'] as bool? ?? false,
    );

Map<String, dynamic> _$AuthDataToJson(AuthData instance) => <String, dynamic>{
      'authToken': instance.authToken,
      'projectId': instance.projectId,
      'ownerId': instance.ownerId,
      'isTemplate': instance.isTemplate,
      'timestamp': dateToJson(instance.timestamp),
    };
