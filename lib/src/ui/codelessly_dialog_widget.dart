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
