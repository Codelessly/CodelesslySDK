import 'package:flutter/material.dart';

import '../../codelessly_sdk.dart';

/// A widget that wraps a canvas widget and shows it in a dialog.
class CodelesslyDialogWidget extends StatelessWidget {
  final WidgetBuilder builder;
  final bool showCloseButton;

  /// Where the dialog sits: centered by default, bottom center for a sheet,
  /// or anywhere else, e.g. a menu at the top right.
  final AlignmentGeometry alignment;

  /// Whether the dialog is only as tall as its canvas, leaving the space
  /// above a bottom sheet to its dismissible scrim.
  final bool hugHeight;

  /// Design-sized dialog, full-width sheet, or full-screen canvas.
  final CanvasSizing sizing;

  const CodelesslyDialogWidget({
    super.key,
    required this.builder,
    required this.showCloseButton,
    this.alignment = Alignment.center,
    this.hugHeight = false,
    this.sizing = CanvasSizing.design,
  });

  @override
  Widget build(BuildContext context) {
    // Responsive layouts can follow the screen even in a design-sized
    // dialog. Empty transparent areas let taps reach the dismissible barrier.
    return CanvasSizingScope(
      sizing: sizing,
      child: TapThroughScope(child: Builder(builder: _buildDialog)),
    );
  }

  /// A sheet sits on the bottom edge wherever the action places a dialog.
  AlignmentGeometry get _alignment =>
      sizing == CanvasSizing.sheet || sizing == CanvasSizing.fillWidth
      ? Alignment.bottomCenter
      : alignment;

  Widget _buildDialog(BuildContext context) {
    final bool sheetHeight =
        hugHeight ||
        sizing == CanvasSizing.sheet ||
        sizing == CanvasSizing.fillWidth;
    if (showCloseButton) {
      return Align(
        alignment: _alignment,
        heightFactor: sheetHeight ? 1 : null,
        child: Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              builder(context),
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  type: MaterialType.transparency,
                  child: IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    splashRadius: 16,
                    icon: const Icon(Icons.close),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (sizing == CanvasSizing.fill) return builder(context);
    return Align(
      alignment: _alignment,
      heightFactor: sheetHeight ? 1 : null,
      child: builder(context),
    );
  }
}

/// Pins a dialog canvas to the bottom of the screen at full width, its
/// height taken from the canvas (its design height, or its content when it
/// shrink-wraps), and no taller than 92% of the screen.
class CodelesslySheetPlacement extends StatelessWidget {
  final Widget child;

  const CodelesslySheetPlacement({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.sizeOf(context);
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: screen.height * 0.92),
        child: ClipRect(
          child: SingleChildScrollView(
            child: SizedBox(
              width: screen.width,
              child: Material(type: MaterialType.transparency, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Places a dialog canvas at its design size just below [anchor] (a global
/// rectangle), left-aligned with it, or above it when there is no room
/// below, and always fully on screen.
class CodelesslyAnchoredPlacement extends StatelessWidget {
  final Rect anchor;
  final double gap;
  final Widget child;

  const CodelesslyAnchoredPlacement({
    super.key,
    required this.anchor,
    required this.gap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return CustomSingleChildLayout(
      delegate: _AnchorDelegate(anchor, gap),
      child: child,
    );
  }
}

class _AnchorDelegate extends SingleChildLayoutDelegate {
  final Rect anchor;
  final double gap;

  _AnchorDelegate(this.anchor, this.gap);

  static const double _margin = 8;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen().deflate(const EdgeInsets.all(_margin));

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    double left = anchor.left;
    left = left.clamp(_margin, size.width - childSize.width - _margin);
    double top = anchor.bottom + gap;
    if (top + childSize.height > size.height - _margin &&
        anchor.top - gap - childSize.height >= _margin) {
      top = anchor.top - gap - childSize.height;
    }
    top = top.clamp(_margin, size.height - childSize.height - _margin);
    return Offset(left, top);
  }

  @override
  bool shouldRelayout(_AnchorDelegate old) =>
      old.anchor != anchor || old.gap != gap;
}
