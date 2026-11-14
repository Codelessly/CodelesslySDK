// App user accounts: who is signed in (the `auth` variable) and the auth
// actions (sign in, sign up, sign out...). Firebase Auth implements it in
// package:codelessly_sdk/firebase.dart.
import 'dart:async';

import 'package:codelessly_api/codelessly_api.dart' show CollectionSchema, DataRules;
import 'package:flutter/foundation.dart';
import 'package:characters/characters.dart';

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
  });

  final String uid;
  final String email;
  final String displayName;
  final String photoUrl;
  final bool emailVerified;

  /// An anonymous user (the SDK's own, to read published data) counts as
  /// signed out for the app.
  final bool isAnonymous;

  /// An anonymous user the app signed in on purpose (a guest session, see
  /// `AuthOperation.signInAnonymously`): it has a uid for its own data but
  /// no email. Unlike the SDK's own anonymous user, `auth.uid` shows it.
  final bool isGuest;

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
      other.isGuest == isGuest &&
      listEquals(other.providers, providers);

  @override
  int get hashCode => Object.hash(uid, email, displayName, photoUrl, emailVerified, isAnonymous, isGuest, Object.hashAll(providers));

  /// This user marked as a guest session.
  AppUser asGuest() => AppUser(
        uid: uid,
        email: email,
        displayName: displayName,
        photoUrl: photoUrl,
        emailVerified: emailVerified,
        isAnonymous: isAnonymous,
        isGuest: true,
        providers: providers,
      );

  @override
  String toString() => 'AppUser($uid${email.isEmpty ? '' : ', $email'}${isGuest ? ', guest' : (isAnonymous ? ', anonymous' : '')})';
}

/// The `auth` value for [user] and their [profile] document: `isSignedIn`,
/// `isGuest`, `uid`, `email`, `displayName`, `initial`, `photoUrl`,
/// `emailVerified`, `providers`, `profile` and `role` (a signed-in user
/// without one is a `user`, a guest a `guest`; signed out, empty).
/// Anonymous users read as signed out; a guest session (an anonymous user
/// the app signed in on purpose) is not signed in either, but has its `uid`
/// and `profile`, so it can keep data of its own.
Map<String, Object?> authValue(AppUser? user, {Map<String, Object?>? profile}) {
  final guest = user != null && user.isGuest;
  final signedIn = user != null && !user.isAnonymous;
  final displayName = signedIn ? user.displayName : '';
  final email = signedIn ? user.email : '';
  final initialSource = displayName.isNotEmpty ? displayName : email;
  return {
    'isSignedIn': signedIn,
    'isGuest': guest,
    'uid': signedIn || guest ? user.uid : '',
    'email': email,
    'displayName': displayName,
    'initial': initialSource.isEmpty ? '' : initialSource.characters.first.toUpperCase(),
    'photoUrl': signedIn ? user.photoUrl : '',
    'emailVerified': signedIn && user.emailVerified,
    'providers': signedIn ? user.providers : const <String>[],
    'profile': profile ?? const <String, Object?>{},
    'role': '${profile?['role'] ?? (signedIn ? 'user' : (guest ? 'guest' : ''))}',
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

  /// Confirms the signed-in user's [password] (a recent sign-in, which
  /// changing the password and deleting the account need). Fails with
  /// `wrong-password` when it isn't theirs.
  Future<void> reauthenticate(String password);

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
  Future<void> reauthenticate(String password) => Future.error(_failure);

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
  Future<AppUser> signUp({required String email, required String password, String displayName = ''}) async {
    final e = email.trim();
    if (!e.contains('@')) throw const AuthFailure('That email address is not valid.', code: 'invalid-email');
    if (accounts.containsKey(e)) {
      throw const AuthFailure('An account already exists for that email.', code: 'email-already-in-use');
    }
    if (password.length < 6) throw const AuthFailure('Password must be at least 6 characters.', code: 'weak-password');
    // A guest's account keeps the guest's uid (and so its data).
    final guest = _user != null && _user!.isGuest ? _user!.uid : null;
    final user = AppUser(uid: guest ?? 'user${++_ids}', email: e, displayName: displayName, providers: const ['password']);
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
    if (_user?.isGuest ?? false) {
      _set(null);
      return;
    }
    accounts.remove(_signedIn().email);
    _set(null);
  }

  @override
  Future<void> reauthenticate(String password) async {
    final u = _signedIn();
    if (accounts[u.email]?.$1 != password) {
      throw const AuthFailure('Wrong email or password.', code: 'wrong-password');
    }
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

/// What the signed-in user of [users] matches in an `audience` list, for
/// [BackendCloudDatabase.audience]: everyone, the user, the role in their
/// profile ([AuthProfiles], `user` without one, as the database's rules
/// read it) and, when not anonymous, signed-in users. [changes] fires when
/// the user or their role changes (give it to
/// [BackendCloudDatabase.userChanges]), so live audience queries follow
/// both.
class AuthAudience {
  AuthAudience({required this.users, required this.currentUser, required this.profile});

  /// The user, on every change ([AuthService.userChanges]).
  final Stream<AppUser?> users;
  final AppUser? Function() currentUser;

  /// The profile of the user with this uid, now and on every change.
  final Stream<Map<String, Object?>?> Function(String uid) profile;

  /// The role a user without a profile role has.
  static const defaultRole = 'user';

  String? _uid;
  String _role = defaultRole;
  StreamSubscription<AppUser?>? _users;
  StreamSubscription<Map<String, Object?>?>? _profile;
  late final StreamController<void> _changes = StreamController<void>.broadcast(
    onListen: _start,
    onCancel: _stop,
  );

  /// Fires when the user or their role changes.
  Stream<void> get changes => _changes.stream;

  /// The role read from the current user's profile.
  String get role => currentUser()?.uid == _uid ? _role : defaultRole;

  /// The entries of an `audience` list the current user matches.
  List<String> call() {
    final user = currentUser();
    if (user == null || user.uid.isEmpty) return const [];
    return DataRules.audienceOf(user.uid, role: user.isAnonymous ? defaultRole : role, signedIn: !user.isAnonymous);
  }

  void _start() {
    _users = users.listen(_onUser, onError: (Object error, StackTrace stack) {
      if (!_changes.isClosed) _changes.addError(error, stack);
    });
  }

  void _onUser(AppUser? user) {
    final uid = user == null || user.isAnonymous ? null : user.uid;
    if (uid != _uid) {
      _profile?.cancel();
      _profile = null;
      _uid = uid;
      _role = defaultRole;
      if (uid != null) {
        _profile = profile(uid).listen((p) {
          final role = '${p?['role'] ?? ''}'.trim();
          final next = role.isEmpty ? defaultRole : role;
          if (next == _role) return;
          _role = next;
          if (!_changes.isClosed) _changes.add(null);
        }, onError: (Object _) {});
      }
    }
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<void> _stop() async {
    await _profile?.cancel();
    await _users?.cancel();
    _profile = null;
    _users = null;
  }
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
