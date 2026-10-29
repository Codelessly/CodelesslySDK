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

/// A layout shown as a full height bottom sheet: the screen's full width
/// and 90% of its height, with the canvas filling it, so the canvas scrolls
/// its own content (a fixed header over a scrolling list). The layout draws
/// its own background, corners and grab handle; the sheet is transparent.
class CodelesslyBottomSheetWidget extends StatelessWidget {
  final WidgetBuilder builder;

  /// The share of the screen height the sheet takes.
  static const double heightFactor = 0.9;

  const CodelesslyBottomSheetWidget({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    return Padding(
      // Keep inputs above the keyboard.
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: media.size.height * heightFactor,
        child: Builder(builder: builder),
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
  Widget build(BuildContext context) => CustomSingleChildLayout(
    delegate: _AnchorDelegate(anchor, gap),
    child: child,
  );
}

/// A layout shown as a popover menu next to [anchor] (the rect, in global
/// coordinates, of the node that opened it): below it and left-aligned with
/// it (right-aligned with [alignEnd]), the other way when that would run off
/// the screen, and above it when there is no room below. The canvas keeps
/// its design size.
class CodelesslyPopoverWidget extends StatelessWidget {
  final Rect? anchor;
  final WidgetBuilder builder;

  /// Whether the popover's right edge lines up with the anchor's, as for a
  /// menu opened from a button at the right of a card.
  final bool alignEnd;

  /// Gap between the anchor and the popover, and the screen margin.
  static const double gap = 6;

  const CodelesslyPopoverWidget({
    super.key,
    required this.anchor,
    required this.builder,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomSingleChildLayout(
      delegate: _PopoverLayout(anchor, alignEnd: alignEnd),
      child: CanvasSizingScope(
        sizing: CanvasSizing.design,
        child: Builder(builder: builder),
      ),
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

class _PopoverLayout extends SingleChildLayoutDelegate {
  final Rect? anchor;
  final bool alignEnd;

  const _PopoverLayout(this.anchor, {this.alignEnd = false});

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen().deflate(
        const EdgeInsets.all(CodelesslyPopoverWidget.gap),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) =>
      popoverPosition(anchor, size, childSize, alignEnd: alignEnd);

  @override
  bool shouldRelayout(covariant _PopoverLayout old) =>
      old.anchor != anchor || old.alignEnd != alignEnd;
}

/// Where a popover of [child] size goes in a [screen] for [anchor]; centered
/// when there is no anchor. See [CodelesslyPopoverWidget.alignEnd].
Offset popoverPosition(
  Rect? anchor,
  Size screen,
  Size child, {
  bool alignEnd = false,
}) {
  const double m = CodelesslyPopoverWidget.gap;
  if (anchor == null) {
    return Offset(
      (screen.width - child.width) / 2,
      (screen.height - child.height) / 2,
    );
  }
  final double start = anchor.left, end = anchor.right - child.width;
  double left = alignEnd ? end : start;
  if (!alignEnd && left + child.width > screen.width - m) left = end;
  if (alignEnd && left < m) left = start;
  left = left.clamp(
    m,
    (screen.width - child.width - m).clamp(m, double.infinity),
  );
  final bool below =
      anchor.bottom + m + child.height <= screen.height - m ||
      anchor.top - m - child.height < m;
  final double top = below ? anchor.bottom + m : anchor.top - m - child.height;
  return Offset(
    left,
    top.clamp(m, (screen.height - child.height - m).clamp(m, double.infinity)),
  );
}
