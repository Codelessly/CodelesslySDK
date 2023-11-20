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
  static double? retrieveLetterSpacing(
    LetterSpacing letterSpacing,
    double fontSize,
  ) {
    if (letterSpacing.unit == LetterSpacingUnitEnum.pixels) {
      return letterSpacing.value;
    } else if (letterSpacing.unit == LetterSpacingUnitEnum.percent) {
      return (letterSpacing.value * fontSize) / 100;
    } else {
      // When it is set to ZERO.
      return null;
    }
  }

  /// Convert LineHeight from Figma values into Flutter.
  static double? retrieveLineHeight(
    LineHeight lineHeight,
    double fontSize,
  ) {
    if (lineHeight.unit == LineHeightUnitEnum.pixels) {
      return lineHeight.value! / fontSize;
    } else if (lineHeight.unit == LineHeightUnitEnum.percent) {
      return lineHeight.value! / 100;
    } else {
      // When it is set to AUTO.
      return null;
    }
  }

  static TextStyle retrieveTextStyleFromTextNode(
    TextNode node, {
    Color? color,
    double? fontSize,
    LetterSpacing? letterSpacing,
    LineHeight? lineHeight,
    FontName? fontName,
    TextDecorationEnum? textDecoration,
  }) {
    double? effectiveFontSize;
    FontName? effectiveFontName;
    TextDecorationEnum? effectiveTextDecoration;
    LineHeight? effectiveLineHeight;
    LetterSpacing? effectiveLetterSpacing;
    Color? effectiveColor;

    for (final prop in node.textMixedProps) {
      effectiveFontSize ??= prop.fontSize;
      effectiveFontName ??= prop.fontName;
      effectiveTextDecoration ??= prop.textDecoration;
      effectiveLineHeight ??= prop.lineHeight;
      effectiveLetterSpacing ??= prop.letterSpacing;
      effectiveColor ??= retrievePropColor(prop);
    }

    return retrieveTextStyle(
      fontSize: effectiveFontSize ?? fontSize,
      fontName: effectiveFontName ?? fontName,
      textDecoration: effectiveTextDecoration ?? textDecoration,
      lineHeight: effectiveLineHeight ?? lineHeight,
      letterSpacing: effectiveLetterSpacing ?? letterSpacing,
      color: effectiveColor ?? color,
      effects: node.effects,
    );
  }

  static TextStyle retrieveTextStyleFromProp(
    TextProp prop, {
    List<Effect> effects = const [],
  }) {
    return retrieveTextStyle(
      fontSize: prop.fontSize,
      fontName: prop.fontName,
      textDecoration: prop.textDecoration,
      lineHeight: prop.lineHeight,
      letterSpacing: prop.letterSpacing,
      color: retrievePropColor(prop),
      effects: effects,
    );
  }

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

    final bool isGoogleFont = fontName == null
        ? false
        : GoogleFonts.asMap().containsKey(fontName.family);
    if (isGoogleFont) {
      return GoogleFonts.getFont(
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
      return TextStyle(
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
  }

  static TextSpan buildTextSpanForProp(
    BuildContext? context,
    String rawText, {
    required String? fieldName,
    required BaseNode? node,
    required TextProp prop,
    required TapGestureRecognizer? tapGestureRecognizer,
    required List<VariableData> variablesOverrides,
    required NullSubstitutionMode nullSubstitutionMode,
    required bool replaceVariableWithSymbol,
    List<Effect>? effects,
  }) {
    String characters;

    if (fieldName != null && node != null && context != null) {
      characters = PropertyValueDelegate.getPropertyValue<String>(
            context,
            node,
            fieldName,
            variablesOverrides: variablesOverrides,
          ) ??
          rawText;
    } else {
      characters = rawText;
    }

    if (prop is StartEndProp) {
      characters = rawText.substring(prop.start, prop.end);
    }

    final TextStyle style = retrieveTextStyleFromProp(
      prop,
      effects: effects ?? (node is BlendMixin ? node.effects : const []),
    );

    if (replaceVariableWithSymbol) {
      final bool isVariable =
          variableSyntaxIdentifierRegex.hasMatch(characters);
      if (isVariable) {
        return VariableSpan(
          variable: characters,
          style: style,
        );
      }
    }

    if (context != null) {
      characters = PropertyValueDelegate.substituteVariables(
        context,
        characters,
        variablesOverrides: variablesOverrides,
        nullSubstitutionMode: nullSubstitutionMode,
      );
    }

    return TextSpan(
      text: characters,
      style: style,
      recognizer: tapGestureRecognizer,
    );
  }

  static TextSpan buildTextSpan(
    BuildContext context,
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
    required String? fieldName,
    required BaseNode? node,
    required List<VariableData> variablesOverrides,
    required NullSubstitutionMode nullSubstitutionMode,
    required bool replaceVariableWithSymbol,
    TapGestureRecognizer? tapGestureRecognizer,
  }) {
    String characters;

    if (fieldName != null && node != null) {
      characters = PropertyValueDelegate.getPropertyValue<String>(
            context,
            node,
            fieldName,
            variablesOverrides: variablesOverrides,
          ) ??
          rawText;
    } else {
      characters = rawText;
    }

    final TextStyle style = retrieveTextStyle(
      fontSize: fontSize,
      fontName: fontName,
      textDecoration: textDecoration,
      lineHeight: lineHeight,
      letterSpacing: letterSpacing,
      color: color,
      effects: effects ?? (node is BlendMixin ? node.effects : const []),
    );

    if (replaceVariableWithSymbol) {
      final bool isVariable =
          variableSyntaxIdentifierRegex.hasMatch(characters);
      if (isVariable) {
        return VariableSpan(
          variable: characters,
          style: style,
        );
      }
    }

    characters = PropertyValueDelegate.substituteVariables(
      context,
      characters,
      variablesOverrides: variablesOverrides,
      nullSubstitutionMode: nullSubstitutionMode,
    );

    return TextSpan(
      text: characters,
      style: style,
      recognizer: tapGestureRecognizer,
    );
  }

  static List<TextSpan> buildTextSpansForProps(
    BuildContext? context,
    String rawText, {
    required String? fieldName,
    required BaseNode? node,
    required List<TextProp> props,
    required List<VariableData> variablesOverrides,
    required NullSubstitutionMode nullSubstitutionMode,
    required bool replaceVariablesWithSymbol,
    List<Effect>? effects,
    Map<String, TapGestureRecognizer> tapGestureRecognizers = const {},
  }) {
    return [
      for (final prop in props)
        buildTextSpanForProp(
          context,
          rawText,
          fieldName: fieldName,
          node: node,
          prop: prop,
          variablesOverrides: variablesOverrides,
          nullSubstitutionMode: nullSubstitutionMode,
          replaceVariableWithSymbol: replaceVariablesWithSymbol,
          tapGestureRecognizer: tapGestureRecognizers[prop.link],
          effects: effects ?? (node is BlendMixin ? node.effects : const []),
        ),
    ];
  }

  static Text buildTextForProps(
    BuildContext context,
    String rawText, {
    required BaseNode node,
    required String fieldName,
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
      fieldName: fieldName,
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
    Map<String, TapGestureRecognizer> tapGestureRecognizers = const {},
  }) {
    final spans = buildTextSpansForProps(
      context,
      textNode.characters,
      node: textNode,
      props: textNode.textMixedProps,
      fieldName: 'characters',
      variablesOverrides: variablesOverrides,
      nullSubstitutionMode: nullSubstitutionMode,
      replaceVariablesWithSymbol: replaceVariablesWithSymbol,
      tapGestureRecognizers: tapGestureRecognizers,
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
    required String? fieldName,

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
      tapGestureRecognizer: tapGestureRecognizers,
      fieldName: fieldName,
      node: node,
    );

    return Text.rich(
      TextSpan(children: [span]),
      textAlign: textAlignHorizontal?.toFlutter(),
      maxLines: maxLines,
      overflow: overflow?.flutterOverflow,
    );
  }
}
