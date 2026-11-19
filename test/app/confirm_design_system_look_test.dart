// A confirm action's built-in dialog under a design system takes the system's
// dialog: its corner, its title and body sizes, its control height and its
// secondary button's outline. A theme with no dialog of its own is unchanged.
import 'package:codelessly_sdk/codelessly_sdk.dart' show ThemeTokens;
import 'package:codelessly_sdk/src/app/ui/feedback_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a design system with a dialog: its radius, sizes, control height and outlined cancel', () {
    final t = FeedbackTheme.fromTokens(ThemeTokens.fromJson({
      'radius': 12,
      'radii': {'popup': 10, 'dialog': 12},
      'sizes': {'control': 34},
      'colors': {'secondaryBorder': '#FFD4D4D8'},
      'textStyles': {
        'dialogTitle': {'fontSize': 16, 'fontWeight': 600},
        'body': {'fontSize': 13},
      },
    }));
    expect(t.radius, 12);
    expect(t.titleSize, 16);
    expect(t.messageSize, 13);
    expect(t.buttonHeight, 34);
    expect(t.cancelBorder, const BorderSide(color: Color(0xFFD4D4D8)));
  });

  test('a theme with no dialog of its own keeps the runtime\'s sizes and a text cancel', () {
    final t = FeedbackTheme.fromTokens(ThemeTokens.fromJson({
      'radius': 12,
      'radii': {'popup': 10},
      'sizes': {'control': 34},
      'colors': {'secondaryBorder': '#FFD4D4D8'},
    }));
    expect(t.radius, 10);
    expect(t.titleSize, isNull);
    expect(t.buttonHeight, isNull);
    expect(t.cancelBorder, isNull);
  });
}
