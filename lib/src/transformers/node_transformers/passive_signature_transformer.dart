import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';

/// A signature drawn as strokes of `[x, y]` points normalized to the box.
typedef SignatureStrokes = List<List<List<double>>>;

class PassiveSignatureTransformer extends NodeWidgetTransformer<SignatureNode> {
  PassiveSignatureTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    SignatureNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) {
    return PassiveSignatureWidget(node: node, settings: settings);
  }
}

/// Reads a signature from a bound value: a list of strokes, each a list of
/// `[x, y]` pairs. Anything else reads as no signature.
SignatureStrokes parseSignatureStrokes(Object? value) {
  if (value is! List) return [];
  final SignatureStrokes strokes = [];
  for (final Object? stroke in value) {
    if (stroke is! List) continue;
    final List<List<double>> points = [];
    for (final Object? point in stroke) {
      if (point is List && point.length >= 2) {
        final Object? x = point[0];
        final Object? y = point[1];
        if (x is num && y is num) points.add([x.toDouble(), y.toDouble()]);
      }
    }
    if (points.isNotEmpty) strokes.add(points);
  }
  return strokes;
}

class PassiveSignatureWidget extends StatefulWidget {
  final SignatureNode node;
  final WidgetBuildSettings settings;

  const PassiveSignatureWidget({
    super.key,
    required this.node,
    required this.settings,
  });

  @override
  State<PassiveSignatureWidget> createState() => _PassiveSignatureWidgetState();
}

class _PassiveSignatureWidgetState extends State<PassiveSignatureWidget> {
  /// The stroke being drawn, kept here until the finger lifts so a moving
  /// pen repaints only this box.
  List<List<double>>? _stroke;

  /// The strokes there were when the current stroke began.
  SignatureStrokes _base = [];

  /// The strokes this box last wrote, for a box with no bound value.
  SignatureStrokes? _written;

  SignatureNode get node => widget.node;

  SignatureStrokes _boundStrokes(ScopedValues scopedValues) {
    if (!node.variables.containsKey('value')) return _written ?? node.strokes;
    return parseSignatureStrokes(
      PropertyValueDelegate.getPropertyValue<Object>(
        node,
        'value',
        scopedValues: scopedValues,
      ),
    );
  }

  List<double> _normalize(Offset p, Size size) => [
    double.parse((p.dx / size.width).clamp(0, 1).toStringAsFixed(4)),
    double.parse((p.dy / size.height).clamp(0, 1).toStringAsFixed(4)),
  ];

  void _write(SignatureStrokes strokes) {
    _written = strokes;
    FunctionsRepository.setPropertyValue(
      context,
      node: node,
      property: 'value',
      value: strokes,
    );
    FunctionsRepository.triggerAction(
      context,
      node: node,
      TriggerType.changed,
      value: strokes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ScopedValues scopedValues = ScopedValues.of(context);
    final SignatureStrokes strokes = _boundStrokes(scopedValues);
    final bool readOnly =
        PropertyValueDelegate.getPropertyValue<bool>(
          node,
          'readOnly',
          scopedValues: scopedValues,
        ) ??
        node.properties.readOnly;
    final Color ink =
        (PropertyValueDelegate.getPropertyValue<ColorRGBA>(
                  node,
                  'inkColor',
                  scopedValues: scopedValues,
                ) ??
                node.properties.inkColor)
            .toFlutterColor();
    final bool interactive =
        !readOnly && node.enabled && !widget.settings.isPreview;

    return SizedBox(
      width: node.basicBoxLocal.width,
      height: node.basicBoxLocal.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final Size size = constraints.biggest;
          final Widget paint = CustomPaint(
            size: size,
            painter: SignaturePainter(
              strokes: [...strokes, if (_stroke case final stroke?) stroke],
              color: ink,
              strokeWidth: node.properties.strokeWidth,
            ),
          );
          final String label = readOnly
              ? 'Signature'
              : strokes.isEmpty
              ? 'Signature pad, empty'
              : 'Signature pad, signed';
          if (!interactive) {
            return Semantics(container: true, label: label, child: paint);
          }
          return Semantics(
            container: true,
            label: label,
            child: MouseRegion(
              cursor: SystemMouseCursors.precise,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (details) {
                  _base = strokes;
                  setState(
                    () => _stroke = [_normalize(details.localPosition, size)],
                  );
                  // Writing the first point at once lets a "sign here" hint
                  // and the sign button react as the pen goes down.
                  _write([...strokes, _stroke!]);
                },
                onPanUpdate: (details) => setState(
                  () => _stroke?.add(_normalize(details.localPosition, size)),
                ),
                onPanEnd: (_) => _finishStroke(),
                onPanCancel: _finishStroke,
                child: paint,
              ),
            ),
          );
        },
      ),
    );
  }

  void _finishStroke() {
    final List<List<double>>? stroke = _stroke;
    if (stroke == null) return;
    setState(() => _stroke = null);
    _write([..._base, stroke]);
  }

  @override
  void didUpdateWidget(PassiveSignatureWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node.id != node.id) {
      _stroke = null;
      _written = null;
    }
  }
}

/// Paints signature strokes with round ink, points normalized to the size.
class SignaturePainter extends CustomPainter {
  final SignatureStrokes strokes;
  final Color color;
  final double strokeWidth;

  SignaturePainter({
    required this.strokes,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint ink = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final List<List<double>> stroke in strokes) {
      if (stroke.isEmpty) continue;
      Offset at(List<double> p) => Offset(p[0] * size.width, p[1] * size.height);
      final Offset first = at(stroke.first);
      final Path path = Path()..moveTo(first.dx, first.dy);
      // A tap leaves a dot.
      if (stroke.length == 1) path.lineTo(first.dx + 0.1, first.dy);
      for (final List<double> p in stroke.skip(1)) {
        final Offset o = at(p);
        path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path, ink);
    }
  }

  @override
  bool shouldRepaint(SignaturePainter oldDelegate) => true;
}
