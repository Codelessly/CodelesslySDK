import 'package:cached_network_image/cached_network_image.dart';
import 'package:codelessly_api/codelessly_api.dart';
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
  final Widget Function(BuildContext context, DownloadProgress? progress)?
      loadingBuilder;
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
  })  : assert(url != null || bytes != null || paint != null,
            'url or bytes or paint must be provided'),
        assert(
            paint == null || (width != null && height != null && node != null),
            'width, height and node must be provided when paint is provided');

  @override
  State<UltimateImageBuilder> createState() => _UltimateImageBuilderState();
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

  double get scale => widget.scale ?? widget.paint?.scale ?? 1;

  BlendMode? get colorBlendMode =>
      widget.blendMode ?? widget.paint?.blendMode.flutterBlendMode;

  ColorFilter? get colorFilter => widget.color != null
      ? ColorFilter.mode(
          widget.color!,
          widget.blendMode ??
              widget.paint?.blendMode.flutterBlendMode ??
              BlendMode.srcIn)
      : null;

  double? get width => widget.width ?? widget.node?.basicBoxLocal.width;

  double? get height => widget.height ?? widget.node?.basicBoxLocal.height;

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

  Widget buildFromUrl({required bool withAlignment}) {
    final String url = widget.url ??
        widget.paint!.croppedImageURL ??
        widget.paint!.downloadUrl!;

    if (url.containsUncheckedVariablePath) return jsonPathBuilder(url);

    if (url.isSvgUrl) {
      return SvgPicture.network(
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

    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      alignment: alignment,
      width: width,
      height: height,
      repeat: repeat,
      color: widget.color,
      filterQuality: FilterQuality.medium,
      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 300),
      colorBlendMode: colorBlendMode,
      placeholder: widget.loadingBuilder != null
          ? (context, _) => widget.loadingBuilder!(context, null)
          : null,
      errorWidget: (context, _, __) =>
          (widget.errorBuilder ?? _defaultErrorBuilder)(context),
      imageBuilder: (context, imageProvider) {
        final decoration = BoxDecoration(
          borderRadius: widget.node is CornerMixin
              ? (widget.node as CornerMixin).cornerRadius.borderRadius
              : null,
          image: DecorationImage(
            image: imageProvider,
            fit: fit,
            repeat: repeat,
            alignment: alignment,
            opacity: widget.paint?.opacity ?? 1,
            scale: scale,
            colorFilter: colorFilter,
            filterQuality: FilterQuality.medium,
          ),
        );
        Widget child = switch (widget.useInk) {
          true => Ink(decoration: decoration),
          false => DecoratedBox(decoration: decoration),
        };

        if (widget.paint?.hasFlippedAxis ?? false) {
          return Transform.scale(
            scaleX: widget.paint!.scaleX.sign,
            scaleY: widget.paint!.scaleY.sign,
            child: child,
          );
        }
        return child;
      },
    );
  }

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
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Colors.white.withOpacity(0.1),
                  BlendMode.dst,
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
          BlendMode.dst,
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
