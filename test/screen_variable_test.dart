import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String text(String expression, Size size) =>
      PropertyValueDelegate.substituteVariables(
        expression,
        scopedValues: ScopedValues.preview(variables: {}, screenSize: size),
        nullSubstitutionMode: NullSubstitutionMode.emptyString,
      );

  group('screen variable', () {
    test('names the breakpoint for the width', () {
      expect(text(r'${screen.breakpoint}', const Size(390, 844)), 'mobile');
      expect(text(r'${screen.breakpoint}', const Size(834, 1112)), 'tablet');
      expect(text(r'${screen.breakpoint}', const Size(1440, 900)), 'desktop');
    });

    test('exposes size and orientation', () {
      expect(text(r'${screen.width}', const Size(390, 844)), '390.0');
      expect(text(r'${screen.isLandscape}', const Size(1440, 900)), 'true');
      expect(text(r'${screen.isMobile}', const Size(1440, 900)), 'false');
    });

    test('works in formulas', () {
      expect(
        text(r'${= screen.isDesktop ? 3 : 1}', const Size(1440, 900)),
        '3',
      );
    });

    test('works in conditions', () {
      final expression = Expression(
        leftPart: VariablePart(valueString: r'${screen.isMobile}'),
        operator: ConditionOperation.equalsTo,
        rightPart: RawValuePart('true'),
      );
      expect(
        expression.evaluate(
          ScopedValues.preview(variables: {}, screenSize: const Size(390, 844)),
        ),
        isTrue,
      );
    });
  });

  group('findForWidth', () {
    final breakpoints = [
      Breakpoint(nodeId: 'desktop', lowerBound: 769),
      Breakpoint(nodeId: 'mobile', upperBound: 511),
      Breakpoint(nodeId: 'tablet', lowerBound: 512, upperBound: 768),
    ];

    test('picks the range the width is in', () {
      expect(breakpoints.findForWidth(390)?.nodeId, 'mobile');
      expect(breakpoints.findForWidth(600)?.nodeId, 'tablet');
      expect(breakpoints.findForWidth(1440)?.nodeId, 'desktop');
    });

    test('gives gaps between ranges to the narrower breakpoint', () {
      expect(breakpoints.findForWidth(511.5)?.nodeId, 'mobile');
      expect(breakpoints.findForWidth(768.5)?.nodeId, 'tablet');
    });

    test('is null only without breakpoints', () {
      expect(<Breakpoint>[].findForWidth(400), isNull);
    });
  });
}
