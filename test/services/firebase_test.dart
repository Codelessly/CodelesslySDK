import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/firebase.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../app/support.dart';
import 'publish_loading_test.dart' show FakeProjectAuth, writePublish;

// Firebase types are faked: the Firebase services run here without Firebase.
// ignore_for_file: subtype_of_sealed_class

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

Future<ProjectAccess> _authenticate(FirebaseProjectAuth auth, _FakeAuth fake, Map<String, dynamic> Function() claims) {
  fake.currentUser = _FakeUser(() async => _FakeIdTokenResult(claims()));
  return auth.authenticate();
}

// A Codelessly instance from a project token alone: Codelessly's Firebase
// options per platform, the secondary Firebase app, and codelesslyWithToken
// reading a publish (Firestore and the project's access faked).

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

void main() {
  group('waiting for access to a project', () {
    test('completes once access is granted', () async {
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

    test('times out when access is never granted', () async {
      final user = _FakeUser(() async => _FakeIdTokenResult({}));
      await expectLater(
        projectAuth(_FakeAuth(user, const Stream.empty())).waitForClaim('project'),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('fails instead of hanging when the token cannot be refreshed', () async {
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

  group('authenticating with a project token', () {
    test('signs in anonymously, verifies the token and remembers the access', () async {
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

    test('waits for the restored user instead of creating a new anonymous one', () async {
      // On the web the persisted user arrives just after start.
      final restored = StreamController<User?>();
      final fake = _FakeAuth(null, restored.stream);
      final auth = FirebaseProjectAuth(
        config: const ProjectAuthConfig(authToken: 'token'),
        auth: fake,
        client: granting(),
        claimsPropagationTimeout: const Duration(milliseconds: 50),
        claimsPollInterval: const Duration(milliseconds: 10),
      );
      final pending = auth.authenticate().then<Object?>((a) => a, onError: (Object e) => e);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      fake.currentUser = _FakeUser(() async => _FakeIdTokenResult({}));
      restored.add(fake.currentUser);
      await pending;
      expect(fake.anonymousSignIns, 0, reason: 'the restored user is kept: a guest keeps their session');
      await restored.close();
      auth.dispose();
    });

    test('fails when the token is refused', () async {
      final fake = _FakeAuth(null, const Stream.empty());
      final auth = projectAuth(fake);
      await expectLater(auth.authenticate(), throwsStateError);
      expect(fake.anonymousSignIns, 1);
      expect(auth.access, isNull);
      auth.dispose();
    });

  });

  group('an app\'s own users', () {
    test('sign up and in, and failures have readable messages', () async {
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

  group('Firestore values', () {
    test('convert both ways', () {
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

    test('a user\'s active purchases are read from their grants', () {
      final (active, nearest) = activeGrants([
        ('pro', {'active': true, 'validUntil': 2000}),
        ('old', {'active': true, 'validUntil': 500}),
        ('off', {'active': false, 'validUntil': 3000}),
        ('max', {'active': true, 'validUntil': 1500}),
      ], 1000);
      expect(active, {'pro', 'max'});
      expect(nearest, 1500);
    });
  

    group('firestore', () {

      test('a cloud query is sent to Firestore with its filters, sorting and limit', () {
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

    });
  
  });

  group('opening a project with a token', () {
    group('CodelesslyFirebaseOptions', () {

      test('on Linux, which has no Firebase, the error says what to do instead', () {
        expect(
          () => CodelesslyFirebaseOptions.forPlatform(TargetPlatform.linux),
          throwsA(isA<UnsupportedError>().having((e) => e.message, 'message', allOf(contains('slug'), contains('bundle')))),
        );
      });

    });

    group('codelesslyWithToken', () {
      final rigcheck = fixture('rigcheck');

      test('a token opens the project it names', () async {
        final db = FakeFirebaseFirestore();
        await writePublish(db, 'p1', rigcheck);
        final access = FakeProjectAuth(const ProjectAccess(projectId: 'p1', authToken: 'tok'));
        final codelessly = await codelesslyWithToken(
          'tok',
          firestore: db,
          projectAuth: access,
          fonts: const NoFontFetcher(),
          data: const {'user': 'Ada'},
        );
        addTearDown(codelessly.dispose);
        expect(codelessly.config.authToken, 'tok');
        expect(codelessly.loader, isA<FirestorePublishLoader>());
        expect(access.calls, 0, reason: 'nothing loads until the instance is initialized');

        await codelessly.initialize();
        expect(access.calls, 1);
        expect(codelessly.status, isA<CLoaded>());
        expect(codelessly.publishModel!.layouts.keys, rigcheck.model.layouts.keys);
        final layout = await codelessly.loadLayout(rigcheck.model.entryLayoutId!);
        expect(layout.id, rigcheck.model.entryLayoutId);
        expect(codelessly.data.read('data.user'), 'Ada');
      });

      test('with cloud services the app authenticates first and keeps its data under the project', () async {
        final db = FakeFirebaseFirestore();
        await writePublish(db, 'p1', rigcheck);
        final access = FakeProjectAuth(const ProjectAccess(projectId: 'p1', authToken: 'tok'));
        final codelessly = await codelesslyWithToken('tok', cloudServices: true, firestore: db, projectAuth: access);
        addTearDown(codelessly.dispose);
        expect(access.calls, 1);
        final services = codelessly.services as Services;
        final cloud = services.cloud as BackendCloudDatabase;
        expect(cloud.root, 'data/p1');
        expect(cloud.backend, isA<FirestoreDocumentBackend>());
        // No Firebase Auth or Storage given: those keep their defaults.
        expect(services.auth, isA<SignedOutAuthService>());
        expect(services.files, isA<MemoryFileStorage>());
      });

      test('services the app passes in win over the cloud ones', () async {
        final mine = Services();
        final access = FakeProjectAuth(const ProjectAccess(projectId: 'p1'));
        final codelessly = await codelesslyWithToken(
          'tok',
          config: CodelesslyConfig(services: mine),
          cloudServices: true,
          firestore: FakeFirebaseFirestore(),
          projectAuth: access,
        );
        addTearDown(codelessly.dispose);
        expect(identical(codelessly.services, mine), isTrue);
        expect(access.calls, 0);
      });

      test('an empty token is refused', () {
        expect(codelesslyWithToken(''), throwsArgumentError);
      });
    });
  });

}
