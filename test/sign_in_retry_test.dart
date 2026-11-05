import 'dart:async';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeUser extends Fake implements User {
  _FakeUser(this.uid);

  @override
  final String uid;
}

class _FakeAuth extends Fake implements FirebaseAuth {
  final StreamController<User?> changes = StreamController.broadcast();

  @override
  User? currentUser;

  @override
  Stream<User?> authStateChanges() => changes.stream;

  Future<void> signIn(String? uid) async {
    currentUser = uid == null ? null : _FakeUser(uid);
    changes.add(currentUser);
    await pumpEventQueue();
  }
}

/// A slug-loaded app's background authentication starts with an anonymous
/// sign-in that can be refused; the app then waited forever. It now runs
/// again when the user signs in with their own account.
void main() {
  test('a failed step runs again when a user signs in', () async {
    final auth = _FakeAuth();
    final List<String> errors = [];
    int runs = 0;
    final retry = SignInRetry(
      auth: auth,
      step: () async {
        runs++;
        if (auth.currentUser == null) {
          throw StateError('anonymous sign-in refused');
        }
        return true;
      },
      onError: (error, _) => errors.add('$error'),
    );
    await retry.run();
    expect(runs, 1);
    expect(errors, ['Bad state: anonymous sign-in refused']);
    expect(retry.isWaiting, isTrue);

    await auth.signIn('user-1');
    expect(runs, 2);
    expect(retry.isWaiting, isFalse);

    // Done: later sign-ins don't run it again.
    await auth.signIn('user-2');
    expect(runs, 2);
  });

  test('a step that reports not done waits for another user', () async {
    final auth = _FakeAuth()..currentUser = _FakeUser('anon');
    int runs = 0;
    final retry = SignInRetry(
      auth: auth,
      step: () async => ++runs > 1 && auth.currentUser?.uid == 'user-1',
    );
    await retry.run();
    expect(runs, 1);
    // The same user signing in again (a token refresh) would only fail again.
    await auth.signIn('anon');
    expect(runs, 1);
    await auth.signIn(null);
    expect(runs, 1);
    await auth.signIn('user-1');
    expect(runs, 2);
    expect(retry.isWaiting, isFalse);
  });

  test('a successful step does not wait', () async {
    final auth = _FakeAuth();
    int runs = 0;
    final retry = SignInRetry(
      auth: auth,
      step: () async {
        runs++;
        return true;
      },
    );
    await retry.run();
    await auth.signIn('user-1');
    expect(runs, 1);
    expect(retry.isWaiting, isFalse);
  });

  test('dispose stops waiting', () async {
    final auth = _FakeAuth();
    int runs = 0;
    final retry = SignInRetry(
      auth: auth,
      step: () async {
        runs++;
        return false;
      },
    );
    await retry.run();
    retry.dispose();
    await auth.signIn('user-1');
    expect(runs, 1);
    expect(retry.isWaiting, isFalse);
  });
}
