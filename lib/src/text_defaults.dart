import 'package:flutter/painting.dart';

/// The style every text run is merged over: Material 3's `bodySmall`
/// (englishLike, 2021) with proportional leading. A run without a line height gets its 1.33; letter
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

/// [kTextBase] without its line height, for a style that asks for the
/// font's own (`TextStyle.naturalHeight`): Flutter's `height: null`.
const TextStyle kTextBaseNatural = TextStyle(
  inherit: false,
  fontSize: 12,
  fontWeight: FontWeight.w400,
  letterSpacing: 0.4,
  textBaseline: TextBaseline.alphabetic,
  leadingDistribution: TextLeadingDistribution.proportional,
);
