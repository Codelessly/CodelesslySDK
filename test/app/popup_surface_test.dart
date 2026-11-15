// A dialog's or popover's screen takes the corners and shadow the theme
// gives what floats (`radii.popup`, `shadows.popup`); a theme that names
// none (SSUI) leaves the screen as it draws itself.
import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_sdk/src/app/navigator_ui.dart' show popupSurface;
import 'package:codelessly_sdk/src/render/control_theme.dart' show CodelesslyThemeTokens;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Widget> _wrapped(WidgetTester tester, api.ThemeTokens tokens, Brightness brightness) async {
  late Widget out;
  const content = SizedBox(width: 100, height: 60);
  await tester.pumpWidget(Theme(
    data: ThemeData(extensions: [CodelesslyThemeTokens(tokens, brightness)]),
    child: Builder(builder: (context) {
      out = popupSurface(context, content);
      return Directionality(textDirection: TextDirection.ltr, child: out);
    }),
  ));
  return out;
}

void main() {
  final cards = api.ThemeTokens.fromJson({
    'radii': {'popup': 20},
    'shadows': {
      'popup': [{'type': 'dropShadow', 'color': '#24000000', 'offset': [0, 16], 'blurRadius': 40}],
    },
    'dark': {
      'shadows': {
        'popup': [{'type': 'dropShadow', 'color': '#80000000', 'offset': [0, 16], 'blurRadius': 40}],
      },
    },
  });

  testWidgets('a theme with radii.popup rounds and shadows the screen, with its dark shadow in dark mode', (tester) async {
    final light = await _wrapped(tester, cards, Brightness.light);
    expect(light, isA<DecoratedBox>());
    final deco = (light as DecoratedBox).decoration as BoxDecoration;
    expect(deco.borderRadius, BorderRadius.circular(20));
    expect(deco.boxShadow!.single.color, const Color(0x24000000));
    expect((light.child! as ClipRRect).borderRadius, BorderRadius.circular(20));
    final dark = await _wrapped(tester, cards, Brightness.dark);
    expect(((dark as DecoratedBox).decoration as BoxDecoration).boxShadow!.single.color, const Color(0x80000000));
  });

  testWidgets('a theme without one leaves the screen as it is', (tester) async {
    expect(await _wrapped(tester, api.ThemeTokens.fromJson({'radii': {'dialog': 12}}), Brightness.light), isA<SizedBox>());
  });
}
