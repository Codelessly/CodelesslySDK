import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('theme tokens set the feedback theme and win over the nodes', () {
    const ThemeTokens tokens = ThemeTokens(
      primary: ColorRGBA(r: 1, g: 0, b: 0, a: 1),
      fontFamily: 'Inter',
      titleFontFamily: 'Fraunces',
      buttonRadius: 20,
    );
    final FeedbackTheme fromTokens = FeedbackTheme.fromTokens(tokens);
    expect(fromTokens.primary, const Color(0xFFFF0000));
    expect(fromTokens.bodyStyle?.fontFamily, 'Inter');
    expect(fromTokens.titleStyle?.fontFamily, 'Fraunces');
    expect(fromTokens.buttonRadius, 20);

    const FeedbackTheme fromNodes = FeedbackTheme(
      primary: Color(0xFF0000FF),
      surface: Color(0xFFFAFAFA),
    );
    final FeedbackTheme merged = fromTokens.merge(fromNodes);
    expect(merged.primary, const Color(0xFFFF0000));
    expect(merged.surface, const Color(0xFFFAFAFA));
    expect(FeedbackTheme.fromTokens(null).primary, isNull);
  });

  test('a layout carries its theme through JSON', () {
    final SDKPublishLayout layout = SDKPublishLayout(
      id: 'l',
      pageId: 'p',
      projectId: 'pr',
      canvases: const {},
      lastUpdated: DateTime(2026),
      theme: const ThemeTokens(fontFamily: 'Inter'),
      owner: 'o',
      teams: const {},
      users: const {},
      roles: const {},
      public: false,
    );
    expect(
      SDKPublishLayout.fromJson(layout.toJson()).theme,
      const ThemeTokens(fontFamily: 'Inter'),
    );
  });
}
