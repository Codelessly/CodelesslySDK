import 'package:flutter/material.dart';

import '../../codelessly_sdk.dart';

/// A widget that wraps a canvas widget and shows it in a dialog.
class CodelesslyDialogWidget extends StatelessWidget {
  final WidgetBuilder builder;
  final bool showCloseButton;

  /// Where the dialog sits: centered by default, bottom center for a sheet,
  /// or anywhere else, e.g. a menu at the top right.
  final AlignmentGeometry alignment;

  /// How the canvas is sized: [CanvasSizing.design] for a dialog,
  /// [CanvasSizing.sheet] for a bottom sheet, [CanvasSizing.fill] for a
  /// full-screen dialog.
  final CanvasSizing sizing;

  const CodelesslyDialogWidget({
    super.key,
    required this.builder,
    required this.showCloseButton,
    this.alignment = Alignment.center,
    this.sizing = CanvasSizing.design,
  });

  @override
  Widget build(BuildContext context) {
    // A dialog is placed and sized by its layout, so its canvas keeps its
    // design size instead of filling the screen; a sheet takes the screen's
    // width and a full-screen dialog all of it.
    return CanvasSizingScope(
      sizing: sizing,
      child: Builder(builder: _buildDialog),
    );
  }

  /// A sheet sits on the bottom edge wherever the action places a dialog.
  AlignmentGeometry get _alignment =>
      sizing == CanvasSizing.sheet ? Alignment.bottomCenter : alignment;

  Widget _buildDialog(BuildContext context) {
    if (showCloseButton) {
      return Align(
        alignment: _alignment,
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
    return Align(alignment: _alignment, child: builder(context));
  }
}
