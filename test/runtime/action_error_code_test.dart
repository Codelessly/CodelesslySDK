import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/runtime/actions/action_error.dart';
import 'package:flutter_test/flutter_test.dart';

class _Coded implements Exception {
  final String code = 'permission-denied';
}

void main() {
  test('the actionError event carries the failure\'s stable code', () {
    Map error(Object e) => actionErrorEvent(ActionFailed('auth', e, nodeId: 'n'))['error'] as Map;
    expect(error(const AuthFailure('Wrong email or password.', code: 'wrong-password'))['code'], 'wrong-password');
    expect(error(const AuthFailure('Wrong email or password.', code: 'wrong-password'))['message'], 'Wrong email or password.');
    expect(error(const CodedFailure('file-too-large', 'a.png is larger than 5 MB'))['code'], 'file-too-large');
    expect(error(_Coded())['code'], 'permission-denied', reason: 'Firebase exceptions have a code too');
    expect(error(StateError('x'))['code'], '');
    expect(error(StateError('x'))['action'], 'auth');
  });
}
