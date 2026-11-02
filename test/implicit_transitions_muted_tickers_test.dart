import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The editor's design canvas (and captures of it) builds under a disabled
// TickerMode, where implicit transitions never tick. They show the current
// state there instead of the old one; in the app they still animate.

RectangleNode pill(String hex) => RectangleNode(
  id: 'pill',
  name: 'Pill',
  basicBoxLocal: NodeBox(0, 0, 80, 30),
  fills: [PaintModel.solid(id: 'f', color: ColorRGB.fromHex(hex))],
)..transitionMs = 300;

Future<void> pumpFill(
  WidgetTester tester,
  String hex, {
  required bool ticking,
}) => tester.pumpWidget(
  TickerMode(
    enabled: ticking,
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: 80,
        height: 30,
        child: buildFill(
          pill(hex),
          index: 0,
          useInk: false,
          settings: const WidgetBuildSettings(debugLabel: 'test'),
          scopedValues: ScopedValues.empty(),
        ),
      ),
    ),
  ),
);

Color? fillOf(WidgetTester tester) =>
    (tester.widget<DecoratedBox>(find.byType(DecoratedBox).first).decoration
            as BoxDecoration)
        .color;

SwitchNode toggle({Map<String, String> variables = const {}}) => SwitchNode(
  id: 's',
  name: 's',
  basicBoxLocal: NodeBox(0, 0, 60, 40),
  value: true,
  properties: SwitchProperties(),
)..variables.addAll(variables);

Future<void> pumpSwitch(
  WidgetTester tester,
  SwitchNode node,
  bool value, {
  required bool ticking,
}) => tester.pumpWidget(
  TickerMode(
    enabled: ticking,
    child: MaterialApp(
      home: Material(
        child: Center(
          child: SizedBox(
            width: 60,
            height: 40,
            child: TransformerSwitch(
              node: node,
              settings: const WidgetBuildSettings(debugLabel: 'test'),
              onChanged: null,
              value: value,
              scopedValues: ScopedValues.empty(),
            ),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('A transitionMs fill jumps to its colour with tickers off', (
    tester,
  ) async {
    await pumpFill(tester, '#FFFFFF', ticking: false);
    await pumpFill(tester, '#1F2B2E', ticking: false);
    expect(fillOf(tester), const Color(0xFF1F2B2E));
  });

  testWidgets('In the app it still eases', (tester) async {
    await pumpFill(tester, '#FFFFFF', ticking: true);
    await pumpFill(tester, '#000000', ticking: true);
    expect(fillOf(tester), const Color(0xFFFFFFFF));
    await tester.pump(const Duration(milliseconds: 150));
    expect(fillOf(tester), isNot(const Color(0xFFFFFFFF)));
    expect(fillOf(tester), isNot(const Color(0xFF000000)));
    await tester.pump(const Duration(milliseconds: 200));
    expect(fillOf(tester), const Color(0xFF000000));
  });

  testWidgets('A switch turned off with tickers off shows off', (tester) async {
    final SwitchNode node = toggle();
    await pumpSwitch(tester, node, true, ticking: false);
    final Element on = tester.element(find.byType(Switch));
    await pumpSwitch(tester, node, false, ticking: false);
    final Switch off = tester.widget<Switch>(find.byType(Switch));
    expect(off.value, isFalse);
    // A fresh switch, built at its value, not one stuck mid-toggle.
    expect(tester.element(find.byType(Switch)), isNot(same(on)));
  });

  testWidgets('In the app the same switch animates its toggle', (tester) async {
    final SwitchNode node = toggle();
    await pumpSwitch(tester, node, true, ticking: true);
    final Element on = tester.element(find.byType(Switch));
    await pumpSwitch(tester, node, false, ticking: true);
    expect(tester.element(find.byType(Switch)), same(on));
    expect(tester.widget<Switch>(find.byType(Switch)).key, isNull);
  });

  testWidgets('Bound track border colours reach the switch', (tester) async {
    final SwitchNode node = toggle(
      variables: {
        'activeTrackBorderColor': r"${= true ? '#FF0000' : '#00FF00'}",
        'inactiveTrackBorderColor': '#0000FF',
      },
    );
    await pumpSwitch(tester, node, true, ticking: false);
    final Switch widget = tester.widget<Switch>(find.byType(Switch));
    expect(
      widget.trackOutlineColor?.resolve({WidgetState.selected}),
      const Color(0xFFFF0000),
    );
    expect(
      widget.trackOutlineColor?.resolve(<WidgetState>{}),
      const Color(0xFF0000FF),
    );
  });
}
