import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:universal_html/html.dart' as html;

import '../utils/extensions.dart';
import 'transformers.dart';

void convertNodeToButtonType(ButtonTypeEnum type, ButtonNode node) {
  switch (type) {
    case ButtonTypeEnum.elevated:
      final brightness = ThemeData.estimateBrightnessForColor(
          node.properties.buttonColor.toFlutterColor());
      final color =
          (brightness == Brightness.light ? Colors.black : Colors.white)
              .toColorRGBA();
      node.properties
        ..labelStyle = node.properties.labelStyle.copyWith(fills: [
          color.toPaint(node.properties.labelStyle.fills.firstOrNull?.id)
        ])
        ..icon = node.properties.icon
            .copyWith(color: color.toFlutterColor().toColorRGBA())
        ..buttonColor = node.properties.buttonColor.copyWith(a: 1)
        ..elevation = 8
        ..gap = node.properties.icon.show ? 8 : 0
        ..shape = CShapeBorder.roundedRectangle
        ..borderColor = null
        ..borderWidth = null;
      break;
    case ButtonTypeEnum.text:
      node.properties
        ..buttonColor = node.properties.buttonColor.copyWith(a: 0.1)
        ..labelStyle = node.properties.labelStyle.copyWith(fills: [
          node.properties.buttonColor
              .copyWith(a: 1)
              .toPaint(node.properties.labelStyle.fills.firstOrNull?.id)
        ])
        ..icon = node.properties.icon
            .copyWith(color: node.properties.buttonColor.copyWith(a: 1))
        ..elevation = 0
        ..shape = CShapeBorder.roundedRectangle
        ..borderWidth = null
        ..borderColor = null;
      break;
    case ButtonTypeEnum.outlined:
      node.properties
        ..buttonColor = node.properties.buttonColor.copyWith(a: 1)
        ..labelStyle = node.properties.labelStyle.copyWith(fills: [
          node.properties.buttonColor
              .copyWith(a: 1)
              .toPaint(node.properties.labelStyle.fills.firstOrNull?.id)
        ])
        ..icon = node.properties.icon
            .copyWith(color: node.properties.buttonColor.copyWith(a: 1))
        ..elevation = 0
        ..shape = CShapeBorder.roundedRectangle
        ..borderWidth = 1
        ..borderColor = null;
      break;
    case ButtonTypeEnum.icon:
      final brightness = ThemeData.estimateBrightnessForColor(
          node.properties.buttonColor.toFlutterColor());
      final color =
          (brightness == Brightness.light ? Colors.black : Colors.white)
              .toColorRGBA();
      node.properties
        ..labelStyle = node.properties.labelStyle.copyWith(fills: [
          color.toPaint(node.properties.labelStyle.fills.firstOrNull?.id)
        ])
        ..icon = node.properties.icon.copyWith(color: color)
        ..buttonColor = node.properties.buttonColor.copyWith(a: 1)
        ..icon = node.properties.icon.copyWith(show: true)
        ..shape = CShapeBorder.circle
        ..gap = 0
        ..elevation = 2
        ..borderColor = null
        ..borderWidth = null;
      break;
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
        style: PassiveTextTransformer.retrieveTextStyleFromProp(
            node.properties.labelStyle)),
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
    middleBoxLocal: node.basicBoxLocal.copyWith(
      width: width,
      height: height,
    ),
    padding: defaultButtonPadding,
  );
  node.properties.icon = node.properties.icon.copyWith(size: painter.height);
  node.aspectRatioLock = false;
}

void transformNodeToIconButton(ButtonNode node) {
  node.update(
    middleBoxLocal: node.basicBoxLocal.copyWith(
      width: 48,
      height: 48,
    ),
    padding: EdgeInsetsModel.zero,
  );
  node.properties.icon = node.properties.icon.copyWith(size: 20);
  node.aspectRatioLock = true;
  if (node.properties.label.isEmpty) node.properties.label = 'button';
}

/// Flutter's ButtonStyle parameters do different things depending on the button
/// type. So we have to manually change them.
ButtonStyle createMasterButtonStyle(ButtonNode node, {double? elevation}) {
  final TextStyle textStyle = PassiveTextTransformer.retrieveTextStyleFromProp(
      node.properties.labelStyle);
  final Color? labelColor =
      node.properties.labelStyle.fills.firstOrNull?.toFlutterColor();

  ButtonStyle? buttonStyle;
  switch (node.properties.buttonType) {
    case ButtonTypeEnum.elevated:
      buttonStyle = ElevatedButton.styleFrom(
        foregroundColor: labelColor,
        elevation: elevation ?? node.properties.elevation,
        shadowColor: node.properties.shadowColor.toFlutterColor(),
        backgroundColor: node.properties.buttonColor.toFlutterColor(),
        visualDensity: VisualDensity.standard,
        padding: node.padding.flutterEdgeInsets,
        textStyle: textStyle,
        minimumSize: Size.zero,
        shape: getButtonShape(node.properties),
      );
      break;
    case ButtonTypeEnum.text:
      buttonStyle = TextButton.styleFrom(
        foregroundColor: labelColor,
        elevation: elevation ?? node.properties.elevation,
        backgroundColor: node.properties.buttonColor.toFlutterColor(),
        padding: node.padding.flutterEdgeInsets,
        visualDensity: VisualDensity.standard,
        textStyle: textStyle,
        minimumSize: Size.zero,
        shadowColor: node.properties.shadowColor.toFlutterColor(),
        shape: getButtonShape(node.properties),
      );
      break;
    case ButtonTypeEnum.outlined:
      buttonStyle = OutlinedButton.styleFrom(
        foregroundColor: labelColor,
        elevation: elevation ?? node.properties.elevation,
        side: getButtonShape(node.properties)?.side,
        backgroundColor: Colors.transparent,
        visualDensity: VisualDensity.standard,
        padding: node.padding.flutterEdgeInsets,
        textStyle: textStyle,
        minimumSize: Size.zero,
        shadowColor: node.properties.shadowColor.toFlutterColor(),
        shape: getButtonShape(node.properties),
      );
      break;
    case ButtonTypeEnum.icon:
      Color? primary;
      if (node.properties.buttonColor.toFlutterColor().opacity > 0 &&
          node.properties.buttonColor.toFlutterColor().opacity < 0.7) {
        primary = node.properties.buttonColor.toFlutterColor().withOpacity(0.1);
      } else if (node.properties.buttonColor.toFlutterColor().opacity == 0) {
        primary = node.properties.icon.color?.toFlutterColor().withOpacity(0.1);
      }
      buttonStyle = TextButton.styleFrom(
        foregroundColor: primary,
        elevation: elevation ?? node.properties.elevation,
        visualDensity: VisualDensity.standard,
        padding: node.padding.flutterEdgeInsets,
        minimumSize: Size.zero,
        backgroundColor: node.properties.buttonColor.toFlutterColor(),
        shadowColor: node.properties.shadowColor.toFlutterColor(),
        shape: getButtonShape(node.properties),
      );
      break;
  }
  return buttonStyle.copyWith(
      elevation:
          MaterialStateProperty.all(elevation ?? node.properties.elevation));
}

OutlinedBorder? getButtonShape(ButtonProperties properties) {
  return getShape(
    radius: properties.cornerRadius,
    shape: properties.shape,
    borderColor: properties.buttonType == ButtonTypeEnum.outlined
        ? properties.borderColor ?? properties.buttonColor
        : properties.borderColor,
    borderWidth: properties.borderWidth,
  );
}

String? getSliderLabel(SliderNode node, double value) {
  if (!node.properties.showLabel) return null;
  if (node.properties.label.trim().isEmpty) return kSliderDefaultLabel;
  final String valueString = node.properties.allowFractionalPoints
      ? value.toStringAsFixed(1)
      : value.round().toString();
  return node.properties.label.replaceAll('\${value}', valueString);
}

Widget? retrieveIconWidget(
  MultiSourceIconModel icon, [
  double? size,
  bool useIconFonts = false,
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
      );
    case IconTypeEnum.image:
      if (icon.iconImage == null) return null;
      if (color != null && color.opacity == 0) {
        // when opacity is zero, we need to display original colors of
        // the image icon which `ImageIcon` widget cannot do. So we
        // use the raw Image widget.
        if (icon.isSvgImage) {
          return SvgPicture.network(
            icon.iconImage!,
            width: size ?? icon.size ?? kDefaultIconSize,
            height: size ?? icon.size ?? kDefaultIconSize,
          );
        }
        return SizedBox.square(
          dimension: size ?? icon.size ?? kDefaultIconSize,
          child: Image.network(
            icon.iconImage!,
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
  bool useIconFonts = false,
  Color? themeColor,
]) =>
    retrieveIconWidget(icon, size, useIconFonts, themeColor) ??
    const SizedBox.shrink();

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
    var url = Uri.parse(html.window.location.href);
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

OutlinedBorder? getShapeFromMixin(ShapeBorderMixin mixin,
        {bool onlyShape = false}) =>
    getShape(
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
          ? BorderSide(
              color: borderColor.toFlutterColor(),
              width: borderWidth,
            )
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
SizeC getEffectiveChildSizeForImage(BaseNode node, PaintModel paint,
    {double? scaleX, double? scaleY}) {
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
    final diff = (paint.sourceWidth! / paint.sourceHeight!) -
        (nodeSize.width / nodeSize.height);
    if (diff.closeTo(0)) return true;
  }

  final imgX = paint.sourceWidth! / paint.scaleX.abs();
  final imgY = paint.sourceHeight! / paint.scaleY.abs();

  return imgX == nodeSize.width || imgY == nodeSize.height;
}

Widget wrapWithScrollable({
  required ScrollableMixin node,
  EdgeInsets? padding,
  Clip? clipBehavior,
  required Widget child,
}) {
  if (!node.isScrollable) return child;
  return SingleChildScrollView(
    scrollDirection: node.scrollDirection.flutterAxis,
    reverse: node.reverse,
    physics: node.physics.flutterScrollPhysics,
    primary: node.primary,
    padding: padding,
    keyboardDismissBehavior:
        node.keyboardDismissBehavior.flutterKeyboardDismissBehavior,
    clipBehavior: clipBehavior ?? Clip.hardEdge,
    child: child,
  );
}

bool get isPlatformSupportedForWebView =>
    kIsWeb ||
    PassiveEmbeddedVideoWidget.supportedPlatforms
        .contains(defaultTargetPlatform);
