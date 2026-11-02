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

  test('A link to no screen opens the Not found screen with its path', () {
    final m = model();
    final nf = layoutOf('nf-layout', [
      canvas('nf', 'nfBody')..name = 'Not found',
      body('nfBody', 'nf', []),
    ]);
    // Without a Not found screen the link stays as it was.
    expect(Codelessly.resolveLinkIn(m, const CodelesslyRoute('nowhere')).canvasId, 'nowhere');
    m.layouts[nf.id] = nf;
    final CodelesslyRoute route = Codelessly.resolveLinkIn(m, const CodelesslyRoute('nowhere', {'q': '1'}));
    expect(route.canvasId, 'nf');
    expect(route.params, {'q': '1', 'path': '/nowhere'});
    // Known screens, by id or by name, are left alone.
    expect(Codelessly.resolveLinkIn(m, const CodelesslyRoute('form')).canvasId, 'form');
    expect(Codelessly.resolveLinkIn(m, const CodelesslyRoute('record-form')).canvasId, 'record-form');
  });
}
