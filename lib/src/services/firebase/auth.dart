// App user accounts on Firebase Auth.
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../auth.dart';
import '../storage.dart';

/// [user] as an [AppUser].
AppUser? appUserOf(User? user) => user == null
    ? null
    : AppUser(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName ?? '',
        photoUrl: user.photoURL ?? '',
        emailVerified: user.emailVerified,
        isAnonymous: user.isAnonymous,
        providers: [for (final info in user.providerData) info.providerId],
      );

/// A readable message for a Firebase Auth [error].
String authMessageFor(Object error) {
  if (error is AuthFailure) return error.message;
  if (error is StateError) return error.message;
  if (error is! FirebaseAuthException) return '$error';
  return switch (error.code) {
    'invalid-credential' || 'wrong-password' || 'user-not-found' || 'INVALID_LOGIN_CREDENTIALS' =>
      'Wrong email or password.',
    'email-already-in-use' => 'An account already exists for that email.',
    'weak-password' => 'Password must be at least 6 characters.',
    'invalid-email' => 'That email address is not valid.',
    'missing-password' => 'Enter your password.',
    'user-disabled' => 'This account has been disabled.',
    'too-many-requests' => 'Too many attempts. Try again later.',
    'network-request-failed' => 'Network error. Check your connection.',
    'requires-recent-login' => 'Sign in again, then try this again.',
    _ => error.message ?? error.code,
  };
}

/// [AuthService] on Firebase Auth. With [anonymousWhenSignedOut] (the SDK
/// reads published data as an anonymous user), signing out or deleting the
/// account signs in anonymously again; anonymous users read as signed out.
///
/// A guest session ([signInAsGuest]) is the anonymous user, marked as a
/// guest by its uid in [storage] (so it survives reloads, as the anonymous
/// user itself does).
class FirebaseAuthService implements AuthService {
  FirebaseAuthService(this.auth, {this.anonymousWhenSignedOut = true, bool? web, this.storage})
      : _web = web ?? kIsWeb;

  final FirebaseAuth auth;
  final bool anonymousWhenSignedOut;
  final bool _web;

  /// Where the guest session's uid is kept (memory when null).
  final LocalStorage? storage;

  static const guestKey = 'auth.guestUid';
  String? _memoryGuest;
  final _guestChanges = StreamController<void>.broadcast();

  String? get _guestUid {
    final stored = storage?.get(guestKey);
    return stored is String && stored.isNotEmpty ? stored : _memoryGuest;
  }

  Future<void> _setGuest(String? uid) async {
    _memoryGuest = uid;
    final s = storage;
    if (s != null) uid == null ? await s.remove(guestKey) : await s.put(guestKey, uid);
    _guestChanges.add(null);
  }

  AppUser? _map(User? user) {
    final u = appUserOf(user);
    if (u == null || !u.isAnonymous || u.uid != _guestUid) return u;
    return u.asGuest();
  }

  bool get _isGuest => _map(auth.currentUser)?.isGuest ?? false;

  @override
  AppUser? get currentUser => _map(auth.currentUser);

  @override
  Stream<AppUser?> get userChanges {
    late StreamController<AppUser?> controller;
    StreamSubscription<User?>? users;
    StreamSubscription<void>? guests;
    controller = StreamController(
      onListen: () {
        users = auth.userChanges().listen((u) => controller.add(_map(u)), onError: controller.addError);
        guests = _guestChanges.stream.listen((_) => controller.add(currentUser));
      },
      onCancel: () async {
        await guests?.cancel();
        await users?.cancel();
      },
    );
    return controller.stream;
  }

  @override
  Future<AppUser> signInAsGuest() => _run(() async {
        var user = auth.currentUser;
        if (user != null && !user.isAnonymous) {
          await auth.signOut();
          user = null;
        }
        user ??= (await auth.signInAnonymously()).user;
        if (user == null) throw const AuthFailure('Could not start a guest session.');
        await _setGuest(user.uid);
        return currentUser!;
      });

  Future<T> _run<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(authMessageFor(e), code: e.code);
    }
  }

  User _signedIn() {
    final user = auth.currentUser;
    if (user == null || user.isAnonymous) throw const AuthFailure('Sign in first.');
    return user;
  }

  Future<AppUser> _reloaded() async {
    await auth.currentUser?.reload();
    return appUserOf(auth.currentUser)!;
  }

  @override
  Future<AppUser> signIn({required String email, required String password}) => _run(() async {
        await auth.signInWithEmailAndPassword(email: email.trim(), password: password);
        await _setGuest(null);
        return _reloaded();
      });

  @override
  Future<AppUser> signUp({required String email, required String password, String displayName = ''}) =>
      _run(() async {
        final guest = auth.currentUser;
        // A guest becomes a real account with the same uid, keeping its data.
        final credential = guest != null && _isGuest
            ? await guest.linkWithCredential(EmailAuthProvider.credential(email: email.trim(), password: password))
            : await auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
        if (displayName.isNotEmpty) await credential.user?.updateDisplayName(displayName);
        await _setGuest(null);
        return _reloaded();
      });

  @override
  Future<AppUser> signInWithProvider(AuthProviderKind provider) => _run(() async {
        final AuthProvider p = switch (provider) {
          AuthProviderKind.google => GoogleAuthProvider(),
          AuthProviderKind.apple => AppleAuthProvider()
            ..addScope('email')
            ..addScope('name'),
        };
        await (_web ? auth.signInWithPopup(p) : auth.signInWithProvider(p));
        await _setGuest(null);
        return _reloaded();
      });

  @override
  Future<void> signOut() => _run(() async {
        await _setGuest(null);
        await auth.signOut();
        if (anonymousWhenSignedOut) await auth.signInAnonymously();
      });

  @override
  Future<void> updateProfile({String? displayName, String? photoUrl}) => _run(() async {
        final user = _signedIn();
        if (displayName != null) await user.updateDisplayName(displayName);
        if (photoUrl != null) await user.updatePhotoURL(photoUrl);
        await user.reload();
      });

  @override
  Future<void> updatePassword(String password) => _run(() => _signedIn().updatePassword(password));

  @override
  Future<void> sendPasswordResetEmail(String email) => _run(() => auth.sendPasswordResetEmail(email: email.trim()));

  @override
  Future<void> sendEmailVerification() => _run(() => _signedIn().sendEmailVerification());

  @override
  Future<void> deleteAccount() => _run(() async {
        final user = auth.currentUser;
        if (user != null && _isGuest) {
          await _setGuest(null);
          await user.delete();
        } else {
          await _signedIn().delete();
        }
        if (anonymousWhenSignedOut) await auth.signInAnonymously();
      });

  @override
  Future<void> sendSignInLink(String email, {required String continueUrl}) => _run(() async {
        if (email.trim().isEmpty) throw const AuthFailure('Enter your email.');
        await auth.sendSignInLinkToEmail(
          email: email.trim(),
          actionCodeSettings: ActionCodeSettings(url: continueUrl, handleCodeInApp: true),
        );
      });

  @override
  bool isSignInLink(String link) => auth.isSignInWithEmailLink(link);

  @override
  Future<AppUser> signInWithLink(String email, String link) => _run(() async {
        if (email.trim().isEmpty) throw const AuthFailure('Enter the email the link was sent to.');
        await auth.signInWithEmailLink(email: email.trim(), emailLink: link);
        await _setGuest(null);
        return _reloaded();
      });
}
