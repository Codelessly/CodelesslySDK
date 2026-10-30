import 'dart:math' as math;

import 'package:barcode/barcode.dart';
import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';

/// Renders a [BarcodeNode]: its resolved data encoded with the node's
/// symbology, painted to fill the node's box.
class PassiveBarcodeTransformer extends NodeWidgetTransformer<BarcodeNode> {
  /// Creates a [PassiveBarcodeTransformer].
  PassiveBarcodeTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    BarcodeNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) => PassiveBarcodeWidget(node: node, settings: settings);
}

/// Paints a [BarcodeNode] in its box.
///
/// The encoded text is the node's `data` binding (`variables['data']`) when
/// it has one, else [BarcodeNode.data] with its variable paths and formulas
/// substituted.
class PassiveBarcodeWidget extends StatelessWidget {
  /// The node to paint.
  final BarcodeNode node;

  /// The settings the node is built with.
  final WidgetBuildSettings settings;

  /// Variables that take precedence over the ones in scope, e.g. preview
  /// values in the editor.
  final List<VariableData> variablesOverrides;

  /// The values bindings are read from. Defaults to the ones in [context].
  final ScopedValues? scopedValues;

  /// Creates a [PassiveBarcodeWidget].
  const PassiveBarcodeWidget({
    super.key,
    required this.node,
    required this.settings,
    this.variablesOverrides = const [],
    this.scopedValues,
  });

  /// The text [node] encodes: its bound `data` when it has a binding, else
  /// [BarcodeNode.data] with variables and formulas substituted.
  static String resolveData(
    BarcodeNode node, {
    required ScopedValues scopedValues,
    NullSubstitutionMode nullSubstitutionMode =
        NullSubstitutionMode.emptyString,
  }) {
    final String? bound = PropertyValueDelegate.getPropertyValue<String>(
      node,
      'data',
      scopedValues: scopedValues,
    );
    if (bound != null) return bound;
    // A binding that resolved to nothing encodes nothing, rather than the
    // design-time text.
    if (node.variables['data'] != null) return '';
    return PropertyValueDelegate.substituteVariables(
      node.data,
      scopedValues: scopedValues,
      nullSubstitutionMode: nullSubstitutionMode,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ScopedValues values =
        scopedValues ??
        ScopedValues.of(context, variablesOverrides: variablesOverrides);
    final BarcodeProperties props = node.properties;
    final String data = resolveData(
      node,
      scopedValues: values,
      nullSubstitutionMode: settings.nullSubstitutionMode,
    );
    final Color color =
        PropertyValueDelegate.getPropertyValue<ColorRGBA>(
          node,
          'color',
          scopedValues: values,
        )?.toFlutterColor() ??
        props.color.toFlutterColor();

    return AdaptiveNodeBox(
      node: node,
      child: Semantics(
        image: true,
        label: props.symbology.prettify,
        child: CustomPaint(
          size: Size.infinite,
          painter: BarcodePainter(
            data: data,
            symbology: props.symbology,
            errorCorrection: props.errorCorrection,
            color: color,
            backgroundColor: props.backgroundColor?.toFlutterColor(),
            drawText: props.drawText,
            textStyle: DefaultTextStyle.of(context).style,
          ),
        ),
      ),
    );
  }
}

/// Paints [data] as a barcode of the given [symbology], filling the canvas.
///
/// Codes with square modules (QR, Aztec, Data Matrix) keep their aspect
/// ratio and are centered; PDF417 and 1D codes stretch to fill the canvas.
/// Empty data, or data [symbology] can't encode, paints a light placeholder
/// instead.
class BarcodePainter extends CustomPainter {
  /// The text to encode.
  final String data;

  /// The encoding.
  final BarcodeSymbology symbology;

  /// Error correction of a QR code.
  final BarcodeErrorCorrection errorCorrection;

  /// Color of the bars or modules.
  final Color color;

  /// Color behind the code. Transparent when null.
  final Color? backgroundColor;

  /// Whether a 1D code draws its text below the bars.
  final bool drawText;

  /// Base style of the text drawn below a 1D code. Its color is replaced by
  /// [color].
  final TextStyle? textStyle;

  /// Creates a [BarcodePainter].
  BarcodePainter({
    required this.data,
    required this.symbology,
    this.errorCorrection = BarcodeErrorCorrection.medium,
    this.color = Colors.black,
    this.backgroundColor,
    this.drawText = true,
    this.textStyle,
  });

  /// The [Barcode] encoder for [symbology].
  static Barcode barcodeFor(
    BarcodeSymbology symbology, {
    BarcodeErrorCorrection errorCorrection = BarcodeErrorCorrection.medium,
  }) => switch (symbology) {
    BarcodeSymbology.qrCode => Barcode.qrCode(
      errorCorrectLevel: switch (errorCorrection) {
        BarcodeErrorCorrection.low => BarcodeQRCorrectionLevel.low,
        BarcodeErrorCorrection.medium => BarcodeQRCorrectionLevel.medium,
        BarcodeErrorCorrection.quartile => BarcodeQRCorrectionLevel.quartile,
        BarcodeErrorCorrection.high => BarcodeQRCorrectionLevel.high,
      },
    ),
    BarcodeSymbology.pdf417 => Barcode.pdf417(),
    BarcodeSymbology.code128 => Barcode.code128(),
    BarcodeSymbology.aztec => Barcode.aztec(),
    BarcodeSymbology.dataMatrix => Barcode.dataMatrix(),
    BarcodeSymbology.ean13 => Barcode.ean13(),
  };

  /// Whether [symbology] can encode [data]. Empty data can't be encoded.
  static bool canEncode(String data, BarcodeSymbology symbology) =>
      data.isNotEmpty && barcodeFor(symbology).isValid(data);

  late final Barcode _barcode = barcodeFor(
    symbology,
    errorCorrection: errorCorrection,
  );

  /// Whether [data] could be encoded and something other than the
  /// placeholder is painted.
  late final bool isEncodable = data.isNotEmpty && _barcode.isValid(data);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final Rect bounds = Offset.zero & size;
    if (backgroundColor case final Color background) {
      canvas.drawRect(bounds, Paint()..color = background);
    }
    final bool painted = symbology.is2D
        ? _paint2D(canvas, size)
        : _paint1D(canvas, size);
    if (!painted) _paintPlaceholder(canvas, size);
  }

  bool _paint2D(Canvas canvas, Size size) {
    if (!isEncodable) return false;
    final List<BarcodeBar> bars;
    try {
      // Square-module codes are laid out by the encoder: as large as fits,
      // centered. PDF417 is laid out at the full width and an unbounded
      // height, then stretched to the canvas height below.
      bars = _barcode
          .make(
            data,
            width: size.width,
            height: symbology.hasSquareModules ? size.height : 1e6,
          )
          .whereType<BarcodeBar>()
          .toList();
    } catch (_) {
      return false;
    }
    if (bars.isEmpty) return false;

    double top = 0;
    double scaleY = 1;
    if (!symbology.hasSquareModules) {
      // Every row yields bars (dark and light) across its full width, so the
      // bars' extent is the code's.
      top = bars.map((bar) => bar.top).reduce(math.min);
      final double bottom = bars.map((bar) => bar.bottom).reduce(math.max);
      if (bottom <= top) return false;
      scaleY = size.height / (bottom - top);
    }

    // One path for every dark run, so neighboring modules don't show
    // anti-aliasing seams between them.
    final Path path = Path();
    for (final BarcodeBar bar in bars) {
      if (!bar.black) continue;
      path.addRect(
        Rect.fromLTWH(
          bar.left,
          (bar.top - top) * scaleY,
          bar.width,
          bar.height * scaleY,
        ),
      );
    }
    canvas.drawPath(path, Paint()..color = color);
    return true;
  }

  bool _paint1D(Canvas canvas, Size size) {
    if (!isEncodable) return false;
    // Text needs some room under the bars to stay legible.
    final bool withText = drawText && size.height >= 24;
    final double fontHeight = withText
        ? (size.height * 0.2).clamp(8.0, 20.0)
        : 0;
    final List<BarcodeElement> elements;
    try {
      elements = _barcode
          .make(
            data,
            width: size.width,
            height: size.height,
            drawText: withText,
            fontHeight: withText ? fontHeight : null,
          )
          .toList();
    } catch (_) {
      return false;
    }

    final Path path = Path();
    for (final BarcodeElement element in elements) {
      if (element is BarcodeBar && element.black) {
        path.addRect(
          Rect.fromLTWH(
            element.left,
            element.top,
            element.width,
            element.height,
          ),
        );
      }
    }
    canvas.drawPath(path, Paint()..color = color);

    for (final BarcodeElement element in elements) {
      if (element is! BarcodeText) continue;
      _paintText(canvas, element, fontHeight);
    }
    return true;
  }

  void _paintText(Canvas canvas, BarcodeText element, double fontHeight) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: element.text,
        style: (textStyle ?? const TextStyle()).copyWith(
          color: color,
          fontSize: fontHeight,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    // Shrink text that is wider than its zone, e.g. long Code 128 data.
    final double scale = painter.width > element.width && painter.width > 0
        ? element.width / painter.width
        : 1;
    final double width = painter.width * scale;
    final double height = painter.height * scale;
    final double left = switch (element.align) {
      BarcodeTextAlign.left => element.left,
      BarcodeTextAlign.center => element.left + (element.width - width) / 2,
      BarcodeTextAlign.right => element.left + element.width - width,
    };
    final double top = element.top + (element.height - height) / 2;
    canvas.save();
    canvas.translate(left, top);
    canvas.scale(scale);
    painter.paint(canvas, Offset.zero);
    canvas.restore();
    painter.dispose();
  }

  /// A light outlined box with a cross: where the code would be.
  void _paintPlaceholder(Canvas canvas, Size size) {
    final Rect rect = (Offset.zero & size).deflate(0.5);
    canvas.drawRect(rect, Paint()..color = color.withValues(alpha: 0.06));
    final Paint stroke = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(rect, stroke);
    canvas.drawLine(rect.topLeft, rect.bottomRight, stroke);
    canvas.drawLine(rect.topRight, rect.bottomLeft, stroke);
  }

  @override
  bool shouldRepaint(covariant BarcodePainter oldDelegate) =>
      oldDelegate.data != data ||
      oldDelegate.symbology != symbology ||
      oldDelegate.errorCorrection != errorCorrection ||
      oldDelegate.color != color ||
      oldDelegate.backgroundColor != backgroundColor ||
      oldDelegate.drawText != drawText ||
      oldDelegate.textStyle != textStyle;
}
