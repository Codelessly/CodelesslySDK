// The SSUI tokens bundled with the SDK are design_systems/ssui's: the
// design system stays the source (tool/controls/bundle_ssui.dart writes
// them).
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/controls/ssui_defaults.g.dart';
import 'package:codelessly_sdk/src/render/controls/tokens.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the bundled SSUI theme is design_systems/ssui/design_system.json\'s (run tool/controls/bundle_ssui.dart)', () {
    final source = jsonDecode(File('design_systems/ssui/design_system.json').readAsStringSync()) as Map<String, Object?>;
    expect(jsonEncode(ssuiTheme), jsonEncode(source['theme']));
  });

  test('a document\'s theme goes over SSUI\'s; its light primary stays in dark mode when it gives no dark one', () {
    final plain = ControlTokens.resolve(ThemeTokens.none, dark: false);
    expect(plain.primary, const Color(0xFF2563EB));
    expect(plain.hoverOverlay, const Color(0x0A000000));
    final brand = ThemeTokens.fromJson({'primary': '#FF1F6F4A'});
    expect(ControlTokens.resolve(brand, dark: false).primary, const Color(0xFF1F6F4A));
    expect(ControlTokens.resolve(brand, dark: true).primary, const Color(0xFF1F6F4A));
    expect(ControlTokens.resolve(brand, dark: true).hoverOverlay, const Color(0x14FFFFFF), reason: 'SSUI\'s dark overlay');
  });

  test('the control scale: a height picks its nearest step', () {
    final t = ControlTokens.resolve(ThemeTokens.none, dark: false);
    expect([for (final h in const <double>[20, 24, 28, 31, 36, 40, 48]) t.scaleFor(h).name], ['xs', 'xs', 'compact', 'small', 'medium', 'regular', 'large']);
    expect(t.radiusFor(t.scaleFor(24)), 5);
    expect(t.radiusFor(t.scaleFor(28)), 7);
    expect(ControlTokens.resolve(ThemeTokens.fromJson({'buttonRadius': 12}), dark: false).radiusFor(t.scaleFor(24)), 12);
  });

  test('a theme may give each step its own corner, so a 28-high button is not a pill where a 44-high one is round', () {
    final cards = ControlTokens.resolve(
        ThemeTokens.fromJson({
          'radii': {'inner': 9, 'control': 12, 'controlCompact': 8, 'controlSmall': 9, 'controlMedium': 10, 'controlLarge': 12},
        }),
        dark: false);
    expect([for (final h in const <double>[24, 28, 32, 36, 44]) cards.radiusFor(cards.scaleFor(h))], [9, 8, 9, 10, 12]);
    // A step it does not name takes the kind's radius; buttonRadius still wins.
    expect(ControlTokens.resolve(ThemeTokens.fromJson({'radii': {'control': 12, 'controlLarge': 14}}), dark: false).radiusFor(cards.scaleFor(28)), 12);
    expect(
        ControlTokens.resolve(ThemeTokens.fromJson({'buttonRadius': 4, 'radii': {'controlCompact': 8}}), dark: false).radiusFor(cards.scaleFor(28)), 4);
    // SSUI names none: 5 at xs, 7 elsewhere, as before.
    final ssui = ControlTokens.resolve(ThemeTokens.none, dark: false);
    expect([for (final h in const <double>[24, 28, 32, 36, 44]) ssui.radiusFor(ssui.scaleFor(h))], [5, 7, 7, 7, 7]);
  });
}
