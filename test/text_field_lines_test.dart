import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const List<Size> _sizes = [Size(390, 844), Size(834, 1194), Size(1440, 900)];

TextFieldNode _field({
  required int? maxLines,
  required int? minLines,
  SizeFit verticalFit = SizeFit.shrinkWrap,
  bool obscureText = false,
}) => TextFieldNode(
  id: 'field',
  name: 'Field',
  basicBoxLocal: NodeBox(0, 0, 300, 120),
  verticalFit: verticalFit,
  properties: TextFieldProperties(
    maxLines: maxLines,
    minLines: minLines,
    obscureText: obscureText,
  ),
);

Future<void> _pump(WidgetTester tester, TextFieldNode node, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final registry = NodeRegistry()..setNodes({node.id: node});
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: CodelesslyContext.empty(),
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => manager.buildWidgetFromNode(
                node,
                context,
                settings: const WidgetBuildSettings(debugLabel: 'test'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void _expectOnScreen(WidgetTester tester, Size size) {
  final Rect rect = tester.getRect(find.byType(TextField));
  expect(rect.width, greaterThan(0));
  expect(rect.height, greaterThan(0));
  expect(
    Offset.zero & size,
    predicate<Rect>((screen) => screen.intersect(rect) == rect),
    reason: 'field $rect should be on a ${size.width}x${size.height} screen',
  );
}

void main() {
  group('resolveTextFieldLines', () {
    test('keeps valid limits', () {
      expect(resolveTextFieldLines(maxLines: 1, minLines: null), (1, null));
      expect(resolveTextFieldLines(maxLines: 5, minLines: 2), (5, 2));
    });

    test('null max lines is unlimited and keeps min lines', () {
      expect(resolveTextFieldLines(maxLines: null, minLines: 3), (null, 3));
    });

    test('min lines above max lines raises max lines', () {
      expect(resolveTextFieldLines(maxLines: 1, minLines: 3), (3, 3));
    });

    test('limits below 1 mean no limit', () {
      expect(resolveTextFieldLines(maxLines: 0, minLines: 0), (null, null));
      expect(resolveTextFieldLines(maxLines: 2, minLines: -1), (2, null));
    });

    test('an expanding field has no limits', () {
      expect(resolveTextFieldLines(maxLines: 1, minLines: 3, expands: true), (
        null,
        null,
      ));
    });
  });

  for (final size in _sizes) {
    final label = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('min 3 with unlimited max lines grows from 3 lines at $label', (
      tester,
    ) async {
      await _pump(tester, _field(maxLines: null, minLines: 3), size);
      expect(tester.takeException(), isNull);
      final TextField field = tester.widget(find.byType(TextField));
      expect(field.maxLines, isNull);
      expect(field.minLines, 3);
      expect(field.expands, isFalse);
      _expectOnScreen(tester, size);

      final double emptyHeight = tester.getSize(find.byType(TextField)).height;
      await tester.enterText(
        find.byType(TextField),
        List.filled(8, 'line').join('\n'),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(TextField)).height,
        greaterThan(emptyHeight),
      );
    });

    testWidgets('min 3 with max 1 does not assert at $label', (tester) async {
      await _pump(tester, _field(maxLines: 1, minLines: 3), size);
      expect(tester.takeException(), isNull);
      final TextField field = tester.widget(find.byType(TextField));
      expect(field.maxLines, 3);
      expect(field.minLines, 3);
      _expectOnScreen(tester, size);
    });

    testWidgets('obscured multi-line field does not assert at $label', (
      tester,
    ) async {
      await _pump(
        tester,
        _field(maxLines: null, minLines: 3, obscureText: true),
        size,
      );
      expect(tester.takeException(), isNull);
      final TextField field = tester.widget(find.byType(TextField));
      expect(field.obscureText, isFalse);
      _expectOnScreen(tester, size);
    });

    testWidgets('fixed-height password field is obscured at $label', (
      tester,
    ) async {
      await _pump(
        tester,
        _field(
          maxLines: 1,
          minLines: null,
          verticalFit: SizeFit.fixed,
          obscureText: true,
        ),
        size,
      );
      expect(tester.takeException(), isNull);
      final TextField field = tester.widget(find.byType(TextField));
      expect(field.obscureText, isTrue);
      expect(field.expands, isFalse);
      expect(field.maxLines, 1);
      expect(tester.getSize(find.byType(TextField)).height, 120);
      _expectOnScreen(tester, size);
    });

    testWidgets('fixed-height field expands with lines set at $label', (
      tester,
    ) async {
      await _pump(
        tester,
        _field(maxLines: null, minLines: 3, verticalFit: SizeFit.fixed),
        size,
      );
      expect(tester.takeException(), isNull);
      final TextField field = tester.widget(find.byType(TextField));
      expect(field.expands, isTrue);
      expect(field.maxLines, isNull);
      expect(field.minLines, isNull);
      expect(tester.getSize(find.byType(TextField)).height, 120);
      _expectOnScreen(tester, size);
    });
  }
}
