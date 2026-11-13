
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('what a screen reads about the user', () {
    test('signed out with no user, or with an anonymous one', () {
      for (final user in [null, const AppUser(uid: 'anon', isAnonymous: true)]) {
        final value = authValue(user);
        expect(value['isSignedIn'], false);
        expect(value['uid'], '');
        expect(value['role'], '');
        expect(value['profile'], isEmpty);
      }
    });

    test('a guest is not signed in but has an id, a profile and a role', () {
      const guest = AppUser(uid: 'g1', isAnonymous: true, isGuest: true);
      final value = authValue(guest, profile: {'favourites': ['a']});
      expect(value['isSignedIn'], false);
      expect(value['isGuest'], true);
      expect(value['uid'], 'g1');
      expect(value['role'], 'guest');
      expect(value['profile'], {'favourites': ['a']});
      expect(authValue(const AppUser(uid: 'anon', isAnonymous: true))['isGuest'], false);
      expect(AuthProfiles.hasProfile(guest), isTrue);
      expect(AuthProfiles.hasProfile(const AppUser(uid: 'anon', isAnonymous: true)), isFalse);
      expect(AuthProfiles.newProfile(guest)['role'], 'guest');
    });

    test('a signed-in user with their profile', () {
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

  group('accounts', () {
    test('a user signs up, out and in, and failures have readable messages', () async {
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

    test('a guest session ends on sign-out and is removed on delete', () async {
      final auth = MemoryAuthService();
      final guest = await auth.signInAsGuest();
      expect(guest.isGuest, isTrue);
      expect(await auth.signInAsGuest(), guest, reason: 'one guest session at a time');
      await auth.signOut();
      expect(auth.currentUser, isNull);
      await auth.signInAsGuest();
      await auth.deleteAccount();
      expect(auth.currentUser, isNull);
      await expectLater(const SignedOutAuthService().signInAsGuest(), throwsA(isA<AuthFailure>()));
      auth.dispose();
    });

    test('nobody is signed in to begin with', () async {
      const auth = SignedOutAuthService();
      expect(auth.currentUser, isNull);
      await expectLater(auth.signIn(email: 'a', password: 'b'), throwsA(isA<AuthFailure>()));
    });
  });

  group('profiles', () {
    test('a new user gets a profile with the default values, once', () async {
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

    test('a screen follows the user and their profile as they change', () async {
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
