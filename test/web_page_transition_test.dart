import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a website switches pages at once by default', () {
    // The platform's transition (Android's zoom off Apple platforms) is none
    // on the web; a transition the action names is kept.
    expect(
      FunctionsRepository.webTransition(PageTransition.platform, isWeb: true),
      PageTransition.none,
    );
    expect(
      FunctionsRepository.webTransition(PageTransition.fade, isWeb: true),
      PageTransition.fade,
    );
    expect(
      FunctionsRepository.webTransition(PageTransition.platform, isWeb: false),
      PageTransition.platform,
    );
  });
}
