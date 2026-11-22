// A theme that says `"mode": "dark"` opens dark in a session's view, whatever
// the device's setting; `"light"` stays light on a dark device; with no mode
// the view follows the device.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<String> _shown(WidgetTester tester, Map<String, Object?> theme, {Brightness device = Brightness.light, DesignSystem? designSystem}) async {
  final session = UiSession(theme: ThemeTokens.fromJson(theme), designSystem: designSystem);
  addTearDown(session.dispose);
  await tester.pumpWidget(MediaQuery(
    data: MediaQueryData(size: const Size(480, 600), platformBrightness: device),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Align(alignment: Alignment.topLeft, child: SizedBox(width: 480, height: 600, child: CodelesslyView(session: session))),
    ),
  ));
  final result = await session.applyNotation(Stream.value('Column\n  Text#mode "{theme.isDark ? \'dark\' : \'light\'} {theme.surface}"\n'));
  expect(result.errors, isEmpty, reason: '${result.errors}');
  await tester.pumpAndSettle();
  final texts = <String>[];
  void visit(RenderObject o) {
    if (o is RenderParagraph) texts.add(o.text.toPlainText());
    o.visitChildren(visit);
  }

  visit(tester.renderObject(find.byType(CodelesslyView)));
  return texts.join(' ');
}

void main() {
  const colors = {
    'surface': '#FFFFFFFF',
    'onSurface': '#FF111111',
    'dark': {'surface': '#FF0B0B0B', 'onSurface': '#FFFFFFFF'},
  };

  testWidgets('mode dark: the dark colors on a light device', (tester) async {
    expect(await _shown(tester, {...colors, 'mode': 'dark'}), contains('dark #FF0B0B0B'));
  });

  testWidgets('mode light: the light colors on a dark device', (tester) async {
    expect(await _shown(tester, {...colors, 'mode': 'light'}, device: Brightness.dark), contains('light #FFFFFFFF'));
  });

  testWidgets('no mode: the device\'s', (tester) async {
    expect(await _shown(tester, colors), contains('light #FFFFFFFF'));
    expect(await _shown(tester, colors, device: Brightness.dark), contains('dark #FF0B0B0B'));
  });

  testWidgets('a site\'s mode over a design system: the design system\'s dark side', (tester) async {
    final ds = DesignSystem(
      manifest: DesignSystemManifest.fromJson({
        'schema': 3,
        'id': 'acme',
        'name': 'Acme',
        'theme': {
          'surface': '#FFFFFFFF',
          'onSurface': '#FF18181B',
          'dark': {'surface': '#FF141417', 'onSurface': '#FFF4F4F5'},
        },
      }),
      components: ComponentLibrary(const {}),
    );
    expect(await _shown(tester, {'mode': 'dark'}, designSystem: ds), contains('dark #FF141417'));
  });
}
