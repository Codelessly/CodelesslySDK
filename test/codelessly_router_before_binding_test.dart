import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/tidepool.dart';

/// An app's `main` builds the router's config as runApp's argument,
/// `runApp(MaterialApp.router(routerConfig: router.config()))`, so config()
/// runs before runApp has created the binding. It read the start address
/// through `WidgetsBinding.instance`, a null check in release builds: every
/// site (site.codelessly.com, the local site viewer) threw "Null check
/// operator used on a null value" and never got past its loading layout.
///
/// Only plain `test`s here: a `testWidgets` would create the test binding
/// first and hide the bug.
void main() {
  test('config() works before any binding exists', () {
    final Codelessly codelessly = Codelessly(
      config: CodelesslyConfig(authToken: 'token'),
      publishDataManager: TestDataManager(tidepoolModel())
        ..status = CStatus.loaded(),
    )..status = CStatus.loaded();
    final CodelesslyRouter router = CodelesslyRouter(
      controller: CodelesslyWidgetController(codelessly: codelessly),
      historyGo: (_) {},
      historyState: () => null,
    );

    final RouterConfig<Object?> config = router.config();

    expect(config.routeInformationProvider, isNotNull);
    expect(config.routeInformationProvider!.value.uri.path, '/');
    expect(config.routeInformationParser, isNotNull);
    // The binding it made is the one runApp goes on to use.
    expect(WidgetsBinding.instance, isA<WidgetsFlutterBinding>());
  });
}
