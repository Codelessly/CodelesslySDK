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
    expect([for (final h in const <double>[20, 24, 28, 31, 36, 40, 48]) t.scaleFor(h).name], ['xs', 'xs', 'compact', 'small', 'medium', 'medium', 'large']);
    expect(t.radiusFor(t.scaleFor(24)), 5);
    expect(t.radiusFor(t.scaleFor(28)), 7);
    expect(ControlTokens.resolve(ThemeTokens.fromJson({'buttonRadius': 12}), dark: false).radiusFor(t.scaleFor(24)), 12);
  });
  test('a theme with its own surface: SSUI\'s neutral names are made from it, so an unstyled field is not SSUI white on navy (test 4)', () {
    final navy = ThemeTokens.fromJson({
      'mode': 'dark', 'primary': 'lime', 'onPrimary': 'navy', 'surface': 'navy', 'onSurface': 'paper',
      'colors': {'navy': '#FF10123A', 'paper': '#FFF7F7FD', 'lime': '#FFD6FF65'},
    });
    // Whatever brightness the screen reports: the surface says it is dark.
    for (final dark in [false, true]) {
      final t = ControlTokens.resolve(navy, dark: dark);
      expect(t.dark, isTrue);
      expect(t.theme.color('primaryBackground')!.value, 0xFF10123A);
      expect(t.theme.color('primaryText')!.value, 0xFFF7F7FD);
      expect(t.focusBorder, const Color(0x80D6FF65), reason: 'the ring is the document\'s primary, not SSUI blue');
    }
    // A name the document gives is kept.
    final own = ThemeTokens.fromJson({'surface': '#FF10123A', 'colors': {'primaryBorder': '#FFFF0000'}});
    expect(ControlTokens.resolve(own, dark: false).primaryBorder, const Color(0xFFFF0000));
    // A theme with no surface or primary of its own is SSUI's, unchanged.
    expect(ControlTokens.resolve(ThemeTokens.fromJson({'fontFamily': 'Inter'}), dark: false).primaryBorder,
        ControlTokens.resolve(ThemeTokens.none, dark: false).primaryBorder);
  });
}
