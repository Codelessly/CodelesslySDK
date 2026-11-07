// Firebase types are faked: the Firebase services run here without Firebase.
// Ported from SDK 8.x's auth_manager_test (now FirebaseProjectAuth).
// ignore_for_file: subtype_of_sealed_class
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_sdk_v2/codelessly_sdk.dart';
import 'package:codelessly_sdk_v2/firebase.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    String part(Object json) => base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
    return '${part({'alg': 'none'})}.${part(claims ?? {})}.signature';
  }
}

class _FakeUser extends Fake implements User {
  _FakeUser(this.result);

  final Future<IdTokenResult> Function() result;

  @override
  bool get isAnonymous => true;

  @override
  String get uid => 'u1';

  @override
  Future<IdTokenResult> getIdTokenResult([bool forceRefresh = false]) => result();
}

class _FakeAuth extends Fake implements FirebaseAuth {
  _FakeAuth(this.currentUser, this.changes);

  @override
  User? currentUser;

  final Stream<User?> changes;
  int anonymousSignIns = 0;

  @override
  Stream<User?> userChanges() => changes;

  @override
  Future<UserCredential> signInAnonymously() async {
    anonymousSignIns++;
    currentUser = _FakeUser(() async => _FakeIdTokenResult({}));
    return _FakeCredential();
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword({required String email, required String password}) async =>
      throw FirebaseAuthException(code: 'wrong-password');
}

class _FakeCredential extends Fake implements UserCredential {}

FirebaseProjectAuth projectAuth(FirebaseAuth auth, {http.Client? client, KeyValueCache? cache}) => FirebaseProjectAuth(
      config: const ProjectAuthConfig(authToken: 'token', functionsBaseUrl: 'https://f.dev'),
      auth: auth,
      cache: cache,
      client: client ?? MockClient((_) async => http.Response('', 500)),
      claimsPropagationTimeout: const Duration(milliseconds: 100),
      claimsPollInterval: const Duration(milliseconds: 10),
    );

http.Client granting({void Function(http.Request)? onRequest}) => MockClient((request) async {
      onRequest?.call(request);
      return http.Response(jsonEncode({'projectId': 'project', 'authToken': 'token'}), 200);
    });

void main() {
  group('project claims', () {
    final result = _FakeIdTokenResult({
      'project_ids': ['project'],
    });

    test('reads the claims', () {
      final auth = projectAuth(_FakeAuth(null, const Stream.empty()));
      expect(auth.hasProjectClaim(result, 'project'), isTrue);
      expect(auth.hasProjectClaim(result, 'other'), isFalse);
      expect(auth.hasProjectClaim(null, 'project'), isFalse);
    });

    test('decodes the token where the platform gives no claims', () {
      final auth = FirebaseProjectAuth(
        config: const ProjectAuthConfig(authToken: 't'),
        auth: _FakeAuth(null, const Stream.empty()),
        claimsFromToken: true,
      );
      expect(auth.hasProjectClaim(result, 'project'), isTrue);
    });
  });

  group('waiting for the claim', () {
    test('completes once the project claim arrives', () async {
      final changes = StreamController<User?>();
      addTearDown(changes.close);
      var claims = <String, dynamic>{};
      final user = _FakeUser(() async => _FakeIdTokenResult(claims));
      final auth = projectAuth(_FakeAuth(user, changes.stream));
      final done = auth.waitForClaim('project');
      await Future<void>.delayed(Duration.zero);
      claims = {
        'project_ids': ['project'],
      };
      changes.add(user);
      await expectLater(done, completes);
    });

    test('polls for the claim when no auth event follows it', () async {
      var calls = 0;
      final user = _FakeUser(() async => _FakeIdTokenResult(calls++ < 2
          ? {}
          : {
              'project_ids': ['project'],
            }));
      await expectLater(projectAuth(_FakeAuth(user, const Stream.empty())).waitForClaim('project'), completes);
    });

    test('verifies again when the claim was granted and then lost', () async {
      var verified = false;
      final client = MockClient((request) async {
        verified = request.url.path.endsWith('/api/verifyProjectAuthToken');
        return http.Response('', 500);
      });
      final user = _FakeUser(() async => _FakeIdTokenResult(verified
          ? {
              'project_ids': ['project'],
            }
          : {}));
      final auth = projectAuth(_FakeAuth(user, const Stream.empty()), client: client);
      await expectLater(auth.waitForClaim('project'), completes);
      expect(verified, isTrue);
    });

    test('times out when the claim never arrives', () async {
      final user = _FakeUser(() async => _FakeIdTokenResult({}));
      await expectLater(
        projectAuth(_FakeAuth(user, const Stream.empty())).waitForClaim('project'),
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
      final done = projectAuth(_FakeAuth(user, changes.stream)).waitForClaim('project');
      await Future<void>.delayed(Duration.zero);
      changes.add(user);
      await expectLater(done, throwsA(isA<FirebaseAuthException>()));
    });
  });

  group('authenticate', () {
    test('signs in anonymously, verifies the token and caches the access', () async {
      var claims = <String, dynamic>{};
      final fake = _FakeAuth(null, const Stream.empty());
      final cache = MemoryKeyValueCache();
      late http.Request sent;
      final auth = projectAuth(fake, cache: cache, client: granting(onRequest: (r) {
        sent = r;
        claims = {
          'project_ids': ['project'],
        };
      }));
      fake.currentUser = null;
      // The anonymous user sees the claim once the backend granted it.
      final access = await _authenticate(auth, fake, () => claims);
      expect(fake.anonymousSignIns, 0, reason: 'a user was set up by the test');
      expect(access.projectId, 'project');
      expect(jsonDecode(sent.body), {'token': 'token', 'slug': null, 'clientType': 'default_client'});
      expect(sent.headers['Authorization'], startsWith('Bearer '));
      expect(await cache.contains(FirebaseProjectAuth.cacheKey), isTrue);
      expect(auth.access, access);
      auth.dispose();
    });

    test('a refused token fails', () async {
      final fake = _FakeAuth(null, const Stream.empty());
      final auth = projectAuth(fake);
      await expectLater(auth.authenticate(), throwsStateError);
      expect(fake.anonymousSignIns, 1);
      expect(auth.access, isNull);
      auth.dispose();
    });

    test('a cached access for the same token is used at once', () async {
      final cache = MemoryKeyValueCache();
      await cache.write(FirebaseProjectAuth.cacheKey, const ProjectAccess(projectId: 'project', authToken: 'token').toJson());
      final user = _FakeUser(() async => _FakeIdTokenResult({
            'project_ids': ['project'],
          }));
      final auth = projectAuth(_FakeAuth(user, const Stream.empty()), cache: cache, client: granting());
      expect((await auth.authenticate()).projectId, 'project');
      expect(auth.hasCloudAccess, isTrue);
      auth.dispose();
    });
  });

  group('app auth', () {
    test('users and readable errors', () async {
      expect(authMessageFor(FirebaseAuthException(code: 'wrong-password')), 'Wrong email or password.');
      expect(authMessageFor(FirebaseAuthException(code: 'odd', message: 'Odd.')), 'Odd.');
      expect(appUserOf(null), isNull);
      final service = FirebaseAuthService(_FakeAuth(_FakeUser(() async => _FakeIdTokenResult({})), const Stream.empty()));
      await expectLater(
        service.signIn(email: 'a@b.c', password: 'x'),
        throwsA(isA<AuthFailure>().having((e) => e.code, 'code', 'wrong-password')),
      );
      await expectLater(service.updatePassword('secret'), throwsA(isA<AuthFailure>()), reason: 'anonymous is signed out');
    });
  });

  group('firestore', () {
    test('values convert both ways', () {
      final date = DateTime.utc(2026, 1, 2);
      expect(fromFirestore({'t': Timestamp.fromDate(date), 'b': Blob(Uint8List(2)), 'g': const GeoPoint(1, 2)}), {
        't': date,
        'b': Uint8List(2),
        'g': {'latitude': 1.0, 'longitude': 2.0},
      });
      expect(toFirestore(const FieldOp.increment(2)), FieldValue.increment(2));
      expect(toFirestore({'x': [FieldOp.delete]}), {'x': [FieldValue.delete()]});
      expect(toFirestore(Uint8List(1)), isA<Blob>());
      expect(firestoreRoot('p1', source: DataSource.preview), 'preview_data/p1');
      expect(describeCloudError(FirebaseException(plugin: 'x', code: 'failed-precondition', message: 'Needs index')),
          'Needs index (failed-precondition)');
      expect(isMissingIndexError(FirebaseException(plugin: 'x', code: 'failed-precondition')), isTrue);
    });

    test('queries apply as Firestore calls', () {
      final calls = <String>[];
      FirestoreDocumentBackend.applyQuery(
        _FakeQuery(calls),
        const CloudQuery(
          filters: [
            CloudWhereFilter('a', WhereOperator.equal, 1),
            CloudWhereFilter('b', WhereOperator.inArray, [1, 2]),
            CloudWhereFilter(cloudDocumentIdField, WhereOperator.greaterThan, 'x'),
          ],
          orderBy: [CloudOrderBy('a', descending: true)],
          limit: 5,
        ),
      );
      expect(calls, ['a == 1', 'b in [1, 2]', '${FieldPath.documentId} > x', 'orderBy a desc', 'limit 5']);
    });

    test('active entitlement grants', () {
      final (active, nearest) = activeGrants([
        ('pro', {'active': true, 'validUntil': 2000}),
        ('old', {'active': true, 'validUntil': 500}),
        ('off', {'active': false, 'validUntil': 3000}),
        ('max', {'active': true, 'validUntil': 1500}),
      ], 1000);
      expect(active, {'pro', 'max'});
      expect(nearest, 1500);
    });
  });
}

Future<ProjectAccess> _authenticate(FirebaseProjectAuth auth, _FakeAuth fake, Map<String, dynamic> Function() claims) {
  fake.currentUser = _FakeUser(() async => _FakeIdTokenResult(claims()));
  return auth.authenticate();
}

class _FakeQuery extends Fake implements Query<Map<String, dynamic>> {
  _FakeQuery(this.calls);

  final List<String> calls;

  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) {
    if (isEqualTo != null) calls.add('$field == $isEqualTo');
    if (whereIn != null) calls.add('$field in $whereIn');
    if (isGreaterThan != null) calls.add('$field > $isGreaterThan');
    return this;
  }

  @override
  Query<Map<String, dynamic>> orderBy(Object field, {bool descending = false}) {
    calls.add('orderBy $field${descending ? ' desc' : ''}');
    return this;
  }

  @override
  Query<Map<String, dynamic>> limit(int limit) {
    calls.add('limit $limit');
    return this;
  }
}
