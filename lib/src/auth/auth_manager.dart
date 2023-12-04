import 'package:flutter/widgets.dart';

import '../../codelessly_sdk.dart';

/// An abstraction for providing authentication to the SDK.
abstract class AuthManager {
  /// Creates a [AuthManager] instance.
  const AuthManager();

  /// Returns the auth data used to authenticate the token if it exists.
  AuthData? get authData;

  /// Returns the stream of the auth data. Any changes to it will be
  /// broadcast to the stream.
  Stream<AuthData?> get authStream;

  /// Returns the [PublishSource] to be used for fetching the published model.
  /// If the [AuthData] reveals that the project is a template, then the
  /// [PublishSource.template] is returned, otherwise the [PublishSource]
  /// configured in the [CodelesslyConfig] is returned.
  PublishSource getBestPublishSource(CodelesslyConfig config) =>
      authData?.isTemplate == true
          ? PublishSource.template
          : config.publishSource;

  /// Initializes the [AuthManager].
  @mustCallSuper
  Future<void> init();

  /// Returns true if a handshake was done successfully.
  bool isAuthenticated();

  /// Returns true if the user has access to cloud storage.
  bool hasCloudStorageAccess(String projectId);

  /// Performs a handshake with the server to authenticate the token.
  Future<void> authenticate();

  /// Disposes this instance of the [AuthManager].
  @mustCallSuper
  void dispose();

  /// Sets the [AuthData] to null and emits a null value to the stream.
  @mustCallSuper
  void reset();
}
