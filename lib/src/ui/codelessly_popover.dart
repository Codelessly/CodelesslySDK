import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

/// Shows a dialog next to a trigger widget, like a popover or a menu, for a
/// [ShowDialogAction] whose [ShowDialogAction.anchor] is
/// [DialogAnchor.trigger].
class CodelesslyPopover {
  CodelesslyPopover._();

  /// The space kept between a popover and the screen edges (after the safe
  /// area).
  static const double screenMargin = 8;

  /// The rect [trigger]'s widget covers in [navigator]'s overlay, where a
  /// popover route lays out, or null when it has no laid out render box.
  ///
  /// Transforms between them (a scaled autoScale canvas, for example) are
  /// applied, so the rect is the one the trigger shows on screen.
  static Rect? anchorRectOf(BuildContext trigger, NavigatorState navigator) {
    final RenderObject? object = trigger.findRenderObject();
    final RenderObject? overlay = navigator.overlay?.context.findRenderObject();
    if (object is! RenderBox ||
        !object.attached ||
        !object.hasSize ||
        overlay is! RenderBox ||
        !overlay.attached) {
      return null;
    }
    return MatrixUtils.transformRect(
      object.getTransformTo(overlay),
      Offset.zero & object.size,
    );
  }

  /// Shows [builder]'s widget next to [anchorRect] (in the overlay of the
  /// navigator [useRootNavigator] picks, see [anchorRectOf]) at [placement],
  /// [gap] away from it and shifted along its edge by [offset].
  ///
  /// The popover is a dialog route: tapping the barrier dismisses it when
  /// [barrierDismissible], and [Navigator.pop] closes it with a result.
  static Future<T?> show<T>({
    required BuildContext context,
    required Rect anchorRect,
    required WidgetBuilder builder,
    DialogPlacement placement = DialogPlacement.belowStart,
    double gap = 4,
    double offset = 0,
    bool barrierDismissible = true,
    Color? barrierColor,
    bool useRootNavigator = false,
    RouteSettings? routeSettings,
  }) {
    final NavigatorState navigator = Navigator.of(
      context,
      rootNavigator: useRootNavigator,
    );
    // The route sits outside the widgets that opened it; take their themes
    // along as a dialog does.
    final CapturedThemes themes = InheritedTheme.capture(
      from: context,
      to: navigator.context,
    );
    final TextDirection textDirection =
        Directionality.maybeOf(context) ?? TextDirection.ltr;
    return showGeneralDialog<T>(
      context: context,
      useRootNavigator: useRootNavigator,
      barrierDismissible: barrierDismissible,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: barrierColor ?? Colors.black54,
      routeSettings: routeSettings,
      transitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (context, animation, secondaryAnimation) {
        final EdgeInsets padding =
            MediaQuery.paddingOf(context) + const EdgeInsets.all(screenMargin);
        return CustomSingleChildLayout(
          delegate: CodelesslyPopoverLayout(
            anchor: anchorRect,
            placement: placement,
            gap: gap,
            offset: offset,
            textDirection: textDirection,
            padding: padding,
          ),
          child: themes.wrap(Builder(builder: builder)),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          ),
    );
  }
}

/// Lays a popover out next to its [anchor]: on [placement]'s side, [gap]
/// away, and lined up with the anchor as [placement] says, shifted along the
/// anchor's edge by [offset].
///
/// When the popover does not fit on its side, it goes on the opposite side
/// if that has more room. It is then kept inside the screen, minus
/// [padding].
class CodelesslyPopoverLayout extends SingleChildLayoutDelegate {
  /// The trigger's rect, in this layout's coordinates.
  final Rect anchor;

  /// The side the popover opens on and how it lines up with [anchor].
  final DialogPlacement placement;

  /// The space between [anchor] and the popover.
  final double gap;

  /// The shift along [anchor]'s edge: toward the end for a placement below
  /// or above (right in a left-to-right app), down for one beside it.
  final double offset;

  /// The reading direction start and end follow.
  final TextDirection textDirection;

  /// The space kept free at the screen edges.
  final EdgeInsets padding;

  const CodelesslyPopoverLayout({
    required this.anchor,
    required this.placement,
    this.gap = 4,
    this.offset = 0,
    this.textDirection = TextDirection.ltr,
    this.padding = EdgeInsets.zero,
  });

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final Size biggest = constraints.biggest;
    return BoxConstraints.loose(
      Size(
        math.max(0, biggest.width - padding.horizontal),
        math.max(0, biggest.height - padding.vertical),
      ),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final Rect bounds = Rect.fromLTRB(
      padding.left,
      padding.top,
      math.max(padding.left, size.width - padding.right),
      math.max(padding.top, size.height - padding.bottom),
    );
    final _Side side = _sideOf(placement);
    final _Align align = _alignOf(placement);
    double x;
    double y;

    if (placement.isVertical) {
      bool below = side == _Side.below;
      final double spaceBelow = bounds.bottom - anchor.bottom - gap;
      final double spaceAbove = anchor.top - gap - bounds.top;
      if (below && childSize.height > spaceBelow && spaceAbove > spaceBelow) {
        below = false;
      } else if (!below &&
          childSize.height > spaceAbove &&
          spaceBelow > spaceAbove) {
        below = true;
      }
      y = below ? anchor.bottom + gap : anchor.top - gap - childSize.height;

      final bool rtl = textDirection == TextDirection.rtl;
      x = switch (align) {
        _Align.start => rtl ? anchor.right - childSize.width : anchor.left,
        _Align.center => anchor.center.dx - childSize.width / 2,
        _Align.end => rtl ? anchor.left : anchor.right - childSize.width,
      };
      x += rtl ? -offset : offset;
    } else {
      bool right = side == _Side.right;
      final double spaceRight = bounds.right - anchor.right - gap;
      final double spaceLeft = anchor.left - gap - bounds.left;
      if (right && childSize.width > spaceRight && spaceLeft > spaceRight) {
        right = false;
      } else if (!right &&
          childSize.width > spaceLeft &&
          spaceRight > spaceLeft) {
        right = true;
      }
      x = right ? anchor.right + gap : anchor.left - gap - childSize.width;
      y = switch (align) {
        _Align.start => anchor.top,
        _Align.center => anchor.center.dy - childSize.height / 2,
        _Align.end => anchor.bottom - childSize.height,
      };
      y += offset;
    }

    x = x.clamp(
      bounds.left,
      math.max(bounds.left, bounds.right - childSize.width),
    );
    y = y.clamp(
      bounds.top,
      math.max(bounds.top, bounds.bottom - childSize.height),
    );
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(CodelesslyPopoverLayout oldDelegate) =>
      anchor != oldDelegate.anchor ||
      placement != oldDelegate.placement ||
      gap != oldDelegate.gap ||
      offset != oldDelegate.offset ||
      textDirection != oldDelegate.textDirection ||
      padding != oldDelegate.padding;
}

enum _Side { below, above, right, left }

enum _Align { start, center, end }

_Side _sideOf(DialogPlacement placement) => switch (placement) {
  DialogPlacement.belowStart ||
  DialogPlacement.belowCenter ||
  DialogPlacement.belowEnd => _Side.below,
  DialogPlacement.aboveStart ||
  DialogPlacement.aboveCenter ||
  DialogPlacement.aboveEnd => _Side.above,
  DialogPlacement.rightStart ||
  DialogPlacement.rightCenter ||
  DialogPlacement.rightEnd => _Side.right,
  DialogPlacement.leftStart ||
  DialogPlacement.leftCenter ||
  DialogPlacement.leftEnd => _Side.left,
  DialogPlacement.anchored ||
  DialogPlacement.center ||
  DialogPlacement.bottomSheet ||
  DialogPlacement.adaptive => _Side.below,
};

_Align _alignOf(DialogPlacement placement) => switch (placement) {
  DialogPlacement.belowStart ||
  DialogPlacement.aboveStart ||
  DialogPlacement.rightStart ||
  DialogPlacement.leftStart => _Align.start,
  DialogPlacement.belowCenter ||
  DialogPlacement.aboveCenter ||
  DialogPlacement.rightCenter ||
  DialogPlacement.leftCenter => _Align.center,
  DialogPlacement.belowEnd ||
  DialogPlacement.aboveEnd ||
  DialogPlacement.rightEnd ||
  DialogPlacement.leftEnd => _Align.end,
  DialogPlacement.anchored ||
  DialogPlacement.center ||
  DialogPlacement.bottomSheet ||
  DialogPlacement.adaptive => _Align.start,
};
