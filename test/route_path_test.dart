import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// `${route.path}`: the URL path a screen was opened at, so a not-found
// screen can show the path it was given.

Future<ScopedValues> scopeIn(
  WidgetTester tester,
  Codelessly codelessly, {
  Object? arguments,
}) async {
  late BuildContext captured;
  Widget probe() => Builder(
    builder: (context) {
      captured = context;
      return const SizedBox();
    },
  );
  await tester.pumpWidget(
    Provider<Codelessly?>.value(
      value: codelessly,
      child: MaterialApp(
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          settings: RouteSettings(arguments: arguments),
          builder: (_) => probe(),
        ),
      ),
    ),
  );
  return ScopedValues.of(captured);
}

void main() {
  testWidgets('The first screen reads the path of the link it was opened at', (
    tester,
  ) async {
    final Codelessly codelessly = Codelessly();
    codelessly.pendingRoute = CodelesslyRoute.tryParse('/pass/zz999?from=x');
    final ScopedValues values = await scopeIn(tester, codelessly);
    expect(values.routeParams['path'], '/pass/zz999');
    expect(
      PropertyValueDelegate.substituteVariables(
        r'No pass at ${route.path}',
        scopedValues: values,
        nullSubstitutionMode: NullSubstitutionMode.emptyString,
      ),
      'No pass at /pass/zz999',
    );
  });

  testWidgets('A param named path wins over the URL path', (tester) async {
    final Codelessly codelessly = Codelessly();
    codelessly.pendingRoute = CodelesslyRoute.tryParse('/pass/zz999');
    final ScopedValues values = await scopeIn(
      tester,
      codelessly,
      arguments: <String, dynamic>{'path': 'given'},
    );
    expect(values.routeParams['path'], 'given');
  });

  testWidgets('Without a link or published screens there is no path', (
    tester,
  ) async {
    final ScopedValues values = await scopeIn(tester, Codelessly());
    expect(values.routeParams.containsKey('path'), isFalse);
    expect(ScopedValues.empty().routeParams, isEmpty);
  });
}
