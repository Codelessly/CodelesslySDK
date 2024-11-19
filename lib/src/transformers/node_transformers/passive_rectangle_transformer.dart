import 'dart:math' hide log;
import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:vector_math/vector_math_64.dart' as vec_math;

import '../../../codelessly_sdk.dart';

class PassiveRectangleTransformer extends NodeWidgetTransformer<BaseNode> {
  PassiveRectangleTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    BaseNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) {
    final List<Widget> children = [];

    for (String childID in node.childrenOrEmpty) {
      final Widget builtWidget =
          manager.buildWidgetByID(childID, context, settings: settings);

      children.add(builtWidget);
    }
    return buildRectangle(
      node,
      settings: settings,
      children: children,
    );
  }

  Widget buildRectangle(
    BaseNode node, {
    AlignmentModel stackAlignment = AlignmentModel.none,
    List<Widget> children = const [],
    bool applyPadding = true,
    required WidgetBuildSettings settings,
  }) {
    return PassiveRectangleWidget(
      node: node,
      stackAlignment: stackAlignment,
      applyPadding: applyPadding,
      settings: settings,
      manager: manager,
      children: children,
    );
  }
}

class PassiveRectangleWidget extends StatelessWidget {
  final BaseNode node;
  final List<Widget> children;
  final AlignmentModel stackAlignment;
  final Clip Function(BaseNode node) getClipBehavior;
  final bool applyPadding;
  final WidgetBuildSettings settings;
  final WidgetNodeTransformerManager manager;

  const PassiveRectangleWidget({
    super.key,
    required this.node,
    this.children = const [],
    this.stackAlignment = AlignmentModel.none,
    this.getClipBehavior = defaultGetClipBehavior,
    this.applyPadding = true,
    required this.settings,
    required this.manager,
  });

  @override
  Widget build(BuildContext context) {
    final ScopedValues scopedValues = ScopedValues.of(context);

    final BaseNode? parent = node.id == kRootNode || node.parentID == kRootNode
        ? null
        : manager.getNode(node.parentID);
    bool isPlaceholder =
        parent is CanvasNode && parent.properties.bodyId == node.id;

    /// TODO Birju / Saad. Why does the commented out parent code below break published layouts only?
    /// Saad's note: The below code looks like AdaptiveNodeBox
    final double? width = (node.horizontalFit == SizeFit.shrinkWrap ||
            isPlaceholder)
        ? null
        : (node.horizontalFit ==
                SizeFit
                    .expanded /* &&
                (parent is! CanvasNode || parent.properties.bodyId != node.id)*/
            )
            ? double.infinity
            : node.basicBoxLocal.width;

    final double? height = (node.verticalFit == SizeFit.shrinkWrap ||
            isPlaceholder)
        ? null
        : (node.verticalFit ==
                SizeFit
                    .expanded /*&&
                (parent is! CanvasNode || parent.properties.bodyId != node.id)*/
            )
            ? double.infinity
            : node.basicBoxLocal.height;

    Widget? portalWidget;
    if (node case PortalMixin portal) {
      if (portal.showPortal &&
          portal.layoutID != null &&
          portal.pageID != null &&
          portal.canvasID != null) {
        portalWidget = Positioned.fill(
          key: ValueKey('Portal ${portal.layoutID}'),
          child: settings.isPreview
              // Show stripes in preview mode
              ? PortalPreviewWidget(node: node)
              : manager.layoutRetrievalBuilder(
                  context,
                  node.innerBoxLocal.size,
                  portal.pageID!,
                  portal.layoutID!,
                  portal.canvasID!,
                ),
        );
      }
    }

    Widget data = Container(
      key: ValueKey('Rectangle Transformer of ${node.debugLabel}'),
      clipBehavior: getClipBehavior(node),
      width: width,
      height: height,
      decoration: BoxDecoration(
        boxShadow: retrieveBoxShadow(node, scopedValues),
        borderRadius: getBorderRadius(node),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment:
            stackAlignment.flutterAlignment ?? AlignmentDirectional.topStart,
        children: [
          ...buildFills(
            node,
            useInk: false,
            obscureImages: settings.obscureImages,
            settings: settings,
            scopedValues: scopedValues,
          ),
          ...buildStrokes(node, scopedValues),
          ...wrapWithInkWell(
            context,
            node,
            wrapWithPaddingAndScroll(
              node,
              [
                ...children,
                if (portalWidget != null) portalWidget,
              ],
              stackAlignment: stackAlignment,
              applyPadding: applyPadding,
            ),
          ),
        ],
      ),
    );

    return data;
  }
}

List<Widget> wrapWithInkWell(
  BuildContext context,
  BaseNode node,
  List<Widget> children,
) {
  if (node is! ReactionMixin) return children;

  final InkWellModel? inkWell = node is BlendMixin ? node.inkWell : null;

  if (inkWell == null) return children;

  final List<Reaction> onClickReactions = (node as ReactionMixin)
      .reactions
      .where((reaction) => reaction.trigger.type == TriggerType.click)
      .toList();

  final List<Reaction> onLongPressReactions = (node as ReactionMixin)
      .reactions
      .where((reaction) => reaction.trigger.type == TriggerType.longPress)
      .toList();

  final widget = Material(
    type: MaterialType.transparency,
    child: InkWell(
      onTap: onClickReactions.isEmpty
          ? null
          : () => FunctionsRepository.triggerAction(
                context,
                TriggerType.click,
                reactions: onClickReactions,
              ),
      onLongPress: onLongPressReactions.isEmpty
          ? null
          : () => FunctionsRepository.triggerAction(
                context,
                TriggerType.longPress,
                reactions: onLongPressReactions,
              ),
      borderRadius: getBorderRadius(node),
      overlayColor: inkWell.overlayColor != null
          ? WidgetStatePropertyAll<Color>(
              inkWell.overlayColor!.toFlutterColor(),
            )
          : null,
      splashColor: inkWell.splashColor?.toFlutterColor(),
      highlightColor: inkWell.highlightColor?.toFlutterColor(),
      hoverColor: inkWell.hoverColor?.toFlutterColor(),
      focusColor: inkWell.focusColor?.toFlutterColor(),
      child: Stack(
        children: children,
      ),
    ),
  );

  return [widget];
}

class PortalPreviewWidget extends StatelessWidget {
  final BaseNode node;

  const PortalPreviewWidget({
    super.key,
    required this.node,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: StripePainter(
        bgColor: const Color(0xFFBA79F4).withOpacity(0.1),
        stripeColor: const Color(0xFFBA79F4),
        nbOfStripes: (node.outerBoxGlobal.size.longestSide / 10).round(),
      ),
    );
  }
}

List<Widget> wrapWithPadding(
  BaseNode node,
  List<Widget> children, {
  required AlignmentModel stackAlignment,
  bool applyPadding = true,
}) {
  if (children.isEmpty || !applyPadding) return children;

  final EdgeInsets resolvedPadding =
      node.innerBoxLocal.edgeInsets.flutterEdgeInsets;

  if (resolvedPadding == EdgeInsets.zero) {
    return children;
  }

  return [
    // This adaptive box forces the Stack to respect the configurations of its
    // associated [node]. Without it, the Stack can produce cases where it
    // wraps around its concrete child tightly instead of expanding from a
    // SizeFit.expand.
    AdaptiveNodeBox(
      node: node,
      child: Padding(
        padding: resolvedPadding,
        child: Stack(
          clipBehavior: Clip.none,
          alignment:
              stackAlignment.flutterAlignment ?? AlignmentDirectional.topStart,
          children: children,
        ),
      ),
    ),
  ];
}

List<Widget> wrapWithPaddingAndScroll(
  BaseNode node,
  List<Widget> children, {
  required AlignmentModel stackAlignment,
  bool applyPadding = true,
}) {
  if (children.isEmpty) return children;

  final EdgeInsets resolvedPadding =
      node.innerBoxLocal.edgeInsets.flutterEdgeInsets;

  if (node is FrameNode && node.isScrollable) {
    return [
      wrapWithPaddedScrollable(
        node: node,
        padding: applyPadding ? resolvedPadding : null,
        clipBehavior: defaultGetClipBehavior(node),
        child: Stack(
          clipBehavior: Clip.none,
          alignment:
              stackAlignment.flutterAlignment ?? AlignmentDirectional.topStart,
          children: children,
        ),
      ),
    ];
  }

  return wrapWithPadding(
    node,
    children,
    stackAlignment: stackAlignment,
    applyPadding: applyPadding,
  );
}

List<BoxShadow> retrieveBoxShadow(BaseNode node, ScopedValues scopedValues) {
  if (node is! DefaultShapeNode) return [];
  return node.effects
      .where((effect) => effect.type == EffectType.dropShadow && effect.visible)
      .map(
    (effect) {
      final ColorRGBA? color =
          PropertyValueDelegate.getPropertyValue<ColorRGBA>(
                node,
                'shadow-color-${effect.id}',
                scopedValues: scopedValues,
              ) ??
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

List<Widget> buildStrokes(BaseNode node, ScopedValues scopedValues) {
  if (node is! GeometryMixin || node.strokeWeight <= 0) {
    return [];
  }
  final List<Widget> strokeWidgets = [];
  for (final paint in node.strokes.where((paint) => paint.visible)) {
    final paintValue = PropertyValueDelegate.getPropertyValue<PaintModel>(
      node,
      'stroke-paint-${paint.id}',
      scopedValues: scopedValues,
    );
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
  bool useInk,
  bool obscureImages,
);

List<Widget> buildFills(
  BaseNode node, {
  Map<int, TypedBytes> imageBytes = const {},
  double? imageOpacity,
  double? imageRotation,
  ImageFillBuilder? imageFillBuilder,
  bool useInk = true,
  bool obscureImages = false,
  required WidgetBuildSettings settings,
  required ScopedValues scopedValues,
}) {
  if (node is! GeometryMixin) return [];

  List<Widget> raster = [];

  // fills that have BlendMode-fills above them in the index list (smaller
  // indices) will recur the list of fills to recursively collect the blend-mode
  // layers above it, and then consume/apply the blendmodes by wrapping itself
  // with ShaderMasks until a non-blendmode fill is found. This is done to
  // ensure that the blendmodes are applied in the correct order.
  Map<int, PaintModel> lastBlendTree = {};
  for (final (i, model) in node.fills.reversed.indexed) {
    if (!model.visible) continue;
    if (model.blendMode != BlendModeC.srcOver) {
      lastBlendTree[i] = model;
      continue;
    }

    // At this point, we have reached a non-blendmode fill. We need to apply the
    // blendmodes in the correct order to this fill.
    Widget fill = buildFill(
      node,
      index: i,
      imageBytes: imageBytes,
      imageOpacity: imageOpacity,
      imageRotation: imageRotation,
      imageFillBuilder: imageFillBuilder,
      useInk: useInk,
      obscureImages: obscureImages,
      settings: settings,
      scopedValues: scopedValues,
    );

    // fill = BlendMask(
    //   model: paint,
    //   image: null,
    //   child: fill,
    // );
    fill = Stack(
      fit: StackFit.expand,
      children: [
        fill,
        for (final MapEntry(key: i, value: paint)
            in lastBlendTree.entries.toList().reversed)
          if (paint.visible)
            Positioned.fill(
              child: PaintBlendMask(
                model: paint,
                image: null,
                child: buildFill(
                  node,
                  index: i,
                  imageBytes: imageBytes,
                  imageOpacity: imageOpacity,
                  imageRotation: imageRotation,
                  imageFillBuilder: imageFillBuilder,
                  useInk: useInk,
                  obscureImages: obscureImages,
                  settings: settings,
                  scopedValues: scopedValues,
                ),
              ),
            ),
      ],
    );

    lastBlendTree.clear();
    raster.add(wrapFillWithPositioned(
      node: node,
      fill: fill,
      paint: model,
    ));
  }

  return raster.reversed.toList();
}

Widget wrapFillWithPositioned({
  required GeometryMixin node,
  required Widget fill,
  required PaintModel paint,
}) =>
    switch (paint.type) {
      PaintType.solid => Positioned.fill(child: fill),
      PaintType.gradientLinear ||
      PaintType.gradientRadial ||
      PaintType.gradientAngular ||
      PaintType.gradientDiamond =>
        Positioned.fill(child: fill),
      PaintType.image => node.isHorizontalWrap || node.isVerticalWrap
          ? Positioned(child: fill)
          : Positioned.fill(child: fill),
      PaintType.emoji => fill,
    };

Widget buildFill(
  GeometryMixin node, {
  required int index,
  Map<int, TypedBytes> imageBytes = const {},
  double? imageOpacity,
  double? imageRotation,
  ImageFillBuilder? imageFillBuilder,
  bool useInk = true,
  bool obscureImages = false,
  required WidgetBuildSettings settings,
  required ScopedValues scopedValues,
}) {
  final paint = node.fills[index];
  final BorderRadius? borderRadius = getBorderRadius(node);

  switch (paint.type) {
    case PaintType.solid:
      final propertyValue = PropertyValueDelegate.getPropertyValue<PaintModel>(
        node,
        'fill-${paint.id}',
        scopedValues: scopedValues,
      );
      final decoration = BoxDecoration(
        borderRadius: borderRadius,
        color: (propertyValue ?? paint).toFlutterColor()!,
      );
      return useInk
          ? Ink(decoration: decoration)
          : DecoratedBox(decoration: decoration);
    case PaintType.gradientLinear:
    case PaintType.gradientRadial:
    case PaintType.gradientAngular:
    case PaintType.gradientDiamond:
      final decoration = BoxDecoration(
        borderRadius: borderRadius,
        gradient: retrieveGradient(paint),
      );
      return useInk
          ? Ink(decoration: decoration)
          : DecoratedBox(decoration: decoration);
    case PaintType.image:
      final TypedBytes? bytes = imageBytes[index];
      final double modifiedOpacity = (imageOpacity ?? 1) * paint.opacity;

      // Substitute URL value from [CodelesslyContext]'s [data] map if
      // [imageURL] represents a JSON path.
      String? imageURL = paint.croppedImageURL ?? paint.downloadUrl!;
      final imageURLValue = PropertyValueDelegate.getPropertyValue<String>(
            node,
            'fill-image-${paint.id}',
            scopedValues: scopedValues,
          ) ??
          imageURL;
      imageURL = PropertyValueDelegate.substituteVariables(
        imageURLValue,
        nullSubstitutionMode: settings.nullSubstitutionMode,
        scopedValues: scopedValues,
      );
      Widget child;

      if (imageFillBuilder != null) {
        child = imageFillBuilder(
          imageURL,
          node.basicBoxLocal.width,
          node.basicBoxLocal.height,
          paint,
          bytes,
          useInk,
          obscureImages,
        );
      } else {
        if (obscureImages) {
          child = SizedBox(
            width: node.basicBoxLocal.width,
            height: node.basicBoxLocal.height,
            child: const Placeholder(),
          );
        } else {
          child = UltimateImageBuilder(
            url: imageURL,
            width: (node.horizontalFit == SizeFit.shrinkWrap)
                ? null
                : (node.horizontalFit == SizeFit.expanded)
                    ? double.infinity
                    : node.basicBoxLocal.width,
            height: (node.verticalFit == SizeFit.shrinkWrap)
                ? null
                : (node.verticalFit == SizeFit.expanded)
                    ? double.infinity
                    : node.basicBoxLocal.height,
            paint: paint,
            node: node,
            bytes: bytes,
            useInk: useInk,
          );
        }
      }

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
        return child;
      }

      return child;

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

// Applies a BlendMode to its child.
class BlendMask extends SingleChildRenderObjectWidget {
  final List<BlendMode> blendModes;
  final double opacity;

  const BlendMask({
    required this.blendModes,
    this.opacity = 1.0,
    super.key,
    required Widget super.child,
  });

  @override
  RenderObject createRenderObject(context) =>
      RenderBlendMask(blendModes, opacity);

  @override
  void updateRenderObject(BuildContext context, RenderBlendMask renderObject) {
    renderObject.blendModes = blendModes;
    renderObject.opacity = opacity;
  }
}

class RenderBlendMask extends RenderProxyBox {
  List<BlendMode> blendModes;
  double opacity;

  RenderBlendMask(this.blendModes, this.opacity);

  @override
  void paint(context, offset) {
    // Complex blend modes can be raster cached incorrectly on the Skia backend.
    context.setWillChangeHint();
    for (var blend in blendModes) {
      context.canvas.saveLayer(
        offset & size,
        Paint()
          ..blendMode = blend
          ..color = Color.fromARGB((opacity * 255).round(), 255, 255, 255),
      );
    }
    super.paint(context, offset);
    context.canvas.restore();
  }
}

class PaintBlendMask extends SingleChildRenderObjectWidget {
  final PaintModel _model;
  final ui.Image? _image;

  const PaintBlendMask({
    required PaintModel model,
    ui.Image? image,
    super.key,
    super.child,
  })  : _model = model,
        _image = image;

  @override
  RenderObject createRenderObject(context) {
    return RenderPaintBlendMask(_model, _image);
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderPaintBlendMask renderObject) {
    renderObject._model = _model;
    renderObject._image = _image;
  }
}

class RenderPaintBlendMask extends RenderProxyBox {
  PaintModel _model;
  ui.Image? _image;

  RenderPaintBlendMask(PaintModel model, ui.Image? image)
      : _model = model,
        _image = image;

  Paint makePaint(Rect bounds) {
    Paint paint = Paint()..blendMode = _model.blendMode.flutterBlendMode;
    // paint.color = Colors.white;
    // return paint;

    switch (_model.type) {
      case PaintType.solid:
        Color? color = _model.toFlutterColor();
        if (color != null) {
          paint.color = color;
        }
      case PaintType.gradientLinear:
      case PaintType.gradientRadial:
      case PaintType.gradientAngular:
      case PaintType.gradientDiamond:
        paint.shader = retrieveGradient(_model)?.createShader(bounds);
      case PaintType.image:
        if (_image case ui.Image image) {
          paint.shader = ImageShader(
            image,
            TileMode.clamp,
            TileMode.clamp,
            Matrix4.identity().storage,
          );
        }
      case PaintType.emoji:
        break;
    }

    return paint;
  }

  @override
  void paint(context, offset) {
    // Complex blend modes can be raster cached incorrectly on the Skia backend.
    context.setWillChangeHint();
    context.canvas.saveLayer(
      offset & size,
      makePaint(offset & size),
    );

    super.paint(context, offset);

    context.canvas.restore();
  }
}
