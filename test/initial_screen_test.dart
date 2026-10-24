import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

import 'feedback_actions_test.dart' show body, canvas, layoutOf;

void main() {
  SDKPublishModel model() {
    final m = SDKPublishModel(
      projectId: 'project',
      owner: 'owner',
      teams: const {},
      users: const {},
      roles: const {},
      public: false,
    );
    for (final layout in [
      layoutOf('home-layout', [
        canvas('home', 'homeBody')..name = 'Crates',
        body('homeBody', 'home', []),
      ]),
      layoutOf('form-layout', [
        canvas('form', 'formBody')..name = 'Record form',
        body('formBody', 'form', []),
      ]),
    ]) {
      m.layouts[layout.id] = layout;
    }
    return m;
  }

  test('A screen is found by canvas id or by its name, loosely', () {
    final m = model();
    expect(CodelesslyWidget.layoutIdForScreen(m, 'form'), 'form-layout');
    expect(CodelesslyWidget.layoutIdForScreen(m, 'record-form'), 'form-layout');
    expect(
      CodelesslyWidget.layoutIdForScreen(m, 'Record%20Form'),
      'form-layout',
    );
    expect(CodelesslyWidget.layoutIdForScreen(m, 'CRATES'), 'home-layout');
  });

  test('No or unknown screen gives no layout, so the entry one is used', () {
    final m = model();
    expect(CodelesslyWidget.layoutIdForScreen(m, null), isNull);
    expect(CodelesslyWidget.layoutIdForScreen(m, ''), isNull);
    expect(CodelesslyWidget.layoutIdForScreen(m, 'ledger'), isNull);
  });
}
