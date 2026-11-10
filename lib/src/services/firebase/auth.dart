// App user accounts on Firebase Auth.
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../auth.dart';

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
class FirebaseAuthService implements AuthService {
  FirebaseAuthService(this.auth, {this.anonymousWhenSignedOut = true, bool? web}) : _web = web ?? kIsWeb;

  final FirebaseAuth auth;
  final bool anonymousWhenSignedOut;
  final bool _web;

  @override
  AppUser? get currentUser => appUserOf(auth.currentUser);

  @override
  Stream<AppUser?> get userChanges => auth.userChanges().map(appUserOf);

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
        return _reloaded();
      });

  @override
  Future<AppUser> signUp({required String email, required String password, String displayName = ''}) =>
      _run(() async {
        final credential = await auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
        if (displayName.isNotEmpty) await credential.user?.updateDisplayName(displayName);
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
        return _reloaded();
      });

  @override
  Future<void> signOut() => _run(() async {
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
        await _signedIn().delete();
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
        return _reloaded();
      });
}
