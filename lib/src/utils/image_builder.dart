import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../codelessly_sdk.dart';

/// Ultimate widget to build image from url, bytes or paint. Supports Gifs and
/// SVGs too!
class UltimateImageBuilder extends StatefulWidget {
  final String? url;
  final TypedBytes? bytes;
  final BoxFit? fit;
  final Alignment? alignment;
  final double? scale;
  final double? width;
  final double? height;
  final ImageRepeat? repeat;
  final Color? color;
  final WidgetBuilder? errorBuilder;
  final Widget Function(BuildContext context, Widget? child)? loadingBuilder;
  final PaintModel? paint;
  final BaseNode? node;
  final BlendMode? blendMode;
  final bool useInk;

  const UltimateImageBuilder({
    super.key,
    this.url,
    this.bytes,
    this.fit,
    this.alignment,
    this.scale,
    this.width,
    this.height,
    this.repeat,
    this.color,
    this.errorBuilder = _defaultErrorBuilder,
    this.loadingBuilder,
    this.paint,
    this.node,
    this.blendMode,
    this.useInk = false,
  }) : assert(url != null || bytes != null || paint != null,
            'url or bytes or paint must be provided')
  /*assert(
            paint == null || (width != null && height != null && node != null),
            'width, height and node must be provided when paint is provided')*/
  ;

  @override
  State<UltimateImageBuilder> createState() => _UltimateImageBuilderState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties.add(StringProperty('url', url));
    properties.add(DiagnosticsProperty<TypedBytes>('bytes', bytes));
    properties.add(EnumProperty<BoxFit>('fit', fit));
    properties.add(DiagnosticsProperty<Alignment>('alignment', alignment));
    properties.add(DoubleProperty('scale', scale));
    properties.add(DoubleProperty('width', width));
    properties.add(DoubleProperty('height', height));
    properties.add(EnumProperty<ImageRepeat>('repeat', repeat));
    properties.add(ColorProperty('color', color));
    properties.add(
        ObjectFlagProperty<WidgetBuilder>.has('errorBuilder', errorBuilder));
    properties.add(ObjectFlagProperty<
            Widget Function(BuildContext context, Widget? child)>.has(
        'loadingBuilder', loadingBuilder));
    properties.add(DiagnosticsProperty<PaintModel>('paint', paint));
    properties.add(DiagnosticsProperty<BaseNode>('node', node));
    properties.add(EnumProperty<BlendMode>('blendMode', blendMode));
    properties.add(DiagnosticsProperty<bool>('useInk', useInk));

    super.debugFillProperties(properties);
  }
}

class _UltimateImageBuilderState extends State<UltimateImageBuilder> {
  Vec? position;
  SizeC? effectiveChildSize;

  ImageRepeat get repeat =>
      widget.repeat ??
      widget.paint?.imageRepeat.flutterImageRepeat ??
      ImageRepeat.noRepeat;

  Alignment get alignment =>
      widget.alignment ??
      widget.paint?.alignment.flutterAlignment ??
      Alignment.center;

  BoxFit get fit => widget.fit ?? widget.paint?.fit.boxFit ?? BoxFit.contain;

  double get scale => (widget.scale ?? widget.paint?.scale ?? 1).abs();

  BlendMode? get colorBlendMode =>
      widget.blendMode ?? widget.paint?.blendMode.flutterBlendMode;

  ColorFilter? get colorFilter => widget.color != null
      ? ColorFilter.mode(
          widget.color!,
          widget.blendMode ??
              widget.paint?.blendMode.flutterBlendMode ??
              BlendMode.srcIn)
      : null;

  double? get width {
    if (widget.width case var width?) return width;

    if (widget.node case var node?) {
      if (node.isHorizontalExpanded) return double.infinity;
      return node.basicBoxLocal.width;
    }

    return null;
  }

  double? get height {
    if (widget.height case var height?) return height;

    if (widget.node case var node?) {
      if (node.isVerticalExpanded) return null;
      return node.basicBoxLocal.height;
    }

    return null;
  }

  @override
  void initState() {
    super.initState();
    calculatePosition();
  }

  @override
  void didUpdateWidget(UltimateImageBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.url != oldWidget.url ||
        widget.paint != oldWidget.paint ||
        widget.width != oldWidget.width ||
        widget.height != oldWidget.height ||
        widget.alignment != oldWidget.alignment ||
        widget.fit != oldWidget.fit ||
        widget.scale != oldWidget.scale) {
      calculatePosition();
    }
  }

  void calculatePosition() {
    if (widget.paint == null ||
        widget.width == null ||
        widget.height == null ||
        widget.node == null) {
      return;
    }
    if (isCustomPositionRequiredForImage(
        widget.paint!, SizeC(widget.width!, widget.height!))) {
      effectiveChildSize =
          getEffectiveChildSizeForImage(widget.node!, widget.paint!);

      position = convertAlignmentToPosition(
        parentWidth: widget.node!.basicBoxGlobal.width,
        parentHeight: widget.node!.basicBoxGlobal.height,
        childWidth: effectiveChildSize!.width,
        childHeight: effectiveChildSize!.height,
        alignmentX: widget.paint!.alignment.data?.x ?? 0,
        alignmentY: widget.paint!.alignment.data?.y ?? 0,
      );
    } else {
      position = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (position != null && effectiveChildSize != null) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: position!.x,
            top: position!.y,
            width: effectiveChildSize!.width,
            height: effectiveChildSize!.height,
            child: buildImage(withAlignment: false),
          )
        ],
      );
    }

    return buildImage(withAlignment: true);
  }

  /// Uses Image.network
  Widget buildImage({required bool withAlignment}) {
    if (widget.bytes != null) return buildFromBytes();

    return buildFromUrl(withAlignment: withAlignment);
  }

  /// TODO: Decorate the rest of the image widgets, not just CachedNetworkImage.
  Widget buildFromUrl({required bool withAlignment}) {
    final String url = widget.url ??
        widget.paint!.croppedImageURL ??
        widget.paint!.downloadUrl!;

    if (url.containsUncheckedVariablePath) return jsonPathBuilder(url);

    Widget child;

    if (url.isSvgUrl) {
      child = SvgPicture.network(
        url,
        fit: fit,
        alignment: alignment,
        width: width,
        height: height,
        colorFilter: colorFilter,
        placeholderBuilder: widget.loadingBuilder != null
            ? (context) => widget.loadingBuilder!(context, null)
            : null,
      );
    }

    if (url.isBase64Blob) {
      child = Image.memory(
        url.base64Data,
        fit: fit,
        alignment: alignment,
        scale: scale,
        width: width,
        height: height,
        repeat: repeat,
        color: widget.color,
        colorBlendMode: colorBlendMode,
        errorBuilder: (context, _, __) =>
            (widget.errorBuilder ?? _defaultErrorBuilder)(context),
      );
    }

    child = Image.network(
      url,
      fit: fit,
      alignment: alignment,
      width: width,
      height: height,
      repeat: repeat,
      color: widget.color,
      opacity: AlwaysStoppedAnimation(widget.paint?.opacity ?? 1),
      filterQuality: FilterQuality.medium,
      colorBlendMode: colorBlendMode,
      loadingBuilder: widget.loadingBuilder != null
          ? (context, child, loadingProgress) =>
              widget.loadingBuilder!(context, child)
          : null,
      errorBuilder: (context, error, stackTrace) {
        print('Image Loading Error: $error');
        return (widget.errorBuilder ?? _defaultErrorBuilder)(context);
      },
    );

    final BoxDecoration decoration = BoxDecoration(
      borderRadius: widget.node is CornerMixin
          ? (widget.node as CornerMixin).cornerRadius.borderRadius
          : null,
    );
    child = switch (widget.useInk) {
      true => Ink(decoration: decoration, child: child),
      false => DecoratedBox(decoration: decoration, child: child),
    };

    if (widget.paint?.hasFlippedAxis ?? false) {
      return Transform.scale(
        scaleX: widget.paint!.scaleX.sign,
        scaleY: widget.paint!.scaleY.sign,
        child: child,
      );
    }

    return child;
  }

  /// TODO: Decorate these image widgets.
  Widget buildFromBytes() {
    final bytes = widget.bytes!;
    if (bytes.type.isSvg) {
      return SvgPicture.memory(
        bytes.bytes,
        fit: fit,
        alignment: alignment,
        width: width,
        height: height,
        colorFilter: colorFilter,
        placeholderBuilder: widget.loadingBuilder != null
            ? (context) => widget.loadingBuilder!(context, null)
            : null,
      );
    }
    return Image.memory(
      bytes.bytes,
      fit: fit,
      alignment: alignment,
      scale: scale,
      width: width,
      height: height,
      repeat: repeat,
      color: widget.color,
      colorBlendMode: colorBlendMode,
      errorBuilder: (context, _, __) =>
          (widget.errorBuilder ?? _defaultErrorBuilder)(context),
    );
  }

  Widget jsonPathBuilder(String path) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight < 64 || constraints.maxWidth < 64) {
          return const FittedBox(
            child: Center(
              child: Icon(Icons.image_outlined),
            ),
          );
        }
        return FractionallySizedBox(
          widthFactor: 0.6,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Center(
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Colors.white.withOpacity(0.1),
                  BlendMode.srcATop,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.image_outlined,
                      size: 100,
                    ),
                    Text(
                      'Variable Image',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.merge(
                            GoogleFonts.sourceCodePro(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                    ),
                    Text(
                      path,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.merge(
                            GoogleFonts.sourceCodePro(
                              color: Colors.greenAccent.shade700,
                              fontSize: 24,
                            ),
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

Widget _defaultErrorBuilder(BuildContext context) {
  // for passive transformer.
  return FittedBox(
    fit: BoxFit.scaleDown,
    child: Center(
      child: ColorFiltered(
        colorFilter: ColorFilter.mode(
          Colors.white.withOpacity(0.1),
          BlendMode.srcATop,
        ),
        child: Icon(
          Icons.broken_image_outlined,
          size: 200,
          color: Colors.grey.withOpacity(0.2),
        ),
      ),
    ),
  );
}
