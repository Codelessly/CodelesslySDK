import 'dart:async';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// An icon bound through `iconName` draws a Material Symbol from its SVG,
/// loaded by name. Until it loads (a capture right after the editor
/// starts), or when it can't (offline), it showed nothing, while an icon
/// bound through `icon` draws Flutter's bundled glyph at once. The symbol
/// now shows the bundled glyph of its name meanwhile.
void main() {
  MaterialSymbol symbol(String name, MaterialSymbolStyle style) =>
      MaterialSymbol(
        codepoint: 0,
        fontFamily: 'MaterialSymbols',
        name: name,
        style: style,
      );

  test('a symbol stands in with Flutter\'s icon of its name and style', () {
    expect(
      materialSymbolFlutterCodepoint(
        symbol('expand_less', MaterialSymbolStyle.outlined),
      ),
      flutterIconsDataMap['expand_less_outlined'],
    );
    expect(
      materialSymbolFlutterCodepoint(
        symbol('expand_less', MaterialSymbolStyle.outlined),
        fill: 1,
      ),
      flutterIconsDataMap['expand_less'],
    );
    expect(
      materialSymbolFlutterCodepoint(
        symbol('expand_more', MaterialSymbolStyle.rounded),
      ),
      flutterIconsDataMap['expand_more_rounded'],
    );
    expect(
      materialSymbolFlutterCodepoint(
        symbol('expand_more', MaterialSymbolStyle.sharp),
        fill: 1,
      ),
      flutterIconsDataMap['expand_more_sharp'],
    );
    // Symbols Flutter doesn't ship, and Material Icons, have none.
    expect(
      materialSymbolFlutterCodepoint(
        symbol('no_such_symbol', MaterialSymbolStyle.outlined),
      ),
      isNull,
    );
    expect(
      materialSymbolFlutterCodepoint(
        const MaterialIcon(
          codepoint: 0,
          fontFamily: 'MaterialIcons',
          name: 'expand_less',
          style: MaterialIconStyle.filled,
        ),
      ),
      isNull,
    );
  });

  IconNode iconNode(Map<String, String> variables) => IconNode(
    id: 'chevron',
    name: 'Chevron',
    basicBoxLocal: NodeBox(0, 0, 24, 24),
    properties: IconProperties(
      icon: const MultiSourceIconModel(
        icon: MaterialIcon(
          codepoint: 0,
          fontFamily: 'MaterialIcons',
          name: 'help',
          style: MaterialIconStyle.filled,
        ),
        show: true,
        size: 24,
      ),
    ),
  )..variables.addAll(variables);

  ScopedValues scope(bool showPast) => ScopedValues.preview(
    variables: {
      'showPast': VariableData(
        id: 'v',
        name: 'showPast',
        value: showPast,
        type: VariableType.boolean,
      ),
    },
  );

  // The symbol's SVG arrives only when the test lets it.
  late Completer<http.Response> svg;
  setUp(() {
    svg = Completer<http.Response>();
    SvgIcon.httpClient = MockClient((_) => svg.future);
  });
  tearDown(() => SvgIcon.httpClient = null);

  for (final bool showPast in [false, true]) {
    final String name = showPast ? 'expand_less' : 'expand_more';
    testWidgets('an iconName bound to a formula draws $name at once', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: PassiveIconWidget(
              node: iconNode({
                'iconName': r"${= showPast ? 'expand_less' : 'expand_more'}",
              }),
              scopedValues: scope(showPast),
            ),
          ),
        ),
      );
      // The binding names the symbol; the node's own icon was filled, so
      // the symbol is filled and Flutter's plain icon stands in for it.
      final Icon icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon?.codePoint, flutterIconsDataMap[name]);
      expect(icon.size, 24);

      // The SVG replaces it once it loads.
      await tester.runAsync(() async {
        svg.complete(
          http.Response(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
            '<path d="M0 0h24v24H0z"/></svg>',
            200,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      expect(find.byType(Icon), findsNothing);
      expect(find.byType(SvgPicture), findsOneWidget);
    });
  }

  testWidgets('the same formula on `icon` draws the same glyph', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: PassiveIconWidget(
            node: iconNode({
              'icon': r"${= showPast ? 'expand_less' : 'expand_more'}",
            }),
            scopedValues: scope(false),
          ),
        ),
      ),
    );
    expect(
      tester.widget<Icon>(find.byType(Icon)).icon?.codePoint,
      flutterIconsDataMap['expand_more'],
    );
  });
}
