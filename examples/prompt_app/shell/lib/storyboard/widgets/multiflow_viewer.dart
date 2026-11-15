import 'package:material_ui/material_ui.dart';
import 'package:skip_shell/storyboard/models/flow_step.dart';
import 'package:skip_shell/storyboard/models/phone_frame.dart';
import 'package:skip_shell/storyboard/models/item_status.dart';

/// A widget that displays a multiflow of screens in phone frames with connecting arrows
/// Supports groups, labels, and complex layouts with multiple rows and columns
/// Similar to design tools like Figma's prototype flow view
class MultiFlowViewer extends StatefulWidget {
  final FlowDefinition flow;
  final bool isDarkMode;
  final PhoneFrame frame;

  const MultiFlowViewer({
    super.key,
    required this.flow,
    required this.isDarkMode,
    this.frame = PhoneFrames.iphone17Pro,
  });

  @override
  State<MultiFlowViewer> createState() => _MultiFlowViewerState();
}

class _MultiFlowViewerState extends State<MultiFlowViewer> {
  final TransformationController _transformationController =
      TransformationController();

  // Track whether initial transform has been applied
  bool _isInitialized = false;

  // Spacing between phone frames
  static const double _horizontalSpacing = 100.0;
  static const double _verticalSpacing = 80.0;

  // Label height above each phone frame
  static const double _labelHeight = 36.0;

  // Arrow settings
  static const double _arrowHeadSize = 12.0;

  // Padding around the content
  static const double _contentPadding = 24.0;

  // Fixed scale for phone frames (don't auto-shrink)
  static const double _phoneScale = 0.35;

  // Group padding and label settings
  static const double _groupPadding = 20.0;
  static const double _groupLabelHeight = 28.0;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  double _calculateInitialZoom(BoxConstraints constraints) {
    final rows = widget.flow.rowCount;
    final maxCols = widget.flow.maxColumns;

    if (rows == 0 || maxCols == 0) return 1.04;

    final frameWidth = widget.frame.width;
    final frameHeight = widget.frame.height;

    final scaledFrameWidth = frameWidth * _phoneScale;
    final scaledFrameHeight = frameHeight * _phoneScale;

    final totalContentWidth = maxCols * scaledFrameWidth +
        (maxCols - 1) * _horizontalSpacing +
        _contentPadding * 2;
    final totalContentHeight = rows * (scaledFrameHeight + _labelHeight) +
        (rows - 1) * _verticalSpacing +
        _contentPadding * 2;

    final availableWidth = constraints.maxWidth;
    final availableHeight = constraints.maxHeight;

    final zoomToFitWidth = availableWidth / totalContentWidth;
    final zoomToFitHeight = availableHeight / totalContentHeight;

    final calculatedZoom =
        zoomToFitWidth < zoomToFitHeight ? zoomToFitWidth : zoomToFitHeight;

    // Scale the calculated zoom by 1.04 (104%)
    final initialZoom = calculatedZoom * 1.04;

    return initialZoom.clamp(0.25, 1.5);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const scale = _phoneScale;

        final initialZoom = _calculateInitialZoom(constraints);

        if (!_isInitialized) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted &&
                _transformationController.value == Matrix4.identity()) {
              final scaledFrameWidth = widget.frame.width * scale;
              final scaledFrameHeight = widget.frame.height * scale;
              final rows = widget.flow.rowCount;
              final maxCols = widget.flow.maxColumns;

              final totalContentWidth = maxCols * scaledFrameWidth +
                  (maxCols - 1) * _horizontalSpacing +
                  _contentPadding * 2;
              final totalContentHeight =
                  rows * (scaledFrameHeight + _labelHeight) +
                      (rows - 1) * _verticalSpacing +
                      _contentPadding * 2;

              final contentCenterX = totalContentWidth / 2;
              final contentCenterY = totalContentHeight / 2;
              final viewportCenterX = constraints.maxWidth / 2;
              final viewportCenterY = constraints.maxHeight / 2;

              // Create transformation: translate to center, scale, translate back
              final matrix = Matrix4.identity()
                ..translateByDouble(viewportCenterX, viewportCenterY, 0, 1.0)
                ..scaleByDouble(initialZoom, initialZoom, 1.0, 1.0)
                ..translateByDouble(-contentCenterX, -contentCenterY, 0, 1.0);

              _transformationController.value = matrix;
              setState(() {
                _isInitialized = true;
              });
            }
          });
        }

        if (!_isInitialized) {
          return const Center(child: CircularProgressIndicator());
        }

        return InteractiveViewer(
          transformationController: _transformationController,
          constrained: false,
          minScale: 0.75,
          maxScale: 8.0,
          boundaryMargin: EdgeInsets.symmetric(
            horizontal: constraints.maxWidth * 2,
            vertical: constraints.maxHeight * 2,
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
                  horizontalSpacing: _horizontalSpacing,
                  verticalSpacing: _verticalSpacing,
                  labelHeight: _labelHeight,
                  arrowColor: widget.isDarkMode
                      ? Colors.white.withValues(alpha: 0.6)
                      : Colors.black.withValues(alpha: 0.5),
                  arrowHeadSize: (_arrowHeadSize * scale).clamp(4.0, _arrowHeadSize),
                  strokeWidth: (2.5 * scale).clamp(1.0, 2.5),
                  groupPadding: _groupPadding,
                  groupLabelHeight: _groupLabelHeight,
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

    final rows = widget.flow.rowCount;
    final maxCols = widget.flow.maxColumns;

    final stepHeight = _labelHeight + scaledFrameHeight;

    final totalWidth =
        maxCols * scaledFrameWidth + (maxCols - 1) * _horizontalSpacing;
    final totalHeight = rows * stepHeight + (rows - 1) * _verticalSpacing;

    return SizedBox(
      width: totalWidth,
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ..._buildGroups(scaledFrameWidth, scaledFrameHeight, stepHeight),
          for (int row = 0; row < rows; row++)
            ..._buildRow(row, scaledFrameWidth, scaledFrameHeight, stepHeight),
        ],
      ),
    );
  }

  /// Build visual group containers (dotted borders and labels)
  List<Widget> _buildGroups(
    double scaledFrameWidth,
    double scaledFrameHeight,
    double stepHeight,
  ) {
    final widgets = <Widget>[];

    for (final group in widget.flow.groups) {
      final stepsInGroup = widget.flow.getStepsInGroup(group.id);
      if (stepsInGroup.isEmpty) continue;

      final minRow =
          stepsInGroup.map((s) => s.row).reduce((a, b) => a < b ? a : b);
      final maxRow =
          stepsInGroup.map((s) => s.row).reduce((a, b) => a > b ? a : b);
      final minCol =
          stepsInGroup.map((s) => s.column).reduce((a, b) => a < b ? a : b);
      final maxCol =
          stepsInGroup.map((s) => s.column).reduce((a, b) => a > b ? a : b);

      final left =
          minCol * (scaledFrameWidth + _horizontalSpacing) - _groupPadding;
      final top = minRow * (stepHeight + _verticalSpacing) -
          _groupPadding -
          (group.showLabel ? _groupLabelHeight : 0);
      final width =
          (maxCol - minCol + 1) * (scaledFrameWidth + _horizontalSpacing) -
              _horizontalSpacing +
              (_groupPadding * 2);
      final height = (maxRow - minRow + 1) * (stepHeight + _verticalSpacing) -
          _verticalSpacing +
          (_groupPadding * 2) +
          (group.showLabel ? _groupLabelHeight : 0);

      widgets.add(
        Positioned(
          left: left,
          top: top,
          child: _GroupContainer(
            width: width,
            height: height,
            label: group.label,
            showBorder: group.showBorder,
            showLabel: group.showLabel,
            backgroundColor: group.backgroundColor,
            borderColor: group.borderColor,
            isDarkMode: widget.isDarkMode,
          ),
        ),
      );
    }

    return widgets;
  }

  List<Widget> _buildRow(
    int row,
    double scaledFrameWidth,
    double scaledFrameHeight,
    double stepHeight,
  ) {
    final steps = widget.flow.getStepsInRow(row);
    final widgets = <Widget>[];

    for (final step in steps) {
      final left = step.column * (scaledFrameWidth + _horizontalSpacing);
      final top = step.row * (stepHeight + _verticalSpacing);

      widgets.add(
        Positioned(
          left: left,
          top: top,
          child: _buildStepFrame(step, scaledFrameWidth, scaledFrameHeight),
        ),
      );
    }

    return widgets;
  }

  Widget _buildStepFrame(
    FlowStep step,
    double scaledFrameWidth,
    double scaledFrameHeight,
  ) {
    // Scale font and icon based on phoneScale, with minimum sizes
    final fontSize = (12.0 * _phoneScale).clamp(4.0, 10.0);
    final iconSize = (16.0 * _phoneScale).clamp(6.0, 12.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: scaledFrameWidth,
          padding: EdgeInsets.only(bottom: 8 * _phoneScale),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(step.status.icon, size: iconSize, color: step.status.color),
              SizedBox(width: 6 * _phoneScale),
              Flexible(
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
            ],
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

/// Widget to render a group container with dotted border and label
class _GroupContainer extends StatelessWidget {
  final double width;
  final double height;
  final String label;
  final bool showBorder;
  final bool showLabel;
  final Color? backgroundColor;
  final Color borderColor;
  final bool isDarkMode;

  const _GroupContainer({
    required this.width,
    required this.height,
    required this.label,
    required this.showBorder,
    required this.showLabel,
    this.backgroundColor,
    required this.borderColor,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          // Background and border
          if (showBorder || backgroundColor != null)
            Positioned.fill(
              child: CustomPaint(
                painter: _DottedBorderPainter(
                  showBorder: showBorder,
                  borderColor: borderColor.withValues(
                    alpha: isDarkMode ? 0.4 : 0.5,
                  ),
                  backgroundColor: backgroundColor,
                  borderRadius: 12,
                ),
              ),
            ),
          // Label
          if (showLabel)
            Positioned(
              top: 8,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.black.withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: borderColor,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Custom painter for dotted border
class _DottedBorderPainter extends CustomPainter {
  final bool showBorder;
  final Color borderColor;
  final Color? backgroundColor;
  final double borderRadius;

  _DottedBorderPainter({
    required this.showBorder,
    required this.borderColor,
    this.backgroundColor,
    this.borderRadius = 8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    // Draw background if specified
    if (backgroundColor != null) {
      final bgPaint = Paint()
        ..color = backgroundColor!
        ..style = PaintingStyle.fill;
      canvas.drawRRect(rrect, bgPaint);
    }

    // Draw dotted border
    if (showBorder) {
      final paint = Paint()
        ..color = borderColor
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      // Create dotted path
      final path = Path()..addRRect(rrect);
      final dashPath = _createDashedPath(path, 6, 4);
      canvas.drawPath(dashPath, paint);
    }
  }

  Path _createDashedPath(Path source, double dashLength, double gapLength) {
    final dashedPath = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final length = dashLength.clamp(0, metric.length - distance);
        dashedPath.addPath(
          metric.extractPath(distance, distance + length),
          Offset.zero,
        );
        distance += dashLength + gapLength;
      }
    }
    return dashedPath;
  }

  @override
  bool shouldRepaint(covariant _DottedBorderPainter oldDelegate) {
    return oldDelegate.showBorder != showBorder ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}

/// Custom painter for drawing arrows between flow steps
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
  final double groupPadding;
  final double groupLabelHeight;

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
    required this.groupPadding,
    required this.groupLabelHeight,
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
      // Skip connections where steps don't exist
      final fromStep = flow.steps.cast<FlowStep?>().firstWhere(
        (s) => s?.id == connection.fromStepId,
        orElse: () => null,
      );
      final toStep = flow.steps.cast<FlowStep?>().firstWhere(
        (s) => s?.id == connection.toStepId,
        orElse: () => null,
      );

      if (fromStep == null || toStep == null) continue;

      // Calculate positions (center of each frame)
      final fromX =
          fromStep.column * (scaledFrameWidth + horizontalSpacing) +
          scaledFrameWidth / 2;
      final fromY =
          fromStep.row * (scaledFrameHeight + verticalSpacing + labelHeight) +
          labelHeight +
          scaledFrameHeight / 2;

      final toX =
          toStep.column * (scaledFrameWidth + horizontalSpacing) +
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
    // Draw the line
    final path = Path();
    path.moveTo(fromX + 8, fromY);
    path.lineTo(toX - arrowHeadSize - 4, toY);
    canvas.drawPath(path, linePaint);

    // Draw arrowhead
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
    // Draw the line
    final path = Path();
    path.moveTo(fromX, fromY + 8);
    path.lineTo(toX, toY - arrowHeadSize - 4);
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
    final path = Path();
    final midX = fromX + spacing / 2;

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
    final path = Path();
    final midX = fromX + spacing / 2;

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
