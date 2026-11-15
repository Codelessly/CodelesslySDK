import 'package:material_ui/material_ui.dart';
import 'package:skip_shell/storyboard/models/flow_step.dart';
import 'package:skip_shell/storyboard/models/phone_frame.dart';

/// A widget that displays a single flow of screens in phone frames with connecting arrows
/// Automatically scales to fit the entire flow in the viewport
class SingleFlowViewer extends StatefulWidget {
  final FlowDefinition flow;
  final bool isDarkMode;
  final PhoneFrame frame;

  const SingleFlowViewer({
    super.key,
    required this.flow,
    required this.isDarkMode,
    this.frame = PhoneFrames.iphone17Pro,
  });

  @override
  State<SingleFlowViewer> createState() => _SingleFlowViewerState();
}

class _SingleFlowViewerState extends State<SingleFlowViewer> {
  final TransformationController _transformationController =
      TransformationController();

  static const double _horizontalSpacing = 100.0;
  static const double _verticalSpacing = 60.0;
  static const double _labelHeight = 36.0;
  static const double _arrowHeadSize = 12.0;
  static const double _contentPadding = 24.0;
  static const double _minScale = 0.15;
  static const double _maxScale = 1.0;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  double _calculateOptimalScale(BoxConstraints constraints) {
    final rows = widget.flow.rowCount;
    final maxCols = widget.flow.maxColumns;

    if (rows == 0 || maxCols == 0) return 0.35;

    final frameWidth = widget.frame.width;
    final frameHeight = widget.frame.height;

    final availableWidth = constraints.maxWidth - (_contentPadding * 2);
    final availableHeight = constraints.maxHeight - (_contentPadding * 2);

    // Scale the spacing along with the frames so gaps stay proportional
    // totalWidth = scale * (maxCols * frameWidth + (maxCols - 1) * horizontalSpacing)
    // scale = availableWidth / (maxCols * frameWidth + (maxCols - 1) * horizontalSpacing)
    final totalUnscaledWidth = maxCols * frameWidth + (maxCols - 1) * _horizontalSpacing;
    final scaleToFitWidth = availableWidth / totalUnscaledWidth;

    // totalHeight = scale * (rows * frameHeight + (rows - 1) * verticalSpacing) + rows * labelHeight
    // Note: labelHeight doesn't scale to keep text readable
    final totalUnscaledHeight = rows * frameHeight + (rows - 1) * _verticalSpacing;
    final heightForFrames = availableHeight - rows * _labelHeight;
    final scaleToFitHeight = heightForFrames / totalUnscaledHeight;

    final optimalScale = scaleToFitWidth < scaleToFitHeight
        ? scaleToFitWidth
        : scaleToFitHeight;

    return optimalScale.clamp(_minScale, _maxScale);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = _calculateOptimalScale(constraints);

        return InteractiveViewer(
          transformationController: _transformationController,
          constrained: false,
          minScale: 0.1,
          maxScale: 2.0,
          boundaryMargin: EdgeInsets.symmetric(
            horizontal: constraints.maxWidth,
            vertical: constraints.maxHeight,
          ),
          child: Container(
            constraints: BoxConstraints(
              minWidth: constraints.maxWidth,
              minHeight: constraints.maxHeight,
            ),
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.all(_contentPadding),
              child: CustomPaint(
                painter: _FlowArrowPainter(
                  flow: widget.flow,
                  scale: scale,
                  frameWidth: widget.frame.width,
                  frameHeight: widget.frame.height,
                  horizontalSpacing: _horizontalSpacing * scale,
                  verticalSpacing: _verticalSpacing * scale,
                  labelHeight: _labelHeight * scale,
                  arrowColor: widget.isDarkMode
                      ? Colors.white.withValues(alpha: 0.6)
                      : Colors.black.withValues(alpha: 0.5),
                  arrowHeadSize: (_arrowHeadSize * scale).clamp(4.0, _arrowHeadSize),
                  strokeWidth: (2.5 * scale).clamp(1.0, 2.5),
                ),
                child: _buildFlowContent(scale),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFlowContent(double scale) {
    final scaledFrameWidth = widget.frame.width * scale;
    final scaledFrameHeight = widget.frame.height * scale;
    final scaledHorizontalSpacing = _horizontalSpacing * scale;
    final scaledVerticalSpacing = _verticalSpacing * scale;
    final scaledLabelHeight = _labelHeight * scale;

    final rows = widget.flow.rowCount;
    final maxCols = widget.flow.maxColumns;

    final stepHeight = scaledLabelHeight + scaledFrameHeight;

    final totalWidth =
        maxCols * scaledFrameWidth + (maxCols - 1) * scaledHorizontalSpacing;
    final totalHeight = rows * stepHeight + (rows - 1) * scaledVerticalSpacing;

    return SizedBox(
      width: totalWidth,
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int row = 0; row < rows; row++)
            ..._buildRow(row, scaledFrameWidth, scaledFrameHeight, stepHeight,
                scaledHorizontalSpacing, scaledVerticalSpacing, scale),
        ],
      ),
    );
  }

  List<Widget> _buildRow(
      int row, double scaledFrameWidth, double scaledFrameHeight, double stepHeight,
      double scaledHorizontalSpacing, double scaledVerticalSpacing, double scale) {
    final steps = widget.flow.getStepsInRow(row);
    final widgets = <Widget>[];

    for (final step in steps) {
      final left = step.column * (scaledFrameWidth + scaledHorizontalSpacing);
      final top = step.row * (stepHeight + scaledVerticalSpacing);

      widgets.add(
        Positioned(
          left: left,
          top: top,
          child: _buildStepFrame(step, scaledFrameWidth, scaledFrameHeight, scale),
        ),
      );
    }

    return widgets;
  }

  Widget _buildStepFrame(
      FlowStep step, double scaledFrameWidth, double scaledFrameHeight, double scale) {
    // Scale font size with layout, minimum of 6px
    final fontSize = (12.0 * scale).clamp(6.0, 12.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: scaledFrameWidth,
          padding: EdgeInsets.only(bottom: 8 * scale),
          child: Text(
            step.label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: widget.isDarkMode
                  ? Colors.white.withValues(alpha: 0.9)
                  : Colors.black87,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(
          width: scaledFrameWidth,
          height: scaledFrameHeight,
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: widget.frame.width,
              height: widget.frame.height,
              child: _buildPhoneContent(step),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneContent(FlowStep step) {
    final wrappedChild = PopScope(
      canPop: false,
      child: Navigator(
        key: ValueKey('flow_nav_${step.id}'),
        pages: [
          MaterialPage(
            key: ValueKey('flow_page_${step.id}'),
            child: step.builder(),
          ),
        ],
        onDidRemovePage: (page) {},
      ),
    );

    final contentWithMediaQuery = MediaQuery(
      data: MediaQueryData(
        size: Size(widget.frame.width, widget.frame.height),
        devicePixelRatio: widget.frame.devicePixelRatio,
        textScaler: const TextScaler.linear(1.0),
        padding: _getPaddingForFrame(widget.frame),
      ),
      child: wrappedChild,
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.frame.borderRadius),
        border: Border.all(
          color: widget.isDarkMode ? Colors.white24 : Colors.black26,
          width: 6,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.frame.borderRadius - 3),
        child: contentWithMediaQuery,
      ),
    );
  }

  EdgeInsets _getPaddingForFrame(PhoneFrame frame) {
    if (frame == PhoneFrames.iphone17Pro ||
        frame == PhoneFrames.iphone17) {
      return const EdgeInsets.only(top: 47, bottom: 34);
    }

    if (frame == PhoneFrames.iphoneSE4) {
      return const EdgeInsets.only(top: 47, bottom: 34);
    }

    if (frame.platform == 'android') {
      return const EdgeInsets.only(top: 24, bottom: 16);
    }

    return const EdgeInsets.only(top: 24, bottom: 0);
  }
}

class _FlowArrowPainter extends CustomPainter {
  final FlowDefinition flow;
  final double scale;
  final double frameWidth;
  final double frameHeight;
  final double horizontalSpacing;
  final double verticalSpacing;
  final double labelHeight;
  final Color arrowColor;
  final double arrowHeadSize;
  final double strokeWidth;

  _FlowArrowPainter({
    required this.flow,
    required this.scale,
    required this.frameWidth,
    required this.frameHeight,
    required this.horizontalSpacing,
    required this.verticalSpacing,
    required this.labelHeight,
    required this.arrowColor,
    required this.arrowHeadSize,
    this.strokeWidth = 2.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = arrowColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final arrowPaint = Paint()
      ..color = arrowColor
      ..style = PaintingStyle.fill;

    final scaledFrameWidth = frameWidth * scale;
    final scaledFrameHeight = frameHeight * scale;

    for (final connection in flow.connections) {
      final fromStep =
          flow.steps.firstWhere((s) => s.id == connection.fromStepId);
      final toStep = flow.steps.firstWhere((s) => s.id == connection.toStepId);

      final fromX =
          fromStep.column * (scaledFrameWidth + horizontalSpacing) +
              scaledFrameWidth / 2;
      final fromY =
          fromStep.row * (scaledFrameHeight + verticalSpacing + labelHeight) +
              labelHeight +
              scaledFrameHeight / 2;

      final toX = toStep.column * (scaledFrameWidth + horizontalSpacing) +
          scaledFrameWidth / 2;
      final toY =
          toStep.row * (scaledFrameHeight + verticalSpacing + labelHeight) +
              labelHeight +
              scaledFrameHeight / 2;

      switch (connection.type) {
        case FlowConnectionType.horizontal:
          _drawHorizontalArrow(
            canvas,
            paint,
            arrowPaint,
            fromX + scaledFrameWidth / 2,
            fromY,
            toX - scaledFrameWidth / 2,
            toY,
          );
          break;

        case FlowConnectionType.vertical:
          _drawVerticalArrow(
            canvas,
            paint,
            arrowPaint,
            fromX,
            fromY + scaledFrameHeight / 2,
            toX,
            toY - scaledFrameHeight / 2 - labelHeight,
          );
          break;

        case FlowConnectionType.branch:
          _drawDownArrow(
            canvas,
            paint,
            arrowPaint,
            fromX + scaledFrameWidth / 2,
            fromY,
            toX - scaledFrameWidth / 2,
            toY,
            scaledFrameHeight,
            horizontalSpacing,
          );
          break;

        case FlowConnectionType.downToNextRow:
          _drawBranchArrow(
            canvas,
            paint,
            arrowPaint,
            fromX,
            fromY + scaledFrameHeight / 2,
            toX,
            toY - scaledFrameHeight / 2 - labelHeight,
          );
          break;

        case FlowConnectionType.upFromPreviousRow:
          _drawUpArrow(
            canvas,
            paint,
            arrowPaint,
            fromX + scaledFrameWidth / 2,
            fromY,
            toX - scaledFrameWidth / 2,
            toY,
            scaledFrameHeight,
            horizontalSpacing,
          );
          break;
      }
    }
  }

  void _drawHorizontalArrow(
    Canvas canvas,
    Paint linePaint,
    Paint arrowPaint,
    double fromX,
    double fromY,
    double toX,
    double toY,
  ) {
    final path = Path();
    path.moveTo(fromX + 8, fromY);
    path.lineTo(toX - arrowHeadSize - 4, toY);
    canvas.drawPath(path, linePaint);

    _drawArrowHead(canvas, arrowPaint, toX - 4, toY, 0);
  }

  void _drawVerticalArrow(
    Canvas canvas,
    Paint linePaint,
    Paint arrowPaint,
    double fromX,
    double fromY,
    double toX,
    double toY,
  ) {
    final path = Path();
    path.moveTo(fromX, fromY + 8);
    path.lineTo(toX, toY - arrowHeadSize - 4);
    canvas.drawPath(path, linePaint);

    // Draw arrowhead pointing down
    _drawArrowHead(canvas, arrowPaint, toX, toY - 4, 90);
  }

  void _drawBranchArrow(
    Canvas canvas,
    Paint linePaint,
    Paint arrowPaint,
    double fromX,
    double fromY,
    double toX,
    double toY,
  ) {
    // Draw a curved path for branching
    final path = Path();
    final controlY = fromY + (toY - fromY) * 0.3;

    path.moveTo(fromX, fromY + 8);
    path.quadraticBezierTo(
      fromX,
      controlY,
      (fromX + toX) / 2,
      (fromY + toY) / 2,
    );
    path.quadraticBezierTo(
      toX,
      toY - (toY - fromY) * 0.3,
      toX,
      toY - arrowHeadSize - 4,
    );

    canvas.drawPath(path, linePaint);

    // Draw arrowhead pointing down
    _drawArrowHead(canvas, arrowPaint, toX, toY - 4, 90);
  }

  void _drawDownArrow(
    Canvas canvas,
    Paint linePaint,
    Paint arrowPaint,
    double fromX,
    double fromY,
    double toX,
    double toY,
    double frameHeight,
    double spacing,
  ) {
    // Draw path that goes: right -> down -> right (or left)
    // Start curving almost immediately (shifted 32px left from original)
    final path = Path();
    final midX = fromX + spacing / 2 - 32;

    path.moveTo(fromX + 8, fromY);
    path.lineTo(midX, fromY);
    path.quadraticBezierTo(midX + 20, fromY, midX + 20, fromY + 20);
    // Extend vertical line all the way down to target Y level
    path.lineTo(midX + 20, toY - 20);
    path.quadraticBezierTo(midX + 20, toY, midX + 40, toY);

    if (toX > fromX) {
      // Going right and down
      path.lineTo(toX - arrowHeadSize - 4, toY);
    } else {
      // Going left and down
      path.lineTo(toX + arrowHeadSize + 4, toY);
    }

    canvas.drawPath(path, linePaint);

    // Draw arrowhead
    _drawArrowHead(canvas, arrowPaint, toX - 4, toY, toX > fromX ? 0 : 180);
  }

  void _drawUpArrow(
    Canvas canvas,
    Paint linePaint,
    Paint arrowPaint,
    double fromX,
    double fromY,
    double toX,
    double toY,
    double frameHeight,
    double spacing,
  ) {
    // Draw path that goes: right -> up -> right
    // Start curving almost immediately (shifted 32px left from original)
    final path = Path();
    final midX = fromX + spacing / 2 - 32;

    path.moveTo(fromX + 8, fromY);
    path.lineTo(midX, fromY);
    path.quadraticBezierTo(midX + 20, fromY, midX + 20, fromY - 20);
    // Extend vertical line all the way up to target Y level
    path.lineTo(midX + 20, toY + 20);
    path.quadraticBezierTo(midX + 20, toY, midX + 40, toY);
    path.lineTo(toX - arrowHeadSize - 4, toY);

    canvas.drawPath(path, linePaint);

    // Draw arrowhead
    _drawArrowHead(canvas, arrowPaint, toX - 4, toY, 0);
  }

  void _drawArrowHead(
    Canvas canvas,
    Paint paint,
    double x,
    double y,
    double angleDegrees,
  ) {
    final angle = angleDegrees * 3.14159 / 180;

    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(angle);

    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(-arrowHeadSize, -arrowHeadSize / 2);
    path.lineTo(-arrowHeadSize, arrowHeadSize / 2);
    path.close();

    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FlowArrowPainter oldDelegate) {
    return oldDelegate.scale != scale ||
        oldDelegate.arrowColor != arrowColor ||
        oldDelegate.flow != flow ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.arrowHeadSize != arrowHeadSize;
  }
}
