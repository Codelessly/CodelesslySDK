// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AuthData _$AuthDataFromJson(Map json) => AuthData(
      authToken: json['authToken'] as String,
      projectId: json['projectId'] as String,
      timestamp: const DateTimeConverter()
          .fromJson((json['timestamp'] as num?)?.toInt()),
      isTemplate: json['isTemplate'] as bool? ?? false,
      owner: json['owner'] as String,
      teams: (json['teams'] as List<dynamic>?)?.map((e) => e as String).toSet(),
      users: (json['users'] as List<dynamic>?)?.map((e) => e as String).toSet(),
      roles: (json['roles'] as Map).map(
        (k, e) => MapEntry(k as String, Role.fromJson(e as String)),
      ),
    );

Map<String, dynamic> _$AuthDataToJson(AuthData instance) {
  final val = <String, dynamic>{
    'owner': instance.owner,
    'users': instance.users.toList(),
    'roles': instance.roles.map((k, e) => MapEntry(k, e.toJson())),
    'teams': instance.teams.toList(),
    'authToken': instance.authToken,
    'projectId': instance.projectId,
  };

  void writeNotNull(
      String key, dynamic value, dynamic jsonValue, dynamic defaultValue) {
    final bool serialize =
        shouldSerialize(key, value, jsonValue, defaultValue, true);

    if (serialize) {
      val[key] = jsonValue;
    }
  }

  writeNotNull('isTemplate', instance.isTemplate, instance.isTemplate, false);
  writeNotNull('timestamp', instance.timestamp,
      const DateTimeConverter().toJson(instance.timestamp), null);
  return val;
}
