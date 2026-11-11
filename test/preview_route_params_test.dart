import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('design canvas values read sample route params', () {
    final ScopedValues values = ScopedValues.preview(
      variables: const {},
      routeParams: const {'title': 'Log black tank dump?', 'danger': true},
    );
    expect(
      PropertyValueDelegate.getVariableValueFromPath<String>(
        r'${route.title}',
        scopedValues: values,
      ),
      'Log black tank dump?',
    );
    expect(
      PropertyValueDelegate.getVariableValueFromPath<String>(
        r'${= upper(route.title)}',
        scopedValues: values,
      ),
      'LOG BLACK TANK DUMP?',
    );
    expect(
      PropertyValueDelegate.getVariableValueFromPath<bool>(
        r'${route.danger}',
        scopedValues: values,
      ),
      isTrue,
    );
  });

  test('computed variables read the sample route params', () {
    final Map<String, VariableData> resolved = ComputedVariables.resolveAll(
      {
        'versionParam': VariableData(
          id: 'v1',
          name: 'versionParam',
          formula: "replace(route.version, 'v', '')",
        ),
      },
      routeParams: const {'version': 'v2.12.0'},
    );
    expect(resolved['versionParam']!.value, '2.12.0');
  });

  testWidgets('RouteParamsScope gives route params to ScopedValues.of', (
    tester,
  ) async {
    late ScopedValues values;
    await tester.pumpWidget(
      RouteParamsScope(
        params: const {'version': '2.12.0'},
        child: Builder(
          builder: (context) {
            values = ScopedValues.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(
      PropertyValueDelegate.getVariableValueFromPath<String>(
        r'${route.version}',
        scopedValues: values,
      ),
      '2.12.0',
    );
  });

  test('a list row keeps the route params of its canvas', () {
    final previous = VariablePreview.scopeResolver;
    addTearDown(() => VariablePreview.scopeResolver = previous);
    VariablePreview.scopeResolver = (_) => ScopedValues.preview(
      variables: const {},
      routeParams: const {'version': '2.12.0'},
      indexedItem: IndexedItem(0, 'a'),
    );
    final ScopedValues? row = VariablePreview.scopeOf(
      null,
      item: IndexedItem(1, 'b'),
    );
    expect(row!.routeParams, {'version': '2.12.0'});
    expect(row.indexedItem!.item, 'b');
  });
}
