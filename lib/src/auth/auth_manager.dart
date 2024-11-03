import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';

import '../../codelessly_sdk.dart';
import '../logging/debug_logger.dart';
import '../logging/error_logger.dart';

/// An implementation that uses Firebase auth to authenticate users and manage
/// authentication state. Handles anonymous authentication, token verification,
/// and cloud storage access checks.
class AuthManager {
  static const String name = 'AuthManager';

  /// The configuration used to authenticate the token.
  final CodelesslyConfig config;

  /// The client used to make HTTP requests.
  final http.Client client;

  /// The cache manager used to store the auth data after authentication.
  final CacheManager cacheManager;

  /// The firebase auth instance used to authenticate the device anonymously.
  final FirebaseAuth firebaseAuth;

  /// The stream controller that broadcasts auth data changes.
  final StreamController<AuthData?> _authStreamController =
      StreamController<AuthData?>.broadcast();

  /// The data used to authenticate the token if it exists.
  AuthData? _authData;

  /// Returns the auth data used to authenticate the token if it exists.
  AuthData? get authData => _authData;

  /// Returns the stream of auth data changes. Any changes will be broadcast
  /// to the stream.
  Stream<AuthData?> get authStream => _authStreamController.stream;

  StreamSubscription<User?>? _authStateChangesSubscription;

  /// The listener for the id token changes on the user's Firebase Auth account.
  StreamSubscription? _idTokenChangeListener;

  /// The id token result of the user's Firebase Auth account.
  IdTokenResult? _idTokenResult;

  /// Indicates whether this instance of the auth manager has been disposed.
  /// This is used to prevent any further background operations on this
  /// instance.
  bool _disposed = false;

  /// Creates an [AuthManager] instance.
  ///
  /// [config] is the configuration used to authenticate the token.
  ///
  /// [cacheManager] is the cache manager used to store the project id after
  /// authentication.
  AuthManager({
    required this.config,
    required this.cacheManager,
    required this.firebaseAuth,
    required this.client,
    AuthData? authData,
  }) : _authData = authData {
    if (_authData != null) {
      _authStreamController.add(_authData);
    }
  }

  /// Initializes the [AuthManager].
  Future<void> init() async {
    DebugLogger.instance.printFunction('init()', name: name);
    final Stopwatch stopwatch = Stopwatch()..start();

    if (firebaseAuth.currentUser == null) {
      DebugLogger.instance
          .printInfo('Authenticating anonymously...', name: name);
      await firebaseAuth.signInAnonymously();
      DebugLogger.instance
          .printInfo('Anonymous authentication successful!', name: name);
    } else {
      DebugLogger.instance.printInfo(
          'Already authenticated ${firebaseAuth.currentUser!.isAnonymous ? 'anonymously' : 'with email ${firebaseAuth.currentUser!.email}'}',
          name: name);
    }

    // This step is mandatory to compare claims for auth. If re-auth is
    // needed, it needs to halt the entire process until auth completes because
    // the server attached a custom claim to the user's token to allow
    // Codelessly Cloud Data to work.
    _idTokenResult = await firebaseAuth.currentUser!.getIdTokenResult(true);

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
            checkClaimsForProject(_idTokenResult, cachedAuthData.projectId)) {
          _authData = cachedAuthData;
          _authStreamController.add(_authData);
        } else {
          if (cachedAuthData.authToken != config.authToken) {
            DebugLogger.instance.printInfo(
                'Auth token mismatch. Cache invalidated.',
                name: name);
          } else {
            DebugLogger.instance.printInfo(
                'Project ID is not in user claims. Cache invalidated.',
                name: name);
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
      DebugLogger.instance
          .printInfo('Auth data is not cached in cache manager.', name: name);
    }

    // We verify the auth token. If it the user is NOT already authenticated
    // from cache, we need to halt the entire process and wait for the user
    // to for the first time.
    //
    // If token is already authenticated, we allow the process to continue,
    // however, we also authenticate in the background to ensure the token
    // is still valid. We do this so as to not block the UI, we load whatever
    // is there immediately while we run our security in the background.

    if (_disposed) return;

    if (!isAuthenticated()) {
      DebugLogger.instance.printInfo(
          'Token is not authenticated. Authenticating...',
          name: name);
      await authenticate();
    } else {
      DebugLogger.instance.printInfo(
          'Token already authenticated! Verifying in the background...',
          name: name);
      authenticate().catchError((error) {
        // Error handling needs to be done here because this will not be caught
        // by SDK initialization.
        ErrorLogger.instance.captureException(error);
      });
    }

    stopwatch.stop();
    DebugLogger.instance.printInfo(
        'Auth manager initialized took ${stopwatch.elapsedMilliseconds}ms or ${stopwatch.elapsed.inSeconds}s',
        name: name);
  }

  /// Disposes this instance of the [AuthManager].
  void dispose() {
    DebugLogger.instance.printFunction('dispose()', name: name);
    DebugLogger.instance.printInfo('Disposing...', name: name);
    _idTokenChangeListener?.cancel();
    _authStateChangesSubscription?.cancel();
    _authStreamController.close();
    _disposed = true;
  }

  /// Sets the [AuthData] to null and emits a null value to the stream.
  void reset() {
    DebugLogger.instance.printFunction('reset()', name: name);
    DebugLogger.instance.printInfo('Invalidating...', name: name);
    _authData = null;
    _authStreamController.add(_authData);
    _idTokenChangeListener?.cancel();
  }

  /// Returns true if a handshake was done successfully with the server.
  /// This indicates whether authentication has completed and auth data exists.
  bool isAuthenticated() => _authData != null;

  /// Returns true if the user has access to cloud storage for the given project.
  /// Checks the user's Firebase token claims to verify project access.
  bool hasCloudStorageAccess(String projectId) {
    return checkClaimsForProject(_idTokenResult, projectId);
  }

  /// Returns the [PublishSource] to be used for fetching the published model.
  /// If the [AuthData] reveals that the project is a template, then the
  /// [PublishSource.template] is returned, otherwise the [PublishSource]
  /// configured in the [CodelesslyConfig] is returned.
  PublishSource getBestPublishSource(CodelesslyConfig config) =>
      authData?.isTemplate == true
          ? PublishSource.template
          : config.publishSource;

  /// A helper method to check if the user has access to a project given their
  /// [result] from [getIdTokenResult] and the [projectId] they're trying to
  /// access.
  bool checkClaimsForProject(IdTokenResult? result, String projectId) {
    DebugLogger.instance.printFunction(
      'checkClaimsForProject(result: ${result != null}, projectId: $projectId)',
      name: name,
    );
    DebugLogger.instance.printInfo(
      'Checking claims for user for a project id [$projectId]',
      name: name,
    );

    if (result == null) {
      DebugLogger.instance.printInfo(
          'Id token result is null. Cannot check claims for project id [$projectId]',
          name: name);
      return false;
    }

    final Map<String, dynamic> claims;

    // https://github.com/firebase/flutterfire/issues/11768#issuecomment-1888363494
    // A temporary fix for windows platform until the issue is resolved.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      claims = JwtDecoder.decode(result.toString());
    } else {
      claims = result.claims ?? {};
    }

    DebugLogger.instance.printInfo('User claims: $claims', name: name);
    if (claims.isEmpty) {
      DebugLogger.instance.printInfo(
          'User claims is null. Cannot check claims for project id [$projectId]',
          name: name);
      return false;
    }
    if (!claims.containsKey('project_ids')) {
      DebugLogger.instance.printInfo(
          'User claims does not contain project_ids. Cannot check claims for project id [$projectId]',
          name: name);
      return false;
    }
    if (claims['project_ids'] is! List) {
      DebugLogger.instance.printInfo(
          'User claims project_ids is not a list. Cannot check claims for project id [$projectId]',
          name: name);
      return false;
    }

    final projectIds = claims['project_ids'] as List;

    DebugLogger.instance
        .printInfo('User project id claims: $projectIds', name: name);

    return projectIds.contains(projectId);
  }

  /// This method is called after successful authentication of the token.
  /// It checks if the user has access to the project via token claims and if
  /// not, it listens to Firebase Auth user changes until the claim appears
  /// on the user's token and then completes the Firebase Auth process.
  ///
  /// The reason we do this is because custom claims may token a moment to
  /// propagate; especially to firestore rules. So we ensure that the user
  /// has access to the project before we proceed but verifying the claim
  /// on the client side.
  ///
  /// [authData] is the data provided after successful authentication.
  Future<void> postAuthSuccess(AuthData authData) async {
    DebugLogger.instance.printFunction(
      'postAuthSuccess(projectId: ${authData.projectId})',
      name: name,
    );
    // Check if the instance of the auth manager has been disposed.
    if (_disposed) return;

    // Check if the user already has access to the project.
    if (checkClaimsForProject(_idTokenResult, authData.projectId)) {
      DebugLogger.instance.printInfo(
          'User has access to project since the claim exists already. Completing Firebase Auth process.',
          name: name);
      return;
    }

    // Force refresh the token immediately to check if the claim exists.
    _idTokenResult = await firebaseAuth.currentUser?.getIdTokenResult(true);
    if (checkClaimsForProject(_idTokenResult, authData.projectId)) {
      DebugLogger.instance.printInfo(
          'User has access to project since the claim exists already after force-refreshing. Completing Firebase Auth process.',
          name: name);
      return;
    }

    DebugLogger.instance.printInfo(
        'Listening & waiting for Firebase Auth state changes to proceed since user token does not have desired claims for project access...',
        name: name);

    // Create a completer to handle the completion of the Firebase Auth process.
    final Completer completer = Completer();

    // Listen to Firebase Auth state changes.
    _idTokenChangeListener =
        firebaseAuth.userChanges().listen((User? event) async {
      // If the completer is already completed, return.
      // We check this because getIdTokenResult may take a while to complete
      // and this userChanges() event may have already triggered a new event.
      if (completer.isCompleted) return;

      DebugLogger.instance.printInfo(
          'Firebase Auth state changed. Checking claims...',
          name: name);
      _idTokenResult = await event?.getIdTokenResult(true);

      // If the completer is already completed, return.
      // We check this because getIdTokenResult may take a while to complete
      // and this userChanges() event may have already triggered a new event.
      if (completer.isCompleted) return;

      // Check if the user has access to the project.
      if (checkClaimsForProject(_idTokenResult, authData.projectId)) {
        DebugLogger.instance.printInfo(
            'User has access to project since the claim exists. Completing Firebase Auth process.',
            name: name);
        completer.complete(event);
      }
    });

    // Wait for the completer to complete.
    await completer.future;

    // Cancel the listener for Firebase Auth state changes.
    _idTokenChangeListener?.cancel();

    DebugLogger.instance.printInfo(
        'Auth state changed successfully as expected. Firebase Auth complete.',
        name: name);
  }

  /// Performs a handshake with the server to authenticate the token.
  /// Makes a network request to verify the auth token and retrieve project access.
  Future<void> authenticate() async {
    DebugLogger.instance.printFunction('authenticate()', name: name);
    try {
      DebugLogger.instance.printInfo('Authenticating token...', name: name);

      final AuthData? authData = await verifyProjectAuthToken(
        userToken: _idTokenResult!.token!,
        config: config,
        client: client,
        postSuccess: postAuthSuccess,
      );

      if (_disposed) {
        DebugLogger.instance.printInfo(
            'Auth manager was disposed. Aborting authentication.',
            name: name);
        return;
      }

      if (authData != null) {
        _authData = authData;
        _authStreamController.add(_authData!);

        await cacheManager.store(authCacheKey, _authData!.toJson());
        DebugLogger.instance.printInfo('Stored auth data in cache', name: name);
        DebugLogger.instance
            .printInfo('Authentication successfully!', name: name);
      } else {
        _authData = null;
        _authStreamController.add(_authData);
        await cacheManager.delete(authCacheKey);
        DebugLogger.instance
            .printInfo('Failed to authenticate token.', name: name);

        ErrorLogger.instance.captureException('Authentication failed',
            message: 'Failed to authenticate token', type: 'auth_failed');
        return;
      }
    } on SocketException catch (e, str) {
      ErrorLogger.instance.captureException(e,
          message: 'Network error during authentication',
          type: 'network_error',
          stackTrace: str);
      rethrow;
    } catch (e, str) {
      ErrorLogger.instance.captureException(e,
          message: 'Failed to authenticate token',
          type: 'auth_error',
          stackTrace: str);
      rethrow;
    }
  }

  /// Verifies the project auth token by making a POST request to the
  /// Codelessly's backend.
  ///
  /// This function is static and can be called without an instance of the
  /// class.
  ///
  /// [userToken] is the token of the user that is currently logged in.
  /// [config] is the configuration that holds the project token to
  /// authenticate.
  /// [postSuccess] is a callback function that is called after successful
  /// authentication that is awaited before this function is completed.
  ///
  /// [returns] a Future that resolves to an instance of [AuthData] if the
  /// authentication is successful and `null` otherwise.
  static Future<AuthData?> verifyProjectAuthToken({
    required String userToken,
    required CodelesslyConfig config,
    required http.Client client,
    required Future<void> Function(AuthData authData) postSuccess,
  }) async {
    DebugLogger.instance.printFunction(
      'verifyProjectAuthToken(authToken: ${config.authToken}, slug: ${config.slug})',
      name: name,
    );

    try {
      // Make a POST request to the server to verify the token.
      final http.Response result = await client.post(
        Uri.parse(
            '${config.firebaseCloudFunctionsBaseURL}/api/verifyProjectAuthToken'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $userToken',
        },
        body: jsonEncode({
          'token': config.authToken,
          'slug': config.slug,
          'clientType': clientType,
        }),
      );

      // If the status code of the response is 200, the authentication was
      // successful.
      if (result.statusCode == 200) {
        DebugLogger.instance.printInfo(
            'Successful auth token verification response received.',
            name: name);

        final jsonBody = jsonDecode(result.body);

        // Create an instance of AuthData from the JSON body.
        final AuthData authData = AuthData.fromJson(jsonBody);

        // Call the postSuccess callback function and wait for it to decide
        // success.
        await postSuccess(authData);

        DebugLogger.instance
            .printInfo('Auth token response:\n${result.body}', name: name);

        return authData;
      } else {
        // If the status code of the response is not 200, the authentication failed.
        // Log the status code, reason, and body of the response.
        DebugLogger.instance.printInfo(
            'Failed to authenticate token.\nStatus Code: ${result.statusCode}.\nReason: ${result.reasonPhrase}\nBody: ${result.body}',
            name: name);
      }
    } catch (e, stacktrace) {
      DebugLogger.instance.printInfo(
          'Error trying to authenticate token.\nError: $e',
          name: name);
      DebugLogger.instance.printInfo('$stacktrace', name: name);
    }

    // If the function has not returned by this point, return null.
    // Live authentication has failed.
    return null;
  }
}
