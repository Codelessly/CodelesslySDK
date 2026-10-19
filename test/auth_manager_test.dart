import 'dart:async';
import 'dart:convert';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FakeIdTokenResult extends Fake implements IdTokenResult {
  _FakeIdTokenResult(this.claims) : token = _jwt(claims);

  @override
  final Map<String, dynamic>? claims;

  @override
  final String? token;

  static String _jwt(Map<String, dynamic>? claims) {
    String part(Object json) =>
        base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
    return '${part({'alg': 'none'})}.${part(claims ?? {})}.signature';
  }
}

class _FakeUser extends Fake implements User {
  _FakeUser(this.result);

  final Future<IdTokenResult> Function() result;

  @override
  Future<IdTokenResult> getIdTokenResult([bool forceRefresh = false]) =>
      result();
}

class _FakeAuth extends Fake implements FirebaseAuth {
  _FakeAuth(this.currentUser, this.changes);

  @override
  final User? currentUser;

  final Stream<User?> changes;

  @override
  Stream<User?> userChanges() => changes;
}

class _NoCache extends Fake implements CacheManager {}

AuthManager authManager(FirebaseAuth auth, {http.Client? client}) =>
    AuthManager(
      config: CodelesslyConfig(authToken: 'token'),
      cacheManager: _NoCache(),
      firebaseAuth: auth,
      client: client ?? MockClient((_) async => http.Response('', 500)),
      claimsPropagationTimeout: const Duration(milliseconds: 100),
      claimsPollInterval: const Duration(milliseconds: 10),
    );

AuthData authData() => AuthData(
  authToken: 'token',
  projectId: 'project',
  timestamp: DateTime(2026),
  owner: 'owner',
  teams: const {},
  users: const {},
  roles: const {},
);

void main() {
  group('checkClaimsForProject', () {
    final result = _FakeIdTokenResult({
      'project_ids': ['project'],
    });

    test('reads the claims', () {
      final manager = authManager(_FakeAuth(null, const Stream.empty()));
      expect(manager.checkClaimsForProject(result, 'project'), isTrue);
      expect(manager.checkClaimsForProject(result, 'other'), isFalse);
    });

    test('decodes the token on Windows', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final manager = authManager(_FakeAuth(null, const Stream.empty()));
      expect(manager.checkClaimsForProject(result, 'project'), isTrue);
    });
  });

  group('postAuthSuccess', () {
    test('completes once the project claim arrives', () async {
      final changes = StreamController<User?>();
      addTearDown(changes.close);
      var claims = <String, dynamic>{};
      final user = _FakeUser(() async => _FakeIdTokenResult(claims));
      final manager = authManager(_FakeAuth(user, changes.stream));

      final done = manager.postAuthSuccess(authData());
      await Future<void>.delayed(Duration.zero);
      claims = {
        'project_ids': ['project'],
      };
      changes.add(user);
      await expectLater(done, completes);
    });

    test('polls for the claim when no auth event follows it', () async {
      var calls = 0;
      final user = _FakeUser(
        () async => _FakeIdTokenResult(
          calls++ < 2
              ? {}
              : {
                  'project_ids': ['project'],
                },
        ),
      );
      final manager = authManager(_FakeAuth(user, const Stream.empty()));
      await expectLater(manager.postAuthSuccess(authData()), completes);
    });

    test('verifies again when the claim was granted and then lost', () async {
      var verified = false;
      final client = MockClient((request) async {
        verified = request.url.path.endsWith('/api/verifyProjectAuthToken');
        return http.Response('', 500);
      });
      final user = _FakeUser(
        () async => _FakeIdTokenResult(
          verified
              ? {
                  'project_ids': ['project'],
                }
              : {},
        ),
      );
      final manager = authManager(
        _FakeAuth(user, const Stream.empty()),
        client: client,
      );
      await expectLater(manager.postAuthSuccess(authData()), completes);
      expect(verified, isTrue);
    });

    test('times out when the claim never arrives', () async {
      final user = _FakeUser(() async => _FakeIdTokenResult({}));
      final manager = authManager(_FakeAuth(user, const Stream.empty()));
      await expectLater(
        manager.postAuthSuccess(authData()),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('fails instead of hanging when refreshing the token fails', () async {
      final changes = StreamController<User?>();
      addTearDown(changes.close);
      var calls = 0;
      final user = _FakeUser(() async {
        if (calls++ == 0) return _FakeIdTokenResult({});
        throw FirebaseAuthException(code: 'network-request-failed');
      });
      final manager = authManager(_FakeAuth(user, changes.stream));

      final done = manager.postAuthSuccess(authData());
      await Future<void>.delayed(Duration.zero);
      changes.add(user);
      await expectLater(done, throwsA(isA<FirebaseAuthException>()));
    });
  });
}
