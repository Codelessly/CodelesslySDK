import 'package:flutter/painting.dart';

/// The style every text run is merged over: Material 3's `bodySmall`
/// (englishLike, 2021) with proportional leading, and no line height: a run
/// without one takes the inherited default text style's (a node's
/// `defaultTextStyle`, Flutter's `DefaultTextStyle`), else the font's own
/// (Flutter's `height: null`). Letter spacing is always the run's own (0
/// when unset).
const TextStyle kTextBase = TextStyle(
  inherit: false,
  fontSize: 12,
  fontWeight: FontWeight.w400,
  letterSpacing: 0.4,
  textBaseline: TextBaseline.alphabetic,
  leadingDistribution: TextLeadingDistribution.proportional,
);
