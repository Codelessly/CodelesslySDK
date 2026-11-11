// Codelessly's user store: app accounts kept per project by Codelessly (the
// `appAuth` function), behind the Supabase-shaped `codelessly.auth`.
//
// Every sign-in ends with a custom token for the backend's token session (a
// per-project Firebase Auth instance, package:codelessly_sdk/firebase.dart);
// the session's claims (cl_p, cl_role, cl_anon, cl_v) are what the cloud data
// rules check. Nothing here imports Firebase: the token session and the
// user-record watch are given, so tests run with fakes.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth.dart';
import 'cache.dart';
import 'cloud/backend.dart';
import 'cloud/query.dart';
import 'storage.dart';

/// A failed user store request: the HTTP [status] and the store's error [code]
/// (`invalid_credentials`, `email_exists`, `weak_password`, `too_many_attempts`...).
class AppAuthException implements Exception {
  const AppAuthException(this.status, this.code, this.message, {this.retryAfter});

  final int status;
  final String code;
  final String message;

  /// Seconds to wait, for `rate_limited` and `too_many_attempts`.
  final int? retryAfter;

  @override
  String toString() => 'AppAuthException($status $code: $message)';
}

/// The user store's HTTP API (`/v1/...`).
abstract interface class AppAuthClient {
  /// Calls [method] [path] (relative to `/v1/`, e.g. `p1/signup`) with [body], as the
  /// session [bearer] when given. Returns the JSON answer (empty for 204); throws
  /// [AppAuthException].
  Future<Map<String, Object?>> send(String method, String path, {Map<String, Object?>? body, String? bearer});
}

/// [AppAuthClient] over HTTP: [baseUrl] is the `appAuth` function's URL.
class HttpAppAuthClient implements AppAuthClient {
  HttpAppAuthClient({required this.baseUrl, http.Client? client}) : client = client ?? http.Client();

  final String baseUrl;
  final http.Client client;

  @override
  Future<Map<String, Object?>> send(String method, String path, {Map<String, Object?>? body, String? bearer}) async {
    final request = http.Request(method, Uri.parse('$baseUrl/v1/$path'))
      ..headers['Content-Type'] = 'application/json'
      ..headers['Accept'] = 'application/json';
    if (bearer != null) request.headers['Authorization'] = 'Bearer $bearer';
    if (body != null) request.body = jsonEncode(body);
    final http.Response response;
    try {
      response = await http.Response.fromStream(await client.send(request));
    } catch (e) {
      throw const AppAuthException(0, 'network', 'Network error. Check your connection.');
    }
    Object? json;
    try {
      json = response.body.isEmpty ? null : jsonDecode(response.body);
    } on FormatException {
      json = null;
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json is Map ? {for (final e in json.entries) '${e.key}': e.value} : const {};
    }
    final error = json is Map && json['error'] is Map ? json['error'] as Map : const {};
    final retryAfter = error['retryAfter'];
    throw AppAuthException(
      response.statusCode,
      '${error['code'] ?? 'http_${response.statusCode}'}',
      '${error['message'] ?? 'The request failed (${response.statusCode}).'}',
      retryAfter: retryAfter is num ? retryAfter.toInt() : null,
    );
  }
}

/// An ID token of the token session and its claims.
@immutable
class IdToken {
  const IdToken(this.token, {this.claims = const {}, this.expiresAt});

  final String token;
  final Map<String, Object?> claims;
  final DateTime? expiresAt;
}

/// Where the session lives once signed in with a custom token: a Firebase Auth instance
/// (one per project) that keeps it between runs and refreshes its ID token.
abstract interface class TokenSession {
  /// The signed-in uid (restored from the last run), or null.
  String? get uid;

  Future<void> signInWithCustomToken(String customToken);

  /// The ID token, refreshed first with [refresh]; null signed out.
  Future<IdToken?> idToken({bool refresh = false});

  Future<void> signOut();
}

/// The user's store record (`projects/{p}/appUsers/{uid}`), live: its `status`,
/// `claimsVersion`, `role`... Null when it isn't readable.
typedef UserRecordWatch = Stream<Map<String, Object?>?> Function(String uid);

/// A readable message for a user store error code.
String appAuthMessage(AppAuthException e) => switch (e.code) {
      'invalid_credentials' => 'Wrong email or password.',
      'email_exists' => 'An account already exists for that email.',
      'invalid_email' => 'That email address is not valid.',
      'weak_password' => e.message,
      'too_many_attempts' => 'Too many failed attempts. Try again later.',
      'rate_limited' => 'Too many requests. Try again later.',
      'user_disabled' => 'This account has been disabled.',
      'requires_recent_login' => 'Sign in again, then try this again.',
      'signup_disabled' => 'Sign-up is turned off for this app.',
      'not_available' => 'This is not available yet.',
      _ => e.message,
    };

AuthFailure _failure(AppAuthException e) => AuthFailure(appAuthMessage(e), code: e.code);

/// [AuthService] on Codelessly's user store for [projectId].
///
/// * Sessions are lazy: [ensureSession] (the cloud data, files and server paywalls
///   call it on first use) signs in anonymously when nobody is; reading the publish
///   needs none.
/// * [signInAsGuest] (the `signInAnonymously` auth action, `codelessly.auth.signInAnonymously`)
///   marks the session ([ensureSession]'s, or a new one) as a guest ([AppUser.isGuest]),
///   by its uid in [storage], as [AuthService] guest sessions are.
/// * Sign-up from an anonymous session keeps the uid; signing in from one to an existing
///   account reports [AuthChangeEvent.merged].
/// * With [watchRecord], a role change (the record's `claimsVersion`) refreshes the
///   token, and a disabled account signs out at once.
/// * Email verification, password reset by email, email links and Google/Apple are not
///   available yet (no email provider): they fail with `not_available`.
class CodelesslyAuthService implements SessionAuthService {
  CodelesslyAuthService({
    required this.projectId,
    required this.client,
    required this.session,
    this.env = 'publish',
    this.watchRecord,
    this.storage,
    this.onError,
  }) {
    _ready = _restore();
  }

  final String projectId;
  final AppAuthClient client;
  final TokenSession session;

  /// Which profile the store mirrors to: `publish` (data/) or `preview` (preview_data/).
  final String env;
  final UserRecordWatch? watchRecord;

  /// Where the guest session's uid is kept (memory when null).
  final LocalStorage? storage;

  static const guestKey = 'auth.guestUid';
  String? _memoryGuest;

  String? get _guestUid {
    final stored = storage?.get(guestKey);
    return stored is String && stored.isNotEmpty ? stored : _memoryGuest;
  }

  Future<void> _setGuest(String? uid) async {
    _memoryGuest = uid;
    final s = storage;
    if (s != null) uid == null ? await s.remove(guestKey) : await s.put(guestKey, uid);
  }

  /// [user], marked as the guest when it is the guest session's.
  AppUser? _marked(AppUser? user) =>
      user != null && user.isAnonymous && user.uid == _guestUid ? user.asGuest() : user;

  /// Background failures (restore, record watch).
  final void Function(Object error, StackTrace stack)? onError;

  late final Future<void> _ready;
  AppUser? _user;
  AuthSession? _session;
  int _claimsVersion = 0;
  bool _restored = false;
  final _events = StreamController<AuthState>.broadcast();
  StreamSubscription<Map<String, Object?>?>? _record;
  Future<AppUser>? _anonymous;

  /// Completes once the last run's session is restored (or found missing).
  Future<void> get ready => _ready;

  @override
  AppUser? get currentUser => _marked(_user);

  @override
  AuthSession? get currentSession => _session;

  @override
  Stream<AuthState> get authStateChanges {
    StreamSubscription<AuthState>? subscription;
    var cancelled = false;
    late final StreamController<AuthState> controller;
    controller = StreamController(
      onListen: () => _ready.then((_) {
        if (cancelled) return;
        controller.add(AuthState(AuthChangeEvent.initialSession, currentUser));
        subscription = _events.stream.listen(controller.add);
      }),
      onCancel: () {
        cancelled = true;
        return subscription?.cancel();
      },
    );
    return controller.stream;
  }

  @override
  Stream<AppUser?> get userChanges => authStateChanges.map((s) => s.user);

  Future<void> _restore() async {
    try {
      if (session.uid == null) return;
      final token = await session.idToken();
      if (token == null || token.claims['cl_p'] != projectId) {
        // Another project's (or an older SDK's) session: not ours to use.
        if (token != null) await session.signOut();
        return;
      }
      _session = AuthSession(accessToken: token.token, expiresAt: token.expiresAt);
      _claimsVersion = (token.claims['cl_v'] as num?)?.toInt() ?? 0;
      // Usable offline from the claims, then completed by the store.
      _user = AppUser(
        uid: session.uid!,
        isAnonymous: token.claims['cl_anon'] != false,
        role: '${token.claims['cl_role'] ?? ''}',
      );
      try {
        final json = await client.send('GET', '$projectId/user', bearer: token.token);
        _user = _userOf(json);
      } on AppAuthException catch (e) {
        if (e.status == 401 || e.status == 403) {
          await session.signOut();
          _user = null;
          _session = null;
        }
      }
      _watch();
    } catch (e, s) {
      onError?.call(e, s);
    } finally {
      _restored = true;
    }
  }

  AppUser _userOf(Map<String, Object?> json) {
    final user = json['user'];
    if (user is! Map) throw const AuthFailure('The user store answered without a user.');
    final record = {for (final e in user.entries) '${e.key}': e.value};
    _claimsVersion = (record['claimsVersion'] as num?)?.toInt() ?? _claimsVersion;
    return AppUser.fromJson(record);
  }

  void _emit(AuthChangeEvent event, {String? mergedFrom}) {
    if (!_events.isClosed) _events.add(AuthState(event, currentUser, mergedFrom: mergedFrom));
  }

  Future<String?> _bearer() async => (await session.idToken())?.token;

  /// Signs the token session in with the answer's custom token and takes its user (the
  /// guest session's with [guest]).
  Future<AppUser> _signIn(Map<String, Object?> json, AuthChangeEvent event,
      {String? mergedFrom, bool guest = false}) async {
    final token = json['customToken'];
    if (token is! String) throw const AuthFailure('The user store answered without a session.');
    await session.signInWithCustomToken(token);
    final id = await session.idToken();
    _session = id == null ? null : AuthSession(accessToken: id.token, expiresAt: id.expiresAt);
    final user = _user = _userOf(json);
    if (guest) {
      await _setGuest(user.uid);
    } else if (_guestUid != null && (user.uid != _guestUid || !user.isAnonymous)) {
      await _setGuest(null);
    }
    _watch();
    _emit(mergedFrom != null ? AuthChangeEvent.merged : event, mergedFrom: mergedFrom);
    return currentUser!;
  }

  Future<T> _run<T>(Future<T> Function() operation) async {
    await _ready;
    try {
      return await operation();
    } on AppAuthException catch (e) {
      throw _failure(e);
    }
  }

  AppUser _signedIn() {
    final user = _user;
    if (user == null || user.isAnonymous) throw const AuthFailure('Sign in first.');
    return user;
  }

  /// The session's uid, signing in anonymously first when there is none.
  Future<String> ensureSession() async {
    await _ready;
    final user = _user;
    if (user != null) return user.uid;
    return (await _signInAnonymously()).uid;
  }

  /// A new anonymous session (the guest session with [guest]).
  Future<AppUser> _signInAnonymously({bool guest = false}) async {
    await _ready;
    if (_user != null) return currentUser!;
    // One request for every caller that asks at once.
    return _anonymous ??= _run(() async {
      final json = await client.send('POST', '$projectId/session/anonymous', body: const {});
      return _signIn(json, AuthChangeEvent.signedIn, guest: guest);
    }).whenComplete(() => _anonymous = null);
  }

  /// Starts a guest session: the anonymous session (made now when there is none; a
  /// signed-in user is signed out first) marked [AppUser.isGuest]. A sign-up keeps its uid.
  @override
  Future<AppUser> signInAsGuest() => _run(() async {
        if (_user case final user? when !user.isAnonymous) await _localSignOut();
        final user = await _signInAnonymously(guest: true);
        if (user.isGuest) return user;
        // The session made on first use (or by a call already running) becomes the guest.
        await _setGuest(user.uid);
        _emit(AuthChangeEvent.userUpdated);
        return currentUser!;
      });

  @override
  Future<AppUser> signUp({required String email, required String password, String displayName = ''}) =>
      signUpWith(email: email, password: password, displayName: displayName);

  @override
  Future<AppUser> signUpWith({
    required String email,
    required String password,
    String displayName = '',
    Map<String, Object?> data = const {},
  }) =>
      _run(() async {
        final anonymous = _user?.isAnonymous == true;
        final json = await client.send(
          'POST',
          '$projectId/signup',
          bearer: anonymous ? await _bearer() : null,
          body: {
            'email': email.trim(),
            'password': password,
            if (displayName.isNotEmpty) 'displayName': displayName,
            if (data.isNotEmpty) 'data': data,
            'env': env,
          },
        );
        return _signIn(json, anonymous ? AuthChangeEvent.userUpdated : AuthChangeEvent.signedIn);
      });

  @override
  Future<AppUser> signIn({required String email, required String password}) => _run(() async {
        final anonymous = _user?.isAnonymous == true;
        final json = await client.send(
          'POST',
          '$projectId/token?grant_type=password',
          bearer: anonymous ? await _bearer() : null,
          body: {'email': email.trim(), 'password': password, 'env': env},
        );
        final merged = json['mergedFrom'];
        return _signIn(json, AuthChangeEvent.signedIn, mergedFrom: merged is String ? merged : null);
      });

  @override
  Future<AppUser> signInWithProvider(AuthProviderKind provider) =>
      Future.error(const AuthFailure('Google and Apple sign-in are not available yet.', code: 'not_available'));

  @override
  Future<void> signOut() => signOutWith(SignOutScope.local);

  @override
  Future<void> signOutWith(SignOutScope scope) async {
    await _ready;
    if (scope == SignOutScope.global && _user != null) {
      try {
        await client.send('POST', '$projectId/logout', bearer: await _bearer(), body: const {'scope': 'global'});
      } on AppAuthException catch (e) {
        throw _failure(e);
      }
    }
    await _localSignOut();
  }

  Future<void> _localSignOut() async {
    await _record?.cancel();
    _record = null;
    await session.signOut();
    final was = _user;
    _user = null;
    _session = null;
    await _setGuest(null);
    if (was != null) _emit(AuthChangeEvent.signedOut);
  }

  @override
  Future<void> updateProfile({String? displayName, String? photoUrl}) =>
      updateUser(UserAttributes(displayName: displayName, photoUrl: photoUrl)).then((_) {});

  @override
  Future<void> updatePassword(String password) => updateUser(UserAttributes(password: password)).then((_) {});

  @override
  Future<AppUser> updateUser(UserAttributes attributes) => _run(() async {
        if (attributes.email != null) {
          throw const AuthFailure('Changing the email is not available yet.', code: 'not_available');
        }
        if (attributes.password != null) _signedIn();
        if (_user == null) throw const AuthFailure('Sign in first.');
        final json = await client.send('PUT', '$projectId/user', bearer: await _bearer(), body: {
          if (attributes.displayName != null) 'displayName': attributes.displayName,
          if (attributes.photoUrl != null) 'photoUrl': attributes.photoUrl,
          if (attributes.password != null) 'password': attributes.password,
          if (attributes.currentPassword != null) 'currentPassword': attributes.currentPassword,
          'env': env,
        });
        // A password change ends every session: this one continues with the new token.
        if (json['customToken'] is String) return _signIn(json, AuthChangeEvent.userUpdated);
        _user = _userOf(json);
        _emit(AuthChangeEvent.userUpdated);
        return currentUser!;
      });

  @override
  Future<void> deleteAccount() => _run(() async {
        // A guest session can be deleted too (it has no account to sign in to again).
        if (!(currentUser?.isGuest ?? false)) _signedIn();
        await client.send('DELETE', '$projectId/user', bearer: await _bearer());
        await _localSignOut();
      });

  @override
  Future<AuthSession?> refreshSession() async {
    await _ready;
    final id = await session.idToken(refresh: true);
    if (id == null) return null;
    _session = AuthSession(accessToken: id.token, expiresAt: id.expiresAt);
    _emit(AuthChangeEvent.tokenRefreshed);
    return _session;
  }

  static const _noEmail =
      AuthFailure('This needs an email provider, which Codelessly accounts do not have yet.', code: 'not_available');

  @override
  Future<void> sendPasswordResetEmail(String email) => Future.error(_noEmail);

  @override
  Future<void> sendEmailVerification() => Future.error(_noEmail);

  @override
  Future<void> sendSignInLink(String email, {required String continueUrl}) => Future.error(_noEmail);

  @override
  bool isSignInLink(String link) => false;

  @override
  Future<AppUser> signInWithLink(String email, String link) => Future.error(_noEmail);

  /// Follows the user's store record: a disabled account signs out; a new claims
  /// version (role change) refreshes the token and the user.
  void _watch() {
    final watch = watchRecord;
    final uid = _user?.uid;
    _record?.cancel();
    _record = null;
    if (watch == null || uid == null) return;
    _record = watch(uid).listen((record) async {
      if (record == null || _user?.uid != uid) return;
      if (record['status'] == 'disabled' || record['status'] == 'deleted') {
        await _localSignOut();
        return;
      }
      final version = (record['claimsVersion'] as num?)?.toInt() ?? 0;
      if (version <= _claimsVersion) return;
      _claimsVersion = version;
      final id = await session.idToken(refresh: true);
      if (id != null) _session = AuthSession(accessToken: id.token, expiresAt: id.expiresAt);
      final role = '${id?.claims['cl_role'] ?? record['role'] ?? _user!.role}';
      _user = _user!.copyWith(role: role, isAnonymous: record['isAnonymous'] == true);
      _emit(AuthChangeEvent.userUpdated);
    }, onError: (Object e, StackTrace s) => onError?.call(e, s));
  }

  /// Whether the last run's session has been looked at (until then `${auth.status}` is
  /// `loading`).
  bool get restored => _restored;

  void dispose() {
    _record?.cancel();
    _events.close();
  }
}

/// [ProjectAuth] on the user store's `/v1/resolve`: the project of the app's project
/// token (or slug), with no Firebase sign-in and no claim to wait for (the publish reads
/// need none). The answer is cached and verified again in the background.
class AppAuthProjectResolver implements ProjectAuth {
  AppAuthProjectResolver({
    required this.client,
    required this.authToken,
    this.slug,
    this.clientType = 'default_client',
    KeyValueCache? cache,
    this.onError,
  }) : cache = cache ?? MemoryKeyValueCache();

  static const cacheKey = 'resolve';

  final AppAuthClient client;
  final String authToken;
  final String? slug;
  final String clientType;
  final KeyValueCache cache;
  final void Function(Object error, StackTrace stack)? onError;

  final _changes = StreamController<ProjectAccess?>.broadcast();
  ProjectAccess? _access;

  /// The project's public auth settings from the last answer: `allowSignUp`,
  /// `anonymous`, `password.minLength`...
  Map<String, Object?> publicAuth = const {};

  @override
  ProjectAccess? get access => _access;

  @override
  Stream<ProjectAccess?> get changes => _changes.stream;

  @override
  Future<ProjectAccess> authenticate() async {
    final cached = await readCached(cache, cacheKey, ProjectAccess.fromJson);
    if (cached != null && cached.authToken == authToken) {
      _set(cached);
      unawaited(_fetch().then<void>((_) {}, onError: (Object e, StackTrace s) => onError?.call(e, s)));
      return cached;
    }
    return _fetch();
  }

  /// Nothing to do: access doesn't depend on who is signed in.
  @override
  Future<void> reauthenticate() async {}

  void _set(ProjectAccess? value) {
    _access = value;
    if (!_changes.isClosed) _changes.add(value);
  }

  Future<ProjectAccess> _fetch() async {
    final Map<String, Object?> json;
    try {
      json = await client.send('POST', 'resolve', body: {
        if (slug != null) 'slug': slug else 'token': authToken,
        'clientType': clientType,
      });
    } on AppAuthException catch (e) {
      if (e.status == 404) await cache.delete(cacheKey);
      throw StateError('Failed to authenticate the project token. (${e.code})');
    }
    final id = json['projectId'];
    if (id is! String) throw StateError('Failed to authenticate the project token.');
    final value = ProjectAccess(
      projectId: id,
      authToken: authToken,
      isTemplate: json['isTemplate'] == true,
      timestamp: DateTime.now(),
    );
    final auth = json['auth'];
    if (auth is Map) publicAuth = {for (final e in auth.entries) '${e.key}': e.value};
    _set(value);
    await cache.write(cacheKey, value.toJson());
    return value;
  }

  @override
  void dispose() => _changes.close();
}

/// [inner], but every operation first makes sure there is a session ([ensure]: an
/// anonymous one when nobody is signed in), so the security rules see the project's
/// claim. The session is created on first use, not at launch.
class SessionDocumentBackend implements DocumentBackend {
  SessionDocumentBackend(this.inner, this.ensure);

  final DocumentBackend inner;
  final Future<Object?> Function() ensure;

  @override
  Future<Map<String, Object?>?> get(String collection, String id) async {
    await ensure();
    return inner.get(collection, id);
  }

  @override
  Stream<Map<String, Object?>?> watch(String collection, String id) =>
      Stream.fromFuture(ensure()).asyncExpand((_) => inner.watch(collection, id));

  @override
  Future<List<CloudDocument>> query(String collection, CloudQuery query) async {
    await ensure();
    return inner.query(collection, query);
  }

  @override
  Stream<List<CloudDocument>> watchQuery(String collection, CloudQuery query) =>
      Stream.fromFuture(ensure()).asyncExpand((_) => inner.watchQuery(collection, query));

  @override
  Future<num?> aggregate(String collection, CloudQuery query, CloudAggregate operation, String field) async {
    await ensure();
    return inner.aggregate(collection, query, operation, field);
  }

  @override
  String newId(String collection) => inner.newId(collection);

  @override
  int get maxBatchWrites => inner.maxBatchWrites;

  @override
  Future<void> commit(List<DocumentWrite> writes) async {
    await ensure();
    return inner.commit(writes);
  }
}

/// [inner] with a session made on first use, as [SessionDocumentBackend].
class SessionFileStorage implements CloudFileStorage {
  SessionFileStorage(this.inner, this.ensure);

  final CloudFileStorage inner;
  final Future<Object?> Function() ensure;

  @override
  Future<CloudFile> upload(String path, Uint8List bytes,
      {String? contentType, void Function(double sent)? onProgress}) async {
    await ensure();
    return inner.upload(path, bytes, contentType: contentType, onProgress: onProgress);
  }

  @override
  Future<void> delete(String pathOrUrl) async {
    await ensure();
    return inner.delete(pathOrUrl);
  }

  @override
  Future<List<CloudFile>> list(String folder) async {
    await ensure();
    return inner.list(folder);
  }

  @override
  Future<String> downloadUrl(String path) async {
    await ensure();
    return inner.downloadUrl(path);
  }
}
