// Codelessly accounts (the per-project user store) against a fake store and a
// fake token session: lazy anonymous sessions, sign-up in place, sign-in,
// merge, restore, the record watch, the Supabase-shaped `codelessly.auth`
// and the `auth` value layouts read.
import 'dart:async';
import 'dart:convert';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/firebase.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../app/northstar_paywall_test.dart' show Backend, Store, bundle;

/// The `appAuth` function in memory: users, passwords, claims and the same answers
/// and error codes. A custom token is `ct:{uid}`; an ID token is `id:{uid}`.
class FakeAppAuthBackend implements AppAuthClient {
  FakeAppAuthBackend({this.projectId = 'p1'});

  final String projectId;
  final Map<String, Map<String, Object?>> users = {};
  final Map<String, String> emails = {};
  final Map<String, String> passwords = {};
  final Map<String, int> failures = {};
  final List<String> calls = [];
  var _ids = 0;

  Map<String, Object?> claimsOf(String uid) {
    final u = users[uid]!;
    return {'cl_p': projectId, 'cl_role': u['role'], 'cl_anon': u['isAnonymous'], 'cl_v': u['claimsVersion']};
  }

  Map<String, Object?> _newUser({bool anonymous = true}) {
    final uid = 'a.$projectId.${'${++_ids}'.padLeft(22, '0')}';
    return users[uid] = {
      'id': uid,
      'email': null,
      'emailVerified': false,
      'displayName': '',
      'role': 'user',
      'status': 'active',
      'isAnonymous': anonymous,
      'providers': <String>[],
      'createdAt': '2026-11-11T00:00:00.000Z',
      'claimsVersion': 0,
    };
  }

  Map<String, Object?> _answer(String uid, [Map<String, Object?> extra = const {}]) =>
      {'customToken': 'ct:$uid', 'user': {...users[uid]!}, ...extra};

  String? _uid(String? bearer) {
    if (bearer == null || !bearer.startsWith('id:')) return null;
    final uid = bearer.substring(3);
    return users[uid]?['status'] == 'active' ? uid : null;
  }

  Never _error(int status, String code, [String message = 'failed']) => throw AppAuthException(status, code, message);

  @override
  Future<Map<String, Object?>> send(String method, String path, {Map<String, Object?>? body, String? bearer}) async {
    calls.add('$method $path');
    final b = body ?? const {};
    if (path == 'resolve') {
      return b['token'] == 'tok' ? {'projectId': projectId, 'isTemplate': false, 'auth': {'allowSignUp': true}} : _error(404, 'project_not_found');
    }
    final route = path.substring(projectId.length + 1);
    switch ('$method $route') {
      case 'POST session/anonymous':
        return _answer(_newUser()['id'] as String, {'isNew': true});
      case 'POST signup':
        final email = '${b['email']}'.toLowerCase();
        if (emails.containsKey(email)) _error(409, 'email_exists');
        if ('${b['password']}'.length < 8) _error(422, 'weak_password', 'Password must be at least 8 characters.');
        final current = _uid(bearer);
        final user = current != null && users[current]!['isAnonymous'] == true ? users[current]! : _newUser();
        user
          ..['email'] = b['email']
          ..['displayName'] = b['displayName'] ?? ''
          ..['isAnonymous'] = false
          ..['providers'] = ['password']
          ..['claimsVersion'] = (user['claimsVersion'] as int) + (current != null ? 1 : 0);
        emails[email] = user['id'] as String;
        passwords[user['id'] as String] = '${b['password']}';
        return _answer(user['id'] as String, {'emailVerificationRequired': false});
      case 'POST token?grant_type=password':
        final uid = emails['${b['email']}'.toLowerCase()];
        if (uid == null) _error(400, 'invalid_credentials');
        if ((failures[uid] ?? 0) >= 5) _error(429, 'too_many_attempts');
        if (passwords[uid] != b['password']) {
          failures[uid] = (failures[uid] ?? 0) + 1;
          _error(400, 'invalid_credentials');
        }
        if (users[uid]!['status'] == 'disabled') _error(403, 'user_disabled');
        final current = _uid(bearer);
        return _answer(uid, {if (current != null && current != uid) 'mergedFrom': current});
      case 'GET user':
        final uid = _uid(bearer) ?? _error(401, 'session_invalid');
        return {'user': {...users[uid]!}};
      case 'PUT user':
        final uid = _uid(bearer) ?? _error(401, 'session_invalid');
        if (b['displayName'] != null) users[uid]!['displayName'] = b['displayName'];
        if (b['password'] != null) {
          if (b['currentPassword'] != passwords[uid]) _error(400, 'invalid_credentials');
          passwords[uid] = '${b['password']}';
          return _answer(uid);
        }
        return {'user': {...users[uid]!}};
      case 'POST logout':
        _uid(bearer) ?? _error(401, 'session_invalid');
        return const {};
      case 'DELETE user':
        final uid = _uid(bearer) ?? _error(401, 'session_invalid');
        users.remove(uid);
        return const {};
    }
    return _error(404, 'not_found');
  }
}

/// A Firebase Auth instance in memory: custom-token sign-in, ID tokens whose claims are
/// the store's (the Auth record), persisted between "runs" by sharing the instance.
class FakeTokenSession implements TokenSession {
  FakeTokenSession(this.backend);

  final FakeAppAuthBackend backend;
  String? _uid;
  Map<String, Object?> _claims = const {};
  int refreshes = 0;

  /// Claims of another project, for a session that isn't this store's.
  Map<String, Object?>? foreignClaims;

  @override
  String? get uid => _uid;

  @override
  Future<void> signInWithCustomToken(String customToken) async {
    _uid = customToken.substring(3);
    _claims = backend.claimsOf(_uid!);
  }

  @override
  Future<IdToken?> idToken({bool refresh = false}) async {
    if (_uid == null) return null;
    if (refresh) {
      refreshes++;
      if (backend.users.containsKey(_uid)) _claims = backend.claimsOf(_uid!);
    }
    return IdToken('id:$_uid', claims: foreignClaims ?? _claims);
  }

  @override
  Future<void> signOut() async {
    _uid = null;
    _claims = const {};
  }
}

void main() {
  late FakeAppAuthBackend store;
  late FakeTokenSession session;
  late StreamController<Map<String, Object?>?> record;

  CodelesslyAuthService service({bool watch = false, LocalStorage? storage}) => CodelesslyAuthService(
        projectId: 'p1',
        client: store,
        session: session,
        watchRecord: watch ? (_) => record.stream : null,
        storage: storage,
      );

  setUp(() {
    store = FakeAppAuthBackend();
    session = FakeTokenSession(store);
    record = StreamController.broadcast();
  });

  group('Codelessly accounts', () {
    test('no session until one is needed; then an anonymous one, made once', () async {
      final auth = service();
      await auth.ready;
      expect(auth.currentUser, isNull);
      expect(store.calls, isEmpty, reason: 'nothing is created at launch');
      final uids = await Future.wait([auth.ensureSession(), auth.ensureSession()]);
      expect(uids[0], uids[1]);
      expect(store.calls.where((c) => c.contains('anonymous')), hasLength(1));
      expect(auth.currentUser!.isAnonymous, isTrue);
      expect((await session.idToken())!.claims['cl_anon'], true);
      expect(authValue(auth.currentUser)['status'], 'anonymous');
      expect(authValue(auth.currentUser)['uid'], '', reason: 'anonymous users keep an empty uid');
      expect(authValue(auth.currentUser)['anonymousId'], uids[0]);
    });

    test('sign-up upgrades the anonymous user in place; sign-in and sign-out', () async {
      final auth = service();
      final events = <AuthState>[];
      auth.authStateChanges.listen(events.add);
      final anon = await auth.signInAsGuest();
      final user = await auth.signUpWith(email: 'ana@x.dev', password: 'correct horse', displayName: 'Ana');
      expect(user.uid, anon.uid);
      expect(user.isAnonymous, isFalse);
      expect(user.email, 'ana@x.dev');
      expect((await session.idToken())!.claims['cl_anon'], false);
      await auth.signOut();
      expect(auth.currentUser, isNull);
      expect(session.uid, isNull);
      await expectLater(
        auth.signIn(email: 'ana@x.dev', password: 'nope nope'),
        throwsA(isA<AuthFailure>()
            .having((e) => e.code, 'code', 'invalid_credentials')
            .having((e) => e.message, 'message', 'Wrong email or password.')),
      );
      expect((await auth.signIn(email: 'ana@x.dev', password: 'correct horse')).uid, anon.uid);
      await pumpEventQueue();
      expect(events.map((e) => e.event), [
        AuthChangeEvent.initialSession,
        AuthChangeEvent.signedIn,
        AuthChangeEvent.userUpdated,
        AuthChangeEvent.signedOut,
        AuthChangeEvent.signedIn,
      ]);
    });

    test('a guest session is the anonymous session, marked: same uid, shown, kept on sign-up', () async {
      final local = MemoryLocalStorage();
      final auth = service(storage: local);
      final lazy = await auth.ensureSession();
      expect(auth.currentUser!.isGuest, isFalse, reason: 'the session made on first use is not a guest');
      expect(authValue(auth.currentUser)['uid'], '');
      final events = <AuthState>[];
      auth.authStateChanges.listen(events.add);
      await pumpEventQueue();
      final guest = await auth.signInAsGuest();
      expect(guest.uid, lazy, reason: 'the anonymous session becomes the guest');
      expect(guest.isGuest, isTrue);
      expect(store.calls.where((c) => c.contains('anonymous')), hasLength(1));
      final value = authValue(auth.currentUser);
      expect([value['status'], value['isGuest'], value['isAnonymous'], value['uid'], value['role']],
          ['anonymous', true, true, lazy, 'guest']);
      expect(await auth.signInAsGuest(), guest, reason: 'one guest session at a time');
      final again = service(storage: local);
      await again.ready;
      expect(again.currentUser!.isGuest, isTrue, reason: 'the restored session is still the guest');
      final user = await auth.signUp(email: 'gi@x.dev', password: 'gi password');
      expect(user.uid, lazy);
      expect(user.isGuest, isFalse);
      await pumpEventQueue();
      expect(events.map((e) => e.event), [
        AuthChangeEvent.initialSession,
        AuthChangeEvent.userUpdated,
        AuthChangeEvent.userUpdated,
      ]);
      final next = await auth.signInAsGuest();
      expect(next.uid, isNot(lazy), reason: 'a signed-in user is signed out first');
      expect(next.isGuest, isTrue);
      await auth.deleteAccount();
      expect(auth.currentUser, isNull);
      expect(local.get(CodelesslyAuthService.guestKey), isNull);
    });

    test('the signInAnonymously auth action starts the guest session', () async {
      final auth = service();
      final scope = VariableScope(const [Variable(name: 'uid', value: '')]);
      final context = RuntimeActionContext(scope: scope, services: Services(auth: auth));
      final node = Node.fromJson({
        'type': 'box',
        'actions': [
          {
            'trigger': {'type': 'click'},
            'actions': [
              {'type': 'auth', 'operation': 'signInAnonymously'},
              {'type': 'setVariable', 'variable': 'uid', 'value': r'${result}'},
            ],
          },
        ],
      }, id: 'n')!;
      await const CodelesslyActions().run(node, 'click', context);
      expect(auth.currentUser!.isGuest, isTrue);
      expect(scope.read('uid'), auth.currentUser!.uid);
    });

    test('signing in from an anonymous session reports the merge', () async {
      final auth = service();
      await auth.signUp(email: 'bo@x.dev', password: 'bo password');
      await auth.signOut();
      final anon = await auth.signInAsGuest();
      final merged = auth.authStateChanges.firstWhere((s) => s.event == AuthChangeEvent.merged);
      final user = await auth.signIn(email: 'bo@x.dev', password: 'bo password');
      expect((await merged).mergedFrom, anon.uid);
      expect(user.uid, isNot(anon.uid));
    });

    test('the last session is restored; another project\'s is dropped', () async {
      await service().signUp(email: 'cy@x.dev', password: 'cy password', displayName: 'Cy');
      final again = service();
      final first = await again.authStateChanges.first;
      expect(first.event, AuthChangeEvent.initialSession);
      expect(first.user!.displayName, 'Cy');
      expect(again.restored, isTrue);

      session.foreignClaims = {'cl_p': 'p2'};
      final other = service();
      await other.ready;
      expect(other.currentUser, isNull);
      expect(session.uid, isNull);
    });

    test('the record watch: a role change refreshes the token; disabled signs out', () async {
      final auth = service(watch: true);
      final user = await auth.signUp(email: 'di@x.dev', password: 'di password');
      store.users[user.uid]!
        ..['role'] = 'admin'
        ..['claimsVersion'] = 5;
      record.add({'status': 'active', 'claimsVersion': 5, 'role': 'admin'});
      await pumpEventQueue();
      expect(session.refreshes, 1);
      expect(auth.currentUser!.role, 'admin');
      expect(authValue(auth.currentUser)['role'], 'admin');
      record.add({'status': 'active', 'claimsVersion': 5});
      await pumpEventQueue();
      expect(session.refreshes, 1, reason: 'the same version needs no refresh');
      record.add({'status': 'disabled', 'claimsVersion': 6});
      await pumpEventQueue();
      expect(auth.currentUser, isNull);
      expect(session.uid, isNull);
    });

    test('profile and password changes; what needs email is not available', () async {
      final auth = service();
      await auth.signUp(email: 'ed@x.dev', password: 'ed password');
      expect((await auth.updateUser(const UserAttributes(displayName: 'Ed'))).displayName, 'Ed');
      await expectLater(auth.updateUser(const UserAttributes(password: 'new password', currentPassword: 'wrong one')),
          throwsA(isA<AuthFailure>().having((e) => e.code, 'code', 'invalid_credentials')));
      await auth.updateUser(const UserAttributes(password: 'new password', currentPassword: 'ed password'));
      await auth.signOut();
      await auth.signIn(email: 'ed@x.dev', password: 'new password');
      for (final call in <Future<Object?> Function()>[
        () => auth.sendPasswordResetEmail('ed@x.dev'),
        () => auth.sendEmailVerification(),
        () => auth.signInWithProvider(AuthProviderKind.google),
        () => auth.updateUser(const UserAttributes(email: 'new@x.dev')),
      ]) {
        await expectLater(call(), throwsA(isA<AuthFailure>().having((e) => e.code, 'code', 'not_available')));
      }
      await auth.deleteAccount();
      expect(auth.currentUser, isNull);
    });

    test('cloud data and files make the session on first use', () async {
      final auth = service();
      final backend = SessionDocumentBackend(MemoryDocumentBackend(), auth.ensureSession);
      expect(auth.currentUser, isNull);
      await backend.get('notes', 'n1');
      expect(auth.currentUser!.isAnonymous, isTrue);
      final files = SessionFileStorage(MemoryFileStorage(), auth.ensureSession);
      await files.list('');
      expect(store.calls.where((c) => c.contains('anonymous')), hasLength(1));
    });

    test('the project token resolves without a Firebase sign-in, cached', () async {
      final cache = MemoryKeyValueCache();
      final resolver = AppAuthProjectResolver(client: store, authToken: 'tok', cache: cache);
      expect((await resolver.authenticate()).projectId, 'p1');
      expect(resolver.publicAuth['allowSignUp'], true);
      final again = AppAuthProjectResolver(client: store, authToken: 'tok', cache: cache);
      expect((await again.authenticate()).projectId, 'p1');
      await expectLater(AppAuthProjectResolver(client: store, authToken: 'bad').authenticate(), throwsStateError);
    });

    test('the HTTP client: paths, bearer, the store\'s errors', () async {
      late http.BaseRequest seen;
      final client = HttpAppAuthClient(
        baseUrl: 'https://f.dev/appAuth',
        client: MockClient((request) async {
          seen = request;
          if (request.url.path.endsWith('/token')) {
            return http.Response(
                jsonEncode({
                  'error': {'code': 'too_many_attempts', 'message': 'Wait', 'retryAfter': 60}
                }),
                429);
          }
          return http.Response(jsonEncode({'ok': true}), 200);
        }),
      );
      expect(await client.send('GET', 'p1/user', bearer: 'id:x'), {'ok': true});
      expect(seen.url.toString(), 'https://f.dev/appAuth/v1/p1/user');
      expect(seen.headers['Authorization'], 'Bearer id:x');
      await expectLater(
        client.send('POST', 'p1/token', body: const {}),
        throwsA(isA<AppAuthException>()
            .having((e) => e.status, 'status', 429)
            .having((e) => e.code, 'code', 'too_many_attempts')
            .having((e) => e.retryAfter, 'retryAfter', 60)),
      );
    });
  });

  group('codelessly.auth', () {
    test('Supabase-shaped over memory accounts: anonymous, sign-up in place, events', () async {
      final auth = CodelesslyAuth(MemoryAuthService());
      final events = <AuthChangeEvent>[];
      auth.onAuthStateChange.listen((s) => events.add(s.event));
      final anon = await auth.signInAnonymously();
      expect(anon.isGuest, isTrue);
      expect(auth.currentSession, isNotNull);
      final user = await auth.signUp(email: 'fi@x.dev', password: 'secret1', data: {'displayName': 'Fi', 'plan': 'free'});
      expect(user.uid, anon.uid);
      expect(user.displayName, 'Fi');
      expect((auth.service as MemoryAuthService).profiles[user.uid], {'plan': 'free'});
      await auth.updateUser(const UserAttributes(displayName: 'Fiona'));
      await auth.signOut(scope: SignOutScope.global);
      await pumpEventQueue();
      expect(events, [
        AuthChangeEvent.initialSession,
        AuthChangeEvent.signedIn,
        AuthChangeEvent.userUpdated,
        AuthChangeEvent.userUpdated,
        AuthChangeEvent.signedOut,
      ]);
    });

    test('over a service without sessions, the session operations fail readably', () async {
      final auth = CodelesslyAuth(const SignedOutAuthService());
      expect(auth.currentSession, isNull);
      await expectLater(auth.signInAnonymously(), throwsA(isA<AuthFailure>()));
      expect((await auth.onAuthStateChange.first).event, AuthChangeEvent.initialSession);
    });

    test('the instance\'s auth and the `auth` value layouts read', () async {
      final accounts = MemoryAuthService();
      final codelessly = Codelessly(config: CodelesslyConfig(slug: 'x', services: Services(auth: accounts)));
      addTearDown(codelessly.dispose);
      expect(codelessly.appVariables.read('auth.status'), 'signedOut');
      await pumpEventQueue();
      await codelessly.auth.signUp(email: 'gu@x.dev', password: 'secret1', data: {'displayName': 'Gu'});
      await pumpEventQueue();
      expect(codelessly.appVariables.read('auth.isSignedIn'), true);
      expect(codelessly.appVariables.read('auth.displayName'), 'Gu');
      expect(codelessly.appVariables.read('auth.role'), 'user');
      await codelessly.auth.signOut();
      await pumpEventQueue();
      expect(codelessly.appVariables.read('auth.status'), 'signedOut');
    });
  });

  group('Codelessly accounts in an app', () {
    test('`auth.status` is loading until the session is restored, from the one auth subscription', () async {
      await service().signUp(email: 'ev@x.dev', password: 'ev password', displayName: 'Ev');
      final auth = service();
      final codelessly = Codelessly(config: CodelesslyConfig(slug: 'x', services: Services(auth: auth)));
      addTearDown(codelessly.dispose);
      expect(codelessly.appVariables.read('auth.status'), 'loading');
      expect(codelessly.appVariables.read('auth.isSignedIn'), false);
      await auth.ready;
      await pumpEventQueue();
      expect(codelessly.appVariables.read('auth.status'), 'signedIn');
      expect(codelessly.appVariables.read('auth.displayName'), 'Ev');
      await codelessly.auth.signOut();
      await pumpEventQueue();
      expect(codelessly.appVariables.read('auth.status'), 'signedOut');
      final anonymous = await auth.ensureSession();
      await pumpEventQueue();
      expect(codelessly.appVariables.read('auth.status'), 'anonymous');
      expect(codelessly.appVariables.read('auth.isAnonymous'), true);
      expect(codelessly.appVariables.read('auth.uid'), '');
      await codelessly.auth.signInAnonymously();
      await pumpEventQueue();
      expect(codelessly.appVariables.read('auth.isGuest'), true);
      expect(codelessly.appVariables.read('auth.uid'), anonymous, reason: 'the guest is the same session');
      expect(codelessly.appVariables.read('auth.role'), 'guest');
    });

    test('a server paywall makes the session before its callables run, keeping the placement', () async {
      final auth = service();
      String? caller;
      final backend = _SessionBackend(() => caller = session.uid);
      final runtime = PaywallRuntime(backend: backend, purchases: Store.new, platform: 'ios');
      final codelessly = Codelessly(
        config: CodelesslyConfig(
            services: Services(auth: auth, paywalls: runtime, analytics: const NoAnalytics())),
        loader: MemoryPublishLoader(bundle()),
      );
      addTearDown(() {
        codelessly.dispose();
        runtime.dispose();
      });
      await auth.ready;
      expect(auth.currentUser, isNull);
      final resolved = await codelessly.paywall.resolve('onboarding');
      expect(resolved, isNotNull, reason: 'the new session does not discard the placement');
      expect(caller, isNotNull);
      expect(caller, auth.currentUser!.uid);
      expect(auth.currentUser!.isAnonymous, isTrue);
      await pumpEventQueue();
      expect(codelessly.appVariables.read('auth.status'), 'anonymous');
      expect(store.calls.where((c) => c.contains('anonymous')), hasLength(1));
      expect(await codelessly.paywall.resolve('onboarding'), isNotNull);
      expect(store.calls.where((c) => c.contains('anonymous')), hasLength(1));
    });
  });

  group('the backend', () {
    test('codeless-editor where it has an app for the platform, else codeless-app', () {
      expect(CodelesslyEditorFirebaseOptions.web.projectId, 'codeless-editor');
      expect(CodelesslyBackend.forPlatform(TargetPlatform.android, isWeb: true), CodelesslyBackend.editor);
      expect(CodelesslyBackend.editor.userStore, isTrue);
      expect(CodelesslyBackend.editor.appAuthUrl, 'https://us-central1-codeless-editor.cloudfunctions.net/appAuth');
      // Not registered in codeless-editor yet (the owner's step): the old backend.
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS, TargetPlatform.macOS, TargetPlatform.windows]) {
        expect(CodelesslyBackend.forPlatform(platform), CodelesslyBackend.app, reason: platform.name);
      }
      expect(CodelesslyBackend.app.options(TargetPlatform.android)!.projectId, 'codeless-app');
    });
  });
}

/// A paywall server that sees who calls it.
class _SessionBackend extends Backend {
  _SessionBackend(this.onCall);

  final void Function() onCall;

  @override
  Future<ResolvedPaywall> resolve(String placement,
      {required String locale, required String platform, required String appVersion}) {
    onCall();
    return super.resolve(placement, locale: locale, platform: platform, appVersion: appVersion);
  }
}
