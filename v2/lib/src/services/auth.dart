// App user accounts: who is signed in (the `auth` variable) and the auth
// actions (sign in, sign up, sign out...). Firebase Auth implements it in
// package:codelessly_sdk_v2/firebase.dart.
import 'dart:async';

import 'package:codelessly_api_v2/codelessly_api.dart' show CollectionSchema;
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
    this.providers = const [],
  });

  final String uid;
  final String email;
  final String displayName;
  final String photoUrl;
  final bool emailVerified;

  /// An anonymous user (the SDK's own, to read published data) counts as
  /// signed out for the app.
  final bool isAnonymous;

  /// Sign-in providers (`password`, `google.com`...).
  final List<String> providers;

  @override
  bool operator ==(Object other) =>
      other is AppUser &&
      other.uid == uid &&
      other.email == email &&
      other.displayName == displayName &&
      other.photoUrl == photoUrl &&
      other.emailVerified == emailVerified &&
      other.isAnonymous == isAnonymous &&
      listEquals(other.providers, providers);

  @override
  int get hashCode => Object.hash(uid, email, displayName, photoUrl, emailVerified, isAnonymous, Object.hashAll(providers));

  @override
  String toString() => 'AppUser($uid${email.isEmpty ? '' : ', $email'}${isAnonymous ? ', anonymous' : ''})';
}

/// The `auth` value for [user] and their [profile] document: `isSignedIn`,
/// `uid`, `email`, `displayName`, `initial`, `photoUrl`, `emailVerified`,
/// `providers`, `profile` and `role` (a signed-in user without one is a
/// `user`; signed out, empty). Anonymous users read as signed out.
Map<String, Object?> authValue(AppUser? user, {Map<String, Object?>? profile}) {
  final signedIn = user != null && !user.isAnonymous;
  final displayName = signedIn ? user.displayName : '';
  final email = signedIn ? user.email : '';
  final initialSource = displayName.isNotEmpty ? displayName : email;
  return {
    'isSignedIn': signedIn,
    'uid': signedIn ? user.uid : '',
    'email': email,
    'displayName': displayName,
    'initial': initialSource.isEmpty ? '' : initialSource.characters.first.toUpperCase(),
    'photoUrl': signedIn ? user.photoUrl : '',
    'emailVerified': signedIn && user.emailVerified,
    'providers': signedIn ? user.providers : const <String>[],
    'profile': profile ?? const <String, Object?>{},
    'role': '${profile?['role'] ?? (signedIn ? 'user' : '')}',
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
/// previews and demos.
class MemoryAuthService implements AuthService {
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
  Stream<AppUser?> get userChanges async* {
    yield _user;
    yield* _changes.stream;
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
  Future<AppUser> signIn({required String email, required String password}) async {
    final account = accounts[email.trim()];
    if (account == null || account.$1 != password) {
      throw const AuthFailure('Wrong email or password.', code: 'invalid-credential');
    }
    return _set(account.$2)!;
  }

  @override
  Future<AppUser> signUp({required String email, required String password, String displayName = ''}) async {
    final e = email.trim();
    if (!e.contains('@')) throw const AuthFailure('That email address is not valid.', code: 'invalid-email');
    if (accounts.containsKey(e)) {
      throw const AuthFailure('An account already exists for that email.', code: 'email-already-in-use');
    }
    if (password.length < 6) throw const AuthFailure('Password must be at least 6 characters.', code: 'weak-password');
    final user = AppUser(uid: 'user${++_ids}', email: e, displayName: displayName, providers: const ['password']);
    accounts[e] = (password, user);
    return _set(user)!;
  }

  @override
  Future<AppUser> signInWithProvider(AuthProviderKind provider) async =>
      _set(AppUser(uid: 'user${++_ids}', providers: ['${provider.name}.com']))!;

  @override
  Future<void> signOut() async => _set(null);

  @override
  Future<void> updateProfile({String? displayName, String? photoUrl}) async {
    final u = _signedIn();
    _set(AppUser(
      uid: u.uid,
      email: u.email,
      displayName: displayName ?? u.displayName,
      photoUrl: photoUrl ?? u.photoUrl,
      emailVerified: u.emailVerified,
      providers: u.providers,
    ));
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
        'role': 'user',
      };

  /// Creates [user]'s profile when it doesn't exist yet, with [newProfile],
  /// the defaults of the `users` schema and `createdAt`.
  static Future<void> ensure(CloudDatabase database, AppUser? user) async {
    if (user == null || user.isAnonymous) return;
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
      user == null || user.isAnonymous ? Stream.value(null) : database.watchDocument(collection, user.uid);
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
