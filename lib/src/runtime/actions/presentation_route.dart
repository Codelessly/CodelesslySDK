// The route a dialog or sheet is presented in: a centered dialog, a bottom
// sheet or a side sheet. SDK 8.x's LayoutPresentationRoute.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart' show Breakpoints, ModalPresentation;
import 'package:flutter/material.dart';

/// The width below which an adaptive modal with no breakpoint of its own is
/// a bottom sheet: the project's second breakpoint's min width (a sheet on
/// the narrowest breakpoint only; never with one breakpoint). DESIGN.md §5.3.
double defaultSheetBelowWidth(Breakpoints breakpoints) => breakpoints.length > 1 ? breakpoints.list[1].minWidth : 0;

/// [presentation] for a screen [width] wide: adaptive is a bottom sheet
/// below [sheetBelowWidth] (the min width of the breakpoint it switches at;
/// `OpenModalAction.sheetBelowWidthIn`), a dialog otherwise. An unknown
/// width is a dialog.
ModalPresentation resolvePresentation(ModalPresentation presentation, double? width, {required double sheetBelowWidth}) =>
    presentation == ModalPresentation.adaptive
        ? (width != null && width < sheetBelowWidth ? ModalPresentation.bottomSheet : ModalPresentation.dialog)
        : presentation;

/// Presents [builder]'s content as [presentation] says, with a barrier that
/// [barrierDismissible] lets the user tap to close it.
class PresentationRoute<T> extends PopupRoute<T> {
  PresentationRoute({
    required ModalPresentation presentation,
    required this.builder,
    required BuildContext context,
    this.sheetWidth,
    this.maxHeightFactor = 1,
    this.insets = EdgeInsets.zero,
    this.showDragHandle = false,
    this.barrierDismissible = true,
    this.barrierColor = Colors.black54,
    this.barrierBlur = 0,
    this.enterScale = 0.96,
    double sheetBelowWidth = 0,
    super.settings,
  })  : presentation = resolvePresentation(presentation, MediaQuery.maybeSizeOf(context)?.width, sheetBelowWidth: sheetBelowWidth),
        _barrierLabel = MaterialLocalizations.of(context).modalBarrierDismissLabel,
        _themes = InheritedTheme.capture(from: context, to: Navigator.of(context).context);

  static const enterDuration = Duration(milliseconds: 320);
  static const exitDuration = Duration(milliseconds: 200);
  static const double defaultSheetWidth = 400;
  static const double bottomSheetRadius = 10;
  static const Size dragHandleSize = Size(40, 4);
  static const double dragHandleTop = 8;
  static const Color dragHandleColor = Color(0xFFA9ADA5);

  final ModalPresentation presentation;
  final WidgetBuilder builder;

  /// Width of a side sheet; null: [defaultSheetWidth].
  final double? sheetWidth;

  /// The most of the screen's height a bottom sheet takes.
  final double maxHeightFactor;

  /// Inset of a side sheet from the screen's edges.
  final EdgeInsets insets;
  final bool showDragHandle;

  /// The page behind a dialog blurs up to this (a Gaussian sigma).
  final double barrierBlur;

  /// The scale a dialog grows from.
  final double enterScale;

  final CapturedThemes? _themes;

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
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    final page = Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: switch (presentation) {
        ModalPresentation.bottomSheet || ModalPresentation.adaptive => _BottomSheet(
            maxHeightFactor: maxHeightFactor,
            showDragHandle: showDragHandle,
            builder: builder,
          ),
        ModalPresentation.sideSheet => _SideSheet(width: sheetWidth ?? defaultSheetWidth, insets: insets, builder: builder),
        _ => SafeArea(child: Center(child: Builder(builder: builder))),
      },
    );
    return _themes?.wrap(page) ?? page;
  }

  @override
  Widget buildTransitions(
      BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    switch (presentation) {
      case ModalPresentation.bottomSheet || ModalPresentation.adaptive:
        return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(curved), child: child);
      case ModalPresentation.sideSheet:
        return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(curved), child: child);
      default:
        Widget dialog = FadeTransition(
          opacity: curved,
          child: ScaleTransition(scale: Tween<double>(begin: enterScale, end: 1).animate(curved), child: child),
        );
        if (barrierBlur > 0) {
          dialog = AnimatedBuilder(
            animation: curved,
            child: dialog,
            builder: (context, child) {
              final sigma = barrierBlur * curved.value;
              return BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma), child: child);
            },
          );
        }
        return dialog;
    }
  }
}

class _BottomSheet extends StatelessWidget {
  const _BottomSheet({required this.maxHeightFactor, required this.showDragHandle, required this.builder});

  final double maxHeightFactor;
  final bool showDragHandle;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // The keyboard pushes the sheet up.
    final keyboard = media.viewInsets.bottom;
    final maxHeight = math.max(0.0, media.size.height - keyboard) * maxHeightFactor.clamp(0, 1);
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: media.size.width, maxHeight: maxHeight),
          child: ClipRRect(
            key: const ValueKey('Codelessly bottom sheet'),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(PresentationRoute.bottomSheetRadius)),
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: MediaQuery.removeViewInsets(
                context: context,
                removeBottom: true,
                child: Stack(
                  children: [
                    Builder(builder: builder),
                    if (showDragHandle)
                      const Positioned(
                        top: PresentationRoute.dragHandleTop,
                        left: 0,
                        right: 0,
                        child: Center(child: _DragHandle()),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey('Codelessly sheet drag handle'),
        width: PresentationRoute.dragHandleSize.width,
        height: PresentationRoute.dragHandleSize.height,
        decoration: BoxDecoration(color: PresentationRoute.dragHandleColor, borderRadius: BorderRadius.circular(2)),
      );
}

class _SideSheet extends StatelessWidget {
  const _SideSheet({required this.width, required this.insets, required this.builder});

  final double width;
  final EdgeInsets insets;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    return Padding(
      padding: insets,
      child: Align(
        alignment: Alignment.centerRight,
        child: DecoratedBox(
          key: const ValueKey('Codelessly side sheet'),
          decoration: const BoxDecoration(
            boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(-4, 0))],
          ),
          child: SizedBox(
            width: math.min(width, math.max(0, screen.width - insets.horizontal)),
            height: math.max(0, screen.height - insets.vertical),
            child: Builder(builder: builder),
          ),
        ),
      ),
    );
  }
}
