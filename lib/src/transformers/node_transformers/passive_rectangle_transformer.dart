import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:codelessly_api/api.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:vector_math/vector_math_64.dart' as vec_math;

import '../../../codelessly_sdk.dart';

class PassiveRectangleTransformer extends NodeWidgetTransformer<BaseNode> {
  PassiveRectangleTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    BaseNode node,
    BuildContext context, [
    WidgetBuildSettings settings = const WidgetBuildSettings(),
  ]) {
    final List<Widget> children = [];

    for (String childID in node.childrenOrEmpty) {
      final Widget builtWidget =
          manager.buildWidgetByID(childID, context, settings: settings);

      children.add(builtWidget);
    }
    return buildRectangle(node, children: children);
  }

  Widget buildRectangle(
    BaseNode node, {
    List<Widget> children = const [],
    Map<int, Uint8List> imageBytes = const {},
  }) {
    return PassiveRectangleWidget(
      node: node,
      imageBytes: imageBytes,
      children: children,
    );
  }
}

class PassiveRectangleWidget extends StatelessWidget {
  final BaseNode node;
  final List<Widget> children;
  final Map<int, Uint8List> imageBytes;

  const PassiveRectangleWidget({
    super.key,
    required this.node,
    this.children = const [],
    this.imageBytes = const {},
  });

  @override
  Widget build(BuildContext context) {
    final CodelesslyContext codelesslyContext =
        context.read<CodelesslyContext>();

    // final BaseNode? parent = node.id == kRootNode || node.parentID == kRootNode
    //     ? null
    //     : getNode(node.parentID);

    /// TODO Birju / Saad. Why does the commented out parent code below break published layouts only?
    final double? width = (node.horizontalFit == SizeFit.shrinkWrap)
        ? null
        : (node.horizontalFit ==
                SizeFit
                    .expanded /* &&
                (parent is! CanvasNode || parent.properties.bodyId != node.id)*/
            )
            ? double.infinity
            : node.basicBoxLocal.width;

    final double? height = (node.verticalFit == SizeFit.shrinkWrap)
        ? null
        : (node.verticalFit ==
                SizeFit
                    .expanded /*&&
                (parent is! CanvasNode || parent.properties.bodyId != node.id)*/
            )
            ? double.infinity
            : node.basicBoxLocal.height;

    Widget data = Container(
      key: ValueKey('Rectangle Transformer of ${node.debugLabel}'),
      clipBehavior: getClipBehavior(node),
      width: width,
      height: height,
      decoration: BoxDecoration(
        // shape: getShape(node),
        color: boxDecorationDataColor(node),
        boxShadow: retrieveBoxShadow(node),
        borderRadius: getBorderRadius(node),
      ),
      child: generateFills(node, codelesslyContext,
          nodeChildren: children, imageBytes: imageBytes),
    );

    if (node is GeometryMixin && (node as GeometryMixin).strokeWeight > 0) {
      final GeometryMixin geometry = node as GeometryMixin;

      // TODO: We can 100% use DecoratedBox for all strokeAlignments, but the
      // basicBoxLocal logic needs to grow to fill it first. The node shrinks in size
      // otherwise because we need to add padding to the widget, and since the
      // basicBoxLocal doesn't account for strokes yet, there's not enough space for
      // the widget to fit, so it shrinks to fit.
      if (geometry.strokeAlign == StrokeAlignC.inside &&
          geometry.dashPattern.isEmpty) {
        data = DecoratedBox(
          decoration: BoxDecoration(
            // shape: getShape(geometry),
            borderRadius: getBorderRadius(geometry),
            border: Border.all(
              color: retrieveStrokeColor(
                  geometry, geometry.strokes.length - 1, true),
              width: geometry.strokeWeight,
            ),
          ),
          position: DecorationPosition.foreground,
          child: data,
        );
      } else {
        // Make strokes render over everything by having it be on
        // top of a stack. It clips behind the paint of the rectangle otherwise.
        data = Stack(
          clipBehavior: Clip.none,
          children: [
            data,
            Positioned.fill(
              child: CustomPaint(
                painter: StrokePainter(
                  color: retrieveStrokeColor(
                      geometry, geometry.strokes.length - 1, true),
                  dashPattern: geometry.dashPattern,
                  strokeWidth: geometry.strokeWeight,
                  borderRadius: getBorderRadius(geometry) ?? BorderRadius.zero,
                  strokeMiterLimit: geometry.strokeMiterLimit,
                  strokeCap: geometry.strokeCap,
                  strokeAlign: geometry.strokeAlign,
                  strokeSide: geometry.strokeSide,
                  boxShape: getBoxShape(geometry),
                ),
              ),
            ),
          ],
        );
      }
    }

    return data;
  }
}

List<BoxShadow> retrieveBoxShadow(BaseNode node) {
  if (node is! DefaultShapeNode) return [];
  return node.effects
      .where((element) => element.type == EffectType.dropShadow)
      .map((d) => BoxShadow(
            spreadRadius: d.spread!,
            offset: Offset(d.offset!.x.toDouble(), d.offset!.y.toDouble()),
            blurRadius: d.radius,
            color: d.color!.toFlutterColor(),
          ))
      .toList();
}

/// Outer BoxDecorationData only sets the color attribute when node.fills is size 1 and solid.
/// In other cases, the returned value is null, and [generateFillsData] sets the color.
Color? boxDecorationDataColor(BaseNode node) {
  if (node is! DefaultShapeNode) return null;
  if (node.fills.length == 1 && node.fills.first.type == PaintType.solid) {
    return retrieveFillColor(node);
  } else {
    return null;
  }
}

Gradient? boxDecorationGradient(BaseNode node) {
  if (node is! GeometryMixin) return null;

  if (node.fills.length == 1 && node.fills.first.type == PaintType.solid) {
    return retrieveGradient(node.fills.first);
  } else {
    return null;
  }
}

BorderRadius? getBorderRadius(Object node) {
  if (node is CornerMixin) {
    if (node.cornerRadius.linked &&
        node.cornerRadius.type == RadiusType.elliptical) {
      return BorderRadius.all(Radius.elliptical(
          node.basicBoxLocal.width, node.basicBoxLocal.height));
    }
    return node.cornerRadius.borderRadius;
  } else {
    return null;
  }
}

Clip getClipBehavior(Object node) {
  // Enable Clip.hardEdge when:
  // node is an Ellipse;
  // node is a Frame (because of clipping);
  // node has a cornerRadius and it is different than zero.
  if (node is ClipMixin) {
    if (node.clipsContent) {
      return Clip.hardEdge;
    } else {
      return Clip.none;
    }
  }

  if (node is BaseNode ||
      (node is CornerMixin && node.cornerRadius != CornerRadius.zero)) {
    return Clip.antiAlias;
  } else {
    return Clip.none;
  }
}

BoxShape getBoxShape(dynamic node) {
  // if (node is EllipseNode) {
  //   return BoxShape.circle;
  // } else {
  return BoxShape.rectangle;
  // }
}

double nearestValue(double goal, List<double> array) {
  return array.reduce((prev, curr) {
    return (curr - goal).abs() < (prev - goal).abs() ? curr : prev;
  });
}

void getLinearGradientAlignment(double rotationDeg) {}

Gradient? retrieveGradient(PaintModel paint) {
  try {
    final double rotation =
        decomposeRelativeTransform(paint.gradientTransform).rotation;

    // We sort the colors to mimic the way Figma changes the order.
    final gradientStops = paint.gradientStops!
        .sorted((g1, g2) => g1.position.compareTo(g2.position));
    final radians = rotation * pi / 180;

    if (paint.type == PaintType.gradientLinear) {
      return LinearGradient(
        colors: gradientStops
            .map((e) => e.color.multiplyAlpha(paint.opacity).toFlutterColor())
            .toList(),
        stops: gradientStops.map((e) => e.position).toList(),
        transform: GradientRotation(radians),
      );
    } else if (paint.type == PaintType.gradientRadial) {
      return RadialGradient(
        colors: gradientStops
            .map((e) => e.color.multiplyAlpha(paint.opacity).toFlutterColor())
            .toList(),
        stops: gradientStops.map((e) => e.position).toList(),
        transform: GradientRotation(radians),
      );
    } else if (paint.type == PaintType.gradientAngular) {
      return SweepGradient(
        colors: gradientStops
            .map((e) => e.color.multiplyAlpha(paint.opacity).toFlutterColor())
            .toList(),
        stops: gradientStops.map((e) => e.position).toList(),
        transform: GradientRotation(radians),
      );
    }

    return null;
  } catch (error, stacktrace) {
    print(error);
    print(stacktrace);
    return null;
  }
}

// from https://math.stackexchange.com/a/2888105
RelativeTransform decomposeRelativeTransform(List<num>? t1) {
  t1 ??= defaultGradientTransform();

  // __        __
  // |a   c   tx|
  // |b   d   ty|
  // --        --
  final double a = t1[0].toDouble();
  final double b = t1.length > 1 ? t1[1].toDouble() : 0;
  final double c = t1.length > 2 ? t1[2].toDouble() : 0;
  final double d = t1.length > 3 ? t1[3].toDouble() : 0;
  final double tx = t1.length > 4 ? t1[4].toDouble() : 0;
  final double ty = t1.length > 5 ? t1[5].toDouble() : 0;

  final double delta = a * d - b * c;

  List<double> translation = [tx, ty];
  double rotation = 0;
  List<double> scale = [0, 0];
  List<double> skew = [0, 0];

  // Apply the QR-like decomposition.
  if (a != 0 || b != 0) {
    final double r = sqrt(a * a + b * b);
    rotation = b > 0 ? acos(a / r) : -acos(a / r);
    scale = [r, delta / r];
    skew = [atan((a * c + b * d) / (r * r)), 0];
  } else if (c != 0 || d != 0) {
    // these are not currently being used.
    final double s = sqrt(c * c + d * d);
    rotation = pi / 2 - (d > 0 ? acos(-c / s) : -acos(c / s));
    scale = [delta / s, s];
    skew = [0, atan((a * c + b * d) / (s * s))];
  } else {
    // a = b = c = d = 0
  }

  return RelativeTransform(
    translation: translation,
    rotation: rotation / pi * 180,
    scale: scale,
    skew: skew,
  );
}

List<num> applyGradientRotation(List<num>? t1, double angle) {
  t1 ??= defaultGradientTransform();
  final double tx = t1.length > 4 ? t1[4].toDouble() : 0;
  final double ty = t1.length > 5 ? t1[5].toDouble() : 0;

  final rads = angle * pi / 180;
  final cosA = cos(rads);
  final sinA = sin(rads);

  final vec_math.Matrix3 matrix =
      vec_math.Matrix3(cosA, sinA, tx, -sinA, cosA, ty, 0, 0, 1);

  final List<num> list = List.filled(9, 0);
  matrix.copyIntoArray(list);

  return list.take(6).toList();
}

List<num> defaultGradientTransform() => [1.0, 0.0, 0.0, -0.0, 1.0, 0.0];

Widget applyEffects(BaseNode node, List<Widget> paint) {
  Widget result = paint.length == 1 ? paint[0] : Stack(children: paint);
  if (node is! BlendMixin) {
    return result;
  }

  for (final Effect effect in node.effects) {
    switch (effect.type) {
      case EffectType.innerShadow:
      case EffectType.dropShadow:
        // Already handled.
        break;
      case EffectType.layerBlur:
      case EffectType.backgroundBlur:
        result = ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: effect.radius / 10,
            sigmaY: effect.radius / 10,
          ),
          child: result,
        );
        break;
    }
  }
  return result;
}

Widget? generateFills(
  BaseNode node,
  CodelesslyContext codelesslyContext, {
  List<Widget> nodeChildren = const [],
  Map<int, Uint8List> imageBytes = const {},
  double? opacity,
  double? rotationRadians,
}) {
  final GeometryMixin? geometry = node is GeometryMixin ? node : null;

  // This is used as an optimization: if there is no dotted border,
  // there is no need to use StackWidgetData for a single image.
  Widget? imageData;

  // This method returns null when WidgetData shouldn't be created.
  if (geometry?.fills.isEmpty ?? false) {
    // return null;
  } else if (geometry?.fills.length == 1) {
    // if (node.fills.first.type == PaintType.solid ||
    //     node.fills.first.type == PaintType.gradientLinear ||
    //     node.fills.first.type == PaintType.gradientAngular ||
    //     node.fills.first.type == PaintType.gradientRadial ||
    //     node.fills.first.type == PaintType.gradientDiamond) {
    // When node has a single solid color or gradient, BoxDecorationData will
    // already be set. Don't return, else dottedBorder won't be loaded.
    // }

    if (geometry!.fills.first.type == PaintType.image) {
      String imageURL = geometry.fills.first.croppedImageURL ??
          geometry.fills.first.downloadUrl!;
      // Substitute URL value from [CodelesslyContext]'s [data] map if
      // [imageURL] represents a JSON path.
      imageURL = substituteData(imageURL, codelesslyContext.data);
      final BoxFit fit = geometry.fills.first.fit.boxFit;
      final Alignment? alignment =
          geometry.fills.first.alignment.flutterAlignment;
      final double modifiedOpacity =
          (opacity ?? 1) * geometry.fills.first.opacity;
      final double scale = geometry.fills.first.scale;
      final ImageRepeat repeat =
          geometry.fills.first.imageRepeat.flutterImageRepeat;
      final Uint8List? bytes = imageBytes[0];

      imageData = Opacity(
        opacity: modifiedOpacity,
        child: bytes != null
            ? Image.memory(
                bytes,
                fit: fit,
                alignment: alignment ?? Alignment.center,
                scale: scale,
                width: geometry.basicBoxLocal.width,
                height: geometry.basicBoxLocal.height,
                repeat: repeat,
              )
            : _NetworkImageWithStates(
                url: imageURL,
                fit: fit,
                alignment: alignment ?? Alignment.center,
                scale: scale,
                width: geometry.basicBoxLocal.width,
                height: geometry.basicBoxLocal.height,
                repeat: repeat,
                paint: geometry.fills.first,
                node: node,
              ),
      );
    }
  }

  final bool hasPadding = node.innerBoxGlobal.edgeSize != SizeC.zero;

  // final dottedBorder = buildCenterInsideDottedBorder(node);

  // Only avoid Stack when image exists and dottedBorder and nodeChildren are null.
  if (imageData != null && nodeChildren.isEmpty) {
    if (rotationRadians != null) {
      imageData = Transform.rotate(angle: rotationRadians, child: imageData);
    }
    return imageData;
  } else if (geometry != null &&
      geometry.fills.length == 1 &&
      geometry.fills.first.type == PaintType.solid) {
    // When color fill is already set.
    if (nodeChildren.isEmpty) {
      return null;
    }

    if (hasPadding && nodeChildren.isNotEmpty) {
      return Padding(
        padding: node.innerBoxGlobal.edgeInsets.edgeInsets,
        child: Stack(children: nodeChildren),
      );
    } else {
      return Stack(children: nodeChildren);
    }
  }

  final List<Widget> paintChildren = geometry == null
      ? []
      : geometry.fills
          .mapIndexed((index, fill) {
            Widget? widget;
            if (fill.type == PaintType.solid) {
              // Ignore when invisible.
              if (fill.visible == true) {
                widget = Container(
                  color: fill.toFlutterColor()!,
                );
              }
            } else if (fill.type == PaintType.gradientLinear ||
                fill.type == PaintType.gradientRadial ||
                fill.type == PaintType.gradientAngular) {
              widget = Container(
                decoration: BoxDecoration(
                  gradient: retrieveGradient(fill),
                  borderRadius: getBorderRadius(geometry),
                ),
              );
            } else if (fill.type == PaintType.image) {
              String imageURL = fill.croppedImageURL ?? fill.downloadUrl!;
              // Substitute URL value from [CodelesslyContext]'s [data] map if
              // [imageURL] represents a JSON path.
              imageURL = substituteData(imageURL, codelesslyContext.data);
              final BoxFit fit = fill.fit.boxFit;
              final Alignment? alignment = fill.alignment.flutterAlignment;
              final double modifiedOpacity = opacity ?? fill.opacity;
              final double scale = fill.scale;
              final ImageRepeat repeat = fill.imageRepeat.flutterImageRepeat;
              final Uint8List? bytes = imageBytes[index];

              widget = ClipRRect(
                borderRadius: getBorderRadius(geometry) ?? BorderRadius.zero,
                child: Opacity(
                  opacity: modifiedOpacity,
                  child: bytes != null
                      ? Image.memory(
                          bytes,
                          fit: fit,
                          alignment: alignment ?? Alignment.center,
                          scale: scale,
                          width: geometry.basicBoxLocal.width,
                          height: geometry.basicBoxLocal.height,
                          repeat: repeat,
                        )
                      : _NetworkImageWithStates(
                          url: imageURL,
                          fit: fit,
                          alignment: alignment ?? Alignment.center,
                          scale: scale,
                          width: geometry.basicBoxLocal.width,
                          height: geometry.basicBoxLocal.height,
                          paint: fill,
                          repeat: repeat,
                          node: node,
                        ),
                ),
              );

              if (rotationRadians != null) {
                imageData =
                    Transform.rotate(angle: rotationRadians, child: imageData);
              }
            }

            if (widget == null) {
              return null;
            }

            return Positioned(
              left: 0.0,
              top: 0.0,
              right: 0.0,
              bottom: 0.0,
              width: null,
              height: null,
              child: widget,
            );
          })
          .whereType<Widget>()
          .toList();

  return Stack(
    children: [
      ...paintChildren,
      if (hasPadding && nodeChildren.isNotEmpty)
        Padding(
          padding: EdgeInsets.fromLTRB(
            node.innerBoxGlobal.edgeLeft,
            node.innerBoxGlobal.edgeTop,
            node.innerBoxGlobal.edgeRight,
            node.innerBoxGlobal.edgeBottom,
          ),
          child: Stack(children: nodeChildren),
        )
      else
        ...nodeChildren,
      // if (dottedBorder != null) dottedBorder
    ],
  );
}

class _NetworkImageWithStates extends StatefulWidget {
  final String url;
  final BoxFit? fit;
  final Alignment alignment;
  final double scale;
  final double width;
  final double height;
  final PaintModel paint;
  final ImageRepeat repeat;
  final BaseNode node;

  const _NetworkImageWithStates({
    required this.url,
    required this.paint,
    this.fit,
    this.alignment = Alignment.center,
    this.scale = 1,
    required this.width,
    required this.height,
    this.repeat = ImageRepeat.noRepeat,
    required this.node,
  });

  @override
  State<_NetworkImageWithStates> createState() =>
      _NetworkImageWithStatesState();
}

class _NetworkImageWithStatesState extends State<_NetworkImageWithStates> {
  Vec? position;
  SizeC? effectiveChildSize;

  @override
  void initState() {
    super.initState();

    calculatePosition();
  }

  @override
  void didUpdateWidget(_NetworkImageWithStates oldWidget) {
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
    if (isCustomPositionRequiredForImage(
        widget.paint, SizeC(widget.width, widget.height))) {
      effectiveChildSize =
          getEffectiveChildSizeForImage(widget.node, widget.paint);

      position = convertAlignmentToPosition(
        parentWidth: widget.node.basicBoxGlobal.width,
        parentHeight: widget.node.basicBoxGlobal.height,
        childWidth: effectiveChildSize!.width,
        childHeight: effectiveChildSize!.height,
        alignmentX: widget.paint.alignment.data?.x ?? 0,
        alignmentY: widget.paint.alignment.data?.y ?? 0,
      );
    } else {
      position = null;
    }
  }

  Widget errorBuilder() {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxHeight < 64 || constraints.maxWidth < 64) {
        return FittedBox(child: Center(child: Icon(Icons.error_outline)));
      }
      return FittedBox(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline),
              Text(
                'Failed to load image',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget loadingBuilder(DownloadProgress progress) {
    return Center(
      child: SizedBox(
        width: widget.width / 3,
        height: widget.height / 3,
        child: FittedBox(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: CircularProgressIndicator(
                value: progress.progress,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget jsonPathBuilder(String path) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxHeight < 64 || constraints.maxWidth < 64) {
        return FittedBox(child: Center(child: Icon(Icons.image)));
      }
      return FittedBox(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.image),
              Text(
                'Variable Image',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.merge(
                      GoogleFonts.sourceCodePro(),
                    ),
              ),
              Text(
                path,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.merge(
                      GoogleFonts.sourceCodePro(
                        color: Colors.greenAccent.shade700,
                      ),
                    ),
              ),
            ],
          ),
        ),
      );
    });
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
            child: buildImage3(withAlignment: false),
          )
        ],
      );
    }

    return buildImage3(withAlignment: true);
  }

  /// Uses CachedNetworkImage
  Widget buildImage3({required bool withAlignment}) {
    if (widget.url.isJsonPath) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: jsonPathBuilder(widget.url),
      );
    }
    return CachedNetworkImage(
      imageUrl: widget.url,
      width: widget.width,
      height: widget.height,
      repeat: widget.repeat,
      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 300),
      placeholderFadeInDuration: const Duration(milliseconds: 300),
      imageBuilder: (context, imageProvider) {
        final child = DecoratedBox(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: imageProvider,
              fit: widget.fit,
              repeat: widget.repeat,
              alignment: withAlignment ? widget.alignment : Alignment.center,
              scale: widget.paint.isNonUniformScale ? 1 : widget.scale.abs(),
            ),
          ),
        );
        if (widget.paint.hasFlippedAxis) {
          return Transform.scale(
            scaleX: widget.paint.scaleX.sign,
            scaleY: widget.paint.scaleY.sign,
            child: child,
          );
        }
        return child;
      },
      progressIndicatorBuilder: (context, url, downloadProgress) =>
          loadingBuilder(downloadProgress),
      errorWidget: (context, url, error) => errorBuilder(),
    );
  }

  /// Uses DecorationImage
  Widget buildImage2({required bool withAlignment}) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: NetworkImage(widget.url),
          fit: widget.fit,
          alignment: withAlignment ? widget.alignment : Alignment.center,
          scale: widget.scale,
          repeat: widget.repeat,
        ),
      ),
    );
  }

  /// Uses Image.network
  Widget buildImage({required bool withAlignment}) {
    if (widget.url.isJsonPath) return jsonPathBuilder(widget.url);
    return Image.network(
      widget.url,
      fit: widget.fit,
      alignment: withAlignment ? widget.alignment : Alignment.center,
      scale: widget.scale,
      width: widget.width,
      height: widget.height,
      repeat: widget.repeat,
      loadingBuilder: (BuildContext context, Widget child,
              ImageChunkEvent? loadingProgress) =>
          AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        child: loadingProgress == null
            ? child
            : Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
      ),
      errorBuilder: (context, Object error, StackTrace? stackTrace) =>
          LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxHeight < 64 || constraints.maxWidth < 64) {
          return Center(child: Icon(Icons.error_outline));
        }
        return Align(
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline),
              Text(
                'Failed to load image',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      }),
    );
  }
}

class RelativeTransform {
  final List<double> translation;
  final double rotation;
  final List<double> scale;
  final List<double> skew;

  const RelativeTransform({
    required this.translation,
    required this.rotation,
    required this.scale,
    required this.skew,
  });

  const RelativeTransform.empty()
      : translation = const [0, 0],
        rotation = 0,
        scale = const [0, 0],
        skew = const [0, 0];

  RelativeTransform copyWith({
    List<double>? translation,
    double? rotation,
    List<double>? scale,
    List<double>? skew,
  }) =>
      RelativeTransform(
        translation: translation ?? this.translation,
        rotation: rotation ?? this.rotation,
        scale: scale ?? this.scale,
        skew: skew ?? this.skew,
      );
}
