// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'markdown_document_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MarkdownDocumentModel _$MarkdownDocumentModelFromJson(Map json) =>
    MarkdownDocumentModel(
      id: json['id'] as String,
      name: json['name'] as String,
      data: json['data'] as String,
      lastOpened:
          const DateTimeConverter().fromJson(json['lastOpened'] as int?),
      lastUpdated:
          const DateTimeConverter().fromJson(json['lastUpdated'] as int?),
      createdAt: const DateTimeConverter().fromJson(json['createdAt'] as int?),
      teams: (json['teams'] as List<dynamic>?)?.map((e) => e as String).toSet(),
      users: (json['users'] as List<dynamic>?)?.map((e) => e as String).toSet(),
      roles: (json['roles'] as Map).map(
        (k, e) => MapEntry(k as String, $enumDecode(_$RoleEnumMap, e)),
      ),
      public: json['public'] as bool?,
    );

Map<String, dynamic> _$MarkdownDocumentModelToJson(
    MarkdownDocumentModel instance) {
  final val = <String, dynamic>{
    'users': instance.users.toList(),
    'roles': instance.roles.map((k, e) => MapEntry(k, _$RoleEnumMap[e]!)),
    'teams': instance.teams.toList(),
    'public': instance.public,
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
  writeNotNull('lastOpened', instance.lastOpened,
      const DateTimeConverter().toJson(instance.lastOpened), null);
  writeNotNull('lastUpdated', instance.lastUpdated,
      const DateTimeConverter().toJson(instance.lastUpdated), null);
  val['data'] = instance.data;
  return val;
}

const _$RoleEnumMap = {
  Role.owner: 'owner',
  Role.editor: 'editor',
  Role.viewer: 'viewer',
};
