import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

/// Runs a step that needs a signed-in Firebase user, and when it fails,
/// runs it again once another user signs in.
///
/// A slug-loaded app authenticates in the background, starting with an
/// anonymous sign-in. That sign-in can be refused (too many accounts made
/// from one address, a network error), and nothing tried again: the app's
/// cloud database never opened, so every list stayed on its spinner even
/// after the user signed in with their own account. With this, the user's
/// sign-in runs the step again.
class SignInRetry {
  /// The auth whose sign-ins start a retry.
  final FirebaseAuth auth;

  /// The step. Returns true when it is done, false when it should run again
  /// on the next sign-in. A thrown error also runs it again.
  final Future<bool> Function() step;

  /// Called with an error [step] threw.
  final void Function(Object error, StackTrace stackTrace)? onError;

  StreamSubscription<User?>? _subscription;
  bool _disposed = false;

  /// Creates a [SignInRetry]. Call [run] to start it.
  SignInRetry({required this.auth, required this.step, this.onError});

  /// Whether a failed step is waiting for a sign-in to run again.
  bool get isWaiting => _subscription != null;

  /// Runs the step, and on failure waits for the next sign-in to run it
  /// again.
  Future<void> run() async {
    if (_disposed) return;
    _cancel();
    bool done;
    try {
      done = await step();
    } catch (error, stackTrace) {
      onError?.call(error, stackTrace);
      done = false;
    }
    if (done || _disposed) return;
    // The user signed in when the step failed would only fail again.
    final String? failedUid = auth.currentUser?.uid;
    _subscription = auth.authStateChanges().listen((User? user) {
      if (user == null || user.uid == failedUid) return;
      _cancel();
      run();
    });
  }

  void _cancel() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// Stops waiting for a sign-in.
  void dispose() {
    _disposed = true;
    _cancel();
  }
}
