import 'package:codelessly_api/codelessly_api.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'auth_data.g.dart';

/// Holds data returned from the server after a successful handshake.
@JsonSerializable()
class AuthData with EquatableMixin {
  /// The authentication token used to authenticate this client.
  final String authToken;

  /// The project id of the project.
  final String projectId;

  /// The owner id of the project.
  final String ownerId;

  /// Whether the project is published as template or not.
  final bool isTemplate;

  /// The issued timestamp of the authentication.
  /// The time the handshake was done that resulted in the successful
  /// authentication.
  @JsonKey(fromJson: jsonToDate, toJson: dateToJson)
  final DateTime timestamp;

  /// Creates a [AuthData] instance.
  const AuthData({
    required this.authToken,
    required this.projectId,
    required this.ownerId,
    required this.timestamp,
    this.isTemplate = false,
  });

  /// Converts a JSON map to an [AuthData] instance.
  factory AuthData.fromJson(Map<String, dynamic> json) =>
      _$AuthDataFromJson(json);

  /// Converts an [AuthData] instance to a JSON map.
  Map<String, dynamic> toJson() => _$AuthDataToJson(this);

  @override
  List<Object?> get props => [
        authToken,
        projectId,
        ownerId,
        timestamp,
        isTemplate,
      ];
}
