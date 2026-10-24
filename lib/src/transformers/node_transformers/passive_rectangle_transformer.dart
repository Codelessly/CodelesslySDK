import 'dart:math' hide log;

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
      final Widget builtWidget = manager.buildWidgetByID(
        childID,
        context,
        settings: settings,
      );

      children.add(builtWidget);
    }
    return buildRectangle(node, settings: settings, children: children);
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

    // The canvas body hugs; the canvas sizes the screen. Every other node
    // follows its fits (see FitBox): an expanded axis fills when bounded and
    // keeps its design size when not.
    final SizeFit horizontalFit = isPlaceholder
        ? SizeFit.shrinkWrap
        : node.horizontalFit;
    final SizeFit verticalFit = isPlaceholder
        ? SizeFit.shrinkWrap
        : node.verticalFit;

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

    Widget child = Stack(
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
            [...children, ?portalWidget],
            stackAlignment: stackAlignment,
            applyPadding: applyPadding,
            getNode: manager.getNode,
            isPlaceholder: isPlaceholder,
          ),
          alignment:
              stackAlignment.flutterAlignment ?? AlignmentDirectional.topStart,
        ),
      ],
    );

    bool hasComplexRendering =
        node is GeometryMixin &&
        (node as GeometryMixin).fills.any(
          (PaintModel fill) => fill.blendMode != BlendModeC.srcOver,
        );

    if (hasComplexRendering) {
      child = BlendMask(child: child);
    }

    return FitBox.fromFits(
      key: ValueKey('Rectangle Transformer of ${node.debugLabel}'),
      horizontalFit: horizontalFit,
      verticalFit: verticalFit,
      size: node.basicBoxLocal.size,
      child: decorateWithShadows(
        boxShadow: retrieveBoxShadow(node, scopedValues),
        borderRadius: getBorderRadius(node),
        clipBehavior: getClipBehavior(node),
        child: child,
      ),
    );
  }
}

/// A box with [borderRadius] and [boxShadow] around [child]. A shadow with a
/// spread on a rounded box is painted by [SpreadShadowPainter], so its
/// corners grow with it as in CSS and design tools; [BoxDecoration] keeps the
/// box's radius, which turns a spread glow around a dot into a square.
Widget decorateWithShadows({
  required List<BoxShadow> boxShadow,
  required BorderRadius? borderRadius,
  required Clip clipBehavior,
  required Widget child,
}) {
  final bool rounded =
      borderRadius != null && borderRadius != BorderRadius.zero;
  final List<BoxShadow> spread = [
    if (rounded)
      for (final BoxShadow shadow in boxShadow)
        if (shadow.spreadRadius != 0) shadow,
  ];
  final Widget box = Container(
    clipBehavior: clipBehavior,
    decoration: BoxDecoration(
      boxShadow: [
        for (final BoxShadow shadow in boxShadow)
          if (!spread.contains(shadow)) shadow,
      ],
      borderRadius: borderRadius,
    ),
    child: child,
  );
  // Only a rounded box has spread shadows here, so it has a radius.
  if (spread.isEmpty) return box;
  return CustomPaint(
    painter: SpreadShadowPainter(shadows: spread, borderRadius: borderRadius!),
    child: box,
  );
}

/// Paints [shadows] around a box of [borderRadius], growing (or, for a
/// negative spread, shrinking) the corner radii with each shadow's spread.
class SpreadShadowPainter extends CustomPainter {
  const SpreadShadowPainter({
    required this.shadows,
    required this.borderRadius,
  });

  final List<BoxShadow> shadows;
  final BorderRadius borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final RRect box = borderRadius.toRRect(Offset.zero & size);
    for (final BoxShadow shadow in shadows) {
      canvas.drawRRect(
        box.shift(shadow.offset).inflate(shadow.spreadRadius),
        shadow.toPaint(),
      );
    }
  }

  @override
  bool shouldRepaint(SpreadShadowPainter oldDelegate) =>
      !const ListEquality<BoxShadow>().equals(oldDelegate.shadows, shadows) ||
      oldDelegate.borderRadius != borderRadius;
}

List<Widget> wrapWithInkWell(
  BuildContext context,
  BaseNode node,
  List<Widget> children, {
  AlignmentGeometry alignment = AlignmentDirectional.topStart,
}) {
  if (node is! ReactionMixin) return children;

  final InkWellModel? inkWell = node is BlendMixin ? node.inkWell : null;

  if (inkWell == null) return children;

  final List<Reaction> onClickReactions = (node as ReactionMixin).reactions
      .where((reaction) => reaction.trigger.type == TriggerType.click)
      .toList();

  final List<Reaction> onLongPressReactions = (node as ReactionMixin).reactions
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
      child: Stack(alignment: alignment, children: children),
    ),
  );

  // A node with a set size fills it with its ink and children. Otherwise the
  // inner stack sizes to its unpositioned children, and when those are
  // hidden (a likes badge on a photo tile) everything else in it gets no
  // space.
  if (node.horizontalFit != SizeFit.shrinkWrap &&
      node.verticalFit != SizeFit.shrinkWrap) {
    return [Positioned.fill(child: widget)];
  }
  return [widget];
}

class PortalPreviewWidget extends StatelessWidget {
  final BaseNode node;

  const PortalPreviewWidget({super.key, required this.node});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: StripePainter(
        bgColor: const Color(0xFFBA79F4).withValues(alpha: 0.1),
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
  bool isPlaceholder = false,
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
    // A canvas body hugs, like its rectangle.
    FitBox.fromFits(
      horizontalFit: isPlaceholder ? SizeFit.shrinkWrap : node.horizontalFit,
      verticalFit: isPlaceholder ? SizeFit.shrinkWrap : node.verticalFit,
      size: node.basicBoxLocal.size,
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
  GetNode? getNode,
  bool isPlaceholder = false,
}) {
  if (children.isEmpty) return children;

  final EdgeInsets resolvedPadding =
      node.innerBoxLocal.edgeInsets.flutterEdgeInsets;

  if (node is FrameNode && node.isScrollable) {
    // The content reaches the farthest child along the scroll axis, and at
    // least the viewport (fillViewport); across it, it spans the viewport.
    // Children are positioned in it, so it cannot size itself from them:
    // [extent] is where the editor placed the farthest edge, and
    // [ScrollContentStack] grows past it when children laid out at runtime
    // reach farther (text that wraps to more lines, data-bound lists).
    final bool vertical = node.scrollDirection.isVertical;
    final double extent = [
      for (final String childID in node.children)
        if (getNode?.call(childID) case final BaseNode child)
          vertical
              ? child.outerBoxLocal.bottom - node.innerBoxLocal.edgeTop
              : child.outerBoxLocal.right - node.innerBoxLocal.edgeLeft,
    ].fold(0, max);
    return [
      wrapWithPaddedScrollable(
        node: node,
        padding: applyPadding ? resolvedPadding : null,
        clipBehavior: defaultGetClipBehavior(node),
        fillViewport: true,
        child: SizedBox(
          width: vertical && node.horizontalFit == SizeFit.shrinkWrap
              ? node.innerBoxLocal.width
              : null,
          height: !vertical && node.verticalFit == SizeFit.shrinkWrap
              ? node.innerBoxLocal.height
              : null,
          child: ScrollContentStack(
            axis: node.scrollDirection.flutterAxis,
            minExtent: extent,
            clipBehavior: Clip.none,
            alignment:
                stackAlignment.flutterAlignment ??
                AlignmentDirectional.topStart,
            children: children,
          ),
        ),
      ),
    ];
  }

  return wrapWithPadding(
    node,
    children,
    stackAlignment: stackAlignment,
    applyPadding: applyPadding,
    isPlaceholder: isPlaceholder,
  );
}

List<BoxShadow> retrieveBoxShadow(BaseNode node, ScopedValues scopedValues) {
  if (node is! DefaultShapeNode) return [];
  return node.effects
      .where((effect) => effect.type == EffectType.dropShadow && effect.visible)
      .map((effect) {
        final ColorRGBA? color =
            PropertyValueDelegate.getPropertyValue<ColorRGBA>(
              node,
              'shadow-color-${effect.id}',
              scopedValues: scopedValues,
            ) ??
            effect.color;
        return BoxShadow(
          spreadRadius: effect.spread!,
          offset: Offset(
            effect.offset!.x.toDouble(),
            effect.offset!.y.toDouble(),
          ),
          blurRadius: effect.radius,
          color: color!.toFlutterColor(),
        );
      })
      .toList();
}

BorderRadius? getBorderRadius(BaseNode node) {
  if (node is CornerMixin) {
    if (node.cornerRadius.linked &&
        node.cornerRadius.type == RadiusType.elliptical) {
      return BorderRadius.all(
        Radius.elliptical(node.basicBoxLocal.width, node.basicBoxLocal.height),
      );
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
    final double rotation = decomposeRelativeTransform(paint.gradientTransform)
        .rotation;

    // We sort the colors to mimic the way Figma changes the order.
    final gradientStops = paint.gradientStops!.sorted(
      (g1, g2) => g1.position.compareTo(g2.position),
    );
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
    DebugLogger.instance.printInfo(
      'Failed to build gradient: $error\n$stacktrace',
      name: 'PassiveRectangleTransformer',
    );
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

  final vec_math.Matrix3 matrix = vec_math.Matrix3(
    cosA,
    sinA,
    tx,
    -sinA,
    cosA,
    ty,
    0,
    0,
    1,
  );

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
    // A solid stroke on every side is Flutter's own border. A stroke on one
    // side, or a dashed one, is painted by [StrokePainter].
    if (node.dashPattern.isEmpty && node.strokeSide == StrokeSide.all) {
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
  List<PaintModel> lastBlendTree = [];
  for (final model in node.fills.reversed) {
    final index = node.fills.indexOf(model);
    if (!model.visible) continue;
    if (settings.withBlendModes && model.blendMode != BlendModeC.srcOver) {
      lastBlendTree.add(model);
      continue;
    }

    // At this point, we have reached a non-blendmode fill. We need to apply the
    // blendmodes in the correct order to this fill.
    Widget fill = buildFill(
      node,
      index: index,
      imageBytes: imageBytes,
      imageOpacity: imageOpacity,
      imageRotation: imageRotation,
      imageFillBuilder: imageFillBuilder,
      useInk: useInk,
      obscureImages: obscureImages,
      settings: settings,
      scopedValues: scopedValues,
    );

    if (lastBlendTree.isNotEmpty) {
      for (final paint in lastBlendTree) {
        if (!paint.visible) continue;
        raster.add(
          Positioned.fill(
            child: BlendMask(
              key: ObjectKey(paint.blendMode),
              blendMode: paint.blendMode.flutterBlendMode,
              child: buildFill(
                node,
                index: node.fills.indexOf(paint),
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
        );
      }
    }

    lastBlendTree.clear();
    raster.add(wrapFillWithPositioned(node: node, fill: fill, paint: model));
  }

  return raster.reversed.toList();
}

Widget wrapFillWithPositioned({
  required GeometryMixin node,
  required Widget fill,
  required PaintModel paint,
}) => switch (paint.type) {
  PaintType.solid => Positioned.fill(child: fill),
  PaintType.gradientLinear ||
  PaintType.gradientRadial ||
  PaintType.gradientAngular ||
  PaintType.gradientDiamond => Positioned.fill(child: fill),
  PaintType.image =>
    node.isHorizontalWrap || node.isVerticalWrap
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
      final imageURLValue =
          PropertyValueDelegate.getPropertyValue<String>(
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
      // A URL path that resolves to nothing, like a cover that isn't set
      // yet, has no image to load.
      if (bytes == null &&
          (imageURL.trim().isEmpty ||
              (settings.replaceVariablesWithSymbols &&
                  variableSyntaxIdentifierRegex.hasMatch(imageURL)))) {
        // The design canvas shows where a bound image goes.
        return settings.replaceVariablesWithSymbols &&
                variableSyntaxIdentifierRegex.hasMatch(imageURLValue)
            ? ImageFillPlaceholder(borderRadius: borderRadius)
            : const SizedBox.shrink();
      }
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
        child = Opacity(opacity: modifiedOpacity, child: child);
      }
      if (imageRotation != null) {
        child = Transform.rotate(angle: imageRotation, child: child);
      }
      return child;
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
  }) => RelativeTransform(
    translation: translation ?? this.translation,
    rotation: rotation ?? this.rotation,
    scale: scale ?? this.scale,
    skew: skew ?? this.skew,
  );
}

/// Stands in on a design canvas for an image bound to a variable that has no
/// value yet.
class ImageFillPlaceholder extends StatelessWidget {
  /// The corners of the node the image fills.
  final BorderRadius? borderRadius;

  /// Creates an [ImageFillPlaceholder].
  const ImageFillPlaceholder({super.key, this.borderRadius});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFE9ECEF),
        borderRadius: borderRadius,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double side = constraints.biggest.shortestSide;
          if (!side.isFinite || side < 12) return const SizedBox.expand();
          return Center(
            child: Icon(
              Icons.image_outlined,
              size: (side / 3).clamp(12, 48),
              color: const Color(0xFFADB5BD),
            ),
          );
        },
      ),
    );
  }
}

/// The content of a scroll view that positions its children: a [Stack]
/// that, unlike a plain one, sizes itself from its [Positioned] children
/// along [axis].
///
/// Along [axis] it is [minExtent] long (and at least the incoming minimum,
/// so it can fill the viewport). When a child laid out at that length ends
/// past it, the stack lays its children out again at the length its
/// farthest child needs, so everything stays reachable by scrolling. Across
/// [axis] it sizes like a [Stack].
class ScrollContentStack extends Stack {
  final Axis axis;
  final double minExtent;

  const ScrollContentStack({
    super.key,
    required this.axis,
    required this.minExtent,
    super.alignment,
    super.clipBehavior,
    super.children,
  });

  @override
  RenderScrollContentStack createRenderObject(BuildContext context) =>
      RenderScrollContentStack(
        axis: axis,
        minExtent: minExtent,
        alignment: alignment,
        textDirection: textDirection ?? Directionality.maybeOf(context),
        fit: fit,
        clipBehavior: clipBehavior,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderScrollContentStack renderObject,
  ) {
    super.updateRenderObject(context, renderObject);
    renderObject
      ..axis = axis
      ..minExtent = minExtent;
  }
}

/// The render object of [ScrollContentStack].
class RenderScrollContentStack extends RenderStack {
  RenderScrollContentStack({
    required Axis axis,
    required double minExtent,
    super.alignment,
    super.textDirection,
    super.fit,
    super.clipBehavior,
  }) {
    _axis = axis;
    _minExtent = minExtent;
  }

  Axis get axis => _axis;
  late Axis _axis;
  set axis(Axis value) {
    if (value == _axis) return;
    _axis = value;
    markNeedsLayout();
  }

  double get minExtent => _minExtent;
  late double _minExtent;
  set minExtent(double value) {
    if (value == _minExtent) return;
    _minExtent = value;
    markNeedsLayout();
  }

  bool get _vertical => axis == Axis.vertical;

  /// Lays the children out in a stack at least [extent] long along [axis]
  /// and returns the stack's size.
  ///
  /// A child that is not positioned (such as a freeform layout that sizes
  /// itself from its children) gets the incoming, unbounded, main axis and
  /// makes the stack as long as it needs. Positioned children are placed in
  /// the resulting size.
  Size _layoutAt(double extent) {
    final BoxConstraints box = _vertical
        ? constraints.copyWith(minHeight: extent, maxHeight: extent)
        : constraints.copyWith(minWidth: extent, maxWidth: extent);
    final BoxConstraints loose = _vertical
        ? box.loosen().copyWith(maxHeight: constraints.maxHeight)
        : box.loosen().copyWith(maxWidth: constraints.maxWidth);
    bool hasNonPositioned = false;
    double width = box.minWidth;
    double height = box.minHeight;
    RenderBox? child = firstChild;
    while (child != null) {
      final data = child.parentData! as StackParentData;
      if (!data.isPositioned) {
        hasNonPositioned = true;
        final Size childSize = ChildLayoutHelper.layoutChild(child, loose);
        width = max(width, childSize.width);
        height = max(height, childSize.height);
      }
      child = data.nextSibling;
    }
    final BoxConstraints grown = _vertical
        ? box.copyWith(maxHeight: constraints.maxHeight)
        : box.copyWith(maxWidth: constraints.maxWidth);
    final Size size = hasNonPositioned
        ? grown.constrain(Size(width, height))
        : box.biggest;

    final Alignment resolved = alignment.resolve(textDirection);
    child = firstChild;
    while (child != null) {
      final data = child.parentData! as StackParentData;
      if (!data.isPositioned) {
        data.offset = resolved.alongOffset(size - child.size as Offset);
      } else {
        RenderStack.layoutPositionedChild(child, data, size, resolved);
      }
      child = data.nextSibling;
    }
    return size;
  }

  /// The farthest edge along [axis] that a child reaches.
  double _farthestChildEdge() {
    double farthest = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      final data = child.parentData! as StackParentData;
      final double edge = _vertical
          ? data.offset.dy + child.size.height
          : data.offset.dx + child.size.width;
      farthest = max(farthest, edge);
      child = data.nextSibling;
    }
    return farthest;
  }

  /// [constraints] made tight at the starting length along [axis]:
  /// [minExtent], within the incoming bounds.
  BoxConstraints _atMinExtent(BoxConstraints constraints) {
    final double extent = _vertical
        ? constraints.constrainHeight(max(minExtent, constraints.minHeight))
        : constraints.constrainWidth(max(minExtent, constraints.minWidth));
    return _vertical
        ? constraints.copyWith(minHeight: extent, maxHeight: extent)
        : constraints.copyWith(minWidth: extent, maxWidth: extent);
  }

  // A dry layout cannot see where positioned children end, so it reports the
  // starting length.
  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      super.computeDryLayout(_atMinExtent(constraints));

  @override
  void performLayout() {
    final double maxMain = _vertical
        ? constraints.maxHeight
        : constraints.maxWidth;
    double extent = _vertical
        ? _atMinExtent(constraints).maxHeight
        : _atMinExtent(constraints).maxWidth;
    size = _layoutAt(extent);
    extent = _vertical ? size.height : size.width;
    final double needed = min(_farthestChildEdge(), maxMain);
    if (needed > extent + 0.5) {
      extent = needed;
      size = _layoutAt(extent);
    }
  }
}
