import 'dart:math';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../codelessly_sdk.dart';
import 'codelessly_dialog_widget.dart';

/// The route a show-dialog action presents its canvas in: a centered dialog,
/// a bottom sheet or a side sheet (see [DialogPresentation]).
///
/// Like a dialog route it has a barrier that [barrierDismissible] lets the
/// user tap to close it, and a "Navigate back" in the canvas pops it with its
/// params as the result.
class LayoutPresentationRoute<T> extends PopupRoute<T> {
  /// How the canvas is presented.
  final DialogPresentation presentation;

  /// Builds the canvas.
  final WidgetBuilder builder;

  /// Whether to show a close button in the corner.
  final bool showCloseButton;

  /// Width of a side sheet. Null takes [designWidth].
  final double? sheetWidth;

  /// The width the destination canvas was designed at.
  final double? designWidth;

  /// The most of the screen's height a bottom sheet takes.
  final double maxHeightFactor;

  /// The inset of a side sheet from the viewport edges.
  final EdgeInsets insets;

  /// Whether the destination canvas sizes its side sheet to content.
  final bool hugsContent;

  /// Whether a bottom sheet shows a grab handle.
  final bool showDragHandle;

  final CapturedThemes? _themes;

  /// Creates a [LayoutPresentationRoute].
  LayoutPresentationRoute({
    required DialogPresentation presentation,
    required this.builder,
    required BuildContext context,
    this.showCloseButton = false,
    this.sheetWidth,
    this.designWidth,
    this.maxHeightFactor = 1,
    this.insets = EdgeInsets.zero,
    this.hugsContent = false,
    this.showDragHandle = false,
    this.barrierDismissible = true,
    this.barrierColor = Colors.black54,
    super.settings,
  }) : presentation = presentation.resolveFor(context),
       _barrierLabel = MaterialLocalizations.of(context)
           .modalBarrierDismissLabel,
       _themes = InheritedTheme.capture(
         from: context,
         to: Navigator.of(context).context,
       );

  /// How long the canvas takes to come in.
  static const Duration enterDuration = Duration(milliseconds: 320);

  /// How long the canvas takes to go away.
  static const Duration exitDuration = Duration(milliseconds: 200);

  /// The width of a side sheet when neither [sheetWidth] nor [designWidth]
  /// is known.
  static const double defaultSheetWidth = 400;

  /// Corner radius of a bottom sheet's top corners.
  static const double bottomSheetRadius = 10;

  /// Size of a bottom sheet's grab handle.
  static const Size dragHandleSize = Size(40, 4);

  /// Distance of a bottom sheet's grab handle from its top edge.
  static const double dragHandleTop = 8;

  /// Color of a bottom sheet's grab handle.
  static const Color dragHandleColor = Color(0xFFA9ADA5);

  @override
  final bool barrierDismissible;

  @override
  final Color? barrierColor;

  final String _barrierLabel;

  @override
  String? get barrierLabel => _barrierLabel;

  @override
  Duration get transitionDuration => enterDuration;

  @override
  Duration get reverseTransitionDuration => exitDuration;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final Widget page = Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: switch (presentation) {
        DialogPresentation.dialog ||
        DialogPresentation.popover ||
        DialogPresentation.fullScreen => SafeArea(
          child: CodelesslyDialogWidget(
            showCloseButton: showCloseButton,
            builder: builder,
          ),
        ),
        DialogPresentation.bottomSheet ||
        DialogPresentation.adaptive => _BottomSheet(
          maxHeightFactor: maxHeightFactor,
          showDragHandle: showDragHandle,
          showCloseButton: showCloseButton,
          builder: builder,
        ),
        DialogPresentation.sideSheet => _SideSheet(
          width: sheetWidth ?? designWidth ?? defaultSheetWidth,
          insets: insets,
          hugsContent: hugsContent,
          showCloseButton: showCloseButton,
          builder: builder,
        ),
      },
    );
    return _themes?.wrap(page) ?? page;
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final Animation<double> curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return switch (presentation) {
      DialogPresentation.dialog ||
      DialogPresentation.popover ||
      DialogPresentation.fullScreen => FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      ),
      DialogPresentation.bottomSheet ||
      DialogPresentation.adaptive => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
      DialogPresentation.sideSheet => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    };
  }
}

/// A close button in the top right corner of a dialog or sheet.
class _CloseButton extends StatelessWidget {
  const _CloseButton();

  @override
  Widget build(BuildContext context) => Positioned(
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
  );
}

/// A canvas anchored to the bottom of the screen, as wide as the screen and
/// as tall as the canvas, up to [maxHeightFactor] of the screen.
class _BottomSheet extends StatelessWidget {
  final double maxHeightFactor;
  final bool showDragHandle;
  final bool showCloseButton;
  final WidgetBuilder builder;

  const _BottomSheet({
    required this.maxHeightFactor,
    required this.showDragHandle,
    required this.showCloseButton,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    // The keyboard pushes the sheet up.
    final double keyboard = media.viewInsets.bottom;
    final double maxHeight =
        max(0, media.size.height - keyboard) * maxHeightFactor.clamp(0, 1);
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: media.size.width,
            maxHeight: maxHeight,
          ),
          child: ClipRRect(
            key: const ValueKey('Codelessly bottom sheet'),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(LayoutPresentationRoute.bottomSheetRadius),
            ),
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: MediaQuery.removeViewInsets(
                context: context,
                removeBottom: true,
                child: CanvasSizingScope(
                  sizing: CanvasSizing.fillWidth,
                  child: Stack(
                    children: [
                      Builder(builder: builder),
                      if (showDragHandle)
                        const Positioned(
                          top: LayoutPresentationRoute.dragHandleTop,
                          left: 0,
                          right: 0,
                          child: Center(child: _DragHandle()),
                        ),
                      if (showCloseButton) const _CloseButton(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The grab handle at the top of a bottom sheet.
class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('Codelessly sheet drag handle'),
    width: LayoutPresentationRoute.dragHandleSize.width,
    height: LayoutPresentationRoute.dragHandleSize.height,
    decoration: BoxDecoration(
      color: LayoutPresentationRoute.dragHandleColor,
      borderRadius: BorderRadius.circular(2),
    ),
  );
}

/// A canvas anchored to the right of the screen, as tall as the screen and
/// [width] wide.
class _SideSheet extends StatelessWidget {
  final double width;
  final EdgeInsets insets;
  final bool hugsContent;
  final bool showCloseButton;
  final WidgetBuilder builder;

  const _SideSheet({
    required this.width,
    required this.insets,
    required this.hugsContent,
    required this.showCloseButton,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.sizeOf(context);
    return Padding(
      padding: insets,
      child: Align(
        alignment: Alignment.centerRight,
        child: DecoratedBox(
          key: const ValueKey('Codelessly side sheet'),
          decoration: const BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 24,
                offset: Offset(-4, 0),
              ),
            ],
          ),
          child: SizedBox(
            width: min(width, max(0, screen.width - insets.horizontal)),
            height: hugsContent
                ? null
                : max(0, screen.height - insets.vertical),
            child: CanvasSizingScope(
              sizing: hugsContent ? CanvasSizing.design : CanvasSizing.fill,
              child: hugsContent
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          children: [
                            Builder(builder: builder),
                            if (showCloseButton) const _CloseButton(),
                          ],
                        ),
                      ],
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        Builder(builder: builder),
                        if (showCloseButton) const _CloseButton(),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Resolves [DialogPresentation.adaptive] for the screen.
extension DialogPresentationResolve on DialogPresentation {
  /// A bottom sheet on phones (narrower than 600 px) and a dialog otherwise
  /// for [DialogPresentation.adaptive]; any other presentation as is.
  DialogPresentation resolveFor(BuildContext context) =>
      this == DialogPresentation.adaptive
      ? (MediaQuery.maybeSizeOf(context)?.width ?? 1024) < 600
            ? DialogPresentation.bottomSheet
            : DialogPresentation.dialog
      : this;
}
