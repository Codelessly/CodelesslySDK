// App user accounts: who is signed in (the `auth` variable) and the auth
// actions (sign in, sign up, sign out...). Firebase Auth implements it in
// package:codelessly_sdk/firebase.dart.
import 'dart:async';

import 'package:codelessly_api/codelessly_api.dart' show CollectionSchema;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show StringCharacters;

import 'cloud/database.dart';
import 'cloud/fields.dart';

/// A signed-in app user.
@immutable
class AppUser {
  const AppUser({
    required this.uid,
    this.email = '',
    this.displayName = '',
    this.photoUrl = '',
    this.emailVerified = false,
    this.isAnonymous = false,
    this.isGuest = false,
    this.providers = const [],
    this.role = '',
    this.createdAt,
    this.lastSignInAt,
  });

  /// [json] from Codelessly's user store (`{id, email, displayName, role, ...}`) or a
  /// store record (`{uid, ...}`); times as ISO text, milliseconds or [DateTime].
  factory AppUser.fromJson(Map<String, Object?> json) {
    String text(String key) => json[key] is String ? json[key] as String : '';
    DateTime? time(String key) => switch (json[key]) {
          final DateTime d => d,
          final String s => DateTime.tryParse(s),
          final int ms => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
          _ => null,
        };
    return AppUser(
      uid: text('id').isNotEmpty ? text('id') : text('uid'),
      email: text('email'),
      displayName: text('displayName'),
      photoUrl: text('photoUrl'),
      emailVerified: json['emailVerified'] == true,
      isAnonymous: json['isAnonymous'] == true,
      providers: [for (final p in (json['providers'] is List ? json['providers'] as List : const [])) '$p'],
      role: text('role'),
      createdAt: time('createdAt'),
      lastSignInAt: time('lastSignInAt'),
    );
  }

  final String uid;
  final String email;
  final String displayName;
  final String photoUrl;
  final bool emailVerified;

  /// An anonymous user (the SDK's own, to read published data; on
  /// Codelessly's user store, the session made on first use) counts as
  /// signed out for the app.
  final bool isAnonymous;

  /// An anonymous user the app signed in on purpose (a guest session, see
  /// `AuthOperation.signInAnonymously`): it has a uid for its own data but
  /// no email. Unlike the SDK's own anonymous user, `auth.uid` shows it.
  final bool isGuest;

  /// Sign-in providers (`password`, `google.com`...).
  final List<String> providers;

  /// The user's role in the app (Codelessly's user store: the `cl_role` claim), or empty
  /// when the backend has none (then `${auth.role}` reads the profile's).
  final String role;
  final DateTime? createdAt;
  final DateTime? lastSignInAt;

  AppUser copyWith({
    String? email,
    String? displayName,
    String? photoUrl,
    bool? emailVerified,
    bool? isAnonymous,
    bool? isGuest,
    List<String>? providers,
    String? role,
  }) =>
      AppUser(
        uid: uid,
        email: email ?? this.email,
        displayName: displayName ?? this.displayName,
        photoUrl: photoUrl ?? this.photoUrl,
        emailVerified: emailVerified ?? this.emailVerified,
        isAnonymous: isAnonymous ?? this.isAnonymous,
        isGuest: isGuest ?? this.isGuest,
        providers: providers ?? this.providers,
        role: role ?? this.role,
        createdAt: createdAt,
        lastSignInAt: lastSignInAt,
      );

  @override
  bool operator ==(Object other) =>
      other is AppUser &&
      other.uid == uid &&
      other.email == email &&
      other.displayName == displayName &&
      other.photoUrl == photoUrl &&
      other.emailVerified == emailVerified &&
      other.isAnonymous == isAnonymous &&
      other.isGuest == isGuest &&
      listEquals(other.providers, providers) &&
      other.role == role &&
      other.createdAt == createdAt &&
      other.lastSignInAt == lastSignInAt;

  @override
  int get hashCode => Object.hash(uid, email, displayName, photoUrl, emailVerified, isAnonymous, isGuest,
      Object.hashAll(providers), role, createdAt, lastSignInAt);

  /// This user marked as a guest session.
  AppUser asGuest() => copyWith(isGuest: true);

  @override
  String toString() => 'AppUser($uid${email.isEmpty ? '' : ', $email'}${isGuest ? ', guest' : (isAnonymous ? ', anonymous' : '')})';
}

/// The `auth` value for [user] and their [profile] document: `status`
/// (`loading` until the session is known when [loading], then `signedOut`,
/// `anonymous` or `signedIn`), `isSignedIn`, `isAnonymous`, `isGuest`,
/// `anonymousId` (an anonymous user's uid), `uid`, `email`, `displayName`,
/// `initial`, `photoUrl`, `emailVerified`, `providers`, `createdAt`,
/// `lastSignInAt` (ISO text, or empty), `profile` and `role` (a signed-in
/// user's own, else the profile's, else `user`; a guest's profile's, else
/// `guest`; signed out, empty).
/// Anonymous users read as signed out: `uid` stays empty for them. A guest
/// session (an anonymous user the app signed in on purpose) is not signed in
/// either, but has its `uid` and `profile`, so it can keep data of its own.
Map<String, Object?> authValue(AppUser? user, {Map<String, Object?>? profile, bool loading = false}) {
  final guest = user != null && user.isGuest;
  final signedIn = user != null && !user.isAnonymous;
  final displayName = signedIn ? user.displayName : '';
  final email = signedIn ? user.email : '';
  final initialSource = displayName.isNotEmpty ? displayName : email;
  final role = signedIn
      ? (user.role.isNotEmpty ? user.role : '${profile?['role'] ?? 'user'}')
      : '${profile?['role'] ?? (guest ? 'guest' : '')}';
  return {
    'status': loading
        ? 'loading'
        : user == null
            ? 'signedOut'
            : user.isAnonymous
                ? 'anonymous'
                : 'signedIn',
    'isSignedIn': signedIn,
    'isAnonymous': user != null && user.isAnonymous,
    'isGuest': guest,
    'anonymousId': user != null && user.isAnonymous ? user.uid : '',
    'uid': signedIn || guest ? user.uid : '',
    'email': email,
    'displayName': displayName,
    'initial': initialSource.isEmpty ? '' : initialSource.characters.first.toUpperCase(),
    'photoUrl': signedIn ? user.photoUrl : '',
    'emailVerified': signedIn && user.emailVerified,
    'providers': signedIn ? user.providers : const <String>[],
    'createdAt': signedIn ? user.createdAt?.toIso8601String() ?? '' : '',
    'lastSignInAt': signedIn ? user.lastSignInAt?.toIso8601String() ?? '' : '',
    'profile': profile ?? const <String, Object?>{},
    'role': role,
  };
}

/// Federated sign-in providers.
enum AuthProviderKind { google, apple }

/// An auth operation that failed, with a message to show the user.
class AuthFailure implements Exception {
  const AuthFailure(this.message, {this.code = ''});

  final String message;

  /// The provider's code (`wrong-password`...), when it has one.
  final String code;

  @override
  String toString() => message;
}

/// App user accounts. Every operation throws [AuthFailure] when it fails.
abstract interface class AuthService {
  /// The signed-in user (maybe anonymous), or null.
  AppUser? get currentUser;

  /// The user, on every sign-in, sign-out and profile change.
  Stream<AppUser?> get userChanges;

  Future<AppUser> signIn({required String email, required String password});
  Future<AppUser> signUp({required String email, required String password, String displayName = ''});
  Future<AppUser> signInWithProvider(AuthProviderKind provider);

  /// Starts a guest session: an anonymous user marked [AppUser.isGuest]
  /// (the one already signed in anonymously, when there is one). A
  /// [signUp] during it keeps its uid.
  Future<AppUser> signInAsGuest();

  /// Signs out (an implementation that reads published data as an
  /// anonymous user signs in anonymously again).
  Future<void> signOut();

  Future<void> updateProfile({String? displayName, String? photoUrl});
  Future<void> updatePassword(String password);
  Future<void> sendPasswordResetEmail(String email);
  Future<void> sendEmailVerification();

  /// Deletes the signed-in user's account.
  Future<void> deleteAccount();

  /// Emails [email] a sign-in link back to [continueUrl].
  Future<void> sendSignInLink(String email, {required String continueUrl});

  /// Whether [link] is a sign-in link.
  bool isSignInLink(String link);

  /// Signs in with a sign-in [link] sent to [email].
  Future<AppUser> signInWithLink(String email, String link);
}

/// What happened to the session ([CodelesslyAuth.onAuthStateChange]).
enum AuthChangeEvent {
  /// The session as it was when listening started (restored, or none).
  initialSession,
  signedIn,
  signedOut,

  /// The same user changed: profile, role, an anonymous user who signed up.
  userUpdated,
  tokenRefreshed,
  passwordRecovery,

  /// An anonymous user signed in to an existing account: [AuthState.mergedFrom] is the
  /// anonymous uid, whose data the app may move over.
  merged,
}

/// A session change: the [event] and the user after it.
@immutable
class AuthState {
  const AuthState(this.event, this.user, {this.mergedFrom});

  final AuthChangeEvent event;
  final AppUser? user;

  /// With [AuthChangeEvent.merged]: the anonymous uid the user came from.
  final String? mergedFrom;

  @override
  bool operator ==(Object other) =>
      other is AuthState && other.event == event && other.user == user && other.mergedFrom == mergedFrom;

  @override
  int get hashCode => Object.hash(event, user, mergedFrom);

  @override
  String toString() => 'AuthState(${event.name}, $user${mergedFrom == null ? '' : ', from $mergedFrom'})';
}

/// The session's access token (a Firebase ID token for Codelessly's user store) and
/// when it expires; the backend refreshes it.
@immutable
class AuthSession {
  const AuthSession({required this.accessToken, this.expiresAt});

  final String accessToken;
  final DateTime? expiresAt;
}

/// What [CodelesslyAuth.updateUser] changes. A new [password] needs a recent sign-in, or
/// [currentPassword].
@immutable
class UserAttributes {
  const UserAttributes({this.email, this.password, this.currentPassword, this.displayName, this.photoUrl});

  final String? email;
  final String? password;
  final String? currentPassword;
  final String? displayName;
  final String? photoUrl;
}

/// [CodelesslyAuth.signOut] on this device, or everywhere (every session of the user).
enum SignOutScope { local, global }

/// An [AuthService] with sessions: the session token, events, a sign-out everywhere,
/// sign-up with profile data. Codelessly's user store and [MemoryAuthService] have them.
/// Anonymous sessions are [AuthService.signInAsGuest]'s, as on every [AuthService].
abstract interface class SessionAuthService implements AuthService {
  /// Every session change, starting with [AuthChangeEvent.initialSession].
  Stream<AuthState> get authStateChanges;

  /// The session's token as last known (null signed out).
  AuthSession? get currentSession;

  /// A fresh session token.
  Future<AuthSession?> refreshSession();

  /// Signs up; an anonymous user is upgraded in place (same uid). [data] goes in the
  /// user's profile.
  Future<AppUser> signUpWith({
    required String email,
    required String password,
    String displayName = '',
    Map<String, Object?> data = const {},
  });

  Future<void> signOutWith(SignOutScope scope);

  Future<AppUser> updateUser(UserAttributes attributes);
}

/// The events of [users]: the first value is the initial session, then sign-in, sign-out
/// and changes of the same user.
Stream<AuthState> authStatesOf(Stream<AppUser?> users) {
  var first = true;
  AppUser? last;
  StreamSubscription<AppUser?>? subscription;
  late final StreamController<AuthState> controller;
  void onUser(AppUser? user) {
    final AuthChangeEvent event;
    if (first) {
      event = AuthChangeEvent.initialSession;
      first = false;
    } else if (user == null) {
      if (last == null) return;
      event = AuthChangeEvent.signedOut;
    } else if (last == null || last!.uid != user.uid) {
      event = AuthChangeEvent.signedIn;
    } else if (user != last) {
      event = AuthChangeEvent.userUpdated;
    } else {
      return;
    }
    last = user;
    controller.add(AuthState(event, user));
  }

  // Subscribed as soon as listened to, so a change made right after is not missed.
  controller = StreamController(
    onListen: () => subscription = users.listen(onUser, onError: controller.addError, onDone: controller.close),
    onCancel: () => subscription?.cancel(),
  );
  return controller.stream;
}

/// App user accounts, Supabase-style: `codelessly.auth`.
///
/// ```dart
/// await codelessly.auth.signUp(email: email, password: password, data: {'displayName': name});
/// codelessly.auth.onAuthStateChange.listen((state) => print(state.event));
/// ```
///
/// Over any [AuthService]; the session operations ([currentSession], a sign-out
/// everywhere, sign-up `data`, [AuthChangeEvent.merged]) need a [SessionAuthService]
/// (Codelessly's user store): without one [currentSession] is null and a sign-out signs
/// out of this device only.
class CodelesslyAuth {
  CodelesslyAuth(this.service);

  /// The service the operations run on ([Services.auth]).
  final AuthService service;

  SessionAuthService? get _sessions => service is SessionAuthService ? service as SessionAuthService : null;

  /// The signed-in user (anonymous ones have [AppUser.isAnonymous]), or null.
  AppUser? get currentUser => service.currentUser;

  /// The session token as last known, or null.
  AuthSession? get currentSession => _sessions?.currentSession;

  /// Every session change, starting with [AuthChangeEvent.initialSession].
  Stream<AuthState> get onAuthStateChange => _sessions?.authStateChanges ?? authStatesOf(service.userChanges);

  /// Creates an account and signs it in. A guest session is upgraded in place, keeping
  /// its uid and data (on Codelessly's user store, any anonymous session is). `data['displayName']` names the user; the rest of [data] goes in
  /// their profile.
  Future<AppUser> signUp({required String email, required String password, Map<String, Object?> data = const {}}) {
    final displayName = '${data['displayName'] ?? ''}';
    final sessions = _sessions;
    if (sessions == null) return service.signUp(email: email, password: password, displayName: displayName);
    return sessions.signUpWith(
      email: email,
      password: password,
      displayName: displayName,
      data: {...data}..remove('displayName'),
    );
  }

  Future<AppUser> signInWithPassword({required String email, required String password}) =>
      service.signIn(email: email, password: password);

  /// Starts a guest session ([AuthService.signInAsGuest], the `signInAnonymously` auth
  /// action's): an anonymous user marked [AppUser.isGuest], whose uid `${auth.uid}`
  /// shows and a later [signUp] keeps. The current anonymous session becomes the guest
  /// (a signed-in user is signed out first).
  Future<AppUser> signInAnonymously() => service.signInAsGuest();

  /// Signs out of this device, or of every device with [SignOutScope.global].
  Future<void> signOut({SignOutScope scope = SignOutScope.local}) =>
      _sessions?.signOutWith(scope) ?? service.signOut();

  /// Changes the user's name, photo or password.
  Future<AppUser> updateUser(UserAttributes attributes) async {
    final sessions = _sessions;
    if (sessions != null) return sessions.updateUser(attributes);
    if (attributes.email != null) throw const AuthFailure('Changing the email is not available.', code: 'unavailable');
    if (attributes.displayName != null || attributes.photoUrl != null) {
      await service.updateProfile(displayName: attributes.displayName, photoUrl: attributes.photoUrl);
    }
    if (attributes.password != null) await service.updatePassword(attributes.password!);
    return service.currentUser ?? (throw const AuthFailure('Sign in first.'));
  }

  /// A fresh session token.
  Future<AuthSession?> refreshSession() => _sessions?.refreshSession() ?? Future.value();

  /// Deletes the signed-in user's account (it needs a recent sign-in).
  Future<void> deleteUser() => service.deleteAccount();
}

/// No accounts: always signed out; every operation fails. The default, for
/// apps without sign-in.
class SignedOutAuthService implements AuthService {
  const SignedOutAuthService();

  static const _failure = AuthFailure('Sign-in is not available.', code: 'unavailable');

  @override
  AppUser? get currentUser => null;

  @override
  Stream<AppUser?> get userChanges => Stream.value(null);

  @override
  Future<AppUser> signIn({required String email, required String password}) => Future.error(_failure);

  @override
  Future<AppUser> signUp({required String email, required String password, String displayName = ''}) =>
      Future.error(_failure);

  @override
  Future<AppUser> signInWithProvider(AuthProviderKind provider) => Future.error(_failure);

  @override
  Future<AppUser> signInAsGuest() => Future.error(_failure);

  @override
  Future<void> signOut() async {}

  @override
  Future<void> updateProfile({String? displayName, String? photoUrl}) => Future.error(_failure);

  @override
  Future<void> updatePassword(String password) => Future.error(_failure);

  @override
  Future<void> sendPasswordResetEmail(String email) => Future.error(_failure);

  @override
  Future<void> sendEmailVerification() => Future.error(_failure);

  @override
  Future<void> deleteAccount() => Future.error(_failure);

  @override
  Future<void> sendSignInLink(String email, {required String continueUrl}) => Future.error(_failure);

  @override
  bool isSignInLink(String link) => false;

  @override
  Future<AppUser> signInWithLink(String email, String link) => Future.error(_failure);
}

/// Accounts in memory, with Firebase Auth's rules and messages: for tests,
/// previews and demos. Anonymous users sign up in place, as with Codelessly's
/// user store.
class MemoryAuthService implements SessionAuthService {
  MemoryAuthService({AppUser? signedIn}) : _user = signedIn;

  /// email → (password, user).
  final Map<String, (String, AppUser)> accounts = {};

  /// Emails sent (reset, verification, link), for tests.
  final List<(String kind, String email)> sent = [];

  AppUser? _user;
  final _changes = StreamController<AppUser?>.broadcast();
  var _ids = 0;

  @override
  AppUser? get currentUser => _user;

  @override
  Stream<AppUser?> get userChanges {
    StreamSubscription<AppUser?>? subscription;
    late final StreamController<AppUser?> controller;
    controller = StreamController(
      onListen: () {
        controller.add(_user);
        subscription = _changes.stream.listen(controller.add);
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }

  AppUser? _set(AppUser? user) {
    _user = user;
    _changes.add(user);
    if (user != null) {
      if (accounts[user.email] case (final password, _)) accounts[user.email] = (password, user);
    }
    return user;
  }

  AppUser _signedIn() {
    final user = _user;
    if (user == null || user.isAnonymous) throw const AuthFailure('Sign in first.');
    return user;
  }

  @override
  Future<AppUser> signInAsGuest() async {
    final user = _user;
    if (user != null && user.isGuest) return user;
    return _set(AppUser(uid: 'guest${++_ids}', isAnonymous: true, isGuest: true))!;
  }

  @override
  Future<AppUser> signIn({required String email, required String password}) async {
    final account = accounts[email.trim()];
    if (account == null || account.$1 != password) {
      throw const AuthFailure('Wrong email or password.', code: 'invalid-credential');
    }
    return _set(account.$2)!;
  }

  @override
  Future<AppUser> signUp({required String email, required String password, String displayName = ''}) =>
      signUpWith(email: email, password: password, displayName: displayName);

  /// Profile data given at sign-up, by uid.
  final Map<String, Map<String, Object?>> profiles = {};

  @override
  Future<AppUser> signUpWith({
    required String email,
    required String password,
    String displayName = '',
    Map<String, Object?> data = const {},
  }) async {
    final e = email.trim();
    if (!e.contains('@')) throw const AuthFailure('That email address is not valid.', code: 'invalid-email');
    if (accounts.containsKey(e)) {
      throw const AuthFailure('An account already exists for that email.', code: 'email-already-in-use');
    }
    if (password.length < 6) throw const AuthFailure('Password must be at least 6 characters.', code: 'weak-password');
    // An anonymous user's (a guest's) account keeps their uid, and so their data.
    final anonymous = _user?.isAnonymous == true ? _user : null;
    final user = AppUser(
      uid: anonymous?.uid ?? 'user${++_ids}',
      email: e,
      displayName: displayName,
      providers: const ['password'],
    );
    accounts[e] = (password, user);
    if (data.isNotEmpty) profiles[user.uid] = {...data};
    return _set(user)!;
  }

  @override
  Stream<AuthState> get authStateChanges => authStatesOf(userChanges);

  @override
  AuthSession? get currentSession => _user == null ? null : AuthSession(accessToken: 'memory-${_user!.uid}');

  @override
  Future<AuthSession?> refreshSession() async => currentSession;

  @override
  Future<void> signOutWith(SignOutScope scope) => signOut();

  @override
  Future<AppUser> updateUser(UserAttributes attributes) async {
    if (attributes.email != null) throw const AuthFailure('Changing the email is not available.', code: 'unavailable');
    if (attributes.displayName != null || attributes.photoUrl != null) {
      await updateProfile(displayName: attributes.displayName, photoUrl: attributes.photoUrl);
    }
    if (attributes.password != null) await updatePassword(attributes.password!);
    return _signedIn();
  }

  @override
  Future<AppUser> signInWithProvider(AuthProviderKind provider) async =>
      _set(AppUser(uid: 'user${++_ids}', providers: ['${provider.name}.com']))!;

  @override
  Future<void> signOut() async => _set(null);

  @override
  Future<void> updateProfile({String? displayName, String? photoUrl}) async {
    final u = _signedIn();
    _set(u.copyWith(displayName: displayName, photoUrl: photoUrl));
  }

  @override
  Future<void> updatePassword(String password) async {
    final u = _signedIn();
    if (password.length < 6) throw const AuthFailure('Password must be at least 6 characters.', code: 'weak-password');
    accounts[u.email] = (password, u);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async => sent.add(('reset', email));

  @override
  Future<void> sendEmailVerification() async => sent.add(('verify', _signedIn().email));

  @override
  Future<void> deleteAccount() async {
    if (_user?.isGuest ?? false) {
      _set(null);
      return;
    }
    accounts.remove(_signedIn().email);
    _set(null);
  }

  @override
  Future<void> sendSignInLink(String email, {required String continueUrl}) async => sent.add(('link', email));

  @override
  bool isSignInLink(String link) => link.contains('signInLink');

  @override
  Future<AppUser> signInWithLink(String email, String link) async {
    if (!isSignInLink(link)) throw const AuthFailure('That sign-in link is not valid.', code: 'invalid-action-code');
    return _set(accounts[email]?.$2 ?? AppUser(uid: 'user${++_ids}', email: email, emailVerified: true))!;
  }

  void dispose() => _changes.close();
}

/// App user profiles: `users/{uid}` documents, which `${auth.profile}` and
/// `${auth.role}` read.
abstract final class AuthProfiles {
  /// The collection of the profiles.
  static const collection = 'users';

  /// The fields a new profile starts with: who they are and the `user` role.
  static Map<String, Object?> newProfile(AppUser user) => {
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName,
        'photoUrl': user.photoUrl,
        'role': user.isGuest ? 'guest' : 'user',
      };

  /// Whether [user] has a profile: signed in, or a guest session.
  static bool hasProfile(AppUser? user) => user != null && (!user.isAnonymous || user.isGuest);

  /// Creates [user]'s profile when it doesn't exist yet, with [newProfile],
  /// the defaults of the `users` schema and `createdAt`.
  static Future<void> ensure(CloudDatabase database, AppUser? user) async {
    if (!hasProfile(user)) return;
    user!;
    if (await database.getDocument(collection, user.uid) != null) return;
    final schema = database.rules.schemaFor(collection);
    final data = <String, Object?>{
      if (schema != null)
        ...CloudFieldValues.buildWrite(
          fields: const [],
          schema: CollectionSchema(schema.name, fields: [for (final f in schema.fields) f.copyWith(required: false)]),
          evaluate: (v) => v,
          create: true,
        ),
      ...newProfile(user),
    };
    await database.addDocument(collection, data, id: user.uid);
  }

  /// [user]'s profile, now and on every change (null signed out).
  static Stream<Map<String, Object?>?> watch(CloudDatabase database, AppUser? user) =>
      hasProfile(user) ? database.watchDocument(collection, user!.uid) : Stream.value(null);
}

/// Access to a Codelessly project's published data, granted for the app's
/// project token.
@immutable
class ProjectAccess {
  const ProjectAccess({required this.projectId, this.authToken = '', this.isTemplate = false, this.timestamp});

  final String projectId;

  /// The project token it was granted for.
  final String authToken;

  /// Whether the project is a template (published data under templates).
  final bool isTemplate;
  final DateTime? timestamp;

  Map<String, Object?> toJson() => {
        'projectId': projectId,
        'authToken': authToken,
        if (isTemplate) 'isTemplate': true,
        if (timestamp != null) 'timestamp': timestamp!.millisecondsSinceEpoch,
      };

  static ProjectAccess? fromJson(Object? json) {
    if (json is! Map || json['projectId'] is! String) return null;
    final ts = json['timestamp'];
    return ProjectAccess(
      projectId: json['projectId'] as String,
      authToken: json['authToken'] is String ? json['authToken'] as String : '',
      isTemplate: json['isTemplate'] == true,
      timestamp: ts is int ? DateTime.fromMillisecondsSinceEpoch(ts) : (ts is String ? DateTime.tryParse(ts) : null),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ProjectAccess &&
      other.projectId == projectId &&
      other.authToken == authToken &&
      other.isTemplate == isTemplate &&
      other.timestamp == timestamp;

  @override
  int get hashCode => Object.hash(projectId, authToken, isTemplate, timestamp);
}

/// Authenticates the app with its Codelessly project, so it can read the
/// project's published data and cloud data.
abstract interface class ProjectAuth {
  /// The current access, or null before (or without) authentication.
  ProjectAccess? get access;

  /// [access], on every change.
  Stream<ProjectAccess?> get changes;

  /// Authenticates (from the cache when it's still valid, verifying in the
  /// background). Throws when it fails.
  Future<ProjectAccess> authenticate();

  /// Authenticates again for the user now signed in.
  Future<void> reauthenticate();

  void dispose();
}
