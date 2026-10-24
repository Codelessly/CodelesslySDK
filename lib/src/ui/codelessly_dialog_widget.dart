import 'package:flutter/material.dart';

import '../../codelessly_sdk.dart';
import 'codelessly_popover.dart';

/// A widget that wraps a canvas widget and shows it in a dialog.
class CodelesslyDialogWidget extends StatelessWidget {
  final WidgetBuilder builder;
  final bool showCloseButton;

  /// Whether the dialog is a popover next to the node that opened it (see
  /// [CodelesslyPopover]) rather than centered on the screen. Its route
  /// positions it, and its canvas keeps its design size even when it holds
  /// a responsive layout.
  final bool anchored;

  const CodelesslyDialogWidget({
    super.key,
    required this.builder,
    required this.showCloseButton,
    this.anchored = false,
  });

  @override
  Widget build(BuildContext context) {
    // A dialog is centered and sized by its layout, so its canvas keeps its
    // design size instead of filling the screen.
    return CanvasSizingScope(
      sizing: anchored ? CanvasSizing.content : CanvasSizing.design,
      child: Builder(builder: _buildDialog),
    );
  }

  Widget _center(Widget child) => anchored ? child : Center(child: child);

  Widget _buildDialog(BuildContext context) {
    if (showCloseButton) {
      return _center(
        Material(
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

    return _center(builder(context));
  }
}
