import 'package:codelessly_sdk/src/functions/app_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile fields give the role from the profile', () {
    expect(AppAuth.profileFields(null), {'profile': {}, 'role': ''});
    expect(AppAuth.profileFields(null, signedIn: true)['role'], 'user');
    expect(
      AppAuth.profileFields({'role': 'admin', 'bio': 'Hi'}, signedIn: true),
      {
        'profile': {'role': 'admin', 'bio': 'Hi'},
        'role': 'admin',
      },
    );
  });

  test('signed out, the auth variable has no providers', () {
    expect(AppAuth.userToMap(null)['providers'], isEmpty);
    expect(AppAuth.userToMap(null)['isSignedIn'], isFalse);
  });
}
