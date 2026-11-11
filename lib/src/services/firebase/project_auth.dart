// The app's access to its Codelessly project: a Firebase user (anonymous
// until an app user signs in) whose token carries the project's claim, which
// the Codelessly backend grants for the app's project token.
import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../auth.dart';
import '../cache.dart';

/// What [FirebaseProjectAuth] authenticates with.
@immutable
class ProjectAuthConfig {
  const ProjectAuthConfig({
    required this.authToken,
    this.slug,
    this.clientType = 'default_client',
    this.functionsBaseUrl = 'https://us-central1-codeless-app.cloudfunctions.net',
  });

  /// The project token from the publish settings.
  final String authToken;

  /// The project's slug, when the app identifies it by slug.
  final String? slug;
  final String clientType;

  /// The Codelessly backend's base URL.
  final String functionsBaseUrl;
}

/// The claims of [result]: its `claims`, or (where the platform doesn't
/// give them, as on Windows) its token's payload.
Map<String, Object?> idTokenClaims(IdTokenResult? result, {bool fromToken = false}) {
  if (result == null) return const {};
  if (!fromToken) return {...?result.claims};
  final parts = result.token?.split('.');
  if (parts == null || parts.length < 2) return const {};
  try {
    final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
    return payload is Map ? {for (final e in payload.entries) '${e.key}': e.value} : const {};
  } on FormatException {
    return const {};
  }
}

/// [ProjectAuth] on Firebase Auth and the Codelessly backend.
///
/// Signs in anonymously when nobody is signed in, reads the cached access
/// (valid while it's for the same token and the user's token still has the
/// project's claim, then verified again in the background), else verifies
/// the project token with the backend and waits for the claim to reach the
/// user's token: it polls (no auth event follows a claim), re-verifies
/// every [claimsReverifyEvery] polls in case the claim was granted and lost,
/// and fails after [claimsPropagationTimeout] instead of hanging.
class FirebaseProjectAuth implements ProjectAuth {
  FirebaseProjectAuth({
    required this.config,
    required this.auth,
    http.Client? client,
    KeyValueCache? cache,
    this.claimsPropagationTimeout = const Duration(seconds: 30),
    this.claimsPollInterval = const Duration(seconds: 2),
    this.claimsReverifyEvery = 3,
    this.restoreTimeout = const Duration(seconds: 3),
    bool? claimsFromToken,
    this.onError,
  })  : client = client ?? http.Client(),
        cache = cache ?? MemoryKeyValueCache(),
        claimsFromToken = claimsFromToken ?? (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows);

  static const cacheKey = 'auth';

  final ProjectAuthConfig config;
  final FirebaseAuth auth;
  final http.Client client;
  final KeyValueCache cache;
  final Duration claimsPropagationTimeout;

  /// How long [authenticate] waits for Firebase to restore a persisted user
  /// before signing in anonymously.
  final Duration restoreTimeout;
  final Duration claimsPollInterval;
  final int claimsReverifyEvery;

  /// Reads claims from the token's payload (Windows, where the plugin
  /// doesn't return them).
  final bool claimsFromToken;

  /// Errors of background verification.
  final void Function(Object error, StackTrace stack)? onError;

  final _changes = StreamController<ProjectAccess?>.broadcast();
  ProjectAccess? _access;
  IdTokenResult? _idToken;
  StreamSubscription<User?>? _userChanges;
  bool _disposed = false;

  @override
  ProjectAccess? get access => _access;

  @override
  Stream<ProjectAccess?> get changes => _changes.stream;

  void _set(ProjectAccess? access) {
    _access = access;
    if (!_disposed) _changes.add(access);
  }

  /// Whether [result]'s claims give access to [projectId].
  bool hasProjectClaim(IdTokenResult? result, String projectId) {
    final ids = idTokenClaims(result, fromToken: claimsFromToken)['project_ids'];
    return ids is List && ids.contains(projectId);
  }

  /// Whether the signed-in user's token has the project's claim.
  bool get hasCloudAccess => _access != null && hasProjectClaim(_idToken, _access!.projectId);

  @override
  Future<ProjectAccess> authenticate() async {
    // On the web Firebase restores the signed-in user (an app user, or the
    // guest's or SDK's anonymous one) after the app starts: wait for it,
    // or every page load signs in a new anonymous user (a guest loses their
    // session, and Firebase soon blocks the device: too-many-requests).
    if (auth.currentUser == null) {
      try {
        await auth.userChanges().first.timeout(restoreTimeout, onTimeout: () => null);
      } on StateError {
        // No event at all (a closed stream): nobody to restore.
      }
    }
    if (auth.currentUser == null) await auth.signInAnonymously();
    _idToken = await auth.currentUser!.getIdTokenResult(true);
    final cached = await readCached(cache, cacheKey, ProjectAccess.fromJson);
    if (cached != null && cached.authToken == config.authToken && hasProjectClaim(_idToken, cached.projectId)) {
      _set(cached);
      unawaited(_verify().then<void>((_) {}, onError: (Object e, StackTrace s) => onError?.call(e, s)));
      return cached;
    }
    if (cached != null) await cache.delete(cacheKey);
    final access = await _verify();
    if (access == null) throw StateError('Failed to authenticate the project token.');
    return access;
  }

  @override
  Future<void> reauthenticate() async {
    if (_disposed) return;
    final user = auth.currentUser;
    if (user == null) return;
    _idToken = await user.getIdTokenResult(true);
    await _verify();
  }

  Future<ProjectAccess?> _verify() async {
    final token = _idToken?.token;
    if (token == null) throw StateError('Cannot authenticate without a Firebase ID token.');
    final access = await verifyProjectToken(token);
    if (_disposed) return access;
    if (access == null) {
      _set(null);
      await cache.delete(cacheKey);
      return null;
    }
    await waitForClaim(access.projectId);
    _set(access);
    await cache.write(cacheKey, access.toJson());
    return access;
  }

  /// Asks the backend to grant the user the project's claim for the app's
  /// project token: the access, or null when it refused.
  Future<ProjectAccess?> verifyProjectToken(String userToken) async {
    final response = await client.post(
      Uri.parse('${config.functionsBaseUrl}/api/verifyProjectAuthToken'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $userToken'},
      body: jsonEncode({'token': config.authToken, 'slug': config.slug, 'clientType': config.clientType}),
    );
    if (response.statusCode != 200) return null;
    final json = jsonDecode(response.body);
    final access = ProjectAccess.fromJson(json);
    if (access == null) return null;
    return ProjectAccess(
      projectId: access.projectId,
      authToken: access.authToken.isEmpty ? config.authToken : access.authToken,
      isTemplate: access.isTemplate,
      timestamp: access.timestamp,
    );
  }

  /// Completes once the signed-in user's token has [projectId]'s claim.
  Future<void> waitForClaim(String projectId) async {
    if (_disposed || hasProjectClaim(_idToken, projectId)) return;
    _idToken = await auth.currentUser?.getIdTokenResult(true);
    if (hasProjectClaim(_idToken, projectId)) return;

    final done = Completer<void>();
    var refreshing = false;
    Future<void> check(User? user, {bool reverify = false}) async {
      if (done.isCompleted || refreshing || user == null) return;
      refreshing = true;
      try {
        // A later server write can replace the claims and drop the project's;
        // verifying again grants it back.
        final token = _idToken?.token;
        if (reverify && token != null) {
          try {
            await verifyProjectToken(token);
          } catch (_) {
            // Polling goes on; the timeout bounds it.
          }
        }
        _idToken = await user.getIdTokenResult(true);
      } catch (e, s) {
        if (!done.isCompleted) done.completeError(e, s);
        return;
      } finally {
        refreshing = false;
      }
      if (!done.isCompleted && hasProjectClaim(_idToken, projectId)) done.complete();
    }

    _userChanges = auth.userChanges().listen(check, onError: (Object e, StackTrace s) {
      if (!done.isCompleted) done.completeError(e, s);
    });
    final poll = Timer.periodic(claimsPollInterval, (timer) {
      check(auth.currentUser, reverify: timer.tick % claimsReverifyEvery == 0);
    });
    try {
      await done.future.timeout(claimsPropagationTimeout);
    } finally {
      poll.cancel();
      await _userChanges?.cancel();
      _userChanges = null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _userChanges?.cancel();
    _changes.close();
  }
}
