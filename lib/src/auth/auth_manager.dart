import 'package:codelessly_api/codelessly_api.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:json_annotation/json_annotation.dart';

import '../../codelessly_sdk.dart';
import '../model/auth_data.dart';

/// An abstraction for providing authentication to the SDK.
abstract class AuthManager {
  /// Creates a [AuthManager] instance.
  const AuthManager();

  /// Returns the auth data used to authenticate the token if it exists.
  AuthData? get authData;

  /// Returns the stream of the auth data. Any changes to it will be
  /// broad0casted to the stream.
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

  /// Performs a handshake with the server to authenticate the token.
  Future<void> authenticate();

  /// Disposes this instance of the [AuthManager].
  @mustCallSuper
  void dispose();

  /// Sets the [AuthData] to null and emits a null value to the stream.
  @mustCallSuper
  void invalidate();
}
