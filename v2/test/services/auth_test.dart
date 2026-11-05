
import 'package:codelessly_sdk_v2/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Ported from SDK 8.x's auth_default_test and app_auth_profile_test.
  group('the auth value', () {
    test('reads as signed out with no user, or an anonymous one', () {
      for (final user in [null, const AppUser(uid: 'anon', isAnonymous: true)]) {
        final value = authValue(user);
        expect(value['isSignedIn'], false);
        expect(value['uid'], '');
        expect(value['role'], '');
        expect(value['profile'], isEmpty);
      }
    });

    test('describes a signed-in user and their profile', () {
      const user = AppUser(uid: 'u1', email: 'ana@x.dev', providers: ['password'], emailVerified: true);
      final value = authValue(user);
      expect(value['initial'], 'A');
      expect(value['role'], 'user', reason: 'a signed-in user without a role is a user');
      expect(value['providers'], ['password']);
      final admin = authValue(const AppUser(uid: 'u1', displayName: 'élan'), profile: {'role': 'admin'});
      expect(admin['initial'], 'É');
      expect(admin['role'], 'admin');
    });
  });

  group('memory accounts', () {
    test('sign up, out and in, with readable failures', () async {
      final auth = MemoryAuthService();
      final user = await auth.signUp(email: 'ana@x.dev', password: 'secret1', displayName: 'Ana');
      expect(auth.currentUser, user);
      await expectLater(
        auth.signUp(email: 'ana@x.dev', password: 'secret1'),
        throwsA(isA<AuthFailure>().having((e) => e.message, 'message', 'An account already exists for that email.')),
      );
      await auth.signOut();
      expect(auth.currentUser, isNull);
      await expectLater(auth.signIn(email: 'ana@x.dev', password: 'nope'), throwsA(isA<AuthFailure>()));
      await auth.signIn(email: 'ana@x.dev', password: 'secret1');
      await auth.updateProfile(displayName: 'Ana B');
      expect(auth.currentUser!.displayName, 'Ana B');
      await auth.deleteAccount();
      await expectLater(auth.signIn(email: 'ana@x.dev', password: 'secret1'), throwsA(isA<AuthFailure>()));
      auth.dispose();
    });

    test('signed out by default', () async {
      const auth = SignedOutAuthService();
      expect(auth.currentUser, isNull);
      await expectLater(auth.signIn(email: 'a', password: 'b'), throwsA(isA<AuthFailure>()));
    });
  });

  group('profiles', () {
    test('a new user gets a profile with the schema defaults, once', () async {
      final db = BackendCloudDatabase(
        backend: MemoryDocumentBackend(),
        rules: DataRules.fromJson({
          'schemas': {
            'users': {
              'fields': [
                {'name': 'plan', 'defaultValue': 'free'},
                {'name': 'bio', 'required': true},
              ],
            },
          },
        }),
      );
      const user = AppUser(uid: 'u1', email: 'ana@x.dev');
      await AuthProfiles.ensure(db, user);
      final profile = (await db.getDocument('users', 'u1'))!;
      expect(profile['plan'], 'free');
      expect(profile['role'], 'user');
      expect(profile['email'], 'ana@x.dev');
      await db.updateDocument('users', 'u1', {'role': 'admin'});
      await AuthProfiles.ensure(db, user);
      expect((await db.getDocument('users', 'u1'))!['role'], 'admin');
      await AuthProfiles.ensure(db, const AppUser(uid: 'anon', isAnonymous: true));
      expect(await db.getDocument('users', 'anon'), isNull);
      db.dispose();
    });

    test('Services.watchAuth follows the user and their profile', () async {
      final auth = MemoryAuthService();
      final services = Services(auth: auth, analytics: RecordingAnalytics());
      final values = <Map<String, Object?>>[];
      final sub = services.watchAuth().listen(values.add);
      await pumpEventQueue();
      final user = await auth.signUp(email: 'ana@x.dev', password: 'secret1');
      await pumpEventQueue();
      await services.cloud.addDocument('users', {'role': 'editor'}, id: user.uid);
      await pumpEventQueue();
      await sub.cancel();
      expect(values.first['isSignedIn'], false);
      expect(values.last['isSignedIn'], true);
      expect(values.last['role'], 'editor');
      auth.dispose();
    });
  });
}
