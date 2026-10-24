import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

/// Without a Codelessly instance (the editor's design canvas, previews) the
/// `auth` variable reads as signed out, so signed-in-only nodes hide.
void main() {
  test('auth reads as signed out with no app user', () {
    final ScopedValues scope = ScopedValues.preview(variables: {});
    String eval(String text) => PropertyValueDelegate.substituteVariables(
      text,
      scopedValues: scope,
      nullSubstitutionMode: NullSubstitutionMode.emptyString,
    );
    expect(eval(r'${auth.isSignedIn}'), 'false');
    expect(eval(r'${= !auth.isSignedIn}'), 'true');
    expect(eval(r'${auth.uid}'), '');
  });
}
