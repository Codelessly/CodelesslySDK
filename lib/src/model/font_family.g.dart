// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'font_family.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FontFamilyModel _$FontFamilyModelFromJson(Map json) => FontFamilyModel(
      id: json['id'] as String?,
      name: json['name'] as String,
      fontVariants: (json['fontVariants'] as List<dynamic>)
          .map((e) =>
              FontVariantModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      owner: json['owner'] as String,
      teams: (json['teams'] as List<dynamic>?)?.map((e) => e as String).toSet(),
      users: (json['users'] as List<dynamic>?)?.map((e) => e as String).toSet(),
      roles: (json['roles'] as Map).map(
        (k, e) => MapEntry(k as String, $enumDecode(_$RoleEnumMap, e)),
      ),
      public: json['public'] as bool?,
    );

Map<String, dynamic> _$FontFamilyModelToJson(FontFamilyModel instance) =>
    <String, dynamic>{
      'owner': instance.owner,
      'users': instance.users.toList(),
      'roles': instance.roles.map((k, e) => MapEntry(k, _$RoleEnumMap[e]!)),
      'teams': instance.teams.toList(),
      'public': instance.public,
      'id': instance.id,
      'name': instance.name,
      'fontVariants': instance.fontVariants.map((e) => e.toJson()).toList(),
    };

const _$RoleEnumMap = {
  Role.admin: 'admin',
  Role.editor: 'editor',
  Role.viewer: 'viewer',
};

FontVariantModel _$FontVariantModelFromJson(Map json) => FontVariantModel(
      name: json['name'] as String? ?? 'regular',
      weight: $enumDecodeNullable(_$FontWeightNumericEnumMap, json['weight']) ??
          FontWeightNumeric.w400,
      style: json['style'] as String? ?? 'Normal',
      fontURL: json['fontURL'] as String? ?? '',
      previewURL: json['previewURL'] as String? ?? '',
    );

Map<String, dynamic> _$FontVariantModelToJson(FontVariantModel instance) {
  final val = <String, dynamic>{};

  void writeNotNull(
      String key, dynamic value, dynamic jsonValue, dynamic defaultValue) {
    final bool serialize =
        shouldSerialize(key, value, jsonValue, defaultValue, true);

    if (serialize) {
      val[key] = jsonValue;
    }
  }

  writeNotNull('name', instance.name, instance.name, 'regular');
  writeNotNull('weight', instance.weight,
      _$FontWeightNumericEnumMap[instance.weight]!, FontWeightNumeric.w400);
  writeNotNull('style', instance.style, instance.style, 'Normal');
  writeNotNull('fontURL', instance.fontURL, instance.fontURL, '');
  writeNotNull('previewURL', instance.previewURL, instance.previewURL, '');
  return val;
}

const _$FontWeightNumericEnumMap = {
  FontWeightNumeric.w100: 'w100',
  FontWeightNumeric.w200: 'w200',
  FontWeightNumeric.w300: 'w300',
  FontWeightNumeric.w400: 'w400',
  FontWeightNumeric.w500: 'w500',
  FontWeightNumeric.w600: 'w600',
  FontWeightNumeric.w700: 'w700',
  FontWeightNumeric.w800: 'w800',
  FontWeightNumeric.w900: 'w900',
};
