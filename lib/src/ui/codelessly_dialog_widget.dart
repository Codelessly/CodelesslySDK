import 'package:flutter/material.dart';

import '../../codelessly_sdk.dart';

/// A widget that wraps a canvas widget and shows it in a dialog.
class CodelesslyDialogWidget extends StatelessWidget {
  final WidgetBuilder builder;
  final bool showCloseButton;

  /// Where the dialog sits: centered by default, bottom center for a sheet,
  /// or anywhere else, e.g. a menu at the top right.
  final AlignmentGeometry alignment;

  /// Space kept between the dialog and the screen edges.
  final EdgeInsets insets;

  /// The most of the screen's height the dialog may take, as a share of it
  /// (see [ShowDialogAction.maxHeightFactor]). Null keeps the canvas's
  /// design height.
  final double? maxHeightFactor;

  const CodelesslyDialogWidget({
    super.key,
    required this.builder,
    required this.showCloseButton,
    this.alignment = Alignment.center,
    this.insets = EdgeInsets.zero,
    this.maxHeightFactor,
  });

  /// The height cap of a canvas shown on a screen [screenHeight] tall with
  /// [factor] (see [ShowDialogAction.maxHeightFactor]), or null for none.
  static double? maxHeightFor(double? factor, double screenHeight) {
    if (factor == null || !factor.isFinite || factor <= 0) return null;
    return screenHeight * factor.clamp(0, 1);
  }

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
    return Padding(
      padding: insets,
      child: Align(alignment: alignment, child: _buildContent(context)),
    );
  }

  Widget _buildContent(BuildContext context) {
    // The canvas keeps its design height up to the cap; a taller design is
    // laid out at the cap and its content (a flexible or expanded scrolling
    // body) adapts. A canvas sized by its content stops at the cap too.
    final double? maxHeight = maxHeightFor(
      maxHeightFactor,
      MediaQuery.sizeOf(context).height,
    );
    if (maxHeight == null) return _buildCanvas(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: _buildCanvas(context),
    );
  }

  Widget _buildCanvas(BuildContext context) {
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

    return builder(context);
  }
}
