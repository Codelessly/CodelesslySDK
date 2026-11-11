// A screen location is encoded once: raw characters escaped, a browser's
// escapes kept, so query values arrive decoded.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('raw characters are escaped and existing escapes kept', () {
    expect(encodeLocation('/journals?toast=Saved to Journal II.'), '/journals?toast=Saved%20to%20Journal%20II.');
    expect(encodeLocation('/journals?toast=Saved%20to%20Journal%20II.'), '/journals?toast=Saved%20to%20Journal%20II.');
    expect(encodeLocation('/a·b'), '/a%C2%B7b');
    expect(encodeLocation('/x?p=100%'), '/x?p=100%25', reason: 'a % that is no escape');
    expect(encodeLocation('/x?e=🙂'), '/x?e=%F0%9F%99%82');
    expect(encodeLocation("/x?a=1&b=(2)+3,4;5='6'"), "/x?a=1&b=(2)+3,4;5='6'");
  });

  test('query values arrive decoded whether the location came typed or from a browser', () {
    for (final l in ['/journals?mode=save&toast=Saved to Journal II.', '/journals?mode=save&toast=Saved%20to%20Journal%20II.']) {
      expect(Uri.parse(encodeLocation(l)).queryParameters['toast'], 'Saved to Journal II.');
    }
  });
}
