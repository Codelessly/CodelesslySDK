import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../codelessly_sdk.dart';

/// The item properties whose binding (a variable or a condition) can change
/// how much room an item takes along a list's scroll axis.
const Set<String> kItemExtentProperties = {
  'visible',
  'width',
  'height',
  'margin',
  'padding',
  'horizontalFit',
  'verticalFit',
  'constraints',
};

/// The extent every item of [list] takes along its scroll axis, or null when
/// items may take different extents and the list must measure them.
///
/// It is the list's own `itemExtent` when set. Otherwise, when the item
/// template [item] has a fixed, locked, expanded or flexible size along the
/// scroll axis (expanded and flexible items take their design extent in a
/// list, see `ListItemBox`) and nothing binds that size or the item's
/// visibility, every item is as long as the template's outer box. Handing
/// that to Flutter's list lets it place item 9,000 without building the
/// items before it, so long lists scroll and jump in constant time.
///
/// [layoutChanges] is true when something else changes item extents (a
/// drop slot that opens inside an item, or overlapping items), and then only
/// an explicit `itemExtent` is used.
double? listItemExtent(
  BuildContext context,
  ListViewNode list,
  BaseNode item, {
  bool layoutChanges = false,
}) {
  final double? explicit = list.properties.itemExtent;
  if (explicit != null) return explicit;
  if (layoutChanges) return null;
  if (list.properties.stacked ||
      list.properties.wrap ||
      list.properties.layout != ListLayout.list) {
    return null;
  }
  if (!item.visible) return null;
  final bool vertical = list.scrollDirection == AxisC.vertical;
  final SizeFit fit = vertical ? item.verticalFit : item.horizontalFit;
  if (fit == SizeFit.shrinkWrap) return null;
  if (_bindsExtent(context, item)) return null;
  final double extent = vertical
      ? item.outerBoxLocal.height
      : item.outerBoxLocal.width;
  if (!extent.isFinite || extent <= 0) return null;
  return extent;
}

bool _bindsExtent(BuildContext context, BaseNode item) {
  for (final String key in item.variables.keys) {
    if (kItemExtentProperties.contains(key)) return true;
  }
  for (final String key in item.multipleVariables.keys) {
    if (kItemExtentProperties.contains(key)) return true;
  }
  final CodelesslyContext? codelessly = context.read<CodelesslyContext?>();
  if (codelessly == null) return false;
  for (final String property in kItemExtentProperties) {
    if (codelessly.conditions.findByNodeProperty(item.id, property) != null) {
      return true;
    }
  }
  return false;
}
