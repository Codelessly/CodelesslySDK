import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('query status follows the snapshot', () {
    expect(
      queryStatusOf(isFetching: true, hasError: false, count: 0),
      kQueryStatusLoading,
    );
    expect(
      queryStatusOf(isFetching: false, hasError: true, count: 3),
      kQueryStatusError,
    );
    expect(
      queryStatusOf(isFetching: false, hasError: false, count: 0),
      kQueryStatusEmpty,
    );
    expect(
      queryStatusOf(isFetching: false, hasError: false, count: 2),
      kQueryStatusLoaded,
    );
  });
}
