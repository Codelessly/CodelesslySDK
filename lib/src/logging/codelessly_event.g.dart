// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'codelessly_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CodelesslyEvent _$CodelesslyEventFromJson(Map json) => CodelesslyEvent(
      message: json['message'] as String?,
      timestamp: const DateTimeConverter().fromJson(json['timestamp'] as int?),
      stacktrace: json['stacktrace'] as String?,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              [],
    );

Map<String, dynamic> _$CodelesslyEventToJson(CodelesslyEvent instance) {
  final val = <String, dynamic>{};

  void writeNotNull(
      String key, dynamic value, dynamic jsonValue, dynamic defaultValue) {
    final bool serialize =
        shouldSerialize(key, value, jsonValue, defaultValue, true);

    if (serialize) {
      val[key] = jsonValue;
    }
  }

  writeNotNull('message', instance.message, instance.message, null);
  writeNotNull('timestamp', instance.timestamp,
      const DateTimeConverter().toJson(instance.timestamp), null);
  writeNotNull('stacktrace', instance.stacktrace, instance.stacktrace, null);
  writeNotNull('tags', instance.tags, instance.tags, const []);
  return val;
}
