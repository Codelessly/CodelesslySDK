import 'package:codelessly_api/api.dart';
import 'package:flutter/widgets.dart';
import 'package:json_annotation/json_annotation.dart';

part 'auth_manager.g.dart';

/// Holds data returned from the server after a successful handshake.
@JsonSerializable()
class AuthData {
  /// The authentication token used to authenticate this client.
  final String authToken;

  /// The project id of the project.
  final String projectId;

  /// The owner id of the project.
  final String ownerId;

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
  });

  /// Converts a json map to an [AuthData] instance.
  factory AuthData.fromJson(Map<String, dynamic> json) =>
      _$AuthDataFromJson(json);

  /// Converts an [AuthData] instance to a json map.
  Map<String, dynamic> toJson() => _$AuthDataToJson(this);
}

/// An abstraction for providing authentication to the SDK.
abstract class AuthManager {
  /// Creates a [AuthManager] instance.
  const AuthManager();

  /// [returns] the auth data used to authenticate the token if it exists.
  AuthData? get authData;

  /// [returns] the stream of the auth data. Any changes to it will be
  /// broad0casted to the stream.
  Stream<AuthData?> get authStream;

  /// Initializes the [AuthManager].
  @mustCallSuper
  Future<void> init();

  /// [returns] true if a handshake was done successfully.
  bool isAuthenticated();

  /// Performs a handshake with the server to authenticate the token.
  Future<void> authenticate();

  /// Disposes this instance of the [AuthManager].
  @mustCallSuper
  void dispose();

  /// Sets the [AuthData] to null and emits a null value to the stream.
  @mustCallSuper
  void invalidate();
}
