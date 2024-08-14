// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'privacy_base.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$PrivacyBaseImplToJson(_PrivacyBaseImpl instance) {
  final val = <String, dynamic>{};

  void writeNotNull(
      String key, dynamic value, dynamic jsonValue, dynamic defaultValue) {
    final bool serialize =
        shouldSerialize(key, value, jsonValue, defaultValue, true);

    if (serialize) {
      val[key] = jsonValue;
    }
  }

  writeNotNull('stringify', instance.stringify, instance.stringify, null);
  val['hashCode'] = instance.hashCode;
  val['users'] = instance.users.toList();
  val['roles'] = instance.roles.map((k, e) => MapEntry(k, _$RoleEnumMap[e]!));
  val['teams'] = instance.teams.toList();
  val['public'] = instance.public;
  val['props'] = instance.props;
  return val;
}

const _$RoleEnumMap = {
  Role.owner: 'owner',
  Role.editor: 'editor',
  Role.viewer: 'viewer',
};
