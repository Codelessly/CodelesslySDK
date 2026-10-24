import 'dart:convert';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../codelessly_sdk.dart';
import '../utils/node_state_provider.dart';

/// A stroke of a signature: its points, in the pad's coordinates.
typedef SignatureStroke = List<Offset>;

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

  /// Builds a signature pad that keeps its strokes to itself, for previews
  /// such as the settings panel.
  Widget buildPreview({
    SignatureProperties? properties,
    SignatureNode? node,
    double? height,
    double? width,
  }) {
    final SignatureNode previewNode = SignatureNode(
      id: '',
      name: 'Signature',
      basicBoxLocal: NodeBox(
        0,
        0,
        width ?? node?.basicBoxLocal.width ?? kSignatureDefaultWidth,
        height ?? node?.basicBoxLocal.height ?? kSignatureDefaultHeight,
      ),
      properties: properties ?? node?.properties ?? SignatureProperties(),
    );
    return TransformerSignature(
      node: previewNode,
      strokes: const [],
      error: previewNode.properties.error,
    );
  }
}

/// A signature pad whose strokes live in the node's bound `value` variable,
/// or its node value when nothing is bound.
///
/// Each finished stroke writes all the strokes to it, as a list of strokes
/// of `[x, y]` points, and fires [TriggerType.changed]. Setting the
/// variable to `[]` clears the pad.
class PassiveSignatureWidget extends StatelessWidget {
  final SignatureNode node;
  final WidgetBuildSettings settings;
  final List<VariableData> variablesOverrides;

  const PassiveSignatureWidget({
    super.key,
    required this.node,
    required this.settings,
    this.variablesOverrides = const [],
  });

  /// Reads strokes from a node value or a variable: a list of strokes, or
  /// its JSON text, such as `[[[10, 20], [12, 24]]]`. Returns null when
  /// [value] holds no strokes, e.g. an unset variable.
  static List<SignatureStroke>? parseStrokes(Object? value) {
    Object? json = value;
    if (json is String) {
      final String text = json.trim();
      if (text.isEmpty) return const [];
      try {
        json = jsonDecode(text);
      } on FormatException {
        return null;
      }
    }
    if (json is! List) return null;
    return [
      for (final List<List<double>> stroke in strokesFromJson(json))
        [for (final List<double> point in stroke) Offset(point[0], point[1])],
    ];
  }

  /// [strokes] as JSON: a list of strokes of `[x, y]` points.
  static List<List<List<double>>> strokesToJson(
    List<SignatureStroke> strokes,
  ) => [
    for (final SignatureStroke stroke in strokes)
      [
        for (final Offset point in stroke) [point.dx, point.dy],
      ],
  ];

  void onStrokesChanged(BuildContext context, List<SignatureStroke> strokes) {
    // Without a runtime, e.g. on a design canvas, the pad keeps its strokes.
    if (context.read<CodelesslyContext?>() == null) return;
    final List<List<List<double>>> value = strokesToJson(strokes);
    NodeStateProvider.setState(context, value);
    FunctionsRepository.setPropertyValue(
      context,
      node: node,
      property: 'value',
      value: value,
    );
    FunctionsRepository.triggerAction(
      context,
      node: node,
      TriggerType.changed,
      value: value,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ScopedValues scopedValues = ScopedValues.of(
      context,
      variablesOverrides: variablesOverrides,
    );
    final List<SignatureStroke> strokes =
        parseStrokes(
          PropertyValueDelegate.getPropertyValue<Object>(
            node,
            'value',
            scopedValues: scopedValues,
          ),
        ) ??
        parseStrokes(node.value) ??
        const [];
    final bool error =
        PropertyValueDelegate.getPropertyValue<bool>(
          node,
          'error',
          scopedValues: scopedValues,
        ) ??
        node.properties.error;
    final bool enabled =
        PropertyValueDelegate.getPropertyValue<bool>(
          node,
          'enabled',
          scopedValues: scopedValues,
        ) ??
        node.properties.enabled;

    return TransformerSignature(
      key: ValueKey(
        'signature ${node.id}-${IndexedItemProvider.maybeOf(context)?.index ?? ''}',
      ),
      node: node,
      strokes: strokes,
      error: error,
      onChanged: enabled ? onStrokesChanged : null,
    );
  }
}

/// Draws a signature pad and records the strokes drawn on it.
///
/// It shows [strokes] until the user draws: a finished stroke is added to
/// the ones shown and reported with [onChanged]. When [strokes] changes from
/// outside, e.g. a variable is cleared, it shows the new strokes. Without
/// [onChanged], it does not take input.
class TransformerSignature extends StatefulWidget {
  final SignatureNode node;
  final List<SignatureStroke> strokes;
  final bool error;
  final void Function(BuildContext context, List<SignatureStroke> strokes)?
  onChanged;

  const TransformerSignature({
    super.key,
    required this.node,
    required this.strokes,
    this.error = false,
    this.onChanged,
  });

  @override
  State<TransformerSignature> createState() => _TransformerSignatureState();
}

class _TransformerSignatureState extends State<TransformerSignature> {
  static const ListEquality<SignatureStroke> _strokesEquality = ListEquality(
    ListEquality<Offset>(),
  );

  late List<SignatureStroke> strokes = [...widget.strokes];
  SignatureStroke? current;

  @override
  void didUpdateWidget(covariant TransformerSignature oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_strokesEquality.equals(oldWidget.strokes, widget.strokes) &&
        !_strokesEquality.equals(strokes, widget.strokes)) {
      strokes = [...widget.strokes];
      current = null;
    }
  }

  /// Rounds [point] to a tenth of a pixel, so the strokes read back from a
  /// variable's text equal the ones drawn.
  Offset _round(Offset point) => Offset(
    (point.dx * 10).roundToDouble() / 10,
    (point.dy * 10).roundToDouble() / 10,
  );

  void onStart(DragStartDetails details) =>
      setState(() => current = [_round(details.localPosition)]);

  void onUpdate(DragUpdateDetails details) {
    final SignatureStroke? stroke = current;
    if (stroke == null) return;
    final Offset point = _round(details.localPosition);
    if (stroke.isNotEmpty && stroke.last == point) return;
    setState(() => stroke.add(point));
  }

  void onEnd([Object? _]) {
    final SignatureStroke? stroke = current;
    if (stroke == null) return;
    setState(() {
      strokes = [...strokes, stroke];
      current = null;
    });
    widget.onChanged?.call(context, strokes);
  }

  @override
  Widget build(BuildContext context) {
    final SignatureProperties properties = widget.node.properties;
    final BorderRadius borderRadius = properties.cornerRadius.borderRadius;
    final Widget pad = DecoratedBox(
      decoration: BoxDecoration(
        color: properties.backgroundColor.toFlutterColor(),
        borderRadius: borderRadius,
        border: Border.all(
          color: widget.error
              ? properties.errorBorderColor.toFlutterColor()
              : properties.borderColor.toFlutterColor(),
          width: widget.error
              ? properties.errorBorderWidth
              : properties.borderWidth,
        ),
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: CustomPaint(
          painter: SignaturePainter(
            strokes: [...strokes, ?current],
            properties: properties,
            textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );

    final Widget sized = SizedBox(
      width: widget.node.basicBoxLocal.width,
      height: widget.node.basicBoxLocal.height,
      child: pad,
    );

    if (widget.onChanged == null) return sized;

    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        _EagerPanGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<_EagerPanGestureRecognizer>(
              _EagerPanGestureRecognizer.new,
              (recognizer) => recognizer
                ..dragStartBehavior = DragStartBehavior.down
                ..onStart = onStart
                ..onUpdate = onUpdate
                ..onEnd = onEnd
                ..onCancel = onEnd,
            ),
      },
      child: sized,
    );
  }
}

/// A pan recognizer that wins the gesture arena as soon as a pointer goes
/// down, so a scrolling parent does not take a stroke that starts
/// vertically.
class _EagerPanGestureRecognizer extends PanGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolvePointer(event.pointer, GestureDisposition.accepted);
  }
}

/// Paints the sign line, the placeholder while there are no strokes, and the
/// strokes, smoothed with quadratic curves through their midpoints.
class SignaturePainter extends CustomPainter {
  final List<SignatureStroke> strokes;
  final SignatureProperties properties;
  final TextDirection textDirection;

  SignaturePainter({
    required this.strokes,
    required this.properties,
    required this.textDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (properties.showSignLine) paintSignLine(canvas, size);
    if (strokes.isEmpty && properties.placeholder.isNotEmpty) {
      paintPlaceholder(canvas, size);
    }

    final Paint ink = Paint()
      ..color = properties.inkColor.toFlutterColor()
      ..strokeWidth = properties.inkWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    for (final SignatureStroke stroke in strokes) {
      if (stroke.isEmpty) continue;
      if (stroke.length == 1) {
        canvas.drawCircle(
          stroke.first,
          properties.inkWidth / 2,
          Paint()..color = ink.color,
        );
        continue;
      }
      canvas.drawPath(smoothPath(stroke), ink);
    }
  }

  /// A path through [points] that bends at each point with a quadratic curve
  /// from the midpoint before it to the midpoint after it.
  static Path smoothPath(SignatureStroke points) {
    final Path path = Path()..moveTo(points.first.dx, points.first.dy);
    if (points.length == 2) {
      return path..lineTo(points.last.dx, points.last.dy);
    }
    for (int i = 1; i < points.length - 1; i++) {
      final Offset point = points[i];
      final Offset mid = (point + points[i + 1]) / 2;
      path.quadraticBezierTo(point.dx, point.dy, mid.dx, mid.dy);
    }
    return path..lineTo(points.last.dx, points.last.dy);
  }

  void paintSignLine(Canvas canvas, Size size) {
    const double inset = 20;
    final double y = size.height - size.height * 0.24;
    if (size.width <= inset * 2 || y <= 0) return;
    final Paint line = Paint()
      ..color = properties.signLineColor.toFlutterColor()
      ..strokeWidth = 1;
    canvas.drawLine(Offset(inset, y), Offset(size.width - inset, y), line);

    final TextPainter cross = TextPainter(
      text: TextSpan(
        text: '×',
        style: TextStyle(
          color: properties.signLineColor.toFlutterColor(),
          fontSize: 16,
          height: 1,
        ),
      ),
      textDirection: textDirection,
    )..layout();
    cross.paint(canvas, Offset(inset, y - cross.height - 4));
    cross.dispose();
  }

  void paintPlaceholder(Canvas canvas, Size size) {
    final TextPainter text = TextPainter(
      text: TextSpan(
        text: properties.placeholder,
        style: TextStyle(
          color: properties.placeholderColor.toFlutterColor(),
          fontSize: properties.placeholderFontSize,
          fontWeight: FontWeight.w600,
          letterSpacing: properties.placeholderFontSize * 0.12,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: textDirection,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: size.width);
    text.paint(
      canvas,
      Offset((size.width - text.width) / 2, (size.height - text.height) / 2),
    );
    text.dispose();
  }

  // Strokes grow in place while the user draws.
  @override
  bool shouldRepaint(covariant SignaturePainter oldDelegate) => true;
}
