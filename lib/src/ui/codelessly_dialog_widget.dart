import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../codelessly_sdk.dart';

/// A widget that wraps a canvas widget and shows it in a dialog.
class CodelesslyDialogWidget extends StatelessWidget {
  final WidgetBuilder builder;
  final bool showCloseButton;

  /// Where the dialog opens; anything but center needs [anchor].
  final DialogPlacement placement;

  /// The global rect of the node that opened the dialog.
  final Rect? anchor;

  /// Space between the dialog and [anchor].
  final double gap;

  const CodelesslyDialogWidget({
    super.key,
    required this.builder,
    required this.showCloseButton,
    this.placement = DialogPlacement.center,
    this.anchor,
    this.gap = 8,
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
      return Center(
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

    if (placement == DialogPlacement.center || anchor == null) {
      return Center(child: builder(context));
    }
    // The route fills the screen from its top-left, so the anchor's global
    // rect is in the same coordinates as the layout below.
    final Offset origin =
        (context.findAncestorRenderObjectOfType<RenderBox>()?.hasSize ?? false)
        ? context.findAncestorRenderObjectOfType<RenderBox>()!.localToGlobal(
            Offset.zero,
          )
        : Offset.zero;
    return CustomSingleChildLayout(
      delegate: PopoverLayoutDelegate(
        anchor: anchor!.shift(-origin),
        placement: placement,
        gap: gap,
      ),
      child: builder(context),
    );
  }
}

/// Places a popover of its own size next to [anchor] per [placement] and
/// keeps it on screen with an 8 px margin.
class PopoverLayoutDelegate extends SingleChildLayoutDelegate {
  final Rect anchor;
  final DialogPlacement placement;
  final double gap;

  static const double margin = 8;

  const PopoverLayoutDelegate({
    required this.anchor,
    required this.placement,
    required this.gap,
  });

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen().deflate(const EdgeInsets.all(margin));

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final Size child = childSize;
    double clampX(double x) =>
        x.clamp(margin, math.max(margin, size.width - child.width - margin));
    double clampY(double y) =>
        y.clamp(margin, math.max(margin, size.height - child.height - margin));
    final bool roomBelow = anchor.bottom + gap + child.height <= size.height;
    final bool roomAbove = anchor.top - gap - child.height >= 0;
    Offset vertical(bool below) => Offset(
      clampX(anchor.left),
      clampY(below ? anchor.bottom + gap : anchor.top - gap - child.height),
    );
    switch (placement) {
      case DialogPlacement.center:
        return Offset(
          (size.width - child.width) / 2,
          (size.height - child.height) / 2,
        );
      case DialogPlacement.below:
        return vertical(roomBelow || !roomAbove);
      case DialogPlacement.above:
        return vertical(!roomAbove && roomBelow);
      case DialogPlacement.beside:
        if (anchor.right + gap + child.width <= size.width - margin) {
          return Offset(
            anchor.right + gap,
            clampY(anchor.bottom - child.height),
          );
        }
        return vertical(roomBelow || !roomAbove);
    }
  }

  @override
  bool shouldRelayout(PopoverLayoutDelegate oldDelegate) =>
      anchor != oldDelegate.anchor ||
      placement != oldDelegate.placement ||
      gap != oldDelegate.gap;
}
