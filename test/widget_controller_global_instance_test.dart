import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a controller uses the unconfigured global instance', () {
    // A host that sets up the global instance before creating its
    // controller expects the controller to use it, not a private copy.
    expect(Codelessly.instance.config, isNull);
    final controller = CodelesslyWidgetController(
      config: CodelesslyConfig(authToken: '', slug: 'demo'),
    );
    expect(controller.createdIntrinsicCodelessly, isFalse);
    expect(controller.effectiveCodelessly, same(Codelessly.instance));
  });
}
