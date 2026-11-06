import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A computed variable written as its value, `${= ...}`, or with a separate
/// [formula] expression when the text isn't wrapped.
VariableData _computed(String name, String formula) => formula.startsWith(r'${')
    ? VariableData(id: name, name: name, type: VariableType.text, value: formula)
    : VariableData(
        id: name,
        name: name,
        type: VariableType.decimal,
        formula: formula,
      );

void main() {
  final VariableData planS = _computed(
    'planS',
    r'${= screen.isMobile ? 0.5 : screen.width / 1000}',
  );

  group('computed variables read predefined values', () {
    test('resolveAll reads the canvas screen', () {
      final Map<String, VariableData> mobile = ComputedVariables.resolveAll({
        'planS': planS,
      }, screenSize: const Size(390, 844));
      expect(mobile['planS']!.value, '0.5');
      final Map<String, VariableData> desktop = ComputedVariables.resolveAll({
        'planS': planS,
      }, screenSize: const Size(1440, 900));
      expect(double.parse(desktop['planS']!.value), closeTo(1.44, 1e-9));
    });

    test('resolveAll reads the screen through other computed variables', () {
      final VariableData wide = _computed('wide', '!screen.isMobile');
      final VariableData cols = _computed('cols', r'${= wide ? 3 : 1}');
      final Map<String, VariableData> resolved = ComputedVariables.resolveAll(
        {'wide': wide, 'cols': cols},
        screenSize: const Size(1440, 900),
      );
      expect(resolved['cols']!.value, '3');
    });

    test('a computed variable read lazily sees the scope screen', () {
      Object? read(Size size) =>
          PropertyValueDelegate.getVariableValueFromPath<Object>(
            'planS',
            scopedValues: ScopedValues.preview(
              variables: {'planS': planS},
              screenSize: size,
            ),
          );
      expect(read(const Size(390, 844)), 0.5);
      // Not cached across screens: it reads a predefined value.
      expect(read(const Size(1200, 800)), closeTo(1.2, 1e-9));
    });

    testWidgets('at runtime it follows the MediaQuery size', (tester) async {
      final List<Object?> seen = [];
      Widget app(Size size) => MediaQuery(
        data: MediaQueryData(size: size),
        child: Builder(
          builder: (context) {
            seen.add(
              PropertyValueDelegate.getVariableValueFromPath<Object>(
                'planS',
                scopedValues: ScopedValues.of(
                  context,
                  variablesOverrides: [planS],
                ),
              ),
            );
            return const SizedBox();
          },
        ),
      );
      await tester.pumpWidget(app(const Size(390, 844)));
      await tester.pumpWidget(app(const Size(1440, 900)));
      expect(seen.first, 0.5);
      expect(seen.last, closeTo(1.44, 1e-9));
    });
  });

  group('predefined overrides', () {
    test('drag shows the previewed keys over its idle value', () {
      final ScopedValues values = ScopedValues.preview(
        variables: {},
        predefinedOverrides: {
          'drag': {'active': true, 'over': 'lamp-2', 'data': {'id': 'l1'}},
        },
      );
      Object? read(String path) =>
          PropertyValueDelegate.getVariableValueFromPath<Object>(
            path,
            scopedValues: values,
          );
      expect(read('drag.over'), 'lamp-2');
      expect(read('drag.active'), isTrue);
      expect(read('drag.data.id'), 'l1');
      // Keys not overridden keep their idle values.
      expect(read('drag.accepted'), isFalse);
      expect(read(r"${= drag.over == 'lamp-2'}"), isTrue);
    });

    test('computed variables see the overrides too', () {
      final Map<String, VariableData> resolved = ComputedVariables.resolveAll(
        {'hot': _computed('hot', r"${= drag.over == 'lamp-2' ? 1 : 0}")},
        predefinedOverrides: {
          'drag': {'over': 'lamp-2'},
        },
      );
      expect(resolved['hot']!.value, '1');
    });

    test('screen overrides merge with the screen size', () {
      final ScopedValues values = ScopedValues.preview(
        variables: {},
        screenSize: const Size(390, 844),
        predefinedOverrides: {
          'screen': {'isDark': true},
        },
      );
      Object? read(String path) =>
          PropertyValueDelegate.getVariableValueFromPath<Object>(
            path,
            scopedValues: values,
          );
      expect(read('screen.isDark'), isTrue);
      expect(read('screen.width'), 390.0);
    });

    test('a row scope keeps the overrides', () {
      final ScopedValues values = ScopedValues.forItem(
        ScopedValues.preview(
          variables: {},
          predefinedOverrides: {
            'drag': {'over': 'x'},
          },
        ),
        IndexedItem(0, 'a'),
      );
      expect(
        PropertyValueDelegate.getVariableValueFromPath<Object>(
          'drag.over',
          scopedValues: values,
        ),
        'x',
      );
    });
  });
}
