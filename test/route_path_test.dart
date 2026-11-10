import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// `${route.path}`: the URL path a screen was opened at, so a not-found
// screen can show the path it was given.

/// The scoped values of a screen a Codelessly router shows at [location],
/// or of a screen pushed with [arguments] on a plain navigator when
/// [location] is null.
Future<ScopedValues> scopeIn(
  WidgetTester tester, {
  String? location,
  Map<String, dynamic> params = const {},
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
    MaterialApp(
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        settings: RouteSettings(arguments: arguments),
        builder: (_) => location == null
            ? probe()
            : CodelesslyRouteScope(
                layoutId: 'pass',
                location: location,
                params: params,
                fromLink: true,
                child: probe(),
              ),
      ),
    ),
  );
  return ScopedValues.of(captured);
}

void main() {
  testWidgets('A screen reads the URL path it is shown at', (tester) async {
    final ScopedValues values = await scopeIn(
      tester,
      location: '/pass/zz999?from=x',
      params: {'from': 'x'},
    );
    expect(values.routeParams['path'], '/pass/zz999');
    expect(values.routeParams['from'], 'x');
    expect(
      PropertyValueDelegate.substituteVariables(
        r'No pass at ${route.path}',
        scopedValues: values,
        nullSubstitutionMode: NullSubstitutionMode.emptyString,
      ),
      'No pass at /pass/zz999',
    );
  });

  testWidgets('The first screen is at /', (tester) async {
    final ScopedValues values = await scopeIn(tester, location: '/');
    expect(values.routeParams['path'], '/');
  });

  testWidgets('A param named path wins over the URL path', (tester) async {
    final ScopedValues values = await scopeIn(
      tester,
      location: '/pass/zz999',
      params: {'path': 'given'},
    );
    expect(values.routeParams['path'], 'given');
  });

  testWidgets('A screen outside a router has no path', (tester) async {
    final ScopedValues values = await scopeIn(
      tester,
      arguments: <String, dynamic>{'id': 'a'},
    );
    expect(values.routeParams, {'id': 'a'});
    expect(ScopedValues.empty().routeParams, isEmpty);
  });
}
