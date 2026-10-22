import 'package:flutter/material.dart';

import '../../codelessly_sdk.dart';

/// A widget that wraps a canvas widget and shows it in a dialog.
class CodelesslyDialogWidget extends StatelessWidget {
  final WidgetBuilder builder;
  final bool showCloseButton;

  /// How the canvas is sized: [CanvasSizing.design] for a centered dialog,
  /// [CanvasSizing.sheet] for a bottom sheet, [CanvasSizing.fill] for a
  /// full-screen dialog.
  final CanvasSizing sizing;

  const CodelesslyDialogWidget({
    super.key,
    required this.builder,
    required this.showCloseButton,
    this.sizing = CanvasSizing.design,
  });

  @override
  Widget build(BuildContext context) {
    // A dialog is centered and sized by its layout, so its canvas keeps its
    // design size instead of filling the screen.
    return CanvasSizingScope(
      sizing: sizing,
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

    return switch (sizing) {
      CanvasSizing.sheet => Align(
        alignment: Alignment.bottomCenter,
        child: builder(context),
      ),
      CanvasSizing.fill => builder(context),
      CanvasSizing.design => Center(child: builder(context)),
    };
  }
}
