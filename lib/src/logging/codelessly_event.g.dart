// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'codelessly_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CodelesslyEvent _$CodelesslyEventFromJson(Map json) => CodelesslyEvent(
      message: json['message'] as String?,
      timestamp: jsonToDate(json['timestamp'] as int?),
      stacktrace: json['stacktrace'] as String?,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              const [],
    );

Map<String, dynamic> _$CodelesslyEventToJson(CodelesslyEvent instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('message', instance.message);
  val['timestamp'] = dateToJson(instance.timestamp);
  writeNotNull('stacktrace', instance.stacktrace);
  val['tags'] = instance.tags;
  return val;
}
