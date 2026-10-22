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

/// A layout shown as a bottom sheet: the screen's full width, its canvas's
/// own height (design or content), at most 90% of the screen high and
/// scrollable past that. The layout draws its own background, corners and
/// grab handle; the sheet itself is transparent.
class CodelesslyBottomSheetWidget extends StatelessWidget {
  final WidgetBuilder builder;

  const CodelesslyBottomSheetWidget({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.9),
      child: Padding(
        // Keep inputs above the keyboard.
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        // Unbounded height inside the scroll view: a filling canvas takes
        // the full width and its own height.
        child: SingleChildScrollView(child: Builder(builder: builder)),
      ),
    );
  }
}
