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
