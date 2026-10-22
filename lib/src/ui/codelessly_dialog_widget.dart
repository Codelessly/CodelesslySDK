import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../codelessly_sdk.dart';

/// A widget that wraps a canvas widget and shows it in a dialog.
class CodelesslyDialogWidget extends StatelessWidget {
  final WidgetBuilder builder;
  final bool showCloseButton;

  const CodelesslyDialogWidget({
    super.key,
    required this.builder,
    required this.showCloseButton,
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

    return Center(child: builder(context));
  }
}

/// Lays out a canvas shown by a show-dialog action as a bottom sheet or a
/// popover (see [DialogPresentation]).
abstract final class DialogPresenter {
  /// Screens narrower than this show an adaptive dialog as a bottom sheet.
  static const double sheetBelowWidth = 600;

  /// A sheet is at most this fraction of the screen height.
  static const double sheetMaxHeightFactor = 0.94;

  /// Gap between a popover and the node it is anchored to, and from the
  /// screen edges.
  static const double popoverGap = 6;

  /// The presentation [presentation] takes on a screen of [screen] size:
  /// adaptive becomes a sheet on phones and a dialog elsewhere.
  static DialogPresentation resolve(
    DialogPresentation presentation,
    Size screen,
  ) => switch (presentation) {
    DialogPresentation.adaptive =>
      screen.width < sheetBelowWidth
          ? DialogPresentation.bottomSheet
          : DialogPresentation.dialog,
    _ => presentation,
  };

  /// The global rect of the widget [context] belongs to, if laid out.
  static Rect? anchorOf(BuildContext context) {
    if (!context.mounted) return null;
    final RenderObject? box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// A sheet: the canvas spans the screen width and keeps its design height,
  /// up to [sheetMaxHeightFactor] of the screen.
  static Widget sheet(BuildContext context, {required WidgetBuilder builder}) {
    final Size screen = MediaQuery.sizeOf(context);
    return CanvasSizingScope(
      sizing: CanvasSizing.design,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: screen.width,
          maxWidth: screen.width,
          maxHeight: screen.height * sheetMaxHeightFactor,
        ),
        child: Builder(builder: builder),
      ),
    );
  }

  /// A popover: the canvas at its design size, below [anchor] (above it
  /// when it doesn't fit below), left-aligned to it and kept on screen.
  /// Without an anchor it is centered.
  static Widget popover({
    required Rect? anchor,
    required WidgetBuilder builder,
  }) {
    final Widget child = CanvasSizingScope(
      sizing: CanvasSizing.design,
      child: Builder(builder: builder),
    );
    if (anchor == null) return Center(child: child);
    return CustomSingleChildLayout(
      delegate: PopoverLayoutDelegate(anchor: anchor, gap: popoverGap),
      child: child,
    );
  }
}

/// Places a popover of any size next to [anchor] within the screen.
class PopoverLayoutDelegate extends SingleChildLayoutDelegate {
  /// The node the popover belongs to, in global coordinates.
  final Rect anchor;

  /// Space between the popover and [anchor] and the screen edges.
  final double gap;

  /// Creates a [PopoverLayoutDelegate].
  const PopoverLayoutDelegate({required this.anchor, required this.gap});

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(constraints.biggest).deflate(EdgeInsets.all(gap));

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final double below = anchor.bottom + gap;
    final double above = anchor.top - gap - childSize.height;
    final double top = below + childSize.height <= size.height - gap
        ? below
        : (above >= gap ? above : (size.height - childSize.height) / 2);
    final double left = anchor.left.clamp(
      gap,
      (size.width - childSize.width - gap).clamp(gap, double.infinity),
    );
    return Offset(left, top);
  }

  @override
  bool shouldRelayout(PopoverLayoutDelegate oldDelegate) =>
      oldDelegate.anchor != anchor || oldDelegate.gap != gap;
}
