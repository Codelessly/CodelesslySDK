// A confirm sheet in an app's own look: a gradient confirm button
// (`confirmGradientStart/Middle/End`), a flat cancel beside a glowing
// confirm (`cancelShadows`), and on a wide screen a sheet that floats above
// the bottom with every corner rounded (`sheetMargin`), as the Northstar
// reference's sign-out and discard sheets are.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'feedback_test.dart' show Host, v;

const _okKey = ValueKey('codelessly-confirm-ok');
const _cancelKey = ValueKey('codelessly-confirm-cancel');
const _sheetKey = ValueKey('Codelessly bottom sheet');

List<Json> _signOut() => [
      {
        'type': 'confirm',
        'title': 'Sign out?',
        'message': 'Your favourites stay safe in your account.',
        'confirmLabel': 'Sign out',
        'presentation': 'bottomSheet',
        'look': {
          'sheetWidth': 520,
          'sheetMargin': 24,
          'radius': 28,
          'stackButtons': true,
          'buttonHeight': 54,
          'buttonRadius': 16,
          'buttonShadows': [
            {'type': 'dropShadow', 'blurRadius': 24, 'offset': [0, 8], 'color': '#52E9C46A'},
          ],
          'cancelShadows': <Object>[],
        },
        'variables': {
          'confirmGradientStart': '#FFF7E2A6',
          'confirmGradientMiddle': '#FFE9C46A',
          'confirmGradientEnd': '#FFC0913A',
          'cancelColor': '#0FFFFFFF',
          'backgroundColor': '#FF141A44',
        },
        'actions': [
          {'type': 'setVariable', 'variable': 'answer', 'value': 'out'},
        ],
      },
    ];

List<BoxShadow> _shadowsAround(WidgetTester tester, Key key) => [
      for (final box in tester.widgetList<DecoratedBox>(find.ancestor(of: find.byKey(key), matching: find.byType(DecoratedBox))))
        if (box.decoration case BoxDecoration(:final boxShadow?)) ...boxShadow,
    ];

void main() {
  testWidgets('the confirm button takes the gradient, the cancel no glow', (tester) async {
    final host = Host([v('answer', '')]);
    await host.pump(tester, size: const Size(390, 844));
    final pending = host.run(_signOut());
    await tester.pumpAndSettle();
    final gradient = tester.widget<DecoratedBox>(find.byKey(const ValueKey('codelessly-confirm-gradient')));
    expect((gradient.decoration as BoxDecoration).gradient, isA<LinearGradient>().having((g) => g.colors, 'colors', const [
      Color(0xFFF7E2A6),
      Color(0xFFE9C46A),
      Color(0xFFC0913A),
    ]));
    expect(_shadowsAround(tester, _okKey), isNotEmpty, reason: 'the confirm glows');
    expect(_shadowsAround(tester, _cancelKey), isEmpty, reason: 'cancelShadows: none for the cancel');
    // A phone's sheet spans the screen and sits on its bottom edge.
    final sheet = tester.getRect(find.byKey(_sheetKey));
    expect(sheet.width, 390);
    expect(sheet.bottom, 844);
    await tester.tap(find.byKey(_okKey));
    await tester.pumpAndSettle();
    await pending;
    expect(host['answer'], 'out');
    expect(host.errors, isEmpty);
  });

  testWidgets('on a wide screen the sheet floats sheetMargin above the bottom, every corner rounded', (tester) async {
    final host = Host([v('answer', '')]);
    await host.pump(tester, size: const Size(834, 1112));
    final pending = host.run(_signOut());
    await tester.pumpAndSettle();
    final sheet = tester.getRect(find.byKey(_sheetKey));
    expect(sheet.width, 520);
    expect(sheet.bottom, 1112 - 24);
    final clip = tester.widget<ClipRRect>(find.byKey(_sheetKey));
    expect(clip.borderRadius, BorderRadius.circular(28));
    await tester.tap(find.byKey(_cancelKey));
    await tester.pumpAndSettle();
    await pending;
    expect(host['answer'], '');
  });

  testWidgets('without the new keys a confirm looks as before', (tester) async {
    final host = Host([v('answer', '')]);
    await host.pump(tester, size: const Size(834, 1112));
    final plain = {..._signOut().single, 'look': {'sheetWidth': 520, 'radius': 28}, 'variables': {'cancelColor': '#FF444444'}};
    final pending = host.run([plain]);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('codelessly-confirm-gradient')), findsNothing);
    final sheet = tester.getRect(find.byKey(_sheetKey));
    expect(sheet.bottom, 1112, reason: 'docked to the bottom');
    await tester.tap(find.byKey(_cancelKey));
    await tester.pumpAndSettle();
    await pending;
  });
}
