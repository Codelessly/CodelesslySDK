import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Missing values in formulas: `text` gives '' and `number` gives null, and
/// `route.<name>` is the route parameter only.
void main() {
  Future<Object? Function(String)> scopeWithRoute(
    WidgetTester tester,
    Map<String, dynamic> params,
  ) async {
    late ScopedValues scope;
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (_) => MaterialPageRoute(
          settings: RouteSettings(arguments: params),
          builder: (context) {
            scope = ScopedValues.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    return (String formula) =>
        PropertyValueDelegate.evaluateFormula(formula, scopedValues: scope);
  }

  testWidgets('an absent route parameter is missing, not a count', (
    tester,
  ) async {
    final eval = await scopeWithRoute(tester, {'nights': '2'});
    expect(eval('route.length'), isNull);
    expect(eval("text(route.length) != ''"), isFalse);
    expect(eval("text(route.length) == ''"), isTrue);
    expect(eval('length(route)'), 1);
    expect(eval('route.nights'), '2');
  });

  testWidgets('a present route parameter named length is read', (tester) async {
    final eval = await scopeWithRoute(tester, {'length': '34'});
    expect(eval("text(route.length) != ''"), isTrue);
    expect(eval('number(route.length) + 1'), 35);
  });

  group('null', () {
    final ScopedValues scope = ScopedValues.preview(variables: {});
    Object? eval(String formula) =>
        PropertyValueDelegate.evaluateFormula(formula, scopedValues: scope);

    test("text(null) is ''", () {
      expect(eval('text(null)'), '');
      expect(eval('text(data.missing)'), '');
    });

    test('number(null) and number of blank text are null', () {
      expect(eval('number(null)'), isNull);
      expect(eval("number('')"), isNull);
      expect(eval("number('  ')"), isNull);
      expect(eval('number(null) == null'), isTrue);
      // Still 0 in arithmetic.
      expect(eval('number(null) + 1'), 1);
      expect(eval("number('4.5') + 1"), 5.5);
      expect(eval('number(0)'), 0);
    });
  });
}
