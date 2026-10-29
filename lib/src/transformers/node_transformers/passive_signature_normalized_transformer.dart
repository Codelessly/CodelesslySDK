import 'dart:convert';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../codelessly_sdk.dart';
import '../utils/node_state_provider.dart';

/// The normalized signature is deliberately separate from the pixel-space pad.
class PassiveSignatureNormalizedTransformer
    extends NodeWidgetTransformer<SignatureNormalizedNode> {
  PassiveSignatureNormalizedTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    SignatureNormalizedNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) => PassiveSignatureNormalizedWidget(node: node, settings: settings);
}

/// A signature whose stored coordinates are fractions of the rendered box.
class PassiveSignatureNormalizedWidget extends StatefulWidget {
  final SignatureNormalizedNode node;
  final WidgetBuildSettings settings;
  final List<VariableData> variablesOverrides;

  const PassiveSignatureNormalizedWidget({
    super.key,
    required this.node,
    required this.settings,
    this.variablesOverrides = const [],
  });

  @override
  State<PassiveSignatureNormalizedWidget> createState() =>
      _PassiveSignatureNormalizedWidgetState();
}

class _PassiveSignatureNormalizedWidgetState
    extends State<PassiveSignatureNormalizedWidget> {
  static const _equality = DeepCollectionEquality();
  List<List<List<double>>> _strokes = [];
  List<List<double>>? _current;
  List<List<List<double>>>? _lastExternal;

  List<List<List<double>>> _parse(Object? value) {
    if (value is String) {
      try {
        value = jsonDecode(value);
      } on FormatException {
        return [];
      }
    }
    if (value is! List) {
      return [];
    }
    final result = <List<List<double>>>[];
    for (final stroke in value) {
      if (stroke is! List) {
        return [];
      }
      final points = <List<double>>[];
      for (final point in stroke) {
        if (point is! List ||
            point.length != 2 ||
            point[0] is! num ||
            point[1] is! num) {
          return [];
        }
        final x = (point[0] as num).toDouble();
        final y = (point[1] as num).toDouble();
        if (!x.isFinite || !y.isFinite || x < 0 || x > 1 || y < 0 || y > 1) {
          return [];
        }
        points.add([x, y]);
      }
      result.add(points);
    }
    return result;
  }

  void _start(DragStartDetails details, Size size) {
    setState(() => _current = [_point(details.localPosition, size)]);
  }

  void _update(DragUpdateDetails details, Size size) {
    if (_current == null) return;
    final point = _point(details.localPosition, size);
    if (_equality.equals(_current!.last, point)) return;
    setState(() => _current!.add(point));
  }

  List<double> _point(Offset position, Size size) => [
    (position.dx / size.width).clamp(0.0, 1.0),
    (position.dy / size.height).clamp(0.0, 1.0),
  ];

  void _end([Object? _]) {
    final current = _current;
    if (current == null) return;
    setState(() {
      _strokes = [..._strokes, current];
      _current = null;
    });
    if (context.read<CodelesslyContext?>() == null) return;
    NodeStateProvider.setState(context, _strokes);
    FunctionsRepository.setPropertyValue(
      context,
      node: widget.node,
      property: 'value',
      value: _strokes,
    );
    FunctionsRepository.triggerAction(
      context,
      node: widget.node,
      TriggerType.changed,
      value: _strokes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final values = ScopedValues.of(
      context,
      variablesOverrides: widget.variablesOverrides,
    );
    final bound = PropertyValueDelegate.getPropertyValue<Object>(
      node,
      'value',
      scopedValues: values,
    );
    final external = bound == null ? _parse(node.strokes) : _parse(bound);
    if (_lastExternal == null ||
        (!_equality.equals(external, _lastExternal) &&
            !_equality.equals(external, _strokes))) {
      _strokes = external;
      _current = null;
    }
    _lastExternal = external;

    final readOnly =
        PropertyValueDelegate.getPropertyValue<bool>(
          node,
          'readOnly',
          scopedValues: values,
        ) ??
        node.properties.readOnly;
    final enabled =
        PropertyValueDelegate.getPropertyValue<bool>(
          node,
          'enabled',
          scopedValues: values,
        ) ??
        node.enabled;
    final color =
        PropertyValueDelegate.getPropertyValue<ColorRGBA>(
          node,
          'inkColor',
          scopedValues: values,
        ) ??
        node.properties.inkColor;

    return SizedBox(
      width: node.basicBoxLocal.width,
      height: node.basicBoxLocal.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final paint = CustomPaint(
            painter: SignatureNormalizedPainter(
              strokes: [..._strokes, ?_current],
              inkColor: color.toFlutterColor(),
              strokeWidth: node.properties.strokeWidth,
            ),
            child: const SizedBox.expand(),
          );
          if (readOnly || !enabled || size.width <= 0 || size.height <= 0) {
            return paint;
          }
          return RawGestureDetector(
            behavior: HitTestBehavior.opaque,
            gestures: {
              _NormalizedPanRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                    _NormalizedPanRecognizer
                  >(_NormalizedPanRecognizer.new, (recognizer) {
                    recognizer.dragStartBehavior = DragStartBehavior.down;
                    recognizer.onStart = (details) {
                      _start(details, size);
                    };
                    recognizer.onUpdate = (details) {
                      _update(details, size);
                    };
                    recognizer.onEnd = _end;
                    recognizer.onCancel = _end;
                  }),
            },
            child: paint,
          );
        },
      ),
    );
  }
}

class _NormalizedPanRecognizer extends PanGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolvePointer(event.pointer, GestureDisposition.accepted);
  }
}

/// Paints fractional points at the current size, without a border or backdrop.
class SignatureNormalizedPainter extends CustomPainter {
  final List<List<List<double>>> strokes;
  final Color inkColor;
  final double strokeWidth;

  SignatureNormalizedPainter({
    required this.strokes,
    required this.inkColor,
    required this.strokeWidth,
  });

  /// Converts stored fractional points into paint-space points at [size].
  static List<Offset> scaledPoints(List<List<double>> stroke, Size size) => [
    for (final point in stroke)
      Offset(point[0] * size.width, point[1] * size.height),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()
      ..color = inkColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    for (final stroke in strokes) {
      final points = scaledPoints(stroke, size);
      if (points.isEmpty) continue;
      if (points.length == 1) {
        canvas.drawCircle(
          points.first,
          strokeWidth / 2,
          Paint()..color = inkColor,
        );
      } else {
        canvas.drawPath(SignaturePainter.smoothPath(points), ink);
      }
    }
  }

  @override
  bool shouldRepaint(covariant SignatureNormalizedPainter oldDelegate) =>
      !_equality.equals(strokes, oldDelegate.strokes) ||
      inkColor != oldDelegate.inkColor ||
      strokeWidth != oldDelegate.strokeWidth;

  static const _equality = DeepCollectionEquality();
}
