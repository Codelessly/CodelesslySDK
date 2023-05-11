import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart';

import '../../codelessly_sdk.dart';
import '../cache/cache_manager.dart';
import '../logging/error_handler.dart';
import 'auth_manager.dart';

/// An implementation of [AuthManager] that uses Firebase auth.
class CodelesslyAuthManager extends AuthManager {
  /// The configuration used to authenticate the token.
  final CodelesslyConfig config;

  /// The cache manager used to store the auth data after authentication.
  final CacheManager cacheManager;

  /// The stream controller used to stream the auth data. Any changes to
  /// it will be broadcasted to the stream.
  final StreamController<AuthData?> _authStreamController;

  /// Creates a [CodelesslyAuthManager] instance.
  ///
  /// [config] is the configuration used to authenticate the token.
  ///
  /// [cacheManager] is the cache manager used to store the project id after
  /// authentication.
  CodelesslyAuthManager({
    required this.config,
    required this.cacheManager,
  }) : _authStreamController = StreamController<AuthData?>.broadcast();

  /// The data provided after successful authentication.
  AuthData? _authData;

  @override
  AuthData? get authData => _authData!;

  @override
  Stream<AuthData?> get authStream => _authStreamController.stream;

  @override
  Future<void> init() async {
    if (cacheManager.isCached(authCacheKey)) {
      try {
        final AuthData cachedAuthData = cacheManager.get<AuthData>(
          authCacheKey,
          decode: AuthData.fromJson,
        );

        // If the token that is stored in the cached auth data does not match
        // the config's, then we need to invalidate the cache and fetch auth
        // data from the server.
        if (cachedAuthData.authToken == config.authToken) {
          _authData = cachedAuthData;
          _authStreamController.add(_authData);
        } else {
          await cacheManager.clearAll();
          await cacheManager.deleteAllByteData();
        }
      } catch (error, stacktrace) {
        // If the cache decoding process fails for any reason, invalidate
        // the cache, log the error, and move on by fetching a fresh token
        // from the server.
        CodelesslyErrorHandler.instance.captureException(
          CodelesslyException.cacheLookupException(
            message: 'Failed to decode cached auth data. Cache invalidated.\n'
                'Error: $error',
          ),
          stacktrace: stacktrace,
          // markForUI: false,
        );
        await cacheManager.clearAll();
        await cacheManager.deleteAllByteData();
      }
    }

    // We verify the auth token. If it the user is NOT already authenticated
    // from cache, we need to halt the entire process and wait for the user
    // to for the first time.
    //
    // If token is already authenticated, we allow the process to continue,
    // however, we also authenticate in the background to ensure the token
    // is still valid. We do this so as to not block the UI, we load whatever
    // is there immediately while we run our security in the background.
    if (!isAuthenticated()) {
      print('Token is not authenticated. Authenticating...');
      await authenticate();
      print('Authentication successfully!');
    } else {
      print('Token already authenticated! Verifying in the background...');
      authenticate().catchError((error) {
        // Error handling needs to be done here because this will not be caught
        // by SDK initialization.
        CodelesslyErrorHandler.instance.captureException(error);
      });
    }
  }

  @override
  void dispose() {
    _authStreamController.close();
  }

  @override
  void invalidate() {
    _authData = null;
    _authStreamController.add(_authData);
  }

  @override
  bool isAuthenticated() => _authData != null;

  /// Calls a cloud function with the auth token as a payload.
  /// The cloud function will validate the token and return a project id.
  /// The project id will be used to retrieve the layout from the database.
  @override
  Future<void> authenticate() async {
    try {
      print('Authenticating token...');
      final Response result = await post(
        Uri.parse('$firebaseCloudFunctionsBaseURL/verifyProjectAuthToken'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          // 'Authorization ': 'Bearer ${config.authToken}',
        },
        body: jsonEncode({'token': config.authToken}),
      );

      print('Auth token response: ${result.body}');

      if (result.statusCode == 200) {
        final jsonBody = jsonDecode(result.body);

        // Let's not send the token back through a network request, and instead
        // just store it locally.
        _authData =
            AuthData.fromJson({...jsonBody, 'authToken': config.authToken});
        _authStreamController.add(_authData!);
        print('Authenticated token. Project ID: ${_authData!.projectId}');
        await cacheManager.store(authCacheKey, _authData!.toJson());
        print('Stored auth data in cache');
      } else {
        _authData = null;
        _authStreamController.add(_authData);
        await cacheManager.delete(authCacheKey);
        throw CodelesslyException.invalidAuthToken(
          message: 'Failed to authenticate token.'
              '\nError Code: ${result.statusCode}'
              '\nReason: ${result.reasonPhrase}',
        );
      }
    } on CodelesslyException {
      rethrow;
    } on SocketException {
      throw CodelesslyException.networkException();
    } catch (e, str) {
      throw CodelesslyException.other(
        message: 'Failed to authenticate token.\nError: $e',
        originalException: e,
        stacktrace: str,
      );
    }
  }
}
