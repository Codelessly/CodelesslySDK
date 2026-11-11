// A signature pad's sign line (solid or dashed, placed and inset), its mark
// (a glyph or a sized icon, above or before the line), its placeholder's
// style and place, and a caption under the line; a checkbox's unchecked
// fill, checked side, compact sizes in node pixels, and a design board's
// checked box shown at rest.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/widgets/inputs_shapes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'lists/support.dart';

Map<String, Json> _pad(Map<String, Object?> props) => {
  'col': {
    'type': 'column',
    'children': ['sg'],
    'layout': {'width': 400, 'height': 300},
  },
  'sg': {
    'type': 'signature',
    'layout': {'width': 300, 'height': 200},
    'props': props,
  },
};

Finder get _padPaint => find.byWidgetPredicate((w) => w is CustomPaint && w.painter is SignaturePainter);
SignaturePainter _painter(WidgetTester tester) => tester.widget<CustomPaint>(_padPaint).painter! as SignaturePainter;
RenderObject _padRender(WidgetTester tester) => tester.renderObject(_padPaint);

Map<String, Json> _box(Map<String, Object?> props, {double size = 40}) => {
  'col': {
    'type': 'column',
    'children': ['cb'],
    'layout': {'width': 300, 'height': 100},
  },
  'cb': {
    'type': 'checkbox',
    'layout': {'width': size, 'height': size},
    'bind': {'props.value': r'${on}'},
    'props': props,
  },
};

void main() {
  group('signature', () {
    testWidgets('unset, it keeps its solid line at 76%, its × glyph and its placeholder', (tester) async {
      await show(tester, _pad({}));
      final p = _painter(tester);
      expect(p.dashed, isFalse);
      expect(p.signLineOffset, isNull);
      expect(p.signLineInset, 20);
      expect(p.signLineWidth, 1);
      expect(p.markGlyph, isTrue);
      expect(p.markSize, 16);
      expect(p.leadingMark, isFalse);
      expect(p.placeholderStyle, isNull);
      expect(p.caption, isEmpty);
      // 200 high: the line at 152, across 20 … 280.
      expect(_padRender(tester), paints..line(p1: const Offset(20, 152), p2: const Offset(280, 152)));
      expect(find.byType(CustomSingleChildLayout), findsNothing);
    });

    testWidgets('a dashed line is placed from the bottom, inset, and starts after a leading mark', (tester) async {
      await show(
        tester,
        _pad({
          'signLineStyle': 'dashed',
          'signLineDash': 6,
          'signLineGap': 6,
          'signLineWidth': 2,
          'signLineOffset': 50,
          'signLineInset': 24,
          'signMarkIcon': {'type': 'MATERIAL_ICON', 'name': 'close', 'style': 'rounded'},
          'signMarkSize': 22,
          'signMarkColor': '#FF5E5E66',
          'signMarkPlacement': 'leading',
          'signMarkGap': 8,
        }),
      );
      // y = 200 - 50; the line starts at 24 + 22 + 8.
      expect(
        _padRender(tester),
        paints
          ..line(p1: const Offset(54, 150), p2: const Offset(60, 150))
          ..line(p1: const Offset(66, 150), p2: const Offset(72, 150)),
      );
      expect(_painter(tester).markGlyph, isFalse);
      // The icon mark: 22 px square, centred on the line at the inset.
      final pad = tester.getTopLeft(_padPaint);
      final mark = find.descendant(of: find.byType(CustomSingleChildLayout), matching: find.byType(SizedBox)).first;
      expect(tester.getRect(mark), Rect.fromLTWH(pad.dx + 24, pad.dy + 139, 22, 22));
    });

    testWidgets('the × glyph sizes and colours by its props', (tester) async {
      await show(tester, _pad({'signMarkSize': 24, 'signMarkColor': '#FFFF0000'}));
      final p = _painter(tester);
      expect(p.markSize, 24);
      expect(p.markColor, const Color(0xFFFF0000));
      final g = p.geometry();
      expect(g.markHeight, 24);
      // Above the line's start, 4 px over it.
      expect(g.markOrigin(const Size(300, 200)), const Offset(20, 152 - 24 - 4));
    });

    testWidgets('a hidden mark leaves the line from the inset', (tester) async {
      await show(tester, _pad({'showSignMark': false, 'signMarkPlacement': 'leading'}));
      expect(_painter(tester).geometry().lineStart(const Size(300, 200)), 20);
    });

    testWidgets('the placeholder takes a full text style, an alignment and an offset', (tester) async {
      await show(
        tester,
        _pad({
          'placeholder': 'Sign here with your finger',
          'placeholderStyle': {'fontWeight': 600, 'fontSize': 20, 'letterSpacing': 0, 'color': '#FFB4B4BA'},
          'placeholderAlignment': [0, 0],
          'placeholderOffset': [0, -15],
        }),
      );
      final p = _painter(tester);
      expect(p.placeholderStyle!.fontSize, 20);
      expect(p.placeholderStyle!.letterSpacing, 0);
      expect(p.placeholderStyle!.fontWeight, FontWeight.w600);
      expect(p.placeholderStyle!.color, const Color(0xFFB4B4BA));
      expect(p.placeholderOffset, const Offset(0, -15));
    });

    testWidgets('a placeholder style keeps the size, colour, weight and spacing it leaves out', (tester) async {
      await show(
        tester,
        _pad({
          'placeholderFontSize': 10,
          'placeholderStyle': {'fontFamily': 'Archivo'},
        }),
      );
      final s = _painter(tester).placeholderStyle!;
      expect(s.fontFamily, 'Archivo');
      expect(s.fontSize, 10);
      expect(s.fontWeight, FontWeight.w600);
      expect(s.letterSpacing, closeTo(1.2, 1e-9));
      expect(s.color, const Color(0xFFA9ADA5));
    });

    testWidgets('a top-start placeholder is painted at its offset', (tester) async {
      await show(
        tester,
        _pad({
          'placeholderAlignment': [-1, -1],
          'placeholderOffset': [10, 12],
          'showSignLine': false,
        }),
      );
      // (A centred paragraph is drawn shifted by its laid-out width: only
      // its top is checked.)
      expect(
        _padRender(tester),
        paints..something((method, args) => method == #drawParagraph && (args[1] as Offset).dy == 12),
      );
    });

    testWidgets('a caption is drawn under the line, in its style', (tester) async {
      await show(
        tester,
        _pad({
          'signLineOffset': 50,
          'signLineInset': 24,
          'showSignMark': false,
          'caption': 'SIGN ABOVE THE LINE',
          'captionStyle': {'fontWeight': 800, 'fontSize': 11, 'letterSpacing': 1.4, 'color': '#FF5E5E66'},
          'captionGap': 10,
          'value': [
            [
              [10, 10],
              [20, 20],
            ],
          ],
        }),
      );
      final p = _painter(tester);
      expect(p.caption, 'SIGN ABOVE THE LINE');
      expect(p.captionStyle!.fontSize, 11);
      expect(p.captionStyle!.letterSpacing, 1.4);
      expect(p.captionStyle!.color, const Color(0xFF5E5E66));
      // Line at 150, 1 px wide: the caption's top at 150.5 + 10.
      expect(
        _padRender(tester),
        paints
          ..line()
          ..paragraph(offset: const Offset(24, 160.5)),
      );
    });
  });

  group('checkbox', () {
    testWidgets('fills its unchecked box with fillColor', (tester) async {
      await show(
        tester,
        _box({'fillColor': '#FF1C1C21', 'activeColor': '#FF1FE07A'}),
        variables: [v('on', false, VariableType.boolean)],
      );
      final c = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(c.fillColor!.resolve({}), const Color(0xFF1C1C21));
      // Checked, its activeColor fills it.
      expect(c.fillColor!.resolve({WidgetState.selected}), isNull);
      expect(c.activeColor, const Color(0xFF1FE07A));
    });

    testWidgets('without fillColor it keeps Flutter\'s', (tester) async {
      await show(tester, _box({}), variables: [v('on', false, VariableType.boolean)]);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).fillColor, isNull);
    });

    testWidgets('a compact box\'s corners and sides are node pixels', (tester) async {
      await show(
        tester,
        _box({
          'compact': true,
          'borderRadius': 8,
          'side': {'color': '#FF2E2E34', 'width': 2},
        }, size: 36),
        variables: [v('on', false, VariableType.boolean)],
      );
      // Scaled ×2 (36 / 18): drawn at half.
      expect(
        tester.widget<Transform>(find.ancestor(of: find.byType(Checkbox), matching: find.byType(Transform)).first),
        isNotNull,
      );
      final c = tester.widget<Checkbox>(find.byType(Checkbox));
      expect((c.shape! as RoundedRectangleBorder).borderRadius, BorderRadius.circular(4));
      expect(c.side!.width, 1);
    });

    testWidgets('an 18 px compact box and a full-size box keep their sizes', (tester) async {
      await show(
        tester,
        _box({
          'compact': true,
          'borderRadius': 4,
          'side': {'width': 2},
        }, size: 18),
        variables: [v('on', false, VariableType.boolean)],
      );
      var c = tester.widget<Checkbox>(find.byType(Checkbox));
      expect((c.shape! as RoundedRectangleBorder).borderRadius, BorderRadius.circular(4));
      expect(c.side!.width, 2);
      await show(
        tester,
        _box({
          'borderRadius': 4,
          'side': {'width': 2},
        }, size: 80),
        variables: [v('on', false, VariableType.boolean)],
      );
      c = tester.widget<Checkbox>(find.byType(Checkbox));
      expect((c.shape! as RoundedRectangleBorder).borderRadius, BorderRadius.circular(4));
      expect(c.side!.width, 2);
    });

    testWidgets('activeSide borders the checked box', (tester) async {
      await show(
        tester,
        _box({
          'side': {'color': '#FF2E2E34', 'width': 2},
          'activeSide': {'color': '#FF1FE07A', 'width': 2},
        }),
        variables: [v('on', true, VariableType.boolean)],
      );
      final side = tester.widget<Checkbox>(find.byType(Checkbox)).side!;
      expect(side, isA<WidgetStateBorderSide>());
      final states = side as WidgetStateBorderSide;
      expect(
        WidgetStateProperty.resolveAs<BorderSide?>(states, {WidgetState.selected})!.color,
        const Color(0xFF1FE07A),
      );
      expect(WidgetStateProperty.resolveAs<BorderSide?>(states, {})!.color, const Color(0xFF2E2E34));
    });

    testWidgets('on a design board (tickers off) a checked box shows checked at once', (tester) async {
      final s = await show(tester, _box({}), variables: [v('on', false, VariableType.boolean)]);
      await tester.pumpWidget(
        TickerMode(
          enabled: false,
          child: MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: NodeView(tree: s.tree, rootId: 'col'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      s.scope.set('on', true);
      await tester.pump();
      await tester.pump();
      final state = tester.state(find.byType(Checkbox)) as ToggleableStateMixin;
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
      expect(state.position.value, 1.0);
    });

    testWidgets('with tickers on it still animates', (tester) async {
      final s = await show(tester, _box({}), variables: [v('on', false, VariableType.boolean)]);
      s.scope.set('on', true);
      await tester.pump();
      await tester.pump();
      final state = tester.state(find.byType(Checkbox)) as ToggleableStateMixin;
      expect(state.position.value, lessThan(1.0));
      await tester.pumpAndSettle();
      expect(state.position.value, 1.0);
    });
  });
}
