import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('screen follows a layout that switches at 700 and 1200', () {
    const Size phablet = Size(650, 900);
    expect(screenVariableValue(phablet)['breakpoint'], 'tablet');
    final Map<String, dynamic> own = screenVariableValue(
      phablet,
      tabletMinWidth: 700,
      desktopMinWidth: 1200,
    );
    expect(own['breakpoint'], 'mobile');
    expect(own['isMobile'], isTrue);
    expect(
      screenVariableValue(const Size(1100, 900), tabletMinWidth: 700, desktopMinWidth: 1200)['isTablet'],
      isTrue,
    );
  });

  testWidgets('nodes inside a responsive layout read its widths', (tester) async {
    (double?, double?)? seen;
    await tester.pumpWidget(
      ResponsiveWidthsScope(
        tabletMinWidth: 700,
        desktopMinWidth: 1200,
        child: Builder(
          builder: (context) {
            seen = ScopedValues.of(context).breakpointWidths;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(seen, (700.0, 1200.0));
  });
}
