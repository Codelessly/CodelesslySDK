import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';

import '../../codelessly_sdk.dart';

/// An implementation of that uses Firebase auth.
class CodelesslyAuthManager extends AuthManager {
  static const String name = 'Codelessly Auth Manager';

  /// The configuration used to authenticate the token.
  final CodelesslyConfig config;

  /// The client used to make HTTP requests.
  final http.Client client;

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

  /// The listener for the id token changes on the user's Firebase Auth account.
  StreamSubscription? _idTokenChangeListener;

  /// The id token result of the user's Firebase Auth account.
  IdTokenResult? _idTokenResult;

  /// Indicates whether this instance of the auth manager has been disposed.
  /// This is used to prevent any further background operations on this
  /// instance.
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
    required this.client,
    AuthData? authData,
  }) : _authData = authData {
    if (_authData != null) {
      _authStreamController.add(_authData);
    }
  }

  /// A helper function to log messages.
  void log(
    String message, {
    bool largePrint = false,
  }) =>
      logger.log(
        name,
        message,
        largePrint: largePrint,
      );

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
    log('Disposing...');
    _idTokenChangeListener?.cancel();
    _authStateChangesSubscription?.cancel();
    _authStreamController.close();
    _disposed = true;
  }

  @override
  void reset() {
    log('Invalidating...');
    _authData = null;
    _authStreamController.add(_authData);
    _idTokenChangeListener?.cancel();
  }

  @override
  bool isAuthenticated() => _authData != null;

  @override
  bool hasCloudStorageAccess(String projectId) {
    return checkClaimsForProject(_idTokenResult, projectId);
  }

  /// A helper method to check if the user has access to a project given their
  /// [result] from [getIdTokenResult] and the [projectId] they're trying to
  /// access.
  bool checkClaimsForProject(IdTokenResult? result, String projectId) {
    log('Checking claims for user for a project id [$projectId]');

    if (result == null) {
      log('Id token result is null. Cannot check claims for project id [$projectId]');
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

    log('User claims: $claims', largePrint: true);
    if (claims.isEmpty) {
      log('User claims is null. Cannot check claims for project id [$projectId]');
      return false;
    }
    if (!claims.containsKey('project_ids')) {
      log('User claims does not contain project_ids. Cannot check claims for project id [$projectId]');
      return false;
    }
    if (claims['project_ids'] is! List) {
      log('User claims project_ids is not a list. Cannot check claims for project id [$projectId]');
      return false;
    }

    final projectIds = claims['project_ids'] as List;

    log('User project id claims: $projectIds', largePrint: true);

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
    // Check if the instance of the auth manager has been disposed.
    if (_disposed) return;

    // Check if the user already has access to the project.
    if (checkClaimsForProject(_idTokenResult, authData.projectId)) {
      log('User has access to project since the claim exists already. Completing Firebase Auth process.');
      return;
    }

    // Force refresh the token immediately to check if the claim exists.
    _idTokenResult = await firebaseAuth.currentUser?.getIdTokenResult(true);
    if (checkClaimsForProject(_idTokenResult, authData.projectId)) {
      log('User has access to project since the claim exists already after force-refreshing. Completing Firebase Auth process.');
      return;
    }

    log('Listening & waiting for Firebase Auth state changes to proceed since user token does not have desired claims for project access...');

    // Create a completer to handle the completion of the Firebase Auth process.
    final Completer completer = Completer();

    // Listen to Firebase Auth state changes.
    _idTokenChangeListener =
        firebaseAuth.userChanges().listen((User? event) async {
      // If the completer is already completed, return.
      // We check this because getIdTokenResult may take a while to complete
      // and this userChanges() event may have already triggered a new event.
      if (completer.isCompleted) return;

      log('Firebase Auth state changed. Checking claims...');
      _idTokenResult = await event?.getIdTokenResult(true);

      // If the completer is already completed, return.
      // We check this because getIdTokenResult may take a while to complete
      // and this userChanges() event may have already triggered a new event.
      if (completer.isCompleted) return;

      // Check if the user has access to the project.
      if (checkClaimsForProject(_idTokenResult, authData.projectId)) {
        log('User has access to project since the claim exists. Completing Firebase Auth process.');
        completer.complete(event);
      }
    });

    // Wait for the completer to complete.
    await completer.future;

    // Cancel the listener for Firebase Auth state changes.
    _idTokenChangeListener?.cancel();

    log('Auth state changed successfully as expected. Firebase Auth complete.');
  }

  /// Calls a cloud function with the auth token as a payload.
  /// The cloud function will validate the token and return a project id.
  /// The project id will be used to retrieve the layout from the database.
  @override
  Future<void> authenticate() async {
    try {
      log('Authenticating token...');

      final AuthData? authData = await verifyProjectAuthToken(
        userToken: _idTokenResult!.token!,
        config: config,
        client: client,
        postSuccess: postAuthSuccess,
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

        throw CodelesslyException.notAuthenticated();
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
    const String label = 'verifyProjectAuthToken';

    // Function to log messages. Uses different methods depending on whether
    // the platform is web or not.
    logger.log(
      label,
      'About to verify token with: authToken: ${config.authToken}, slug: ${config.slug}',
      largePrint: true,
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
        logger.log(
          label,
          'Successful auth token verification response received.',
          largePrint: true,
        );

        // Parse the body of the response to JSON.
        final jsonBody = jsonDecode(result.body);

        // Create an instance of AuthData from the JSON body.
        final AuthData authData = AuthData.fromJson(jsonBody);

        // Call the postSuccess callback function and wait for it to decide
        // success.
        await postSuccess(authData);

        logger.log(label, 'Auth token response:\n${result.body}',
            largePrint: true);

        return authData;
      }
      // If the status code of the response is not 200, the authentication failed.
      // Log the status code, reason, and body of the response.
      else {
        logger.log(
          label,
          'Failed to authenticate token.\nStatus Code: ${result.statusCode}.\nReason: ${result.reasonPhrase}\nBody: ${result.body}',
          largePrint: true,
        );
      }
    } catch (e, stacktrace) {
      logger.log(
        label,
        'Error trying to authenticate token.\nError: $e',
        largePrint: true,
      );
      logger.log(
        label,
        '$stacktrace',
        largePrint: true,
      );
    }

    // If the function has not returned by this point, return null.
    // Live authentication has failed.
    return null;
  }
}
