import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../codelessly_sdk.dart';

// const Color _kDefaultColor = Colors.black;
// const double _kDefaultFontSize = 18.0;
// const LetterSpacing _kDefaultLetterSpacing = LetterSpacing.zero;
// const FontName _kDefaultFontName = FontName.robotoRegular;
// const TextDecorationEnum _kDefaultTextDecoration = TextDecorationEnum.none;
// const LineHeight _kDefaultLineHeight = LineHeight.auto;

class TextUtils {
  const TextUtils._();

  static TextSpan buildTextSpanForProp(
    BuildContext? context,
    String rawText, {
    required BaseNode? node,
    required TextProp prop,
    required TapGestureRecognizer? tapGestureRecognizer,
    required List<VariableData> variablesOverrides,
    required NullSubstitutionMode nullSubstitutionMode,
    required bool replaceVariableWithSymbol,
    bool hasMissingFont = false,
    List<Effect>? effects,
  }) {
    String characters = rawText;

    // Get substring from the raw text for the given start and end positions.
    if (prop is StartEndProp) {
      characters = rawText.substring(prop.start, prop.end);
    }

    return buildTextSpan(
      context,
      characters,
      node: node,
      color: retrievePropColor(prop),
      fontSize: prop.fontSize,
      letterSpacing: prop.letterSpacing,
      fontName: prop.fontName,
      lineHeight: prop.lineHeight,
      textDecoration: prop.textDecoration,
      effects: effects ?? (node is BlendMixin ? node.effects : const []),
      variablesOverrides: variablesOverrides,
      nullSubstitutionMode: nullSubstitutionMode,
      replaceVariableWithSymbol: replaceVariableWithSymbol,
      hasMissingFont: hasMissingFont,
      tapGestureRecognizer: tapGestureRecognizer,
    );
  }

  static TextSpan buildTextSpan(
    BuildContext? context,
    String rawText, {
    // Text properties.
    Color? color,
    double? fontSize,
    LetterSpacing? letterSpacing,
    LineHeight? lineHeight,
    FontName? fontName,
    TextDecorationEnum? textDecoration,
    List<Effect>? effects,

    // Additional properties.
    required BaseNode? node,
    required List<VariableData> variablesOverrides,
    required NullSubstitutionMode nullSubstitutionMode,
    required bool replaceVariableWithSymbol,
    bool hasMissingFont = false,
    TapGestureRecognizer? tapGestureRecognizer,
  }) {
    String characters = rawText;

    final TextStyle style = switch (hasMissingFont) {
      false => retrieveTextStyle(
          fontSize: fontSize,
          fontName: fontName,
          textDecoration: textDecoration,
          lineHeight: lineHeight,
          letterSpacing: letterSpacing,
          color: color,
          effects: effects ?? (node is BlendMixin ? node.effects : const []),
        ),
      true => TextStyle(
          color: Colors.red,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          decorationColor: Colors.yellow,
          decoration: TextDecoration.underline,
        ),
    };

    // Replace with fx symbol if required.
    if (replaceVariableWithSymbol) {
      final spans = characters
          .splitMap(
            variableSyntaxIdentifierRegex,
            onMatch: (match) =>
                VariableSpan(variable: characters, style: style),
            onNonMatch: (text) => TextSpan(text: text, style: style),
          )
          .toList();

      if (spans.length == 1) return spans.first;

      return TextSpan(children: spans, style: style);
    } else if (context != null) {
      // Substitute variables.
      characters = PropertyValueDelegate.substituteVariables(
        rawText,
        nullSubstitutionMode: nullSubstitutionMode,
        scopedValues: ScopedValues.of(
          context,
          variablesOverrides: variablesOverrides,
        ),
      );
    }

    return TextSpan(
      text: characters,
      style: style,
      recognizer: tapGestureRecognizer,
    );
  }

  static List<TextSpan> buildTextSpansForProps(
    BuildContext? context,
    String rawText, {
    required BaseNode? node,
    required List<TextProp> props,
    required List<VariableData> variablesOverrides,
    required NullSubstitutionMode nullSubstitutionMode,
    required bool replaceVariablesWithSymbol,
    bool hasMissingFont = false,
    List<Effect>? effects,
    Map<String, TapGestureRecognizer> tapGestureRecognizers = const {},
  }) {
    return [
      for (final prop in props)
        buildTextSpanForProp(
          context,
          rawText,
          node: node,
          prop: prop,
          variablesOverrides: variablesOverrides,
          nullSubstitutionMode: nullSubstitutionMode,
          replaceVariableWithSymbol: replaceVariablesWithSymbol,
          hasMissingFont: hasMissingFont,
          tapGestureRecognizer: tapGestureRecognizers[prop.link],
          effects: effects ?? (node is BlendMixin ? node.effects : const []),
        ),
    ];
  }

  static Text buildTextForProps(
    BuildContext context,
    String rawText, {
    BaseNode? node,
    required List<TextProp> props,
    required List<VariableData> variablesOverrides,
    required NullSubstitutionMode nullSubstitutionMode,
    required bool replaceVariablesWithSymbol,
    TextAlignHorizontalEnum? textAlignHorizontal,
    int? maxLines,
    TextOverflowC? overflow,
    Map<String, TapGestureRecognizer> tapGestureRecognizers = const {},
  }) {
    final spans = buildTextSpansForProps(
      context,
      rawText,
      node: node,
      props: props,
      variablesOverrides: variablesOverrides,
      nullSubstitutionMode: nullSubstitutionMode,
      replaceVariablesWithSymbol: replaceVariablesWithSymbol,
      tapGestureRecognizers: tapGestureRecognizers,
    );

    return Text.rich(
      TextSpan(children: spans),
      textAlign: textAlignHorizontal?.toFlutter(),
      maxLines: maxLines,
      overflow: overflow?.flutterOverflow,
    );
  }

  static Text buildTextForTextNode(
    BuildContext context,
    TextNode textNode, {
    required List<VariableData> variablesOverrides,
    required NullSubstitutionMode nullSubstitutionMode,
    required bool replaceVariablesWithSymbol,
    bool hasMissingFont = false,
    Map<String, TapGestureRecognizer> tapGestureRecognizers = const {},
  }) {
    final spans = buildTextSpansForProps(
      context,
      textNode.characters,
      node: textNode,
      props: textNode.textMixedProps,
      variablesOverrides: variablesOverrides,
      nullSubstitutionMode: nullSubstitutionMode,
      replaceVariablesWithSymbol: replaceVariablesWithSymbol,
      tapGestureRecognizers: tapGestureRecognizers,
      hasMissingFont: hasMissingFont,
    );

    return Text.rich(
      TextSpan(children: spans),
      textAlign: textNode.textAlignHorizontal.toFlutter(),
      maxLines: textNode.maxLines,
      overflow: textNode.overflow.flutterOverflow,
    );
  }

  static Text buildText(
    BuildContext context,
    String rawText, {
    required BaseNode? node,

    // Text properties.
    Color? color,
    double? fontSize,
    LetterSpacing? letterSpacing,
    LineHeight? lineHeight,
    FontName? fontName,
    TextDecorationEnum? textDecoration,
    List<Effect>? effects,
    TapGestureRecognizer? tapGestureRecognizers,
    TextAlignHorizontalEnum? textAlignHorizontal,
    int? maxLines,
    TextOverflowC? overflow,

    // Additional data.
    required List<VariableData> variablesOverrides,
    required NullSubstitutionMode nullSubstitutionMode,
    required bool replaceVariablesWithSymbol,
    bool hasMissingFont = false,
  }) {
    final span = buildTextSpan(
      context,
      rawText,
      fontSize: fontSize,
      fontName: fontName,
      textDecoration: textDecoration,
      lineHeight: lineHeight,
      letterSpacing: letterSpacing,
      color: color,
      effects: effects,
      variablesOverrides: variablesOverrides,
      nullSubstitutionMode: nullSubstitutionMode,
      replaceVariableWithSymbol: replaceVariablesWithSymbol,
      hasMissingFont: hasMissingFont,
      tapGestureRecognizer: tapGestureRecognizers,
      node: node,
    );

    return Text.rich(
      TextSpan(children: [span]),
      textAlign: textAlignHorizontal?.toFlutter(),
      maxLines: maxLines,
      overflow: overflow?.flutterOverflow,
    );
  }

  static Color? retrievePropColor(TextProp prop) => prop.fills
      .firstWhereOrNull((fill) => fill.color != null)
      ?.toFlutterColor();

  static Color? retrieveTextColor(List<TextProp> props) {
    for (final prop in props) {
      final Color? color = prop.fills
          .firstWhereOrNull((fill) => fill.color != null)
          ?.toFlutterColor();
      if (color != null) return color;
    }

    return null;
  }

  /// Convert LetterSpacing from Figma values into Flutter.
  static double retrieveLetterSpacing(
    LetterSpacing letterSpacing,
    double fontSize,
  ) =>
      switch (letterSpacing.unit) {
        LetterSpacingUnitEnum.pixels => letterSpacing.value,
        LetterSpacingUnitEnum.percent => (letterSpacing.value * fontSize) / 100,
      };

  /// Convert LineHeight from Figma values into Flutter.
  static double? retrieveLineHeight(
    LineHeight lineHeight,
    double fontSize,
  ) =>
      lineHeight.value == null || lineHeight.value! <= 0
          ? null
          : switch (lineHeight.unit) {
              LineHeightUnitEnum.pixels => lineHeight.value! / fontSize,
              LineHeightUnitEnum.percent => lineHeight.value! / 100,
              LineHeightUnitEnum.auto => null,
            };

  static TextStyle retrieveTextStyleFromProp(
    TextProp prop, {
    List<Effect> effects = const [],
  }) =>
      retrieveTextStyle(
        fontSize: prop.fontSize,
        fontName: prop.fontName,
        textDecoration: prop.textDecoration,
        lineHeight: prop.lineHeight,
        letterSpacing: prop.letterSpacing,
        color: retrievePropColor(prop),
        effects: effects,
      );

  /// Sets default values.
  static TextStyle retrieveTextStyle({
    Color? color,
    double? fontSize,
    LetterSpacing? letterSpacing,
    LineHeight? lineHeight,
    FontName? fontName,
    TextDecorationEnum? textDecoration,
    List<Effect> effects = const [],
  }) {
    final TextDecoration? textDecorationProp = textDecoration?.toFlutter();

    final double? lineHeightProp = lineHeight != null && fontSize != null
        ? retrieveLineHeight(lineHeight, fontSize)
        : null;
    final double? letterSpacingProp = letterSpacing != null && fontSize != null
        ? retrieveLetterSpacing(letterSpacing, fontSize)
        : null;
    final FontWeight? fontWeightProp = fontName?.flutterFontWeight;
    final FontStyle? fontStyle = fontName != null
        ? (fontName.style.toLowerCase().contains('italic'))
            ? FontStyle.italic
            : FontStyle.normal
        : null;

    // Not supported yet but good to have.
    final List<Shadow> shadows = effects
        .where((element) => element.type == EffectType.dropShadow)
        .map(
          (d) => Shadow(
            offset: Offset(d.offset!.x.toDouble(), d.offset!.y.toDouble()),
            blurRadius: d.radius,
            color: d.color!.toFlutterColor(),
          ),
        )
        .toList();

    final bool isGoogleFont =
        fontName != null && GoogleFonts.asMap().containsKey(fontName.family);
    final TextStyle style;
    if (isGoogleFont) {
      style = GoogleFonts.getFont(
        fontName.family,
        color: color,
        fontStyle: fontStyle,
        fontSize: fontSize,
        fontWeight: fontWeightProp,
        letterSpacing: letterSpacingProp,
        height: lineHeightProp,
        decoration: textDecorationProp,
        shadows: shadows,
      );
    } else {
      final String? fontFamily =
          fontName == null ? null : getFontFamilyNameAndVariant(fontName);

      // Enable this for fonts debugging.
      // print('Transformer is using fontFamily: $fontFamily');
      style = TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeightProp,
        fontStyle: fontStyle,
        letterSpacing: letterSpacingProp,
        height: lineHeightProp,
        shadows: shadows,
        decoration: textDecorationProp,
        fontFamily: fontFamily,
        fontFamilyFallback: const [
          // Enable this to test fonts loading.
          // 'Tofu',
        ],
      );
    }

    final TextTheme typography = Typography.material2021().englishLike;

    return typography.bodySmall!.merge(style);
  }
}
