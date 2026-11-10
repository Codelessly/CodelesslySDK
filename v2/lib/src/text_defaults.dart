import 'package:flutter/painting.dart';

/// The style every text run is merged over: Material 3's `bodySmall`
/// (englishLike, 2021) with proportional leading, which is what SDK 8.x
/// rendered under. A run without a line height gets its 1.33; letter
/// spacing is always the run's own (0 when unset).
const TextStyle kTextBase = TextStyle(
  inherit: false,
  fontSize: 12,
  fontWeight: FontWeight.w400,
  letterSpacing: 0.4,
  height: 1.33,
  textBaseline: TextBaseline.alphabetic,
  leadingDistribution: TextLeadingDistribution.proportional,
);
