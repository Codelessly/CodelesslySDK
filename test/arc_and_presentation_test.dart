import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/ui/codelessly_dialog_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

LoadingIndicatorNode indicator(
  MaterialLoadingIndicatorProperties props, [
  Map<String, String> variables = const {},
]) => LoadingIndicatorNode(
  id: 'gauge',
  name: 'Gauge',
  basicBoxLocal: NodeBox(0, 0, 120, 120),
  properties: props,
)..variables.addAll(variables);

Future<void> pump(WidgetTester tester, LoadingIndicatorNode node) =>
    tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty(),
        child: MaterialApp(
          home: Center(
            child: PassiveLoadingIndicatorWidget(
              node: node,
              onChanged: null,
              settings: const WidgetBuildSettings(debugLabel: 'test'),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('a full ring is a CircularProgressIndicator', (tester) async {
    await pump(
      tester,
      indicator(
        MaterialLoadingIndicatorProperties(color: ColorRGBA.white, value: 0.5),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('an arc paints its start, sweep and bound value', (tester) async {
    await pump(
      tester,
      indicator(
        MaterialLoadingIndicatorProperties(
          color: ColorRGBA.white,
          backgroundColor: ColorRGBA.black,
          value: 0.1,
          startAngle: 180,
          sweepAngle: 180,
        ),
        {
          'value': r'${= 20 / 28}',
          'color': r'${= 1 > 2 ? "#FFFFFF" : "#3F6B4F"}',
        },
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    final ArcIndicatorPainter painter =
        tester
                .widget<CustomPaint>(
                  find.byWidgetPredicate(
                    (w) => w is CustomPaint && w.painter is ArcIndicatorPainter,
                  ),
                )
                .painter!
            as ArcIndicatorPainter;
    expect(painter.startAngle, 180);
    expect(painter.sweepAngle, 180);
    expect(painter.value, closeTo(20 / 28, 1e-9));
    expect(painter.color.toARGB32(), 0xFF3F6B4F);
    expect(painter.trackColor.toARGB32(), 0xFF000000);
  });

  testWidgets('bound start and sweep turn a ring into an arc', (tester) async {
    await pump(
      tester,
      indicator(MaterialLoadingIndicatorProperties(color: ColorRGBA.white), {
        'startAngle': r'${= 22 * 15 - 90}',
        'sweepAngle': r'${= 9 * 15}',
      }),
    );
    final CustomPaint paint = tester.widget(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is ArcIndicatorPainter,
      ),
    );
    final ArcIndicatorPainter painter = paint.painter! as ArcIndicatorPainter;
    expect(painter.startAngle, 240);
    expect(painter.sweepAngle, 135);
  });

  group('DialogPresenter', () {
    test('adaptive is a sheet below 600 and a dialog above', () {
      expect(
        DialogPresenter.resolve(
          DialogPresentation.adaptive,
          const Size(390, 844),
        ),
        DialogPresentation.bottomSheet,
      );
      expect(
        DialogPresenter.resolve(
          DialogPresentation.adaptive,
          const Size(834, 1112),
        ),
        DialogPresentation.dialog,
      );
      expect(
        DialogPresenter.resolve(
          DialogPresentation.popover,
          const Size(390, 844),
        ),
        DialogPresentation.popover,
      );
    });

    test('a popover sits below its anchor, above when it must, on screen', () {
      const Size screen = Size(1440, 900);
      Offset place(Rect anchor, Size child) => PopoverLayoutDelegate(
        anchor: anchor,
        gap: 6,
      ).getPositionForChild(screen, child);
      // Room below: under the anchor, left-aligned.
      expect(
        place(const Rect.fromLTWH(100, 100, 40, 40), const Size(280, 300)),
        const Offset(100, 146),
      );
      // No room below: above it.
      expect(
        place(const Rect.fromLTWH(12, 820, 232, 52), const Size(280, 300)),
        const Offset(12, 514),
      );
      // Near the right edge: pulled back on screen.
      expect(
        place(const Rect.fromLTWH(1400, 10, 36, 36), const Size(280, 300)).dx,
        1440 - 280 - 6,
      );
    });
  });
}
