import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a controller uses the unconfigured global instance', () {
    // A host sets the global instance's link before creating its
    // controller; a separate instance would never open it.
    expect(Codelessly.instance.config, isNull);
    Codelessly.instance.pendingRoute = const CodelesslyRoute('screen-b');
    final controller = CodelesslyWidgetController(
      config: CodelesslyConfig(authToken: '', slug: 'demo'),
    );
    expect(controller.createdIntrinsicCodelessly, isFalse);
    expect(controller.effectiveCodelessly, same(Codelessly.instance));
    expect(
      controller.effectiveCodelessly.pendingRoute?.canvasId,
      'screen-b',
    );
  });
}
