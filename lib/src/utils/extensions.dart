import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart' as flutter;
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';

import '../../codelessly_sdk.dart';
import '../transformers/utils/condition_evaluator.dart';
import '../transformers/utils/condition_visitors.dart';

extension FABLocationHelper on FABLocation {
  FloatingActionButtonLocation toFloatingActionButtonLocation() {
    switch (this) {
      case FABLocation.startTop:
        return FloatingActionButtonLocation.startTop;
      case FABLocation.miniStartTop:
        return FloatingActionButtonLocation.miniStartTop;
      case FABLocation.centerTop:
        return FloatingActionButtonLocation.centerTop;
      case FABLocation.miniCenterTop:
        return FloatingActionButtonLocation.miniCenterTop;
      case FABLocation.endTop:
        return FloatingActionButtonLocation.endTop;
      case FABLocation.miniEndTop:
        return FloatingActionButtonLocation.miniEndTop;
      case FABLocation.startFloat:
        return FloatingActionButtonLocation.startFloat;
      case FABLocation.miniStartFloat:
        return FloatingActionButtonLocation.miniStartFloat;
      case FABLocation.centerFloat:
        return FloatingActionButtonLocation.centerFloat;
      case FABLocation.miniCenterFloat:
        return FloatingActionButtonLocation.miniCenterFloat;
      case FABLocation.endFloat:
        return FloatingActionButtonLocation.endFloat;
      case FABLocation.miniEndFloat:
        return FloatingActionButtonLocation.miniEndFloat;
      case FABLocation.startDocked:
        return FloatingActionButtonLocation.startDocked;
      case FABLocation.miniStartDocked:
        return FloatingActionButtonLocation.miniStartDocked;
      case FABLocation.centerDocked:
        return FloatingActionButtonLocation.centerDocked;
      case FABLocation.miniCenterDocked:
        return FloatingActionButtonLocation.miniCenterDocked;
      case FABLocation.endDocked:
        return FloatingActionButtonLocation.endDocked;
      case FABLocation.miniEndDocked:
        return FloatingActionButtonLocation.miniEndDocked;
    }
  }
}

extension M2NavigationBarTypeHelper on M2NavigationBarType {
  BottomNavigationBarType get flutterNavigationBarType {
    switch (this) {
      case M2NavigationBarType.fixed:
        return BottomNavigationBarType.fixed;
      case M2NavigationBarType.shifting:
        return BottomNavigationBarType.shifting;
    }
  }
}

extension M2NavigationBarLandscapeLayoutHelper
    on M2NavigationBarLandscapeLayout {
  BottomNavigationBarLandscapeLayout get flutterLandscapeLayout {
    switch (this) {
      case M2NavigationBarLandscapeLayout.spread:
        return BottomNavigationBarLandscapeLayout.spread;
      case M2NavigationBarLandscapeLayout.centered:
        return BottomNavigationBarLandscapeLayout.centered;
      case M2NavigationBarLandscapeLayout.linear:
        return BottomNavigationBarLandscapeLayout.linear;
    }
  }
}

extension M3NavigationDestinationLabelBehaviorHelper
    on MaterialNavigationBarLabelBehavior {
  NavigationDestinationLabelBehavior get flutterLabelBehavior {
    switch (this) {
      case MaterialNavigationBarLabelBehavior.alwaysShow:
        return NavigationDestinationLabelBehavior.alwaysShow;
      case MaterialNavigationBarLabelBehavior.alwaysHide:
        return NavigationDestinationLabelBehavior.alwaysHide;
      case MaterialNavigationBarLabelBehavior.onlyShowSelected:
        return NavigationDestinationLabelBehavior.onlyShowSelected;
      case MaterialNavigationBarLabelBehavior.onlyShowUnselected:
        throw UnsupportedError(
            'MaterialNavigationBarLabelBehavior.onlyShowUnselected is not supported for material 2.');
    }
  }
}

extension ListTileControlAffinityHelper on ListTileControlAffinityC {
  ListTileControlAffinity get flutterControlAffinity {
    switch (this) {
      case ListTileControlAffinityC.leading:
        return ListTileControlAffinity.leading;
      case ListTileControlAffinityC.trailing:
        return ListTileControlAffinity.trailing;
      case ListTileControlAffinityC.platform:
        return ListTileControlAffinity.platform;
    }
  }
}

extension BaseNodeHelper on BaseNode {
  Vec globalPosFromBoundary(NodeBoundaryType type) {
    switch (type) {
      case NodeBoundaryType.outerBox:
        return outerBoxGlobal.topLeft;
      case NodeBoundaryType.outerRotatedBox:
        return outerRotatedBoxGlobal.topLeft;
      case NodeBoundaryType.middleBox:
        return middleBoxGlobal.topLeft;
      case NodeBoundaryType.middleRotatedBox:
        return middleRotatedBoxGlobal.topLeft;
      case NodeBoundaryType.innerBox:
      case NodeBoundaryType.innerRotatedBox:
        return innerBoxGlobal.topLeft;
    }
  }

  Vec localPosFromBoundary(NodeBoundaryType type) {
    switch (type) {
      case NodeBoundaryType.outerBox:
        return outerBoxLocal.topLeft;
      case NodeBoundaryType.outerRotatedBox:
        return outerRotatedBoxLocal.topLeft;
      case NodeBoundaryType.middleBox:
        return middleBoxLocal.topLeft;
      case NodeBoundaryType.middleRotatedBox:
        return middleRotatedBoxLocal.topLeft;
      case NodeBoundaryType.innerBox:
      case NodeBoundaryType.innerRotatedBox:
        return innerBoxLocal.topLeft;
    }
  }

  SizeC sizeFromBoundary(NodeBoundaryType type) {
    switch (type) {
      case NodeBoundaryType.outerBox:
        return outerBoxLocal.size;
      case NodeBoundaryType.outerRotatedBox:
        return outerRotatedBoxLocal.size;
      case NodeBoundaryType.middleBox:
        return middleBoxLocal.size;
      case NodeBoundaryType.middleRotatedBox:
        return middleRotatedBoxLocal.size;
      case NodeBoundaryType.innerBox:
      case NodeBoundaryType.innerRotatedBox:
        return innerBoxLocal.size;
    }
  }

  RectC localRectFromBoundary(NodeBoundaryType type) {
    switch (type) {
      case NodeBoundaryType.outerBox:
        return outerBoxLocal.rect;
      case NodeBoundaryType.outerRotatedBox:
        return outerRotatedBoxLocal.rect;
      case NodeBoundaryType.middleBox:
        return middleBoxLocal.rect;
      case NodeBoundaryType.middleRotatedBox:
        return middleRotatedBoxLocal.rect;
      case NodeBoundaryType.innerBox:
      case NodeBoundaryType.innerRotatedBox:
        return innerBoxLocal.rect;
    }
  }

  RectC globalRectFromBoundary(NodeBoundaryType type) {
    switch (type) {
      case NodeBoundaryType.outerBox:
        return outerBoxGlobal.rect;
      case NodeBoundaryType.outerRotatedBox:
        return outerRotatedBoxGlobal.rect;
      case NodeBoundaryType.middleBox:
        return middleBoxGlobal.rect;
      case NodeBoundaryType.middleRotatedBox:
        return middleRotatedBoxGlobal.rect;
      case NodeBoundaryType.innerBox:
      case NodeBoundaryType.innerRotatedBox:
        return innerBoxGlobal.rect;
    }
  }

  RectC rectFromBoundary(NodeBoundaryType type,
      {required PositioningSpace space}) {
    switch (space) {
      case PositioningSpace.local:
        return localRectFromBoundary(type);
      case PositioningSpace.global:
        return globalRectFromBoundary(type);
    }
  }

  Vec posFromBoundary(NodeBoundaryType type,
      {required PositioningSpace space}) {
    switch (space) {
      case PositioningSpace.global:
        return globalPosFromBoundary(type);
      case PositioningSpace.local:
        return localPosFromBoundary(type);
    }
  }
}

extension KeyboardDismissBehaviorHelper on ScrollViewKeyboardDismissBehaviorC {
  ScrollViewKeyboardDismissBehavior get flutterKeyboardDismissBehavior {
    switch (this) {
      case ScrollViewKeyboardDismissBehaviorC.manual:
        return ScrollViewKeyboardDismissBehavior.manual;
      case ScrollViewKeyboardDismissBehaviorC.onDrag:
        return ScrollViewKeyboardDismissBehavior.onDrag;
    }
  }
}

extension ScrollPhysicsHelper on ScrollPhysicsC {
  ScrollPhysics? flutterScrollPhysics(bool shouldAlwaysScroll) {
    final parent = switch (this) {
      ScrollPhysicsC.platformDependent => null,
      ScrollPhysicsC.bouncingScrollPhysics => const BouncingScrollPhysics(),
      ScrollPhysicsC.clampingScrollPhysics => const ClampingScrollPhysics(),
      ScrollPhysicsC.rangeMaintainingScrollPhysics =>
        const RangeMaintainingScrollPhysics(),
      ScrollPhysicsC.neverScrollableScrollPhysics =>
        const NeverScrollableScrollPhysics()
    };
    if (shouldAlwaysScroll) {
      return AlwaysScrollableScrollPhysics(parent: parent);
    }
    return parent;
  }
}

extension TextModelEnumHelper on TextAlignHorizontalEnum {
  TextAlign get flutterTextAlignment {
    switch (this) {
      case TextAlignHorizontalEnum.left:
        return TextAlign.left;
      case TextAlignHorizontalEnum.center:
        return TextAlign.center;
      case TextAlignHorizontalEnum.right:
        return TextAlign.right;
      case TextAlignHorizontalEnum.justified:
        return TextAlign.justify;
    }
  }
}

extension TextOverflowHelper on TextOverflowC {
  TextOverflow get flutterOverflow {
    switch (this) {
      case TextOverflowC.clip:
        return TextOverflow.clip;
      case TextOverflowC.fade:
        return TextOverflow.fade;
      case TextOverflowC.ellipsis:
        return TextOverflow.ellipsis;
      case TextOverflowC.visible:
        return TextOverflow.visible;
      default:
        throw Exception('Unknown TextOverflowc value: $this');
    }
  }

  String get capitalName {
    return '${name[0].toUpperCase()}${name.substring(1)}';
  }
}

extension RowColumnTypeHelper on RowColumnType {
  AxisC get axis =>
      this == RowColumnType.row ? AxisC.horizontal : AxisC.vertical;
}

extension CornerRadiusHelper on CornerRadius {
  flutter.BorderRadius get borderRadius => flutter.BorderRadius.only(
        topLeft: Radius.elliptical(tl.x, tl.y),
        topRight: Radius.elliptical(tr.x, tr.y),
        bottomLeft: Radius.elliptical(bl.x, bl.y),
        bottomRight: Radius.elliptical(br.x, br.y),
      );
}

extension ColorHelper on flutter.Color {
  ColorRGB get colorRGB =>
      ColorRGB(r: red / 255.0, g: green / 255.0, b: blue / 255.0);

  ColorRGBA get colorRGBA => ColorRGBA(
      r: red / 255.0, g: green / 255.0, b: blue / 255.0, a: alpha / 255.0);

  Color darken([double percent = 10]) {
    assert(1 <= percent && percent <= 100);
    var f = 1 - percent / 100;
    return Color.fromARGB(
        alpha, (red * f).round(), (green * f).round(), (blue * f).round());
  }

  ColorRGB toColorRGB() => colorRGB;

  ColorRGBA toColorRGBA() => colorRGBA;

  String get hex => value.toRadixString(16).padLeft(8, '0').toUpperCase();

  PaintModel toPaint([String? id]) => PaintModel.solid(
        id: id ?? generateId(),
        visible: true,
        opacity: opacity,
        color: toColorRGB(),
      );

  Effect toShadow() => Effect(
        id: generateId(),
        type: EffectType.dropShadow,
        color: colorToRGBA(this),
        offset: const Vec(0, 4),
        radius: 8,
        spread: 0,
      );
}

extension ColorRGBAHelper on ColorRGBA {
  Color toFlutterColor() {
    var ir = (r * 255).toInt();
    var ig = (g * 255).toInt();
    var ib = (b * 255).toInt();
    var ia = (a * 255).toInt();
    return Color.fromARGB(ia, ir, ig, ib);
  }

  ColorRGB toRGB() => toFlutterColor().colorRGB;

  PaintModel toPaint([String? id]) => PaintModel.solid(
      id: id ?? generateId(),
      visible: true,
      opacity: toFlutterColor().opacity,
      color: toRGB());
}

extension PaintModelExt on PaintModel {
  Color? toFlutterColor() {
    if (color == null) return null;
    return color!.toFlutterColor(opacity: opacity);
  }

  String get imageExtension =>
      path.extension(Uri.parse(croppedImageURL ?? downloadUrl ?? '').path);

  bool get isStaticImage => staticImageTypesRegex.hasMatch(imageExtension);

  bool get isSvgImage => imageExtension == '.svg' || imageExtension == 'svg';

  bool get isGifImage => imageExtension == '.gif';
}

extension ColorRGBHelper on ColorRGB {
  flutter.Color get flutterColor => flutter.Color.fromRGBO(
      (r * 255).toInt(), (g * 255).toInt(), (b * 255).toInt(), 1);

  Color toFlutterColor({required double opacity}) {
    var ir = (r * 255).toInt();
    var ig = (g * 255).toInt();
    var ib = (b * 255).toInt();
    var ia = (opacity * 255).toInt();
    return Color.fromARGB(ia, ir, ig, ib);
  }

  ColorRGBA toColorRGBA([double? opacity]) =>
      toFlutterColor(opacity: opacity ?? 1).colorRGBA;
}

extension BoxConstraintsModelHelper on BoxConstraintsModel {
  flutter.BoxConstraints get flutterConstraints => flutter.BoxConstraints(
        minWidth: minWidth ?? 0.0,
        maxWidth: maxWidth ?? double.infinity,
        minHeight: minHeight ?? 0.0,
        maxHeight: maxHeight ?? double.infinity,
      );
}

extension AlignmentDataHelper on AlignmentData {
  Vec get vec => Vec(x, y);

  flutter.AlignmentGeometry get flutterAlignmentGeometry =>
      flutter.Alignment(x, y);

  flutter.Alignment get flutterAlignment => flutter.Alignment(x, y);

  AlignmentData resolve(TextDirection direction) {
    switch (direction) {
      case TextDirection.rtl:
        return AlignmentData(-x, y);
      case TextDirection.ltr:
        return AlignmentData(x, y);
    }
  }
}

extension AlignmentModelHelper on AlignmentModel {
  Vec? get vec => data?.vec;

  flutter.AlignmentGeometry? get flutterAlignmentGeometry =>
      data?.flutterAlignmentGeometry;

  flutter.Alignment? get flutterAlignment => data?.flutterAlignment;

  AlignmentEnum get alignmentEnum {
    if (data == null) return AlignmentEnum.none;
    if (data?.x == -1 && data?.y == -1) return AlignmentEnum.topLeft;
    if (data?.x == 0 && data?.y == -1) return AlignmentEnum.topCenter;
    if (data?.x == 1 && data?.y == -1) return AlignmentEnum.topRight;
    if (data?.x == -1 && data?.y == 0) return AlignmentEnum.centerLeft;
    if (data?.x == 0 && data?.y == 0) return AlignmentEnum.center;
    if (data?.x == 1 && data?.y == 0) return AlignmentEnum.centerRight;
    if (data?.x == -1 && data?.y == 1) return AlignmentEnum.bottomLeft;
    if (data?.x == 0 && data?.y == 1) return AlignmentEnum.bottomCenter;
    if (data?.x == 1 && data?.y == 1) return AlignmentEnum.bottomRight;
    return AlignmentEnum.custom;
  }
}

extension AlignmentGeometryHelper on flutter.AlignmentGeometry {
  flutter.Alignment? get toNormalAlignment => resolve(null);
}

extension CMainAxisAlignmentHelper on MainAxisAlignmentC {
  flutter.MainAxisAlignment get flutterAxis {
    switch (this) {
      case MainAxisAlignmentC.start:
        return flutter.MainAxisAlignment.start;
      case MainAxisAlignmentC.end:
        return flutter.MainAxisAlignment.end;
      case MainAxisAlignmentC.center:
        return flutter.MainAxisAlignment.center;
      case MainAxisAlignmentC.spaceBetween:
        return flutter.MainAxisAlignment.spaceBetween;
      case MainAxisAlignmentC.spaceAround:
        return flutter.MainAxisAlignment.spaceAround;
      case MainAxisAlignmentC.spaceEvenly:
        return flutter.MainAxisAlignment.spaceEvenly;
      default:
        return flutter.MainAxisAlignment.start;
    }
  }
}

extension CCrossAxisAlignmentHelper on CrossAxisAlignmentC {
  flutter.CrossAxisAlignment get flutterAxis {
    switch (this) {
      case CrossAxisAlignmentC.start:
        return flutter.CrossAxisAlignment.start;
      case CrossAxisAlignmentC.end:
        return flutter.CrossAxisAlignment.end;
      case CrossAxisAlignmentC.center:
        return flutter.CrossAxisAlignment.center;
      case CrossAxisAlignmentC.stretch:
        return flutter.CrossAxisAlignment.stretch;
      case CrossAxisAlignmentC.baseline:
        return flutter.CrossAxisAlignment.baseline;
      default:
        return flutter.CrossAxisAlignment.start;
    }
  }
}

extension AxisHelperExt on AxisC {
  flutter.Axis get flutterAxis => this == AxisC.horizontal
      ? flutter.Axis.horizontal
      : flutter.Axis.vertical;
}

extension FlutterAxisHelper on flutter.Axis {
  AxisC get cAxis =>
      this == flutter.Axis.horizontal ? AxisC.horizontal : AxisC.vertical;
}

extension FlutterAlignmentHelper on flutter.Alignment {
  AlignmentModel get alignmentModel => AlignmentModel(alignmentData);

  AlignmentData get alignmentData => AlignmentData(x, y);
}

extension RectHelper on RectC {
  flutter.Rect get flutterRect =>
      flutter.Rect.fromLTRB(left, top, right, bottom);
}

extension FlutterRectHelper on flutter.Rect {
  RectC get cRect => RectC.fromLTRB(left, top, right, bottom);
}

extension FlutterSizeHelper on flutter.Size {
  SizeC get cSize => SizeC(width, height);
}

extension SizeHelper on SizeC {
  flutter.Size get flutterSize => flutter.Size(width, height);

  flutter.Offset get flutterOffset => flutter.Offset(width, height);

  Vec get vec => Vec(width, height);
}

extension OffsetHelper on flutter.Offset {
  Vec get vec => Vec(dx, dy);

  SizeC get cSize => SizeC(dx, dy);
}

extension VecHelper on Vec {
  flutter.Offset get offset => flutter.Offset(x, y);

  SizeC get cSize => SizeC(x, y);

  Vec operator +(flutter.Offset other) => Vec(x + other.dx, y + other.dy);

  Vec operator -(flutter.Offset other) => Vec(x - other.dx, y - other.dy);

  Vec operator *(double other) => Vec(x * other, y * other);

  Vec operator /(double other) => Vec(x / other, y / other);
}

extension EdgeInsetsHelper on EdgeInsetsModel {
  flutter.EdgeInsets get flutterEdgeInsets =>
      flutter.EdgeInsets.fromLTRB(l, t, r, b);

  bool get isSymmetric => l == r && r == t && t == b;

  bool get isHorizontalSymmetric => l == r;

  bool get isVerticalSymmetric => t == b;
}

extension VariableDataListExtensions<T extends VariableData> on Iterable<T> {
  Iterable<T> findAllByNames(Iterable<String> names) =>
      where((element) => names.contains(element.name));

  VariableData? findByNameOrNull(String? name) =>
      firstWhereOrNull((element) => element.name == name);

  VariableData findByName(String name) =>
      firstWhere((element) => element.name == name);

  VariableData? findByIdOrNull(String? id) =>
      firstWhereOrNull((element) => element.id == id);

  VariableData findById(String id) => firstWhere((element) => element.id == id);

  // TODO: Is there a better way to do this?
  bool getBooleanById(String id, {required bool defaultValue}) {
    if (id.isEmpty) return defaultValue;
    return findByIdOrNull(id)?.typedValue<bool>() ?? defaultValue;
  }

  int getIntById(String id, {required int defaultValue}) {
    if (id.isEmpty) return defaultValue;
    return findByIdOrNull(id)?.typedValue<int>() ?? defaultValue;
  }

  double getDoubleById(String id, {required double defaultValue}) {
    if (id.isEmpty) return defaultValue;
    return findByIdOrNull(id)?.typedValue<double>() ?? defaultValue;
  }

  String getStringById(String id, {required String defaultValue}) {
    if (id.isEmpty) return defaultValue;
    return findByIdOrNull(id)?.typedValue<String>() ?? defaultValue;
  }

  bool? getBooleanByIdOrNull(String id, {bool? defaultValue}) {
    if (id.isEmpty) return defaultValue;
    return findByIdOrNull(id)?.typedValue<bool>() ?? defaultValue;
  }

  int? getIntByIdOrNull(String id, {int? defaultValue}) {
    if (id.isEmpty) return defaultValue;
    return findByIdOrNull(id)?.typedValue<int>() ?? defaultValue;
  }

  double? getDoubleByIdOrNull(String id, {double? defaultValue}) {
    if (id.isEmpty) return defaultValue;
    return findByIdOrNull(id)?.typedValue<double>() ?? defaultValue;
  }

  String? getStringByIdOrNull(String id, {String? defaultValue}) {
    if (id.isEmpty) return defaultValue;
    return findByIdOrNull(id)?.typedValue<String>() ?? defaultValue;
  }

  bool getBooleanByName(String name, {required bool defaultValue}) {
    if (name.isEmpty) return defaultValue;
    return findByNameOrNull(name)?.typedValue<bool>() ?? defaultValue;
  }

  int getIntByName(String name, {required int defaultValue}) {
    if (name.isEmpty) return defaultValue;
    return findByNameOrNull(name)?.typedValue<int>() ?? defaultValue;
  }

  double getDoubleByName(String name, {required double defaultValue}) {
    if (name.isEmpty) return defaultValue;
    return findByNameOrNull(name)?.typedValue<double>() ?? defaultValue;
  }

  String getStringByName(String name, {required String defaultValue}) {
    if (name.isEmpty) return defaultValue;
    return findByNameOrNull(name)?.typedValue<String>() ?? defaultValue;
  }

  bool? getBooleanByNameOrNull(String name, {bool? defaultValue}) {
    if (name.isEmpty) return defaultValue;
    return findByNameOrNull(name)?.typedValue<bool>() ?? defaultValue;
  }

  int? getIntByNameOrNull(String name, {int? defaultValue}) {
    if (name.isEmpty) return defaultValue;
    return findByNameOrNull(name)?.typedValue<int>() ?? defaultValue;
  }

  double? getDoubleByNameOrNull(String name, {double? defaultValue}) {
    if (name.isEmpty) return defaultValue;
    return findByNameOrNull(name)?.typedValue<double>() ?? defaultValue;
  }

  String? getStringByNameOrNull(String name, {String? defaultValue}) {
    if (name.isEmpty) return defaultValue;
    return findByNameOrNull(name)?.typedValue<String>() ?? defaultValue;
  }

  List<String> nameToId(List<String> names) => names
      .map((name) => findByNameOrNull(name))
      .whereNotNull()
      .map((e) => e.id)
      .toList();

  List<String> idToName(List<String> ids) => ids
      .map((id) => findByIdOrNull(id))
      .whereNotNull()
      .map((e) => e.name)
      .toList();

  List<String> toIds() => map((e) => e.id).toList();

  List<String> toNames() => map((e) => e.name).toList();
}

extension FitsExtension on BaseNode {
  bool get isHorizontalFlexible => horizontalFit == SizeFit.flexible;

  bool get isVerticalFlexible => verticalFit == SizeFit.flexible;

  bool get isHorizontalFixed =>
      horizontalFit == SizeFit.locked || horizontalFit == SizeFit.fixed;

  bool get isVerticalFixed =>
      verticalFit == SizeFit.locked || verticalFit == SizeFit.fixed;

  bool get isHorizontalWrap => horizontalFit == SizeFit.shrinkWrap;

  bool get isVerticalWrap => verticalFit == SizeFit.shrinkWrap;

  bool get isHorizontalExpanded => horizontalFit == SizeFit.expanded;

  bool get isVerticalExpanded => verticalFit == SizeFit.expanded;

  bool get isBothWrapped => isHorizontalWrap && isVerticalWrap;

  bool get isBothExpanded => isHorizontalExpanded && isVerticalExpanded;

  bool get isBothFlexible => isHorizontalFlexible && isVerticalFlexible;

  bool get isBothFixed => isHorizontalFixed && isVerticalFixed;

  bool get isOneFixed =>
      (isHorizontalFixed && !isVerticalFixed) ||
      (isVerticalFixed && !isHorizontalFixed);

  bool get isOneFlexible =>
      (isHorizontalFlexible && !isVerticalFlexible) ||
      (isVerticalFlexible && !isHorizontalFlexible);

  bool get isOneWrap =>
      (isHorizontalWrap && !isVerticalWrap) ||
      (!isHorizontalWrap && isVerticalWrap);

  bool get isOneExpanded =>
      (isHorizontalExpanded && !isVerticalExpanded) ||
      (!isHorizontalExpanded && isVerticalExpanded);

  bool get isOneOrBothFixed => isHorizontalFixed || isVerticalFixed;

  bool get isOneOrBothFlexible => isHorizontalFlexible || isVerticalFlexible;

  bool get isOneOrBothWrap => isHorizontalWrap || isVerticalWrap;

  bool get isOneOrBothExpanded => isHorizontalExpanded || isVerticalExpanded;

  bool canFillParent(BaseNode parent) =>
      edgePins.inner(parent).isBothExpanded || isBothExpanded;
}

extension RowColumnMixinExtensions on RowColumnMixin {
  bool get isMainAxisWrap => mainAxisFit == SizeFit.shrinkWrap;

  bool get isMainAxisExpanded => mainAxisFit == SizeFit.expanded;

  bool get isMainAxisFlexible => mainAxisFit == SizeFit.flexible;

  bool get isMainAxisFixed =>
      mainAxisFit == SizeFit.locked || mainAxisFit == SizeFit.fixed;

  bool get isCrossAxisWrap => crossAxisFit == SizeFit.shrinkWrap;

  bool get isCrossAxisExpanded => crossAxisFit == SizeFit.expanded;

  bool get isCrossAxisFlexible => crossAxisFit == SizeFit.flexible;

  bool get isCrossAxisFixed =>
      crossAxisFit == SizeFit.locked || crossAxisFit == SizeFit.fixed;

  SizeFit get mainAxisFit => isRow ? horizontalFit : verticalFit;

  SizeFit get crossAxisFit => isRow ? verticalFit : horizontalFit;

  bool get isRow => rowColumnType == RowColumnType.row;

  bool get isColumn => rowColumnType == RowColumnType.column;
}

extension EdgePinsExtensions on EdgePinsModel {
  EdgePinsModel inner(BaseNode? parent) => EdgePinsModel(
        left: effectiveLeft(parent),
        top: effectiveTop(parent),
        right: effectiveRight(parent),
        bottom: effectiveBottom(parent),
      );

  double? effectiveLeft(BaseNode? parent) {
    if (parent == null || left == null) return left;
    return left! - parent.innerBoxLocal.edgeLeft;
  }

  double? effectiveTop(BaseNode? parent) {
    if (parent == null || top == null) return top;
    return top! - parent.innerBoxLocal.edgeTop;
  }

  double? effectiveRight(BaseNode? parent) {
    if (parent == null || right == null) return right;
    return right! - parent.innerBoxLocal.edgeRight;
  }

  double? effectiveBottom(BaseNode? parent) {
    if (parent == null || bottom == null) return bottom;
    return bottom! - parent.innerBoxLocal.edgeBottom;
  }

  bool isFillingHorizontally(BaseNode? parent) {
    if (left == null || right == null) return false;
    if (parent == null) return left == 0 && right == 0;
    if (left == 0 && right == 0) return true;

    final l = left! - parent.innerBoxLocal.edgeLeft;
    final r = right! - parent.innerBoxLocal.edgeRight;
    if (l == 0 && r == 0) return true;
    return false;
  }

  bool isFillingVertically(BaseNode? parent) {
    if (top == null || bottom == null) return false;
    if (parent == null) return top == 0 && bottom == 0;
    if (top == 0 && bottom == 0) return true;

    final t = top! - parent.innerBoxLocal.edgeTop;
    final b = bottom! - parent.innerBoxLocal.edgeBottom;
    if (t == 0 && b == 0) return true;
    return false;
  }
}

extension FitExtension on Fit {
  BoxFit get boxFit {
    switch (this) {
      case Fit.contain:
        return BoxFit.contain;
      case Fit.cover:
        return BoxFit.cover;
      case Fit.fill:
        return BoxFit.fill;
      case Fit.fitHeight:
        return BoxFit.fitHeight;
      case Fit.fitWidth:
        return BoxFit.fitWidth;
      case Fit.none:
        return BoxFit.none;
      case Fit.scaleDown:
        return BoxFit.scaleDown;
      default:
        return BoxFit.contain;
    }
  }
}

extension BoxFitExt on BoxFit {
  bool get supportsAlignment => {
        BoxFit.fitHeight,
        BoxFit.fitWidth,
        BoxFit.scaleDown,
        BoxFit.none,
      }.contains(this);
}

extension AlignmentModelExtensions on AlignmentModel {
  bool get touchesVerticalEdges =>
      data != null && (data!.y == -1 || data!.y == 1);

  bool get touchesHorizontalEdges =>
      data != null && (data!.x == -1 || data!.x == 1);

  bool get touchesACorner {
    if (data == null) return false;
    final x = data!.x;
    final y = data!.y;

    return (x == -1 && y == -1) ||
        (x == -1 && y == 1) ||
        (x == 1 && y == -1) ||
        (x == 1 && y == 1);
  }

  bool get touchesAnEdge {
    if (data == null) return false;
    final x = data!.x;
    final y = data!.y;

    return ((x == -1 || x == 1) && y != -1 && y != 1) ||
        ((y == -1 || y == 1) && x != -1 && x != 1);
  }
}

extension GenericExtensions<T extends Object> on T? {
  T? includeIf(bool shouldInclude) => shouldInclude ? this : null;

  T? orNullIf(bool returnNull) => returnNull ? null : this;
}

extension MultiIconModelExtensions on MultiSourceIconModel {
  IconModel? getIconData() {
    if (!isStandardIcon) return null;
    if (!isIconAvailable) return null;
    return icon!;
  }

  bool get isIconAvailable {
    switch (type) {
      case IconTypeEnum.icon:
        return icon != null;
      case IconTypeEnum.image:
        return iconImage != null;
    }
  }

  String get imageExtension => path.extension(Uri.parse(iconImage ?? '').path);

  bool get isStaticImage => staticImageTypesRegex.hasMatch(imageExtension);

  bool get isSvgImage => imageExtension == '.svg' || imageExtension == 'svg';

  bool get isGifImage => imageExtension == '.gif';
}

extension AssetModelExt on AssetModel {
  String get imageExtension => path.extension(Uri.parse(url).path);

  bool get isStaticImage => staticImageTypesRegex.hasMatch(imageExtension);

  bool get isSvgImage => imageExtension == '.svg' || imageExtension == 'svg';

  bool get isGifImage => imageExtension == '.gif';
}

extension TextAlignHorizontalEnumExtensions on TextAlignHorizontalEnum {
  TextAlign toFlutter() {
    switch (this) {
      case TextAlignHorizontalEnum.center:
        return TextAlign.center;
      case TextAlignHorizontalEnum.left:
        return TextAlign.left;
      case TextAlignHorizontalEnum.right:
        return TextAlign.right;
      case TextAlignHorizontalEnum.justified:
        return TextAlign.justify;
    }
  }
}

extension FontWeightExtension on FontWeightNumeric {
  FontWeight get flutterFontWeight {
    switch (this) {
      case FontWeightNumeric.w100:
        return FontWeight.w100;
      case FontWeightNumeric.w200:
        return FontWeight.w200;
      case FontWeightNumeric.w300:
        return FontWeight.w300;
      case FontWeightNumeric.w400:
        return FontWeight.w400;
      case FontWeightNumeric.w500:
        return FontWeight.w500;
      case FontWeightNumeric.w600:
        return FontWeight.w600;
      case FontWeightNumeric.w700:
        return FontWeight.w700;
      case FontWeightNumeric.w800:
        return FontWeight.w800;
      case FontWeightNumeric.w900:
        return FontWeight.w900;
    }
  }
}

extension FontNameExtensions on FontName {
  /// Convert text defined fontWeights like "Bold" into Flutter types, like
  /// w700.
  /// Source: [https://cssreference.io/property/font-weight/].
  FontWeight get flutterFontWeight {
    // This is used for layouts exported after April 30, 2021.
    if (weight != null) return weight!.flutterFontWeight;

    // Deprecated

    // Convert 'extra-bold' or 'extra bold' into 'extrabold'.
    final String style =
        this.style.toLowerCase().replaceAll('-', '').replaceAll(' ', '');

    // String might contain 'italic', which is why it uses [contains] for the
    // comparison.
    if (style.contains('thin')) {
      return FontWeight.w100;
    } else if (style.contains('extralight')) {
      return FontWeight.w200;
    } else if (style.contains('light')) {
      return FontWeight.w300;
    } else if (style.contains('normal')) {
      return FontWeight.w400;
    } else if (style.contains('medium')) {
      return FontWeight.w500;
    } else if (style.contains('semibold')) {
      return FontWeight.w600;
    } else if (style.contains('extrabold')) {
      // order matters, extrabold must come before bold.
      return FontWeight.w800;
    } else if (style.contains('ultrabold')) {
      // order matters, ultrabold must come before bold.
      return FontWeight.w900;
    } else if (style.contains('bold')) {
      return FontWeight.w700;
    } else if (style.contains('black')) {
      return FontWeight.w900;
    }

    return FontWeight.w400;
  }
}

extension TextDecorationEnumExtensions on TextDecorationEnum {
  /// Convert TextDecorationEnum into TextDecoration from Flutter.
  TextDecoration toFlutter() {
    switch (this) {
      case TextDecorationEnum.none:
        return TextDecoration.none;
      case TextDecorationEnum.underline:
        return TextDecoration.underline;
      case TextDecorationEnum.overline:
        return TextDecoration.overline;
      case TextDecorationEnum.strikethrough:
        return TextDecoration.lineThrough;
    }
  }
}

extension FloatingLabelBehaviorEnumExtensions on FloatingLabelBehaviorEnum {
  FloatingLabelBehavior toFlutter() {
    switch (this) {
      case FloatingLabelBehaviorEnum.never:
        return FloatingLabelBehavior.never;
      case FloatingLabelBehaviorEnum.auto:
        return FloatingLabelBehavior.auto;
      case FloatingLabelBehaviorEnum.always:
        return FloatingLabelBehavior.always;
    }
  }
}

extension BorderSideModelExtensions on BorderSideModel {
  BorderSide toFlutter() {
    return BorderSide(color: color.toFlutterColor(), width: width);
  }
}

extension TextInputTypeEnumExtensions on TextInputTypeEnum {
  TextInputType toFlutter() {
    switch (this) {
      case TextInputTypeEnum.dateTime:
        return TextInputType.datetime;
      case TextInputTypeEnum.emailAddress:
        return TextInputType.emailAddress;
      case TextInputTypeEnum.multiline:
        return TextInputType.multiline;
      case TextInputTypeEnum.name:
        return TextInputType.name;
      case TextInputTypeEnum.none:
        return TextInputType.none;
      case TextInputTypeEnum.number:
        return TextInputType.number;
      case TextInputTypeEnum.phone:
        return TextInputType.phone;
      case TextInputTypeEnum.streetAddress:
        return TextInputType.streetAddress;
      case TextInputTypeEnum.text:
        return TextInputType.text;
      case TextInputTypeEnum.url:
        return TextInputType.url;
      case TextInputTypeEnum.visiblePassword:
        return TextInputType.visiblePassword;
    }
  }
}

extension BoxHeightStyleEnumExtensions on BoxHeightStyleEnum {
  BoxHeightStyle toFlutter() {
    switch (this) {
      case BoxHeightStyleEnum.includeLineSpacingBottom:
        return BoxHeightStyle.includeLineSpacingBottom;
      case BoxHeightStyleEnum.includeLineSpacingMiddle:
        return BoxHeightStyle.includeLineSpacingMiddle;
      case BoxHeightStyleEnum.includeLineSpacingTop:
        return BoxHeightStyle.includeLineSpacingTop;
      case BoxHeightStyleEnum.max:
        return BoxHeightStyle.max;
      case BoxHeightStyleEnum.strut:
        return BoxHeightStyle.strut;
      case BoxHeightStyleEnum.tight:
        return BoxHeightStyle.tight;
      default:
        return BoxHeightStyle.tight;
    }
  }
}

extension BoxWidthStyleEnumExtensions on BoxWidthStyleEnum {
  BoxWidthStyle toFlutter() {
    switch (this) {
      case BoxWidthStyleEnum.max:
        return BoxWidthStyle.max;
      case BoxWidthStyleEnum.tight:
        return BoxWidthStyle.tight;
      default:
        return BoxWidthStyle.tight;
    }
  }
}

extension IconModelExt on IconModel {
  String get label => name.split('_').map((part) => part.capitalized).join(' ');

  // IconData toFontIconData() {
  //   if (this is MaterialIcon) {
  //     return IconData(
  //       codepoint,
  //       fontFamily: 'MaterialIcons${(this as MaterialIcon).style.fontFamily}',
  //       fontPackage: fontPackage,
  //     );
  //   }
  //   return IconData(codepoint,
  //       fontFamily: fontFamily, fontPackage: fontPackage);
  // }

  // IconData toFlutterIconData() {
  //   if (this is MaterialIcon) {
  //     return IconData(
  //       flutterIconsDataMap[flutterID] ?? 0,
  //       fontFamily: 'MaterialIcons',
  //     );
  //   }
  //
  //   return IconData(codepoint,
  //       fontFamily: fontFamily, fontPackage: fontPackage);
  // }

  /// This would return flutter icon name if it is a material icon. This is
  /// useful for codegen.
  String? get flutterID {
    if (this is MaterialIcon) {
      return flutterIconNames[(this as MaterialIcon).styledName];
    }
    return null;
  }

  String? toSvgUrl() {
    if (this is MaterialIcon) {
      final icon = this as MaterialIcon;
      // e.g https://fonts.gstatic.com/s/i/materialiconsoutlined/home/v16/24px.svg
      // TODO: how to get the right version?
      return kSvgIconBaseUrlTemplate
          .replaceAll(
              '{{style}}', 'materialicons${icon.style.styleName.toLowerCase()}')
          .replaceAll('{{name}}', icon.name.toLowerCase())
          .replaceAll('{{version}}', '${icon.version ?? 1}')
          .replaceAll('{{size}}', '24');
    }
    return null;
  }
}

extension MaterialIconExt on MaterialIcon {
  String? get flutterID => flutterIconNames[styledName];

  String get styledName {
    if (style == MaterialIconStyle.filled) return name;
    return '${name}_${style.name.toLowerCase()}';
  }
}

extension MaterialIconStyleExt on MaterialIconStyle {
  String get styleName {
    switch (this) {
      case MaterialIconStyle.outlined:
        return 'Outlined';
      case MaterialIconStyle.filled:
        return '';
      case MaterialIconStyle.rounded:
        return 'Round';
      case MaterialIconStyle.sharp:
        return 'Sharp';
      case MaterialIconStyle.twoTone:
        return 'Two Tone';
    }
  }

  String get fontFamily {
    switch (this) {
      case MaterialIconStyle.outlined:
        return 'Outlined';
      case MaterialIconStyle.filled:
        return 'Filled';
      case MaterialIconStyle.rounded:
        return 'Rounded';
      case MaterialIconStyle.sharp:
        return 'Sharp';
      case MaterialIconStyle.twoTone:
        return 'TwoTone';
    }
  }
}

extension MaterialSymbolStyleExt on MaterialSymbolStyle {
  String get styleName {
    switch (this) {
      case MaterialSymbolStyle.outlined:
        return 'Outlined';
      case MaterialSymbolStyle.rounded:
        return 'Round';
      case MaterialSymbolStyle.sharp:
        return 'Sharp';
    }
  }

  String get fontFamily {
    switch (this) {
      case MaterialSymbolStyle.outlined:
        return 'Outlined';
      case MaterialSymbolStyle.rounded:
        return 'Rounded';
      case MaterialSymbolStyle.sharp:
        return 'Sharp';
    }
  }
}

extension VisualDensityModelExt on VisualDensityModel {
  VisualDensity get flutterVisualDensity {
    switch (type) {
      case VisualDensityType.standard:
        return VisualDensity.standard;
      case VisualDensityType.comfortable:
        return VisualDensity.comfortable;
      case VisualDensityType.compact:
        return VisualDensity.compact;
      case VisualDensityType.adaptivePlatformDensity:
        return VisualDensity.adaptivePlatformDensity;
      case VisualDensityType.minimum:
        return const VisualDensity(
          horizontal: VisualDensity.minimumDensity,
          vertical: VisualDensity.minimumDensity,
        );
      case VisualDensityType.maximum:
        return const VisualDensity(
          horizontal: VisualDensity.maximumDensity,
          vertical: VisualDensity.maximumDensity,
        );
      case VisualDensityType.custom:
        return VisualDensity(
          horizontal: horizontal,
          vertical: vertical,
        );
    }
  }
}

extension VisualDensityTypeExt on VisualDensityType {
  VisualDensityModel get visualDensityModel {
    switch (this) {
      case VisualDensityType.standard:
        return VisualDensityModel.standard;
      case VisualDensityType.comfortable:
        return VisualDensityModel.comfortable;
      case VisualDensityType.compact:
        return VisualDensityModel.compact;
      case VisualDensityType.adaptivePlatformDensity:
        return VisualDensityModel(
          horizontal: VisualDensity.adaptivePlatformDensity.horizontal,
          vertical: VisualDensity.adaptivePlatformDensity.vertical,
          type: VisualDensityType.adaptivePlatformDensity,
        );
      case VisualDensityType.minimum:
        return const VisualDensityModel(
          horizontal: VisualDensity.minimumDensity,
          vertical: VisualDensity.minimumDensity,
          type: VisualDensityType.minimum,
        );
      case VisualDensityType.maximum:
        return const VisualDensityModel(
          horizontal: VisualDensity.maximumDensity,
          vertical: VisualDensity.maximumDensity,
          type: VisualDensityType.maximum,
        );
      case VisualDensityType.custom:
    }
    throw Exception("Visual density type custom can't be converted");
  }

  VisualDensity get visualDensity => visualDensityModel.flutterVisualDensity;
}

extension StringExt on String {
  String get capitalized => characters.isEmpty
      ? this
      : characters.first.toUpperCase() +
          characters.skip(1).string.toLowerCase();

  /// Whether the string contains all the valid variable paths inside it.
  /// This will also evaluate the path inside the ${} to be valid.
  bool get isValidVariablePath => variablePathRegex.hasMatch(this);

  /// Whether the string contains a variable path that is not checked for
  /// validity. This will only check for ${...} and not the path inside.
  bool get containsUncheckedVariablePath =>
      variableSyntaxIdentifierRegex.hasMatch(this);

  String get camelToSentenceCase {
    // Split camel case string into words.
    final String splitWords = replaceAll(RegExp(r'(?<!^)(?=[A-Z])'), r' ');
    // Capitalize first character.
    final String capitalized =
        splitWords[0].toUpperCase() + splitWords.substring(1);
    return capitalized;
  }

  String wrapWithVariableSyntax() {
    if (variableSyntaxIdentifierRegex.hasMatch(this)) {
      return this;
    }
    return '\${$this}';
  }

  /// [String.splitMapJoin] is limited to [Pattern] which can only do [Match]
  /// and not [RegExpMatch]. Because of this, you can't access named groups
  /// inside the pattern. This function fixes that.
  /// Ref: https://github.com/dart-lang/sdk/issues/52721
  String splitMapJoinRegex(
    RegExp pattern, {
    String Function(RegExpMatch match)? onMatch,
    String Function(String text)? onNonMatch,
  }) {
    return splitMapJoin(
      pattern,
      onMatch: onMatch != null
          ? (match) {
              match as RegExpMatch;
              return onMatch(match);
            }
          : null,
      onNonMatch: onNonMatch != null
          ? (text) {
              return onNonMatch(text);
            }
          : null,
    );
  }

  Iterable<R> splitMap<R>(
    RegExp pattern, {
    R Function(RegExpMatch match)? onMatch,
    R Function(String text)? onNonMatch,
  }) {
    List<R> result = [];
    splitMapJoinRegex(
      pattern,
      onMatch: onMatch != null
          ? (match) {
              result.add(onMatch(match));
              return match[0]!;
            }
          : null,
      onNonMatch: onNonMatch != null
          ? (text) {
              result.add(onNonMatch(text));
              return text;
            }
          : null,
    );
    return result;
  }

  bool get isSvgUrl {
    final uri = Uri.tryParse(this);
    if (uri == null) return false;
    return path.extension(uri.path).contains('svg');
  }

  bool get isBase64Blob {
    final uri = Uri.tryParse(this);
    if (uri == null) return false;
    return uri.scheme == 'data' && uri.path.contains('base64');
  }

  // Assumes [isBase64Blob] is true. Decodes the base64 data and returns it.
  // data:image/gif;base64,<BASE64 CODE>
  Uint8List get base64Data {
    return base64Decode(split(',')[1]);
  }

  String toJsonPointerPath() {
    final tokens = split(RegExp('[[.]'));
    final formatted = tokens.map((e) => e.replaceAll(']', '')).join('/');
    return '/$formatted';
  }
}

/// Can match:
///   1. [https://youtu.be/<video_id>]
///   2. [https://www.youtube.com/embed/<video_id>]
///   3. [https://youtube.com/embed/<video_id>]
RegExp youtubeShareUrlRegex = RegExp(
    'https://(www.)?(youtu.be|((youtube.com)(?:/embed)))/(?<video_id>[a-zA-Z_0-9]+)');

/// Can match: [https://www.youtube.com/watch?v=<video_id>]
RegExp youtubeWatchUrlRegex = RegExp(
    '^https://(www.)?(youtube.com/watch)?.*v=(?<video_id>[a-zA-Z_0-9]+)');

RegExp vimeoUrlRegex = RegExp('^https://vimeo.com/(?<video_id>[a-zA-Z0-9]+)');

extension EmbeddedVideoPropertiesExt on EmbeddedVideoProperties {
  bool get hasMetadata {
    switch (source) {
      case EmbeddedVideoSource.youtube:
        return forYoutube.metadata != null;
      case EmbeddedVideoSource.vimeo:
        return forVimeo.metadata != null;
    }
  }
}

/// Returns empty string if the url is not a valid youtube video url.
String extractYoutubeVideoId(String? url) {
  if (url == null || url.trim().isEmpty) return '';
  return youtubeShareUrlRegex.firstMatch(url)?.namedGroup('video_id') ??
      youtubeWatchUrlRegex.firstMatch(url)?.namedGroup('video_id') ??
      '';
}

/// Returns empty string if the url is not a valid vimeo video url.
String extractVimeoVideoId(String? url) {
  if (url == null || url.trim().isEmpty) return '';
  return vimeoUrlRegex.firstMatch(url)?.namedGroup('video_id') ?? '';
}

const kEpsilon = 1.0e-8;

extension FloatHelper on double {
  bool closeTo(double other, [double precision = kEpsilon]) {
    return (this - other).abs() <= precision;
  }
}

extension ImageRepeatEnumExt on ImageRepeatEnum {
  ImageRepeat get flutterImageRepeat {
    switch (this) {
      case ImageRepeatEnum.noRepeat:
        return ImageRepeat.noRepeat;
      case ImageRepeatEnum.repeat:
        return ImageRepeat.repeat;
      case ImageRepeatEnum.repeatX:
        return ImageRepeat.repeatX;
      case ImageRepeatEnum.repeatY:
        return ImageRepeat.repeatY;
    }
  }
}

extension BuildContextExt on BuildContext {
  ValueNotifier<List<ValueModel>> nodeListenableValues(String nodeId) {
    return read<CodelesslyContext>().nodeValues[nodeId]!;
  }

  List<ValueModel> nodeValues(String nodeId) {
    return read<CodelesslyContext>().nodeValues[nodeId]?.value ?? [];
  }

  T? getNodeValueModel<T extends ValueModel>(String nodeId, String key) {
    return nodeValues(nodeId).firstWhereOrNull((value) => value.name == key)
        as T?;
  }

  T? getNodeValue<T>(String nodeId, String key) {
    return nodeValues(nodeId)
        .firstWhereOrNull((value) => value.name == key)
        ?.value as T?;
  }
}

extension PaintIterableExt on Iterable<PaintModel> {
  List<PaintModel> visible() => where((e) => e.visible).toList();
}

extension EffectIterableExt on Iterable<Effect> {
  List<Effect> visible() => where((e) => e.visible).toList();
}

extension ReactionIterableExt on Iterable<Reaction> {
  bool hasTriggerType(TriggerType type) => any((e) => e.trigger.type == type);

  Iterable<Reaction> whereTriggerType(TriggerType type) =>
      where((e) => e.trigger.type == type);
}

extension ActionModelExt on ActionModel {
  bool hasProperty(String nodeId, String name) {
    final action = this;
    if (action is SetValueAction && action.nodeID == nodeId) {
      return action.values.any((element) => element.name == name);
    }
    if (action is SetVariantAction &&
        (name == 'variant' || name == 'currentVariantId')) {
      return action.nodeID == nodeId;
    }

    return false;
  }

  bool hasNode(String nodeId) {
    final action = this;
    if (action is SetValueAction && action.nodeID == nodeId) {
      return true;
    }
    if (action is SetVariantAction) {
      return action.nodeID == nodeId;
    }

    return false;
  }

  ActionModel withUpdatedNodeId(String oldNodeId, String newNodeId) {
    final action = this;
    if (action is SetValueAction && action.nodeID == oldNodeId) {
      return action.copyWith(nodeID: newNodeId);
    }
    if (action is SetVariantAction && action.nodeID == oldNodeId) {
      return action.copyWith(nodeID: newNodeId);
    }
    return action;
  }
}

extension BaseConditionExt on BaseCondition {
  bool hasProperty(String nodeId, String name) {
    final condition = this;
    if (condition is Condition) {
      final condition = this as Condition;
      return condition.actions
          .any((action) => action.hasProperty(nodeId, name));
    }
    if (condition is ConditionGroup) {
      return condition.ifCondition.hasProperty(nodeId, name) ||
          condition.elseCondition?.hasProperty(nodeId, name) == true ||
          condition.elseIfConditions
              .any((condition) => condition.hasProperty(nodeId, name));
    }
    if (condition is ElseCondition) {
      return condition.actions
          .any((action) => action.hasProperty(nodeId, name));
    }
    return false;
  }

  bool hasNode(String nodeId) {
    final condition = this;
    if (condition is Condition) {
      final condition = this as Condition;
      return condition.actions.any((action) => action.hasNode(nodeId));
    }
    if (condition is ConditionGroup) {
      return condition.ifCondition.hasNode(nodeId) ||
          condition.elseCondition?.hasNode(nodeId) == true ||
          condition.elseIfConditions
              .any((condition) => condition.hasNode(nodeId));
    }
    if (condition is ElseCondition) {
      return condition.actions.any((action) => action.hasNode(nodeId));
    }
    return false;
  }

  /// Returns all the variables names used in this condition. This includes the
  /// predefined variables as well. Returns names of the variables.
  Set<String> getVariables() =>
      accept<Set<String>>(const ConditionVariablesVisitor()) ?? {};

  /// Returns all the variables used in this condition except the predefined
  /// variables. Returns names of the variables.
  Set<String> getReactiveVariables() =>
      accept<Set<String>>(ConditionVariablesVisitor(
          excludedVariableNames: {...predefinedVariableNames}
            ..removeAll(predefinedListenableVariableNames))) ??
      {};

  /// [variables] is a map of variable name to variable value.
  R? evaluate<R extends Object>(ScopedValues scopedValues) => accept<R>(
        ConditionEvaluator<R>(scopedValues: scopedValues),
      );

  void prettyPrint() => ConditionPrinter().printCondition(this);

  Set<String> getNodeIds() =>
      accept<Set<String>>(const ConditionNodesVisitor()) ?? {};

  BaseCondition withUpdatedNodeId(String oldNodeId, String newNodeId) {
    final condition = this;
    return switch (condition) {
      ElseCondition() => condition.copyWith(
          actions: condition.actions
              .map((action) => action.withUpdatedNodeId(oldNodeId, newNodeId))
              .toList()),
      Condition() => condition.copyWith(
          actions: condition.actions
              .map((action) => action.withUpdatedNodeId(oldNodeId, newNodeId))
              .toList()),
      ConditionGroup() => condition.copyWith(
          elseCondition: condition.elseCondition?.withUpdatedNodeId(
            oldNodeId,
            newNodeId,
          ) as ElseCondition?,
          elseIfConditions: condition.elseIfConditions
              .map((condition) => condition.withUpdatedNodeId(
                    oldNodeId,
                    newNodeId,
                  ) as Condition)
              .toList(),
          ifCondition: condition.ifCondition.withUpdatedNodeId(
            oldNodeId,
            newNodeId,
          ) as Condition,
        ),
    };
  }
}

extension CanvasConditionsMapExt on Map<String, CanvasConditions> {
  bool hasCondition(String nodeId, String name) {
    return values.any((condition) => condition.hasCondition(nodeId, name));
  }

  BaseCondition? findByNodeProperty(String nodeId, String property) => values
      .expand((element) => element.conditions.values)
      .firstWhereOrNull((condition) => condition.hasProperty(nodeId, property));

  BaseCondition? findByNode(String nodeId) => values
      .expand((element) => element.conditions.values)
      .firstWhereOrNull((condition) => condition.hasNode(nodeId));

  Iterable<BaseCondition> findAllByNode(String nodeId) {
    return values
        .expand((element) => element.conditions.values)
        .where((condition) => condition.hasNode(nodeId));
  }
}

extension ConditionsMapExt on Map<String, BaseCondition> {
  bool hasCondition(String nodeId, String name) {
    return values.any((condition) => condition.hasProperty(nodeId, name));
  }

  BaseCondition? findByNodeProperty(String nodeId, String property) => values
      .firstWhereOrNull((condition) => condition.hasProperty(nodeId, property));

  BaseCondition? findByNode(String nodeId) =>
      values.firstWhereOrNull((condition) => condition.hasNode(nodeId));

  Iterable<BaseCondition> findAllByNode(String nodeId) {
    return values.where((condition) => condition.hasNode(nodeId));
  }

  Iterable<BaseCondition> findAllForNodes(Iterable<BaseNode> nodes) =>
      nodes.expand((node) => findAllByNode(node.id));

  Iterable<BaseCondition> findAllForNodeIds(Iterable<String> nodeIds) =>
      nodeIds.expand(findAllByNode);
}

extension CanvasConditionsExt on CanvasConditions {
  bool hasCondition(String nodeId, String name) {
    return conditions.values
        .any((condition) => condition.hasProperty(nodeId, name));
  }
}

extension ExpressionExt on BaseExpression {
  /// [variables] is a map of variable names and their values.
  bool evaluate(ScopedValues scopedValues) =>
      accept<bool>(ConditionEvaluator<bool>(scopedValues: scopedValues))!;
}

extension ExpressionPartExt on ExpressionPart {
  /// [variables] is a map of variable name and its value.
  dynamic evaluate(ScopedValues scopedValues) =>
      accept(ConditionEvaluator(scopedValues: scopedValues));
}

extension VariantIterable on Iterable<Variant> {
  Variant? findByName(String? name) =>
      firstWhereOrNull((variant) => variant.name == name);

  Variant? findById(String? id) =>
      firstWhereOrNull((variant) => variant.id == id);
}

extension IterableExt<V> on Iterable<V> {
  Map<K, V> mapBy<K>(K Function(V) key) => <K, V>{
        for (final value in this) key(value): value,
      };
}

extension TabBarIndicatorSizeExtensions on TabBarIndicatorSizeEnum {
  TabBarIndicatorSize toFlutter() {
    return switch (this) {
      TabBarIndicatorSizeEnum.label => TabBarIndicatorSize.label,
      TabBarIndicatorSizeEnum.tab => TabBarIndicatorSize.tab,
    };
  }
}

extension TextAlignVerticalEnumExt on TextAlignVerticalEnum {
  TextAlignVertical get flutterTextAlignVertical {
    return switch (this) {
      TextAlignVerticalEnum.top => TextAlignVertical.top,
      TextAlignVerticalEnum.bottom => TextAlignVertical.bottom,
      TextAlignVerticalEnum.center => TextAlignVertical.center,
    };
  }
}

extension BaseNodeExt on BaseNode {
  /// Collects all the variable names used in this node.
  Set<String> getUsedVariableNames({bool includePredefined = false}) {
    final Set<String> usedVariables = {};
    for (final path in variables.values) {
      final match = VariableMatch.parse(path.wrapWithVariableSyntax());
      if (match == null) continue;

      final bool isPredefined = predefinedVariableNames.contains(match.name);
      if (!includePredefined && isPredefined) continue;

      usedVariables.add(match.name);
    }
    for (final paths in multipleVariables.values) {
      for (final path in paths) {
        final match = VariableMatch.parse(path.wrapWithVariableSyntax());
        if (match == null) continue;

        final bool isPredefined = predefinedVariableNames.contains(match.name);
        if (!includePredefined && isPredefined) continue;

        usedVariables.add(match.name);
      }
    }
    return usedVariables;
  }
}

extension StrokeCapEnumExt on StrokeCapEnum {
  StrokeCap get flutterStrokeCap => switch (this) {
        StrokeCapEnum.round => StrokeCap.round,
        StrokeCapEnum.butt => StrokeCap.butt,
        StrokeCapEnum.square => StrokeCap.square,
      };
}

extension BlendModeCExt on BlendModeC {
  BlendMode get flutterBlendMode => switch (this) {
        BlendModeC.src => BlendMode.src,
        BlendModeC.srcOver => BlendMode.srcOver,
        BlendModeC.srcATop => BlendMode.srcATop,
        BlendModeC.srcIn => BlendMode.srcIn,
        BlendModeC.srcOut => BlendMode.srcOut,
        BlendModeC.dst => BlendMode.dst,
        BlendModeC.dstOver => BlendMode.dstOver,
        BlendModeC.dstIn => BlendMode.dstIn,
        BlendModeC.dstOut => BlendMode.dstOut,
        BlendModeC.dstATop => BlendMode.dstATop,
        BlendModeC.clear => BlendMode.clear,
        BlendModeC.multiply => BlendMode.multiply,
        BlendModeC.screen => BlendMode.screen,
        BlendModeC.overlay => BlendMode.overlay,
        BlendModeC.darken => BlendMode.darken,
        BlendModeC.lighten => BlendMode.lighten,
        BlendModeC.colorDodge => BlendMode.colorDodge,
        BlendModeC.colorBurn => BlendMode.colorBurn,
        BlendModeC.hardLight => BlendMode.hardLight,
        BlendModeC.softLight => BlendMode.softLight,
        BlendModeC.difference => BlendMode.difference,
        BlendModeC.exclusion => BlendMode.exclusion,
        BlendModeC.hue => BlendMode.hue,
        BlendModeC.saturation => BlendMode.saturation,
        BlendModeC.color => BlendMode.color,
        BlendModeC.luminosity => BlendMode.luminosity,
        BlendModeC.xor => BlendMode.xor,
        BlendModeC.plus => BlendMode.plus,
        BlendModeC.modulate => BlendMode.modulate,
      };
}
