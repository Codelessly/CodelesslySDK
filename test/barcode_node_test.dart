import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/functions/action_chain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Observable<VariableData> variable(
  String name,
  Object? value,
  VariableType type,
) => Observable(VariableData(id: name, name: name, value: value, type: type));

Future<void> pump(
  WidgetTester tester,
  CodelesslyContext context,
  Widget child,
) async {
  tester.view.physicalSize = const Size(800, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: context,
      child: MaterialApp(
        home: ActionChainHost(
          child: Scaffold(body: Center(child: child)),
        ),
      ),
    ),
  );
}

BarcodeNode barcode({
  String data = '',
  BarcodeSymbology symbology = BarcodeSymbology.qrCode,
  Map<String, String> variables = const {},
  double width = 160,
  double height = 160,
}) => BarcodeNode(
  id: 'barcode',
  name: 'Barcode',
  basicBoxLocal: NodeBox(0, 0, width, height),
  data: data,
  properties: BarcodeProperties(
    symbology: symbology,
    backgroundColor: ColorRGBA.white,
  ),
)..variables.addAll(variables);

BarcodePainter painterOf(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find
                  .descendant(
                    of: find.byType(PassiveBarcodeWidget),
                    matching: find.byType(CustomPaint),
                  )
                  .first,
            )
            .painter!
        as BarcodePainter;

const String _iataPass =
    'M1DOE/JOHN            EABC123 SFOJFKUA 0015 123Y012A0001 100';

void main() {
  testWidgets('every symbology paints its data in the node box', (
    tester,
  ) async {
    for (final (symbology, data, width, height) in [
      (BarcodeSymbology.qrCode, _iataPass, 160.0, 160.0),
      (BarcodeSymbology.pdf417, _iataPass, 300.0, 90.0),
      (BarcodeSymbology.aztec, _iataPass, 160.0, 160.0),
      (BarcodeSymbology.dataMatrix, _iataPass, 160.0, 160.0),
      (BarcodeSymbology.code128, 'ABC-123', 240.0, 80.0),
      (BarcodeSymbology.ean13, '590123412345', 240.0, 80.0),
    ]) {
      await pump(
        tester,
        CodelesslyContext.empty(),
        PassiveBarcodeWidget(
          node: barcode(
            data: data,
            symbology: symbology,
            width: width,
            height: height,
          ),
          settings: const WidgetBuildSettings(debugLabel: 'test'),
        ),
      );
      final BarcodePainter painter = painterOf(tester);
      expect(painter.data, data, reason: '$symbology');
      expect(painter.symbology, symbology);
      expect(painter.isEncodable, isTrue, reason: '$symbology');
      expect(
        tester.getSize(find.byType(PassiveBarcodeWidget)),
        Size(width, height),
        reason: '$symbology',
      );
      expect(tester.takeException(), isNull, reason: '$symbology');
    }
  });

  testWidgets('the transformer builds the barcode widget', (tester) async {
    final BarcodeNode node = barcode(data: 'hello');
    final PassiveNodeTransformerManager manager = PassiveNodeTransformerManager(
      (id) => node,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    final transformer = manager.getTransformerByNode(node);
    expect(transformer, isA<PassiveBarcodeTransformer>());
    await pump(
      tester,
      CodelesslyContext.empty(),
      Builder(
        builder: (context) => transformer.buildWidget(
          node,
          context,
          const WidgetBuildSettings(debugLabel: 'test'),
        ),
      ),
    );
    expect(painterOf(tester).data, 'hello');
    expect(tester.takeException(), isNull);
  });

  testWidgets('data binds to variables and formulas', (tester) async {
    final CodelesslyContext context = CodelesslyContext.empty()
      ..variables['pass'] = variable('pass', {
        'barcode': _iataPass,
        'pnr': 'ABC123',
      }, VariableType.map);

    // A whole-value binding.
    await pump(
      tester,
      context,
      PassiveBarcodeWidget(
        node: barcode(
          data: 'design-time',
          variables: {'data': r'${pass.barcode}'},
        ),
        settings: const WidgetBuildSettings(debugLabel: 'test'),
      ),
    );
    expect(painterOf(tester).data, _iataPass);

    // Paths and formulas inside the data text.
    await pump(
      tester,
      context,
      PassiveBarcodeWidget(
        key: const ValueKey('inline'),
        node: barcode(data: r'PNR:${pass.pnr}/${= 2 + 3}'),
        settings: const WidgetBuildSettings(debugLabel: 'test'),
      ),
    );
    expect(painterOf(tester).data, 'PNR:ABC123/5');

    // A formula binding.
    await pump(
      tester,
      context,
      PassiveBarcodeWidget(
        key: const ValueKey('formula'),
        node: barcode(variables: {'data': r'${= pass.pnr + "-1"}'}),
        settings: const WidgetBuildSettings(debugLabel: 'test'),
      ),
    );
    expect(painterOf(tester).data, 'ABC123-1');
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid or empty data paints a placeholder without throwing', (
    tester,
  ) async {
    for (final (symbology, data) in [
      (BarcodeSymbology.ean13, 'NOT-DIGITS'),
      (BarcodeSymbology.ean13, '123'),
      (BarcodeSymbology.code128, 'émoji 🚀'),
      (BarcodeSymbology.qrCode, ''),
      (BarcodeSymbology.pdf417, ''),
    ]) {
      await pump(
        tester,
        CodelesslyContext.empty(),
        PassiveBarcodeWidget(
          node: barcode(data: data, symbology: symbology),
          settings: const WidgetBuildSettings(debugLabel: 'test'),
        ),
      );
      expect(painterOf(tester).isEncodable, isFalse, reason: '$symbology');
      expect(tester.takeException(), isNull, reason: '$symbology "$data"');
    }

    // A binding to a missing variable encodes nothing.
    await pump(
      tester,
      CodelesslyContext.empty(),
      PassiveBarcodeWidget(
        node: barcode(data: 'fallback', variables: {'data': r'${missing}'}),
        settings: const WidgetBuildSettings(debugLabel: 'test'),
      ),
    );
    expect(painterOf(tester).data, isEmpty);
    expect(tester.takeException(), isNull);
  });

  test('canEncode checks the data against the symbology', () {
    expect(
      BarcodePainter.canEncode('590123412345', BarcodeSymbology.ean13),
      isTrue,
    );
    expect(BarcodePainter.canEncode('ABC', BarcodeSymbology.ean13), isFalse);
    expect(BarcodePainter.canEncode('', BarcodeSymbology.qrCode), isFalse);
    expect(
      BarcodePainter.canEncode('any text', BarcodeSymbology.qrCode),
      isTrue,
    );
  });

  /// The bounds of the dark pixels [symbology] paints for [data] in a
  /// [width] x [height] box.
  Future<Rect?> darkBounds(
    WidgetTester tester,
    BarcodeSymbology symbology,
    String data,
    double width,
    double height,
  ) async {
    final GlobalKey key = GlobalKey();
    await pump(
      tester,
      CodelesslyContext.empty(),
      RepaintBoundary(
        key: key,
        child: PassiveBarcodeWidget(
          node: barcode(
            data: data,
            symbology: symbology,
            width: width,
            height: height,
          ),
          settings: const WidgetBuildSettings(debugLabel: 'test'),
        ),
      ),
    );
    final RenderRepaintBoundary boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final ByteData? bytes = await tester.runAsync<ByteData?>(() async {
      final ui.Image image = await boundary.toImage();
      final ByteData? data = await image.toByteData();
      image.dispose();
      return data;
    });
    int? left, top, right, bottom;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int offset = (y * width.toInt() + x) * 4;
        // Black bars on a white background.
        if (bytes!.getUint8(offset) < 128) {
          left = left == null || x < left ? x : left;
          right = right == null || x > right ? x : right;
          top ??= y;
          bottom = y;
        }
      }
    }
    if (left == null) return null;
    return Rect.fromLTRB(
      left.toDouble(),
      top!.toDouble(),
      right! + 1.0,
      bottom! + 1.0,
    );
  }

  testWidgets('a QR code is square and centered in a wide box', (tester) async {
    final Rect? bounds = await darkBounds(
      tester,
      BarcodeSymbology.qrCode,
      _iataPass,
      200,
      100,
    );
    expect(bounds, isNotNull);
    expect(bounds!.width, closeTo(bounds.height, 2));
    expect(bounds.center.dx, closeTo(100, 2));
    expect(bounds.center.dy, closeTo(50, 2));
    expect(bounds.height, greaterThan(90));
  });

  testWidgets('a PDF417 code fills its box', (tester) async {
    final Rect? bounds = await darkBounds(
      tester,
      BarcodeSymbology.pdf417,
      _iataPass,
      300,
      90,
    );
    expect(bounds, isNotNull);
    expect(bounds!.left, lessThan(2));
    expect(bounds.top, lessThan(2));
    expect(bounds.right, greaterThan(297));
    expect(bounds.bottom, greaterThan(87));
  });

  testWidgets('invalid data paints only a faint placeholder', (tester) async {
    final Rect? bounds = await darkBounds(
      tester,
      BarcodeSymbology.ean13,
      'NOT-DIGITS',
      200,
      80,
    );
    expect(bounds, isNull);
  });
}
