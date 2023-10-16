import 'package:codelessly_api/codelessly_api.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';

part 'codelessly_event.g.dart';

/// Holds information for an event that happened inside the SDK. This data
/// will be sent to Codelessly for analysis.
@JsonSerializable()
class CodelesslyEvent with EquatableMixin {
  /// A unique identifier for this event.
  final String id;

  /// An optional attached message that describes this event.
  final String? message;

  /// The time at which this event was created.
  @DateTimeConverter()
  final DateTime timestamp;

  /// An optional stacktrace associated with this message if it was an error.
  final String? stacktrace;

  /// A list of tags that can be used to filter events.
  final List<String> tags;

  // DeviceMetadata? deviceMetadata;

  /// Creates a new [CodelesslyEvent] with the given properties.
  CodelesslyEvent({
    this.message,
    DateTime? timestamp,
    this.stacktrace,
    this.tags = const [],
    // this.deviceMetadata,
  })  : id = const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  /// Internal constructor to support [copyWith] method.
  CodelesslyEvent._({
    required this.id,
    required this.message,
    required this.timestamp,
    required this.stacktrace,
    required this.tags,
    // required this.deviceMetadata,
  });

  /// Creates a copy of this event but with the given fields replaced with the
  /// new values.
  CodelesslyEvent copyWith({
    String? message,
    Map<String, dynamic>? extras,
    DateTime? timestamp,
    String? stacktrace,
    List<String>? tags,
    // DeviceMetadata? deviceMetadata,
  }) =>
      CodelesslyEvent._(
        id: id,
        message: message ?? this.message,
        timestamp: timestamp ?? this.timestamp,
        stacktrace: stacktrace ?? this.stacktrace,
        tags: tags ?? this.tags,
        // deviceMetadata: deviceMetadata ?? this.deviceMetadata,
      );

  /// Populates the [deviceMetadata] field with information about the device.
  Future<void> populateDeviceMetadata() async {
    // deviceMetadata = await DeviceMetadata.fromPlatform();
  }

  /// Converts this event to a JSON map.
  Map<String, dynamic> toJson() => _$CodelesslyEventToJson(this);

  /// Creates an event from a JSON map.
  factory CodelesslyEvent.fromJson(Map<String, dynamic> json) =>
      _$CodelesslyEventFromJson(json);

  @override
  List<Object?> get props => [
        id,
        message,
        timestamp,
        stacktrace,
        tags,
        // deviceMetadata,
      ];
}

// /// Holds information about the device that is running this SDK.
// @JsonSerializable()
// class DeviceMetadata with EquatableMixin {
//   /// The DeviceInfo plugin does not return a JSON-serializable map of a
//   /// device's info. So instead of reconstructing the entire plugin's models or
//   /// only storing a tiny fraction of data, we convert the entire map as a
//   /// string.
//   final String? data;
//
//   /// Creates a new instance of [DeviceMetadata].
//   DeviceMetadata({this.data});
//
//   /// Creates a new instance of [DeviceMetadata] by querying the device's
//   /// information using the DeviceInfo plugin.
//   static Future<DeviceMetadata> fromPlatform() async {
//     final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
//     final BaseDeviceInfo info = await deviceInfo.deviceInfo;
//     return DeviceMetadata(data: info.data.toString());
//   }
//
//   /// Converts this event to a JSON map.
//   Map<String, dynamic> toJson() => _$DeviceMetadataToJson(this);
//
//   /// Creates an event from a JSON map.
//   factory DeviceMetadata.fromJson(Map<String, dynamic> json) =>
//       _$DeviceMetadataFromJson(json);
//
//   @override
//   List<Object?> get props => [data];
// }
