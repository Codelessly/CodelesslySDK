import 'package:flutter/material.dart';

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

    return Center(
      child: builder(context),
    );
  }
}
