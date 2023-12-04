import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart';

import '../../codelessly_sdk.dart';
import '../logging/error_handler.dart';

const String _label = 'Auth Manager';

/// An implementation of that uses Firebase auth.
class CodelesslyAuthManager extends AuthManager {
  /// The configuration used to authenticate the token.
  final CodelesslyConfig config;

  /// The cache manager used to store the auth data after authentication.
  final CacheManager cacheManager;

  /// The firebase auth instance used to authenticate the device anonymously.
  final FirebaseAuth firebaseAuth;

  /// The error handler used to report errors.
  final CodelesslyErrorHandler errorHandler;

  /// The stream controller used to stream the auth data. Any changes to
  /// it will be broad=casted to the stream.
  final StreamController<AuthData?> _authStreamController =
      StreamController<AuthData?>.broadcast();

  /// The data provided after successful authentication.
  AuthData? _authData;

  @override
  AuthData? get authData => _authData;

  @override
  Stream<AuthData?> get authStream => _authStreamController.stream;

  StreamSubscription<User?>? _authStateChangesSubscription;

  /// Indicates whether this instance of the auth manager has been disposed.
  /// This is used to prevent any further background operations on this instance.
  bool _disposed = false;

  /// Creates a [CodelesslyAuthManager] instance.
  ///
  /// [config] is the configuration used to authenticate the token.
  ///
  /// [cacheManager] is the cache manager used to store the project id after
  /// authentication.
  CodelesslyAuthManager({
    required this.config,
    required this.cacheManager,
    required this.firebaseAuth,
    required this.errorHandler,
    AuthData? authData,
  }) : _authData = authData {
    if (_authData != null) {
      _authStreamController.add(_authData);
    }
  }

  void log(String message) => logger.log(_label, message);

  @override
  Future<void> init() async {
    final Stopwatch stopwatch = Stopwatch()..start();

    if (firebaseAuth.currentUser == null) {
      log('Authenticating anonymously...');
      await firebaseAuth.signInAnonymously();
      log('Anonymous authentication successful!');
    } else {
      log('Already authenticated ${firebaseAuth.currentUser!.isAnonymous ? 'anonymously' : 'with email ${firebaseAuth.currentUser!.email}'}');
    }

    // This step is mandatory to compare claims for auth. If re-auth is
    // needed, it needs to halt the entire process until auth completes because
    // the server attached a custom claim to the user's token to allow
    // Codelessly Cloud Data to work.
    final token = await firebaseAuth.currentUser!.getIdTokenResult(true);
    final claims = token.claims;

    if (cacheManager.isCached(authCacheKey)) {
      try {
        final AuthData cachedAuthData = cacheManager.get<AuthData>(
          authCacheKey,
          decode: AuthData.fromJson,
        );

        // If the token that is stored in the cached auth data does not match
        // the config's, then we need to invalidate the cache and fetch auth
        // data from the server.
        //
        // Additionally, if the stored claim does not contain a project id or
        // the project id does not match the cached data's projectId, then we
        // also need to invalidate the cache and fetch auth data from the
        // server and revalidate.
        if (cachedAuthData.authToken == config.authToken &&
            claims != null &&
            claims.containsKey('project_ids') &&
            claims['project_ids'] is List &&
            (claims['project_ids'] as List)
                .contains(cachedAuthData.projectId)) {
          _authData = cachedAuthData;
          _authStreamController.add(_authData);
        } else {
          if (cachedAuthData.authToken != config.authToken) {
            log('Auth token mismatch. Cache invalidated.');
          } else {
            log('Project ID is not in user claims. Cache invalidated.');
          }
          await cacheManager.clearAll();
          await cacheManager.deleteAllByteData();
        }
      } catch (error) {
        // If the cache decoding process fails for any reason, invalidate
        // the cache, and move on by fetching a fresh token
        // from the server.
        await cacheManager.clearAll();
        await cacheManager.deleteAllByteData();
      }
    } else {
      log('Auth data is not cached in cache manager.');
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
      log('Token is not authenticated. Authenticating...');
      await authenticate();
    } else {
      log('Token already authenticated! Verifying in the background...');
      authenticate().catchError((error) {
        // Error handling needs to be done here because this will not be caught
        // by SDK initialization.
        errorHandler.captureException(error);
      });
    }

    stopwatch.stop();
    log('Auth manager initialized took ${stopwatch.elapsedMilliseconds}ms or ${stopwatch.elapsed.inSeconds}s');
  }

  @override
  void dispose() {
    _authStateChangesSubscription?.cancel();
    _authStreamController.close();
    _disposed = true;
  }

  @override
  void reset() {
    log('Invalidating...');
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
      log('Authenticating token...');

      final String? userIdToken = await firebaseAuth.currentUser?.getIdToken();

      final authData = await verifyProjectAuthToken(
        userToken: userIdToken!,
        config: config,
      );

      if (_disposed) {
        log('Auth manager was disposed. Aborting authentication.');
        return;
      }

      if (authData != null) {
        _authData = authData;
        _authStreamController.add(_authData!);

        await cacheManager.store(authCacheKey, _authData!.toJson());
        log('Stored auth data in cache');
        log('Authentication successfully!');
      } else {
        _authData = null;
        _authStreamController.add(_authData);
        await cacheManager.delete(authCacheKey);
        log('Failed to authenticate token.');
        return;
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

  static Future<AuthData?> verifyProjectAuthToken({
    required String userToken,
    required CodelesslyConfig config,
  }) async {
    void log(String msg) {
      if (kIsWeb) {
        debugPrint('[verifyProjectAuthToken] $msg');
      } else {
        logger.log('verifyProjectAuthToken', msg);
      }
    }

    log('About to verify token with: authToken: ${config.authToken}, slug: ${config.slug}');
    final Response result = await post(
      Uri.parse(
          '${config.firebaseCloudFunctionsBaseURL}/verifyProjectAuthToken'),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $userToken',
      },
      body: jsonEncode({
        'token': config.authToken,
        'slug': config.slug,
      }),
    );

    if (result.statusCode == 200) {
      final jsonBody = jsonDecode(result.body);

      log('Auth token response:\n${result.body}');
      return AuthData.fromJson(jsonBody);
    } else {
      log(
        'Failed to authenticate token.\nStatus Code: ${result.statusCode}.\nReason: ${result.reasonPhrase}\nBody: ${result.body}',
      );
    }

    return null;
  }
}
