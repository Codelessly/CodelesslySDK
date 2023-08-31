import 'dart:math' hide log;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
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
    AlignmentModel stackAlignment = AlignmentModel.none,
    List<Widget> children = const [],
  }) {
    return PassiveRectangleWidget(
      node: node,
      stackAlignment: stackAlignment,
      children: children,
    );
  }
}

class PassiveRectangleWidget extends StatelessWidget {
  final BaseNode node;
  final List<Widget> children;
  final AlignmentModel stackAlignment;
  final Clip Function(BaseNode node) getClipBehavior;

  PassiveRectangleWidget({
    super.key,
    required this.node,
    this.children = const [],
    this.stackAlignment = AlignmentModel.none,
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
        boxShadow: retrieveBoxShadow(context, node, codelesslyContext),
        borderRadius: getBorderRadius(node),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          clipBehavior: Clip.none,
          alignment:
              stackAlignment.flutterAlignment ?? AlignmentDirectional.topStart,
          children: [
            ...buildFills(context, node, codelesslyContext),
            ...buildStrokes(context, node, codelesslyContext),
            ...wrapWithPadding(node, children, stackAlignment: stackAlignment),
          ],
        ),
      ),
    );

    return data;
  }
}

List<Widget> wrapWithPadding(
  BaseNode node,
  List<Widget> children, {
  required AlignmentModel stackAlignment,
}) {
  if (children.isEmpty) return children;

  final EdgeInsets resolvedPadding =
      node.innerBoxLocal.edgeInsets.flutterEdgeInsets;

  if (node is FrameNode && node.isScrollable) {
    return [
      wrapWithScrollable(
        node: node,
        padding: resolvedPadding,
        clipBehavior: defaultGetClipBehavior(node),
        child: SizedBox(
          width: node.scrollDirection.isHorizontal
              ? node.outerBoxLocal.width
              : null,
          height: node.scrollDirection.isVertical
              ? node.outerBoxLocal.height
              : null,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: stackAlignment.flutterAlignment ??
                AlignmentDirectional.topStart,
            children: children,
          ),
        ),
      ),
    ];
  }

  if (resolvedPadding == EdgeInsets.zero) {
    return children;
  }

  return [
    Padding(
      padding: resolvedPadding,
      child: Stack(
        clipBehavior: Clip.none,
        alignment:
            stackAlignment.flutterAlignment ?? AlignmentDirectional.topStart,
        children: children,
      ),
    ),
  ];
}

List<BoxShadow> retrieveBoxShadow(
    BuildContext context, BaseNode node, CodelesslyContext codelesslyContext) {
  if (node is! DefaultShapeNode) return [];
  return node.effects
      .where((effect) => effect.type == EffectType.dropShadow && effect.visible)
      .map(
    (effect) {
      final ColorRGBA? color =
          PropertyValueDelegate.getPropertyValue<ColorRGBA>(
                  context, node, 'shadow-color-${effect.id}') ??
              effect.color;
      return BoxShadow(
        spreadRadius: effect.spread!,
        offset:
            Offset(effect.offset!.x.toDouble(), effect.offset!.y.toDouble()),
        blurRadius: effect.radius,
        color: color!.toFlutterColor(),
      );
    },
  ).toList();
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

List<Widget> buildStrokes(
    BuildContext context, BaseNode node, CodelesslyContext codelesslyContext) {
  if (node is! GeometryMixin || node.strokeWeight <= 0) {
    return [];
  }
  final List<Widget> strokeWidgets = [];
  for (final paint in node.strokes.where((paint) => paint.visible)) {
    final paintValue = PropertyValueDelegate.getPropertyValue<PaintModel>(
        context, node, 'stroke-paint-${paint.id}');
    if (node.dashPattern.isEmpty) {
      strokeWidgets.add(
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: getBorderRadius(node),
              border: Border.all(
                strokeAlign: node.strokeAlign.alignment,
                color: (paintValue ?? paint).toFlutterColor()!,
                width: node.strokeWeight,
              ),
            ),
          ),
        ),
      );
    } else {
      strokeWidgets.add(
        Positioned.fill(
          child: CustomPaint(
            painter: StrokePainter(
              color: (paintValue ?? paint).toFlutterColor()!,
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
        ),
      );
    }
  }

  return strokeWidgets;
}

typedef ImageFillBuilder = Widget Function(
  String url,
  double width,
  double height,
  PaintModel paint,
  TypedBytes? bytes,
);

List<Widget> buildFills(
  BuildContext context,
  BaseNode node,
  CodelesslyContext codelesslyContext, {
  Map<int, TypedBytes> imageBytes = const {},
  double? imageOpacity,
  double? imageRotation,
  ImageFillBuilder? imageFillBuilder,
}) {
  if (node is! GeometryMixin) return [];

  final BorderRadius? borderRadius = getBorderRadius(node);
  return [
    ...node.fills.where((paint) => paint.visible).mapIndexed((index, paint) {
      switch (paint.type) {
        case PaintType.solid:
          final propertyValue =
              PropertyValueDelegate.getPropertyValue<PaintModel>(
                  context, node, 'fill-${paint.id}');
          return Positioned.fill(
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                color: (propertyValue ?? paint).toFlutterColor()!,
              ),
            ),
          );
        case PaintType.gradientLinear:
        case PaintType.gradientRadial:
        case PaintType.gradientAngular:
        case PaintType.gradientDiamond:
          return Positioned.fill(
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                gradient: retrieveGradient(paint),
              ),
            ),
          );
        case PaintType.image:
          final TypedBytes? bytes = imageBytes[index];
          final double modifiedOpacity = (imageOpacity ?? 1) * paint.opacity;

          // Substitute URL value from [CodelesslyContext]'s [data] map if
          // [imageURL] represents a JSON path.
          String? imageURL = paint.croppedImageURL ?? paint.downloadUrl!;
          final imageURLValue = PropertyValueDelegate.getPropertyValue<String>(
                context,
                node,
                'fill-image-${paint.id}',
              ) ??
              imageURL;
          imageURL = PropertyValueDelegate.getVariableValueFromPath<String>(
                  context, imageURLValue) ??
              imageURL;
          Widget child;

          if (imageFillBuilder != null) {
            child = imageFillBuilder(
              imageURL,
              node.basicBoxLocal.width,
              node.basicBoxLocal.height,
              paint,
              bytes,
            );
          } else {
            child = UltimateImageBuilder(
              url: imageURL,
              width: node.basicBoxLocal.width,
              height: node.basicBoxLocal.height,
              paint: paint,
              node: node,
              bytes: bytes,
            );
          }

          child = Transform.scale(
            scaleX: paint.isFlippedX ? -1 : 1,
            scaleY: paint.isFlippedY ? -1 : 1,
            child: child,
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

          if (node.isHorizontalWrap || node.isVerticalWrap) {
            // if the node is shrink-wrapping on one or both axes, then we
            // need to wrap the image in a Positioned widget so that it
            // doesn't expand to the size of the parent.
            return Positioned(child: child);
          }

          return Positioned.fill(child: child);

        // if (node.childrenOrEmpty.isEmpty) {
        //   // If we don't do this then shrink-wrapping images will not work.
        //   // They will expand to the size of the parent.
        //   return child;
        // } else {
        //   // This was Positioned.fill before. If this is breaking something,
        //   // then we need to figure out a way to make it work with
        //   // Positioned.fill and Positioned because Positioned.fill breaks
        //   // shrink-wrapping.
        //   return Positioned(child: child);
        // }

        case PaintType.emoji:
          return const SizedBox.shrink();
      }
    }),
  ];
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
