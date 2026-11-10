// A navigation's page transition (NavigateAction.transition): fade, rise,
// slide or scale in over its duration, or none; the platform's is none on
// the web. SDK 8.x's FunctionsRepository.navigationRoute.
import 'package:codelessly_api/codelessly_api.dart' show PageTransition;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../runtime/actions/hero_flights.dart';

/// [transition] where the app runs: the platform's page transition off
/// Apple platforms is Android's zoom, which a website shouldn't play, so on
/// the web it is none.
PageTransition webTransition(PageTransition transition, {bool isWeb = kIsWeb}) =>
    isWeb && transition == PageTransition.platform ? PageTransition.none : transition;

/// Milliseconds [transition] takes when the action doesn't say.
int defaultTransitionMs(PageTransition transition) => switch (transition) {
      PageTransition.platform => 300,
      PageTransition.none => 0,
      PageTransition.fade => 250,
      PageTransition.fadeUp => 520,
      PageTransition.slideUp => 400,
      PageTransition.slideLeft => 350,
      PageTransition.scale => 300,
    };

/// A screen's route playing [transition] (not the platform's) over
/// [transitionMs] and back over [reverseTransitionMs], flying shared
/// elements as long as it lasts.
class CodelesslyPageTransitionRoute<T> extends PageRouteBuilder<T> with CodelesslyHeroRoute<T> {
  CodelesslyPageTransitionRoute({
    required this.transition,
    required WidgetBuilder builder,
    int? transitionMs,
    int? reverseTransitionMs,
    super.settings,
  }) : super(
          transitionDuration: Duration(milliseconds: _ms(transitionMs ?? defaultTransitionMs(transition))),
          reverseTransitionDuration:
              Duration(milliseconds: _ms(reverseTransitionMs ?? transitionMs ?? defaultTransitionMs(transition))),
          pageBuilder: (context, _, _) => builder(context),
          transitionsBuilder: (context, animation, _, child) => buildPageTransition(context, transition, animation, child),
        );

  final PageTransition transition;

  static int _ms(int ms) => ms.clamp(0, 60000);
}

/// Draws [child], a screen coming in, with [transition] at [animation]'s
/// value (0 hidden, 1 shown; it runs back when the screen leaves).
Widget buildPageTransition(BuildContext context, PageTransition transition, Animation<double> animation, Widget child) {
  final eased = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
  switch (transition) {
    case PageTransition.platform || PageTransition.none:
      return child;
    case PageTransition.fade:
      return FadeTransition(opacity: eased, child: child);
    case PageTransition.fadeUp:
      // Fades in over the first 60% while rising 3% of its height.
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: const Interval(0, 0.6)),
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero).animate(eased),
          child: child,
        ),
      );
    case PageTransition.slideUp:
      return SlideTransition(position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(eased), child: child);
    case PageTransition.slideLeft:
      final rtl = Directionality.maybeOf(context) == TextDirection.rtl;
      return SlideTransition(
        position: Tween<Offset>(begin: Offset(rtl ? -1 : 1, 0), end: Offset.zero).animate(eased),
        child: child,
      );
    case PageTransition.scale:
      return FadeTransition(
        opacity: eased,
        child: ScaleTransition(scale: Tween<double>(begin: 0.9, end: 1).animate(eased), child: child),
      );
  }
}
