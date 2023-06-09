import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../codelessly_sdk.dart';

class PassiveTextTransformer extends NodeWidgetTransformer<TextNode> {
  PassiveTextTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    TextNode node,
    BuildContext context, [
    WidgetBuildSettings settings = const WidgetBuildSettings(),
  ]) {
    final Widget child = PassiveTextWidget(node: node, settings: settings);
    if (isTestLayout) {
      return DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.red, width: 2),
        ),
        child: child,
      );
    } else {
      return child;
    }
  }

  static Color? getTextColor(TextNode node) {
    if (node.textMixedProps[0].fills.isNotEmpty &&
        (node.textMixedProps[0].fills[0].color != null)) {
      return node.textMixedProps[0].fills[0].toFlutterColor()!;
    } else {
      // Use pink as a placeholder while we add support for Gradients.
      return null;
    }
  }

  static List<TextSpan> getTextSpan(
    TextNode node, {
    Map<String, TapGestureRecognizer> tapGestureRecognizers = const {},
    List<VariableData> variablesOverrides = const [],
    BuildContext? context,
  }) {
    final List<TextSpan> textSpanChildren = node.textMixedProps.map(
      (spanProp) {
        // Get relevant characters.
        String characters = node.characters.substring(
          spanProp.start,
          spanProp.end,
        );

        if (context != null) {
          characters = PropertyValueDelegate.substituteVariables(
            context,
            characters,
            variablesOverrides: variablesOverrides,
          );
        }

        return TextSpan(
          text: characters,
          style: retrieveTextStyleData(
            fontSize: spanProp.fontSize,
            fontName: spanProp.fontName,
            textDecoration: spanProp.textDecoration,
            lineHeight: spanProp.lineHeight,
            letterSpacing: spanProp.letterSpacing,
            effects: node.effects,
            // Use pink as a placeholder while we add support for Gradients.
            color:
                (spanProp.fills.isNotEmpty && (spanProp.fills[0].color != null))
                    ? spanProp.fills[0].toFlutterColor()!
                    : Colors.pink,
          ),
          recognizer: tapGestureRecognizers[spanProp.link],
        );
      },
    ).toList();

    return textSpanChildren;
  }

  /// Convert LetterSpacing from Figma values into Flutter.
  static double? retrieveLetterSpacing(
      LetterSpacing letterSpacing, double fontSize) {
    if (letterSpacing.unit == LetterSpacingUnitEnum.pixels) {
      return letterSpacing.value;
    } else if (letterSpacing.unit == LetterSpacingUnitEnum.percent) {
      return (letterSpacing.value * fontSize) / 100;
    } else {
      // When it is set to AUTO.
      // ignore: avoid_returning_null
      return null;
    }
  }

  /// Convert LineHeight from Figma values into Flutter.
  static double? retrieveLineHeight(LineHeight lineHeight, double fontSize) {
    if (lineHeight.unit == LineHeightUnitEnum.pixels) {
      return lineHeight.value! / fontSize;
    } else if (lineHeight.unit == LineHeightUnitEnum.percent) {
      return lineHeight.value! / 100;
    } else {
      // ignore: avoid_returning_null
      return null;
    }
  }

  static TextStyle retrieveTextStyleFromProp(TextProp prop) {
    return retrieveTextStyleData(
      fontSize: prop.fontSize,
      lineHeight: prop.lineHeight,
      letterSpacing: prop.letterSpacing,
      color: prop.fills.firstOrNull?.toFlutterColor(),
      fontName: prop.fontName,
      textDecoration: prop.textDecoration,
      effects: [],
    );
  }

  static TextStyle retrieveTextStyleDataFromNode(TextNode node) {
    return retrieveTextStyleData(
      fontSize: node.textMixedProps[0].fontSize,
      fontName: node.textMixedProps[0].fontName,
      textDecoration: node.textMixedProps[0].textDecoration,
      lineHeight: node.textMixedProps[0].lineHeight,
      letterSpacing: node.textMixedProps[0].letterSpacing,
      color: PassiveTextTransformer.getTextColor(node),
      effects: node.effects,
    );
  }

  static TextStyle retrieveTextStyleFromStartEndProp(StartEndProp prop) =>
      retrieveTextStyleData(
        fontSize: prop.fontSize,
        fontName: prop.fontName,
        textDecoration: prop.textDecoration,
        lineHeight: null,
        letterSpacing: prop.letterSpacing,
        color: prop.fills.firstOrNull?.toFlutterColor() ?? Colors.black,
        effects: [],
      );

  static TextStyle? retrieveTextStyleFromTextProp(TextProp? prop) {
    if (prop == null) return null;
    return retrieveTextStyleData(
      fontSize: prop.fontSize,
      fontName: prop.fontName,
      textDecoration: prop.textDecoration,
      lineHeight: null,
      letterSpacing: prop.letterSpacing,
      color: prop.fills.firstOrNull?.toFlutterColor(),
      effects: [],
    );
  }

  static TextStyle retrieveTextStyleData({
    required double fontSize,
    required LineHeight? lineHeight,
    required LetterSpacing letterSpacing,
    required Color? color,
    required FontName fontName,
    required TextDecorationEnum textDecoration,
    required List<Effect> effects,
  }) {
    final TextDecoration textDecorationProp = textDecoration.toFlutter();

    final FontWeight fontWeightProp = fontName.flutterFontWeight;

    final double? lineHeightProp =
        (lineHeight == null) ? null : retrieveLineHeight(lineHeight, fontSize);
    final double? letterSpacingProp =
        retrieveLetterSpacing(letterSpacing, fontSize);
    final FontStyle fontStyle =
        (fontName.style.toLowerCase().contains('italic'))
            ? FontStyle.italic
            : FontStyle.normal;

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

    final bool isGoogleFont = GoogleFonts.asMap().containsKey(fontName.family);
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
      final fontFamily = getFontFamilyNameAndVariant(fontName);

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
}

class PassiveTextWidget extends StatefulWidget {
  final TextNode node;
  final WidgetBuildSettings settings;
  final List<VariableData> variablesOverrides;
  final bool clickable;

  PassiveTextWidget({
    super.key,
    required this.node,
    this.settings = const WidgetBuildSettings(),
    this.variablesOverrides = const [],
    this.clickable = true,
  });

  @override
  State<PassiveTextWidget> createState() => _PassiveTextWidgetState();
}

class _PassiveTextWidgetState extends State<PassiveTextWidget> {
  /// Map of URL to TapGestureRecognizer.
  Map<String, TapGestureRecognizer> tapGestureRecognizerRegistry = {};

  @override
  void initState() {
    super.initState();
    initTapGestureRecognizers();
  }

  @override
  void dispose() {
    disposeTapGestureRecognizers();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PassiveTextWidget oldWidget) {
    disposeTapGestureRecognizers();
    initTapGestureRecognizers();
    super.didUpdateWidget(oldWidget);
  }

  /// Initializes TapGestureRecognizer for each link that's not empty and
  /// stores in a [tapGestureRecognizerRegistry].
  void initTapGestureRecognizers() {
    if (!widget.clickable) return;
    widget.node.textMixedProps.forEach((property) {
      String link = property.link;
      if (link.isNotEmpty) {
        TapGestureRecognizer tapGestureRecognizer =
            TapGestureRecognizer(debugOwner: link)
              ..onTap = () => launchUrl(Uri.parse(link));
        tapGestureRecognizerRegistry[link] = tapGestureRecognizer;
      }
    });
  }

  /// Disposes TapGestureRecognizer and resets [tapGestureRecognizerRegistry].
  void disposeTapGestureRecognizers() {
    if (!widget.clickable) return;
    tapGestureRecognizerRegistry.forEach(
        (link, tapGestureRecognizer) => tapGestureRecognizer.dispose());
    tapGestureRecognizerRegistry = {};
  }

  @override
  Widget build(BuildContext context) {
    Widget textWidget;

    if (widget.node.textMixedProps.length == 1) {
      // Get relevant characters.
      final charactersValue = PropertyValueDelegate.getPropertyValue<String>(
            context,
            widget.node,
            'characters',
            variablesOverrides: widget.variablesOverrides,
          ) ??
          widget.node.characters;

      final String characters = PropertyValueDelegate.substituteVariables(
        context,
        charactersValue,
        variablesOverrides: widget.variablesOverrides,
      );

      final StartEndProp textProps = widget.node.textMixedProps.first;
      textWidget = Text(
        characters,
        textAlign: widget.node.textAlignHorizontal.toFlutter(),
        overflow: widget.node.overflow.flutterOverflow,
        maxLines: widget.node.maxLines,
        style: PassiveTextTransformer.retrieveTextStyleData(
          fontSize: textProps.fontSize,
          fontName: textProps.fontName,
          textDecoration: textProps.textDecoration,
          lineHeight: textProps.lineHeight,
          letterSpacing: textProps.letterSpacing,
          color: PassiveTextTransformer.getTextColor(widget.node),
          effects: widget.node.effects,
        ),
      );

      if (tapGestureRecognizerRegistry.length == 1) {
        textWidget = GestureDetector(
          onTap: () =>
              launchUrl(Uri.parse(tapGestureRecognizerRegistry.keys.first)),
          child: textWidget,
        );
      }
    } else {
      List<InlineSpan> spans = PassiveTextTransformer.getTextSpan(
        widget.node,
        variablesOverrides: widget.variablesOverrides,
        context: context,
        tapGestureRecognizers: tapGestureRecognizerRegistry,
      );

      textWidget = RichText(
        text: TextSpan(children: spans),
        textAlign: widget.node.textAlignHorizontal.toFlutter(),
        maxLines: widget.node.maxLines,
        overflow: widget.node.overflow.flutterOverflow,
      );
    }

    // Text Align Vertical (top/middle/center). There is no Text property for this.
    // Occasionally this also overrides the textAlign property.
    // if (node.textAutoResize != TextAutoResize.WIDTH_AND_HEIGHT) {
    //   widget = Align(
    //     alignment: PassiveTextTransformer.getTextNodeAlign(node),
    //     child: widget,
    //   );
    // }
    //
    // // Manually set the Text size.
    // if (node.textAutoResize == TextAutoResize.HEIGHT) {
    //   widget = SizedBox(
    //     child: widget,
    //     width: node.basicBoxLocal.width,
    //   );
    // } else if (node.textAutoResize == TextAutoResize.NONE) {
    //   widget = SizedBox(
    //     child: widget,
    //     width: node.basicBoxLocal.width,
    //     height: node.basicBoxLocal.height,
    //   );
    // }

    return AdaptiveNodeBox(
      node: widget.node,
      child: textWidget,
    );
  }
}
