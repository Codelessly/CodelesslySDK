// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_manager.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AuthData _$AuthDataFromJson(Map json) => AuthData(
      authToken: json['authToken'] as String,
      projectId: json['projectId'] as String,
      ownerId: json['ownerId'] as String,
      timestamp: jsonToDate(json['timestamp'] as int?),
    );

Map<String, dynamic> _$AuthDataToJson(AuthData instance) => <String, dynamic>{
      'authToken': instance.authToken,
      'projectId': instance.projectId,
      'ownerId': instance.ownerId,
      'timestamp': dateToJson(instance.timestamp),
    };
