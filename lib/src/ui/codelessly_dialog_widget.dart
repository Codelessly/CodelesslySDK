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
    // design size instead of filling the screen, unless it holds a
    // responsive layout (see CanvasSizing.design). Taps on its empty parts
    // reach the barrier.
    return CanvasSizingScope(
      sizing: CanvasSizing.design,
      child: TapThroughScope(child: Builder(builder: _buildDialog)),
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
