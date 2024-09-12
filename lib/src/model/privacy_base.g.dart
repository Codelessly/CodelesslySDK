// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'privacy_base.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PrivacyBaseImpl _$PrivacyBaseImplFromJson(Map json) => _PrivacyBaseImpl(
      owner: json['owner'] as String,
      teams: (json['teams'] as List<dynamic>?)?.map((e) => e as String).toSet(),
      users: (json['users'] as List<dynamic>?)?.map((e) => e as String).toSet(),
      roles: (json['roles'] as Map).map(
        (k, e) => MapEntry(k as String, Role.fromJson(e as String)),
      ),
      public: json['public'] as bool?,
    );

Map<String, dynamic> _$PrivacyBaseImplToJson(_PrivacyBaseImpl instance) =>
    <String, dynamic>{
      'owner': instance.owner,
      'users': instance.users.toList(),
      'roles': instance.roles.map((k, e) => MapEntry(k, e.toJson())),
      'teams': instance.teams.toList(),
      'public': instance.public,
    };
