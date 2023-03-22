import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:codelessly_api/codelessly_api.dart';
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
  }) {
    return PassiveRectangleWidget(
      node: node,
      children: children,
    );
  }
}

class PassiveRectangleWidget extends StatelessWidget {
  final BaseNode node;
  final List<Widget> children;
  final Clip Function(BaseNode node) getClipBehavior;

  PassiveRectangleWidget({
    super.key,
    required this.node,
    this.children = const [],
    this.getClipBehavior = defaultGetClipBehavior,
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
        boxShadow: retrieveBoxShadow(node),
        borderRadius: getBorderRadius(node),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          ...buildFills(node, codelesslyContext),
          ...buildStrokes(node),
          ...wrapWithPadding(node, children),
        ],
      ),
    );

    return data;
  }
}

List<Widget> wrapWithPadding(BaseNode node, List<Widget> children) {
  final EdgeInsets resolvedPadding = node.resolvedPadding().edgeInsets;

  if (resolvedPadding == EdgeInsets.zero) {
    return children;
  }

  return children.map((child) => Padding(
    padding: resolvedPadding,
    child: child,
  )).toList();
}

List<BoxShadow> retrieveBoxShadow(BaseNode node) {
  if (node is! DefaultShapeNode) return [];
  return node.effects
      .where((effect) => effect.type == EffectType.dropShadow)
      .map(
        (effect) => BoxShadow(
          spreadRadius: effect.spread!,
          offset:
              Offset(effect.offset!.x.toDouble(), effect.offset!.y.toDouble()),
          blurRadius: effect.radius,
          color: effect.color!.toFlutterColor(),
        ),
      )
      .toList();
}

BorderRadius? getBorderRadius(BaseNode node) {
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

Clip defaultGetClipBehavior(BaseNode node) {
  if (node is ClipMixin) {
    if (node.clipsContent) {
      return Clip.hardEdge;
    } else {
      return Clip.none;
    }
  }

  if (node is CornerMixin && node.cornerRadius != CornerRadius.zero) {
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
        result = ClipRect(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: effect.radius / 10,
              sigmaY: effect.radius / 10,
            ),
            child: result,
          ),
        );
        break;
    }
  }
  return result;
}

List<Widget> buildStrokes(BaseNode node) {
  if (node is! GeometryMixin || node.strokeWeight <= 0) {
    return [];
  }
  if (node.dashPattern.isEmpty) {
    return [
      for (final paint in node.strokes)
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: getBorderRadius(node),
            border: Border.all(
              strokeAlign: node.strokeAlign.alignment,
              color: paint.toFlutterColor()!,
              width: node.strokeWeight,
            ),
          ),
        ),
    ];
  } else {
    return [
      for (final paint in node.strokes)
        CustomPaint(
          painter: StrokePainter(
            color: paint.toFlutterColor()!,
            borderRadius: getBorderRadius(node) ?? BorderRadius.zero,
            dashPattern: node.dashPattern,
            strokeWidth: node.strokeWeight,
            strokeMiterLimit: node.strokeMiterLimit,
            strokeCap: node.strokeCap,
            strokeAlign: node.strokeAlign,
            strokeSide: node.strokeSide,
            boxShape: getBoxShape(node),
          ),
        ),
    ];
  }
}

List<Widget> buildFills(
  BaseNode node,
  CodelesslyContext codelesslyContext, {
  Map<int, Uint8List> imageBytes = const {},
  double? imageOpacity,
  double? imageRotation,
}) {
  if (node is! GeometryMixin) {
    return [];
  }

  final BorderRadius? borderRadius = getBorderRadius(node);
  return [
    ...node.fills.mapIndexed((index, paint) {
      switch (paint.type) {
        case PaintType.solid:
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              color: paint.toFlutterColor()!,
            ),
          );
        case PaintType.gradientLinear:
        case PaintType.gradientRadial:
        case PaintType.gradientAngular:
        case PaintType.gradientDiamond:
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              gradient: retrieveGradient(paint),
            ),
          );
        case PaintType.image:
          final Uint8List? bytes = imageBytes[index];

          // Substitute URL value from [CodelesslyContext]'s [data] map if
          // [imageURL] represents a JSON path.
          String? imageURL = paint.croppedImageURL ?? paint.downloadUrl!;
          imageURL = substituteData(imageURL, codelesslyContext.data);

          final BoxFit fit = paint.fit.boxFit;
          final Alignment? alignment = paint.alignment.flutterAlignment;
          final double modifiedOpacity = (imageOpacity ?? 1) * paint.opacity;
          final double scale = paint.scale;
          final ImageRepeat repeat = paint.imageRepeat.flutterImageRepeat;

          Widget child = bytes != null
              ? Image.memory(
                  bytes,
                  fit: fit,
                  alignment: alignment ?? Alignment.center,
                  scale: scale,
                  width: node.basicBoxLocal.width,
                  height: node.basicBoxLocal.height,
                  repeat: repeat,
                )
              : _NetworkImageWithStates(
                  url: imageURL,
                  fit: fit,
                  alignment: alignment ?? Alignment.center,
                  scale: scale,
                  width: node.basicBoxLocal.width,
                  height: node.basicBoxLocal.height,
                  repeat: repeat,
                  paint: paint,
                  node: node,
                );

          if (modifiedOpacity != 1) {
            child = Opacity(
              opacity: modifiedOpacity,
              child: child,
            );
          }
          if (imageRotation != null) {
            child = Transform.rotate(
              angle: imageRotation,
              child: child,
            );
          }

          return child;

        case PaintType.emoji:
          return const SizedBox.shrink();
      }
    }),
  ];
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
