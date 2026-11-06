import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

/// API responses are stored in variables named `api` + a capitalised name;
/// ordinary words that start with "api" are ordinary variables.
void main() {
  test('only api + a capitalised name is an API variable', () {
    expect(isApiVariableName('apiGetUsers'), isTrue);
    expect(isApiVariableName(apiNameToVariableName('get hives')), isTrue);
    expect(isApiVariableName('api'), isTrue);
    expect(isApiVariableName('api_2'), isTrue);
    expect(isApiVariableName('apiary'), isFalse);
    expect(isApiVariableName('apiece'), isFalse);
    expect(isApiVariableName('rapid'), isFalse);
  });
}
