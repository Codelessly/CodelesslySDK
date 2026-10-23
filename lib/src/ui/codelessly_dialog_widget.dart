import 'package:flutter/material.dart';

import '../../codelessly_sdk.dart';

/// A widget that wraps a canvas widget and shows it in a dialog.
class CodelesslyDialogWidget extends StatelessWidget {
  final WidgetBuilder builder;
  final bool showCloseButton;

  /// Where the dialog sits: centered by default, bottom center for a sheet,
  /// or anywhere else, e.g. a menu at the top right.
  final AlignmentGeometry alignment;

  const CodelesslyDialogWidget({
    super.key,
    required this.builder,
    required this.showCloseButton,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    // A dialog is centered and sized by its layout, so its canvas keeps its
    // design size instead of filling the screen.
    return CanvasSizingScope(
      sizing: CanvasSizing.design,
      child: Builder(builder: _buildDialog),
    );
  }

  Widget _buildDialog(BuildContext context) {
    if (showCloseButton) {
      return Align(
        alignment: alignment,
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

    return Align(alignment: alignment, child: builder(context));
  }
}

/// A layout shown as a bottom sheet: the screen's full width, its canvas's
/// own height (design or content), at most 90% of the screen high and
/// scrollable past that. The layout draws its own background, corners and
/// grab handle; the sheet itself is transparent.
class CodelesslyBottomSheetWidget extends StatelessWidget {
  final WidgetBuilder builder;

  /// Whether the sheet is as tall as it can be (90% of the screen) with the
  /// canvas filling it, so the canvas scrolls its own content under a fixed
  /// header. Otherwise the sheet is as tall as the canvas and scrolls as one.
  final bool fullHeight;

  /// The share of the screen height a sheet can take.
  static const double maxHeightFactor = 0.9;

  const CodelesslyBottomSheetWidget({
    super.key,
    required this.builder,
    this.fullHeight = false,
  });

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final double maxHeight = media.size.height * maxHeightFactor;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Padding(
        // Keep inputs above the keyboard.
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: fullHeight
            // A bounded height: an expanded list in the canvas scrolls
            // inside it.
            ? SizedBox(
                height: maxHeight,
                child: Builder(builder: builder),
              )
            // Unbounded height inside the scroll view: a filling canvas
            // takes the full width and its own height.
            : SingleChildScrollView(child: Builder(builder: builder)),
      ),
    );
  }
}

/// A layout shown as a popover menu next to [anchor] (the rect, in global
/// coordinates, of the node that opened it): below it and left-aligned with
/// it, right-aligned when that would run off the screen, and above it when
/// there is no room below. The canvas keeps its design size.
class CodelesslyPopoverWidget extends StatelessWidget {
  final Rect? anchor;
  final WidgetBuilder builder;

  /// Gap between the anchor and the popover, and the screen margin.
  static const double gap = 6;

  const CodelesslyPopoverWidget({
    super.key,
    required this.anchor,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return CustomSingleChildLayout(
      delegate: _PopoverLayout(anchor),
      child: CanvasSizingScope(
        sizing: CanvasSizing.design,
        child: Builder(builder: builder),
      ),
    );
  }
}

class _PopoverLayout extends SingleChildLayoutDelegate {
  final Rect? anchor;

  const _PopoverLayout(this.anchor);

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen().deflate(
        const EdgeInsets.all(CodelesslyPopoverWidget.gap),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) =>
      popoverPosition(anchor, size, childSize);

  @override
  bool shouldRelayout(covariant _PopoverLayout old) => old.anchor != anchor;
}

/// Where a popover of [child] size goes in a [screen] for [anchor]; centered
/// when there is no anchor.
Offset popoverPosition(Rect? anchor, Size screen, Size child) {
  const double m = CodelesslyPopoverWidget.gap;
  if (anchor == null) {
    return Offset(
      (screen.width - child.width) / 2,
      (screen.height - child.height) / 2,
    );
  }
  double left = anchor.left;
  if (left + child.width > screen.width - m) left = anchor.right - child.width;
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
