// A host for a Codelessly view that is a part of a larger app (a preview
// canvas in an editor, a panel): the box the view is in is its whole world.
//
// What a view opens or floats — a dialog, a sheet, a drawer, a menu or a
// popover, a confirm dialog, a toast, a banner, a hover card
// — is shown by the app's navigator and overlay, which cover the
// whole window: a dialog of a 390 × 844 preview dims and centres on the
// editor around it. Under a [CodelesslyViewHost] they are shown in the
// host's own navigator and overlay, which are exactly the host's box: a
// dialog centres in it, a sheet rises from its bottom edge and is as wide
// as it, the barrier dims it alone, everything is clipped to it and scales
// with it, and a press outside it reaches what is there.
// (A drag's proxy is still drawn in the overlay around the view: the
// drag code is under this layer.)
//
// The runtime asks [viewNavigatorOf] and [viewOverlayOf] wherever it asked
// `Navigator.of` and `Overlay.of` (the root ones too): the host's when the
// context is under one, else the app's as before, so an app with no host is
// unchanged. Give the host the box's MediaQuery (its size) above it: the
// routes read it.
import 'package:flutter/widgets.dart';

/// Makes its box the world of the Codelessly views under it: see the
/// library's comment. Its size is [child]'s.
class CodelesslyViewHost extends StatefulWidget {
  const CodelesslyViewHost({super.key, required this.child});

  /// The view (and whatever is around it in the box: a scroll view).
  final Widget child;

  /// The navigator of the host [context] is under; null when it is under
  /// none.
  static NavigatorState? navigatorOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_ViewHostScope>()?.navigator.currentState;

  /// The overlay of the host [context] is under; null when it is under none.
  static OverlayState? overlayOf(BuildContext context) => navigatorOf(context)?.overlay;

  @override
  State<CodelesslyViewHost> createState() => _CodelesslyViewHostState();
}

class _CodelesslyViewHostState extends State<CodelesslyViewHost> {
  final GlobalKey<NavigatorState> _navigator = GlobalKey<NavigatorState>(debugLabel: 'CodelesslyViewHost');

  @override
  Widget build(BuildContext context) => _ViewHostScope(
        navigator: _navigator,
        child: Stack(
          // The view sizes the host; what it opens is clipped to that box.
          fit: StackFit.passthrough,
          clipBehavior: Clip.hardEdge,
          children: [
            widget.child,
            Positioned.fill(
              // The host's routes are no part of the app's hero flights.
              child: HeroControllerScope.none(
                child: Navigator(
                  key: _navigator,
                  // Under everything the view opens: an empty page a press
                  // goes through to the view.
                  onGenerateInitialRoutes: (navigator, initialRoute) => [_EmptyRoute()],
                  onGenerateRoute: (settings) => _EmptyRoute(settings: settings),
                ),
              ),
            ),
          ],
        ),
      );
}

class _ViewHostScope extends InheritedWidget {
  const _ViewHostScope({required this.navigator, required super.child});

  final GlobalKey<NavigatorState> navigator;

  @override
  bool updateShouldNotify(_ViewHostScope oldWidget) => oldWidget.navigator != navigator;
}

/// The route under a host's routes: nothing is drawn and nothing is pressed
/// (it is no modal route: it has no barrier, so a press goes through to the
/// view under the navigator).
class _EmptyRoute extends OverlayRoute<void> {
  _EmptyRoute({super.settings});

  @override
  Iterable<OverlayEntry> createOverlayEntries() => [OverlayEntry(builder: (context) => const SizedBox.shrink())];
}

/// The navigator what a view at [context] opens is shown in: its
/// [CodelesslyViewHost]'s, else the app's (the root one with [rootNavigator]);
/// null when there is none.
NavigatorState? maybeViewNavigatorOf(BuildContext context, {bool rootNavigator = false}) =>
    CodelesslyViewHost.navigatorOf(context) ?? Navigator.maybeOf(context, rootNavigator: rootNavigator);

/// [maybeViewNavigatorOf], which must be there.
NavigatorState viewNavigatorOf(BuildContext context, {bool rootNavigator = false}) =>
    CodelesslyViewHost.navigatorOf(context) ?? Navigator.of(context, rootNavigator: rootNavigator);

/// The context the themes around a view at [from] are captured up to, for
/// what it shows in [shownIn] (a navigator's or an overlay's context,
/// `InheritedTheme.capture`'s `to`): [shownIn] itself, or, when that is its
/// host's (which is beside the view, not around it), the host, which is
/// around both.
BuildContext viewThemesTo(BuildContext from, BuildContext shownIn) {
  final host = from.getElementForInheritedWidgetOfExactType<_ViewHostScope>();
  if (host == null) return shownIn;
  final navigator = (host.widget as _ViewHostScope).navigator.currentState;
  if (navigator == null) return shownIn;
  return identical(navigator.context, shownIn) || identical(navigator.overlay?.context, shownIn) ? host : shownIn;
}

/// The overlay what a view at [context] floats is shown in: its
/// [CodelesslyViewHost]'s, else the app's (the root one with [rootOverlay]);
/// null when there is none.
OverlayState? maybeViewOverlayOf(BuildContext context, {bool rootOverlay = false}) =>
    CodelesslyViewHost.overlayOf(context) ?? Overlay.maybeOf(context, rootOverlay: rootOverlay);
