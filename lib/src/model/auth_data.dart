import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_json_annotation/codelessly_json_annotation.dart';

import '../../codelessly_sdk.dart';

part 'auth_data.g.dart';

/// Holds data returned from the server after a successful handshake.
@JsonSerializable()
class AuthData extends PrivacyBase {
  /// The authentication token used to authenticate this client.
  final String authToken;

  /// The project id of the project.
  final String projectId;

  /// Whether the project is published as template or not.
  final bool isTemplate;

  /// The issued timestamp of the authentication.
  /// The time the handshake was done that resulted in the successful
  /// authentication.
  @DateTimeConverter()
  final DateTime timestamp;

  /// Creates a [AuthData] instance.
  const AuthData({
    required this.authToken,
    required this.projectId,
    required this.timestamp,
    this.isTemplate = false,

    // Privacy
    required super.teams,
    required super.users,
    required super.roles,
    Map<String, Role>? invitations,
  }) : super(public: true);

  AuthData.private({
    required this.authToken,
    required this.projectId,
    required this.timestamp,
    this.isTemplate = false,

    // Privacy
    required super.privacy,
    required Map<String, Role>? invitations,
  }) : super.private();

  /// Converts a JSON map to an [AuthData] instance.
  factory AuthData.fromJson(Map<String, dynamic> json) =>
      _$AuthDataFromJson(json);

  /// Converts an [AuthData] instance to a JSON map.
  @override
  Map<String, dynamic> toJson() => _$AuthDataToJson(this);

  @override
  List<Object?> get props => [
        ...super.props,
        authToken,
        projectId,
        timestamp,
        isTemplate,
      ];
}
