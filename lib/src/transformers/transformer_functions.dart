import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../utils/extensions.dart';
import '../utils/material_icon_versions.dart';
import 'transformers.dart';

/// The colour a button of [type] has when its buttonColor is unset (null):
/// no fill for a text button, as Flutter's TextButton; black for every other
/// type, which is what designs saved before buttonColor was nullable meant by
/// leaving it out. An outlined button is never filled; black is its outline
/// and label colour.
ColorRGBA defaultButtonColorFor(ButtonTypeEnum type) => switch (type) {
  ButtonTypeEnum.text => ColorRGBA.transparent,
  ButtonTypeEnum.elevated ||
  ButtonTypeEnum.outlined ||
  ButtonTypeEnum.filled ||
  ButtonTypeEnum.filledTonal ||
  ButtonTypeEnum.icon => ColorRGBA.black,
};

/// Resolves [ButtonProperties.buttonColor] for rendering.
extension EffectiveButtonColor on ButtonProperties {
  /// [buttonColor], or the [buttonType]'s default when it is unset.
  ColorRGBA get effectiveButtonColor =>
      buttonColor ?? defaultButtonColorFor(buttonType);
}

void convertNodeToButtonType(ButtonTypeEnum type, ButtonNode node) {
  switch (type) {
    case ButtonTypeEnum.elevated:
      final brightness = ThemeData.estimateBrightnessForColor(
        node.properties.effectiveButtonColor.toFlutterColor(),
      );
      final color =
          (brightness == Brightness.light ? Colors.black : Colors.white)
              .toColorRGBA();
      node.properties
        ..labelStyle = node.properties.labelStyle.copyWith(
          fills: [
            color.toPaint(node.properties.labelStyle.fills.firstOrNull?.id),
          ],
        )
        ..icon = node.properties.icon.copyWith(
          color: color.toFlutterColor().toColorRGBA(),
        )
        ..buttonColor = node.properties.buttonColor?.copyWith(a: 1)
        ..elevation = 8
        ..gap = node.properties.icon.show ? 8 : 0
        ..shape = CShapeBorder.roundedRectangle
        ..borderColor = null
        ..borderWidth = null;
    case ButtonTypeEnum.text:
      node.properties
        ..buttonColor = node.properties.buttonColor?.copyWith(a: 0.1)
        ..labelStyle = node.properties.labelStyle.copyWith(
          fills: [
            node.properties.effectiveButtonColor
                .copyWith(a: 1)
                .toPaint(node.properties.labelStyle.fills.firstOrNull?.id),
          ],
        )
        ..icon = node.properties.icon.copyWith(
          color: node.properties.effectiveButtonColor.copyWith(a: 1),
        )
        ..elevation = 0
        ..shape = CShapeBorder.roundedRectangle
        ..borderWidth = null
        ..borderColor = null;
    case ButtonTypeEnum.outlined:
      node.properties
        ..buttonColor = node.properties.buttonColor?.copyWith(a: 1)
        ..labelStyle = node.properties.labelStyle.copyWith(
          fills: [
            node.properties.effectiveButtonColor
                .copyWith(a: 1)
                .toPaint(node.properties.labelStyle.fills.firstOrNull?.id),
          ],
        )
        ..icon = node.properties.icon.copyWith(
          color: node.properties.effectiveButtonColor.copyWith(a: 1),
        )
        ..elevation = 0
        ..shape = CShapeBorder.roundedRectangle
        ..borderWidth = 1
        ..borderColor = null;
    case ButtonTypeEnum.filled:
      final brightness = ThemeData.estimateBrightnessForColor(
        node.properties.effectiveButtonColor.toFlutterColor(),
      );
      final color =
          (brightness == Brightness.light ? Colors.black : Colors.white)
              .toColorRGBA();
      node.properties
        ..labelStyle = node.properties.labelStyle.copyWith(
          fills: [
            color.toPaint(node.properties.labelStyle.fills.firstOrNull?.id),
          ],
        )
        ..icon = node.properties.icon.copyWith(color: color)
        ..buttonColor = node.properties.buttonColor?.copyWith(a: 1)
        ..elevation = 0
        ..gap = node.properties.icon.show ? 8 : 0
        ..shape = CShapeBorder.stadium
        ..borderColor = null
        ..borderWidth = null;
    case ButtonTypeEnum.filledTonal:
      node.properties
        ..buttonColor = node.properties.buttonColor?.copyWith(a: 0.2)
        ..labelStyle = node.properties.labelStyle.copyWith(
          fills: [
            node.properties.effectiveButtonColor
                .copyWith(a: 1)
                .toPaint(node.properties.labelStyle.fills.firstOrNull?.id),
          ],
        )
        ..icon = node.properties.icon.copyWith(
          color: node.properties.effectiveButtonColor.copyWith(a: 1),
        )
        ..elevation = 0
        ..gap = node.properties.icon.show ? 8 : 0
        ..shape = CShapeBorder.stadium
        ..borderColor = null
        ..borderWidth = null;
    case ButtonTypeEnum.icon:
      final brightness = ThemeData.estimateBrightnessForColor(
        node.properties.effectiveButtonColor.toFlutterColor(),
      );
      final color =
          (brightness == Brightness.light ? Colors.black : Colors.white)
              .toColorRGBA();
      node.properties
        ..labelStyle = node.properties.labelStyle.copyWith(
          fills: [
            color.toPaint(node.properties.labelStyle.fills.firstOrNull?.id),
          ],
        )
        ..icon = node.properties.icon.copyWith(color: color)
        ..buttonColor = node.properties.buttonColor?.copyWith(a: 1)
        ..icon = node.properties.icon.copyWith(show: true)
        ..shape = CShapeBorder.circle
        ..gap = 0
        ..elevation = 2
        ..borderColor = null
        ..borderWidth = null;
  }
  if (node.properties.buttonType == ButtonTypeEnum.icon) {
    transformNodeFromIconButton(node);
  } else if (type == ButtonTypeEnum.icon) {
    transformNodeToIconButton(node);
  }
  node.properties.buttonType = type;
}

void transformNodeFromIconButton(ButtonNode node) {
  final painter = TextPainter(
    text: TextSpan(
      text: node.properties.label,
      style: TextUtils.retrieveTextStyleFromProp(
        node.properties.labelStyle,
        effects: const [],
      ),
    ),
    textDirection: TextDirection.ltr,
    textAlign: node.properties.labelAlignment.toFlutter(),
  );
  painter.layout();
  double width =
      painter.width + ((node.properties.icon.size ?? kDefaultIconSize) * 2);
  if (node.properties.icon.show) {
    width +=
        ((node.properties.icon.size ?? kDefaultIconSize) + node.properties.gap);
  }
  double height = painter.height + (10 * 2);
  node.update(
    middleBoxLocal: node.basicBoxLocal.copyWith(width: width, height: height),
    padding: defaultButtonPadding,
  );
  node.properties.icon = node.properties.icon.copyWith(size: painter.height);
  node.aspectRatioLock = false;
}

void transformNodeToIconButton(ButtonNode node) {
  node.update(
    middleBoxLocal: node.basicBoxLocal.copyWith(width: 48, height: 48),
    padding: EdgeInsetsModel.zero,
  );
  node.properties.icon = node.properties.icon.copyWith(size: 20);
  node.aspectRatioLock = true;
  if (node.properties.label.isEmpty) node.properties.label = 'button';
}

/// Flutter's ButtonStyle parameters do different things depending on the button
/// type. So we have to manually change them.
ButtonStyle createMasterButtonStyle(
  ButtonNode node, {
  double? elevation,
  required ScopedValues scopedValues,
}) {
  final TextStyle textStyle = TextUtils.retrieveTextStyleFromProp(
    node.properties.labelStyle,
  );
  final Color? labelColor =
      PropertyValueDelegate.getPropertyValue<ColorRGBA>(
        node,
        'labelColor',
        scopedValues: scopedValues,
      )?.toFlutterColor() ??
      TextUtils.retrievePropColor(node.properties.labelStyle);

  final ColorRGBA buttonColor =
      PropertyValueDelegate.getPropertyValue<ColorRGBA>(
        node,
        'buttonColor',
        scopedValues: scopedValues,
      ) ??
      node.properties.effectiveButtonColor;

  final shadowColor =
      PropertyValueDelegate.getPropertyValue<ColorRGBA>(
        node,
        'shadowColor',
        scopedValues: scopedValues,
      ) ??
      node.properties.shadowColor;

  ButtonStyle? buttonStyle;
  switch (node.properties.buttonType) {
    case ButtonTypeEnum.elevated:
      buttonStyle = ElevatedButton.styleFrom(
        foregroundColor: labelColor,
        elevation: elevation ?? node.properties.elevation,
        shadowColor: shadowColor.toFlutterColor(),
        backgroundColor: buttonColor.toFlutterColor(),
        visualDensity: VisualDensity.standard,
        padding: node.padding.flutterEdgeInsets,
        textStyle: textStyle,
        minimumSize: Size.zero,
        shape: getButtonShape(node, scopedValues),
      );
    case ButtonTypeEnum.text:
      buttonStyle = TextButton.styleFrom(
        foregroundColor: labelColor,
        elevation: elevation ?? node.properties.elevation,
        // No fill unless a button color is set; see [defaultButtonColorFor].
        backgroundColor: buttonColor.toFlutterColor(),
        padding: node.padding.flutterEdgeInsets,
        visualDensity: VisualDensity.standard,
        textStyle: textStyle,
        minimumSize: Size.zero,
        shadowColor: shadowColor.toFlutterColor(),
        shape: getButtonShape(node, scopedValues),
      );
    case ButtonTypeEnum.filled:
    case ButtonTypeEnum.filledTonal:
      buttonStyle = FilledButton.styleFrom(
        foregroundColor: labelColor,
        elevation: elevation ?? node.properties.elevation,
        shadowColor: shadowColor.toFlutterColor(),
        backgroundColor: buttonColor.toFlutterColor(),
        visualDensity: VisualDensity.standard,
        padding: node.padding.flutterEdgeInsets,
        textStyle: textStyle,
        minimumSize: Size.zero,
        shape: getButtonShape(node, scopedValues),
      );
    case ButtonTypeEnum.outlined:
      buttonStyle = OutlinedButton.styleFrom(
        foregroundColor: labelColor,
        elevation: elevation ?? node.properties.elevation,
        side: getButtonShape(node, scopedValues)?.side,
        backgroundColor: Colors.transparent,
        visualDensity: VisualDensity.standard,
        padding: node.padding.flutterEdgeInsets,
        textStyle: textStyle,
        minimumSize: Size.zero,
        shadowColor: shadowColor.toFlutterColor(),
        shape: getButtonShape(node, scopedValues),
      );
    case ButtonTypeEnum.icon:
      Color? primary;
      if (buttonColor.toFlutterColor().a > 0 &&
          buttonColor.toFlutterColor().a < 0.7) {
        primary = buttonColor.toFlutterColor().withValues(alpha: 0.1);
      } else if (buttonColor.toFlutterColor().a == 0) {
        final iconColor =
            PropertyValueDelegate.getPropertyValue<ColorRGBA>(
              node,
              'iconColor',
              scopedValues: scopedValues,
            ) ??
            node.properties.icon.color;
        primary = iconColor?.toFlutterColor().withValues(alpha: 0.1);
      }
      buttonStyle = TextButton.styleFrom(
        foregroundColor: primary,
        elevation: elevation ?? node.properties.elevation,
        visualDensity: VisualDensity.standard,
        padding: node.padding.flutterEdgeInsets,
        minimumSize: Size.zero,
        backgroundColor: buttonColor.toFlutterColor(),
        shadowColor: shadowColor.toFlutterColor(),
        shape: getButtonShape(node, scopedValues),
      );
  }
  return buttonStyle.copyWith(
    elevation: WidgetStateProperty.all(elevation ?? node.properties.elevation),
  );
}

OutlinedBorder? getButtonShape(ButtonNode node, ScopedValues scopedValues) {
  final ColorRGBA buttonColor =
      PropertyValueDelegate.getPropertyValue<ColorRGBA>(
        node,
        'buttonColor',
        scopedValues: scopedValues,
      ) ??
      node.properties.effectiveButtonColor;
  final borderColor =
      PropertyValueDelegate.getPropertyValue<ColorRGBA>(
        node,
        'borderColor',
        scopedValues: scopedValues,
      ) ??
      node.properties.borderColor;

  return getShape(
    radius: node.properties.cornerRadius,
    shape: node.properties.shape,
    borderColor: node.properties.buttonType == ButtonTypeEnum.outlined
        ? borderColor ?? buttonColor
        : borderColor,
    // An outlined button without a border width set still draws its outline,
    // as Flutter's OutlinedButton does.
    borderWidth: node.properties.buttonType == ButtonTypeEnum.outlined
        ? node.properties.borderWidth ?? 1
        : node.properties.borderWidth,
  );
}

String? getSliderLabel(SliderNode node, double value) {
  final showValueIndicator = node.properties.showValueIndicator;
  if (showValueIndicator == ShowValueIndicatorC.never) return null;
  if (showValueIndicator == null && !node.properties.showLabel) return null;
  if (node.properties.label.trim().isEmpty) return kSliderDefaultLabel;
  final String valueString = node.properties.allowFractionalPoints
      ? value.toStringAsFixed(1)
      : value.round().toString();
  return node.properties.label.replaceAll('\${value}', valueString);
}

/// [base] showing the Material icon named [name] instead, for an icon bound
/// to data. [name] is a Flutter `Icons` name such as `kitchen` or
/// `kitchen_outlined`: an `_outlined`, `_rounded` or `_sharp` suffix picks
/// the style. The icon is drawn from its SVG by name, so no codepoint is
/// needed. Returns [base] for an empty or malformed name.
MultiSourceIconModel iconWithName(MultiSourceIconModel base, String? name) {
  final String key = (name ?? '').trim().toLowerCase();
  if (!RegExp(r'^[a-z0-9_]+$').hasMatch(key)) return base;
  MaterialIconStyle style = MaterialIconStyle.filled;
  String iconName = key;
  for (final (String suffix, MaterialIconStyle suffixStyle) in const [
    ('_outlined', MaterialIconStyle.outlined),
    ('_rounded', MaterialIconStyle.rounded),
    ('_sharp', MaterialIconStyle.sharp),
  ]) {
    if (key.endsWith(suffix)) {
      style = suffixStyle;
      iconName = key.substring(0, key.length - suffix.length);
      break;
    }
  }
  return base.copyWith(
    type: IconTypeEnum.icon,
    // The icon's SVG is served from the version the icon was added in.
    icon: MaterialIcon(
      codepoint: 0,
      name: iconName,
      style: style,
      version: materialIconVersions[iconName] ?? 1,
    ),
    forceIcon: true,
  );
}

Widget? retrieveIconWidget(
  MultiSourceIconModel icon, [
  double? size,
  Color? themeColor,
]) {
  if (!icon.show) return null;
  final Color? color = icon.color?.toFlutterColor() ?? themeColor;
  switch (icon.type) {
    case IconTypeEnum.icon:
      if (icon.icon == null) return null;

      // Using SVG icon instead of Flutter's Icon widget to reduce the SDK.
      return SvgIcon(
        icon: icon.icon!,
        size: size ?? icon.size ?? kDefaultIconSize,
        color: color,
        fill: icon.fill,
        weight: icon.weight,
        grade: icon.grade,
        opticalSize: icon.opticalSize,
      );
    case IconTypeEnum.image:
      if (icon.iconImage == null) return null;
      if (color != null && color.a == 0) {
        // when opacity is zero, we need to display original colors of
        // the image icon which `ImageIcon` widget cannot do. So we
        // use the raw Image widget.
        if (icon.isSvgImage) {
          return SvgPicture.network(
            icon.iconImage!,
            width: size ?? icon.size ?? kDefaultIconSize,
            height: size ?? icon.size ?? kDefaultIconSize,
            errorBuilder: (context, error, stackTrace) => SizedBox.square(
              dimension: size ?? icon.size ?? kDefaultIconSize,
            ),
          );
        }
        return SizedBox.square(
          dimension: size ?? icon.size ?? kDefaultIconSize,
          child: Image.network(
            icon.iconImage!,
            webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
            // scale: icon.scale,
            // color: color,
          ),
        );
      } else {
        if (icon.isSvgImage) {
          return SvgIconImage(
            url: icon.iconImage!,
            size: size ?? icon.size,
            color: color,
          );
        }
        return ImageIcon(
          NetworkImage(icon.iconImage!, scale: icon.scale),
          size: size ?? icon.size,
          color: color,
        );
      }
  }
}

Widget retrieveNavBarItemIconWidget(
  MultiSourceIconModel icon, [
  double? size,
  Color? themeColor,
]) => retrieveIconWidget(icon, size, themeColor) ?? const SizedBox.shrink();

String buildYoutubeEmbedUrl({
  required EmbeddedYoutubeVideoProperties properties,
  required double? width,
  required double? height,
  required String baseUrl,
}) {
  final Map<String, String> queryParams = {
    'video_id': properties.videoId ?? '<video_id>',
    'mute': '${properties.mute}',
    'autoplay': '${properties.autoPlay}',
    'loop': '${properties.loop}',
    if (properties.startAt != null) 'start': '${properties.startAt}',
    if (properties.startAt != null) 'end': '${properties.endAt}',
    'show_fullscreen_button': '${properties.showFullscreenButton}',
    if (width != null) 'width': '${width.toInt()}',
    if (height != null) 'height': '${height.toInt()}',
    'controls': '${properties.showControls}',
    'show_video_annotations': '${properties.showVideoAnnotations}',
    'show_captions': '${properties.showCaptions}',
    'caption_lang': properties.captionLanguage,
  };

  final baseUri = Uri.parse(getVideoUrl(properties.source, baseUrl));
  final String url = Uri(
    scheme: baseUri.scheme,
    host: baseUri.host,
    port: baseUri.port,
    path: baseUri.path,
    queryParameters: queryParams,
  ).toString();
  return url;
}

String buildVimeoEmbedUrl({
  required EmbeddedVimeoVideoProperties properties,
  required double? width,
  required double? height,
  required String baseUrl,
}) {
  final Map<String, String> queryParams = {
    'video_id': properties.videoId ?? '<video_id>',
    'mute': '${properties.mute}',
    'autoplay': '${properties.autoPlay}',
    'loop': '${properties.loop}',
    'show_fullscreen_button': '${properties.showFullscreenButton}',
    if (width != null) 'width': '${width.toInt()}',
    if (height != null) 'height': '${height.toInt()}',
  };

  final baseUri = Uri.parse(getVideoUrl(properties.source, baseUrl));
  final String url = Uri(
    scheme: baseUri.scheme,
    host: baseUri.host,
    port: baseUri.port,
    path: baseUri.path,
    queryParameters: queryParams,
  ).toString();

  return url;
}

/// [baseUrl] param allows to override the base url of the video.
String getVideoUrl(EmbeddedVideoSource source, String baseUrl) {
  String updatedBaseUrl = baseUrl;
  if (kIsWeb && !kReleaseMode) {
    // This allows to test and debug video player scripts in local environment.
    // "When running in a browser, this is the current URL of the current page
    // (from `window.location.href`)."
    final Uri url = Uri.base;
    //     var url = Uri.parse(web.window.location.href);
    updatedBaseUrl = url.origin;
  }

  // Remove trailing slash if any.
  if (updatedBaseUrl.endsWith('/')) {
    updatedBaseUrl = updatedBaseUrl.substring(0, updatedBaseUrl.length - 1);
  }

  switch (source) {
    case EmbeddedVideoSource.youtube:
      return '$updatedBaseUrl/players/youtube.html';
    case EmbeddedVideoSource.vimeo:
      return '$updatedBaseUrl/players/vimeo.html';
  }
}

OutlinedBorder? getShapeFromMixin(
  ShapeBorderMixin mixin, {
  bool onlyShape = false,
}) => getShape(
  shape: mixin.shape,
  radius: mixin.cornerRadius,
  borderColor: onlyShape ? null : mixin.borderColor,
  borderWidth: onlyShape ? null : mixin.borderWidth,
);

OutlinedBorder getShape({
  required CShapeBorder shape,
  required CornerRadius radius,
  ColorRGBA? borderColor,
  double? borderWidth,
}) {
  final BorderSide side =
      borderColor != null && borderWidth != null && borderWidth > 0
      ? BorderSide(color: borderColor.toFlutterColor(), width: borderWidth)
      : BorderSide.none;

  switch (shape) {
    case CShapeBorder.rectangle:
      return RoundedRectangleBorder(side: side);
    case CShapeBorder.circle:
      return CircleBorder(side: side);
    case CShapeBorder.stadium:
      return StadiumBorder(side: side);
    case CShapeBorder.roundedRectangle:
      return RoundedRectangleBorder(
        borderRadius: radius.borderRadius,
        side: side,
      );
    case CShapeBorder.continuousRectangle:
      return ContinuousRectangleBorder(
        borderRadius: radius.borderRadius,
        side: side,
      );
    case CShapeBorder.beveledRectangle:
      return BeveledRectangleBorder(
        borderRadius: radius.borderRadius,
        side: side,
      );
    case CShapeBorder.roundedSuperellipse:
      return RoundedSuperellipseBorder(
        borderRadius: radius.borderRadius,
        side: side,
      );
  }
}

/// Get effective child size for image position calculation for rendering
/// alignment overlay for images.
///
/// Except for fitWidth and fitHeight, it returns child size calculated
/// based on the alignment and image scale.
///
/// However, if image fit is fitWidth or fitHeight, image is scaled internally
/// regardless of given [PaintModel.scaleX]/[PaintModel.scaleY] value to
/// fit either on width or height. Since this is internal, we need to account
/// for it because the effective width and child height are no longer depend
/// on given [PaintModel.scaleX]/[PaintModel.scaleY] value. For this case, we
/// manually calculate the effective child size by calculating the linear
/// scale factor based on node size and image aspect ratio.
///
/// This method must be called before calling [convertAlignmentToPosition]
/// and [convertPositionToAlignment] to get the correct childWidth and
/// childHeight for these methods.
SizeC getEffectiveChildSizeForImage(
  BaseNode node,
  PaintModel paint, {
  double? scaleX,
  double? scaleY,
}) {
  final double modifiedScaleX = (scaleX ?? paint.scaleX).abs();
  final double modifiedScaleY = (scaleY ?? paint.scaleY).abs();

  final double width;
  if (paint.fit == Fit.fitWidth) {
    width = node.middleBoxGlobal.width;
  } else if (paint.fit == Fit.fitHeight && paint.hasImageSourceSize) {
    final aspectRatio = paint.sourceWidth! / paint.sourceHeight!;
    width = aspectRatio * node.middleBoxGlobal.height;
  } else {
    width = (paint.sourceWidth ?? node.middleBoxGlobal.width) / modifiedScaleX;
  }

  final double height;
  if (paint.fit == Fit.fitHeight) {
    height = node.middleBoxGlobal.height;
  } else if (paint.fit == Fit.fitWidth && paint.hasImageSourceSize) {
    final aspectRatio = paint.sourceWidth! / paint.sourceHeight!;
    height = node.middleBoxGlobal.width / aspectRatio;
  } else {
    height =
        (paint.sourceHeight ?? node.middleBoxGlobal.height) / modifiedScaleY;
  }
  return SizeC(width, height);
}

Vec convertAlignmentToPosition({
  required double parentWidth,
  required double parentHeight,
  required double childWidth,
  required double childHeight,
  required double alignmentX,
  required double alignmentY,
}) {
  final double widthDelta = parentWidth - childWidth;
  final double heightDelta = parentHeight - childHeight;

  final bool isSameWidth = widthDelta.closeTo(0);
  final bool isSameHeight = heightDelta.closeTo(0);

  // When the size is the same as that of the [rect] size, we account for it
  // by using the [size] directly instead of a zero-delta value.
  // It does not matter whether we use [rect] or [size] since they
  // are the same.
  final double deltaX = (isSameWidth ? childWidth : widthDelta) / 2;
  final double deltaY = (isSameHeight ? childHeight : heightDelta) / 2;

  final double adjustedAlignmentX = alignmentX - (isSameWidth ? 1 : 0);
  final double adjustedAlignmentY = alignmentY - (isSameHeight ? 1 : 0);

  final double x = deltaX + adjustedAlignmentX * deltaX;
  final double y = deltaY + adjustedAlignmentY * deltaY;

  return Vec(
    double.parse(x.toStringAsFixed(3)),
    double.parse(y.toStringAsFixed(3)),
  );
}

/// This fixes an issue with Flutter's image aligning. Flutter can't align
/// image with given alignment when the widget and image both have same size.
/// This is a workaround for that. It uses a stack in that case.
bool isCustomPositionRequiredForImage(PaintModel paint, SizeC nodeSize) {
  if (!paint.fit.supportsAlignment) return false;
  if (paint.alignment.isStandard) return false;
  if (paint.sourceWidth == null || paint.sourceHeight == null) return false;
  if (paint.isNonUniformScale) return true;
  if (paint.fit == Fit.fitWidth || paint.fit == Fit.fitHeight) {
    final diff =
        (paint.sourceWidth! / paint.sourceHeight!) -
        (nodeSize.width / nodeSize.height);
    if (diff.closeTo(0)) return true;
  }

  final imgX = paint.sourceWidth! / paint.scaleX.abs();
  final imgY = paint.sourceHeight! / paint.scaleY.abs();

  return imgX == nodeSize.width || imgY == nodeSize.height;
}

/// Wraps [child] in [node]'s scroll view, sized by [node]'s fits (see
/// [FitBox]). See [buildScrollView] for [fillViewport] and [flexContent].
///
/// With [contentSizedOnScrollAxis] the scroll view hugs its content along
/// the scroll axis (at most the incoming maximum) instead of taking its
/// design size: a flexible Row/Column that scrolls.
Widget wrapWithPaddedScrollable({
  required ScrollableMixin node,
  EdgeInsets? padding,
  Clip? clipBehavior,
  bool fillViewport = false,
  bool flexContent = false,
  bool contentSizedOnScrollAxis = false,
  required Widget child,
}) {
  if (!node.isScrollable) return child;
  final bool vertical = node.scrollDirection.isVertical;
  return FitBox.fromFits(
    horizontalFit: contentSizedOnScrollAxis && !vertical
        ? SizeFit.shrinkWrap
        : node.horizontalFit,
    verticalFit: contentSizedOnScrollAxis && vertical
        ? SizeFit.shrinkWrap
        : node.verticalFit,
    size: node.basicBoxLocal.size,
    child: buildScrollView(
      node: node,
      padding: padding,
      clipBehavior: clipBehavior,
      fillViewport: fillViewport,
      flexContent: flexContent,
      child: child,
    ),
  );
}

/// The [SingleChildScrollView] of [node], with no size of its own.
///
/// The content's main axis is unbounded, as in any scroll view. When
/// [fillViewport] (a Row/Column that centers or spreads its children) or
/// [flexContent] (the content has expanded or flexible children, or flex
/// spacers, along the scroll axis) is set, the content is instead at least as
/// long as the viewport: `max(viewport, natural length)`, the extent the
/// editor gives a scrolling Row/Column (see [ScrollContentExtent]). Flex
/// children then share what is left of the viewport, and take their design
/// size once the content scrolls.
Widget buildScrollView({
  required ScrollableMixin node,
  EdgeInsets? padding,
  Clip? clipBehavior,
  bool fillViewport = false,
  bool flexContent = false,
  required Widget child,
}) {
  final bool vertical = node.scrollDirection.isVertical;
  Widget scrollView(Widget content) => SingleChildScrollView(
    scrollDirection: node.scrollDirection.flutterAxis,
    reverse: node.reverse,
    physics: node.physics.flutterScrollPhysics(node.shouldAlwaysScroll),
    primary: node.primary,
    padding: padding,
    keyboardDismissBehavior:
        node.keyboardDismissBehavior.flutterKeyboardDismissBehavior,
    clipBehavior: clipBehavior ?? Clip.hardEdge,
    child: content,
  );
  if (!fillViewport && !flexContent) return scrollView(child);
  return LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final double extent = vertical
          ? constraints.maxHeight - (padding?.vertical ?? 0)
          : constraints.maxWidth - (padding?.horizontal ?? 0);
      if (!extent.isFinite || extent <= 0) return scrollView(child);
      return scrollView(
        ScrollContentExtent(
          axis: vertical ? Axis.vertical : Axis.horizontal,
          viewportExtent: extent,
          child: child,
        ),
      );
    },
  );
}

bool get isPlatformSupportedForWebView =>
    kIsWeb ||
    PassiveEmbeddedVideoWidget.supportedPlatforms.contains(
      defaultTargetPlatform,
    );
