import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Map<String, dynamic>> routeIn(
  WidgetTester tester, {
  Object? arguments,
}) async {
  late Map<String, dynamic> route;
  await tester.pumpWidget(
    MaterialApp(
      onGenerateRoute: (settings) => MaterialPageRoute(
        settings: RouteSettings(arguments: arguments),
        builder: (context) {
          route = ScopedValues.of(context).routeParams;
          return const SizedBox();
        },
      ),
    ),
  );
  return route;
}

void main() {
  tearDown(() => urlQueryParameters = () => const {});

  testWidgets('route holds the page URL query parameters', (tester) async {
    urlQueryParameters = () => {'date': '2026-10-22', 'tab': 'fleet'};
    expect(await routeIn(tester), {'date': '2026-10-22', 'tab': 'fleet'});
  });

  testWidgets('navigation params win over the URL query', (tester) async {
    urlQueryParameters = () => {'date': '2026-10-22', 'tab': 'fleet'};
    expect(await routeIn(tester, arguments: {'tab': 'service'}), {
      'date': '2026-10-22',
      'tab': 'service',
    });
  });

  testWidgets('a formula reads the date or falls back', (tester) async {
    urlQueryParameters = () => {'date': '2026-10-22'};
    late Object? value;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            value = PropertyValueDelegate.getVariableValueFromPath<String>(
              r"${= coalesce(route.date, 'none')}",
              scopedValues: ScopedValues.of(context),
            );
            return const SizedBox();
          },
        ),
      ),
    );
    expect(value, '2026-10-22');
  });
}
