// A switch drawn as a plain toggle: a thumb border that eases between its
// off and on colors like the track's, and the slide's duration and curve.
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/widgets/inputs_toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _rule = Color(0xFFDDDDDD), _ink = Color(0xFF111111);

Map<String, Object?> _switch({bool value = false, Map<String, Object?> props = const {}}) => {
      'type': 'switch',
      'layout': {'width': 50, 'height': 30},
      'props': {
        'fillTrack': true,
        'thumbInset': 3,
        'value': value,
        'inactiveTrackColor': '#FFFFFFFF',
        'activeTrackColor': '#FF111111',
        'inactiveThumbColor': '#FFFFFFFF',
        'activeThumbColor': '#FFFFFFFF',
        'uniformThumb': true,
        ...props,
      },
    };

Future<void> _show(WidgetTester tester, Map<String, Object?> node) async {
  final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({
    'roots': ['s'],
    'nodes': {'s': node},
  })));
  addTearDown(tree.dispose);
  await tester.pumpWidget(MaterialApp(
    home: Align(alignment: Alignment.topLeft, child: NodeView(key: UniqueKey(), tree: tree, rootId: 's', interactive: true)),
  ));
}

Finder get _paint => find.descendant(of: find.byType(PlainToggle), matching: find.byType(CustomPaint)).first;

double _position(WidgetTester tester) => (tester.widget<CustomPaint>(_paint).painter! as PlainTogglePainter).position.value;

const _border = {'inactiveThumbBorderColor': '#FFDDDDDD', 'activeThumbBorderColor': '#FF111111', 'thumbBorderWidth': 1};

void main() {
  test('the thumb border, duration and curve props decode', () {
    final p = api.Props.fromJson(api.SwitchProps.spec, {
      ..._border,
      'toggleDurationMs': 180,
      'toggleCurve': 'linear',
    });
    expect(p.get(api.SwitchProps.inactiveThumbBorderColor), api.Color.fromJson('#FFDDDDDD'));
    expect(p.get(api.SwitchProps.activeThumbBorderColor), api.Color.fromJson('#FF111111'));
    expect(p.get(api.SwitchProps.thumbBorderWidth), 1);
    expect(p.get(api.SwitchProps.toggleDurationMs), 180);
    expect(p.get(api.SwitchProps.toggleCurve), api.AnimationCurve.linear);
    final d = api.Props.fromJson(api.SwitchProps.spec, const {});
    expect(d.get(api.SwitchProps.toggleDurationMs), 220);
    expect(d.get(api.SwitchProps.toggleCurve), api.AnimationCurve.easeOutCubic);
  });

  for (final on in [false, true]) {
    testWidgets('the thumb draws its ${on ? 'on' : 'off'} border inside its edge', (tester) async {
      await _show(tester, _switch(value: on, props: _border));
      // Thumb 24 across at (15|35, 15): fill, then a 1 px ring inside it.
      final x = on ? 35.0 : 15.0;
      expect(
        tester.renderObject(_paint),
        paints
          ..rrect()
          ..circle(x: x, y: 15, radius: 12, color: const Color(0xFFFFFFFF))
          ..circle(x: x, y: 15, radius: 11.5, color: on ? _ink : _rule, style: PaintingStyle.stroke, strokeWidth: 1),
      );
    });
  }

  testWidgets('a thumb border alone makes a filled-track switch a plain toggle', (tester) async {
    await _show(tester, {
      'type': 'switch',
      'layout': {'width': 50, 'height': 30},
      'props': {'fillTrack': true, ..._border},
    });
    expect(find.byType(PlainToggle), findsOneWidget);
  });

  testWidgets('the thumb slides for toggleDurationMs along toggleCurve', (tester) async {
    await _show(tester, _switch(props: {'toggleDurationMs': 180, 'toggleCurve': 'linear'}));
    await tester.tap(find.byType(PlainToggle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    expect(_position(tester), closeTo(0.5, 0.01));
    await tester.pump(const Duration(milliseconds: 90));
    expect(_position(tester), 1);
  });

  testWidgets('the slide keeps its 220 ms ease-out by default', (tester) async {
    await _show(tester, _switch());
    await tester.tap(find.byType(PlainToggle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    expect(_position(tester), lessThan(1));
    await tester.pump(const Duration(milliseconds: 40));
    expect(_position(tester), 1);
  });
}
