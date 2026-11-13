// Whether a list view can be measured: a list that lays every item out (a
// Flex or a Wrap) has intrinsic sizes; one that builds its items as they
// scroll into view (a viewport) doesn't.
import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_api/core.dart' show CollectionScrollProps, ListViewProps, Node, SizeFit;

/// The list flows its items onto runs (a Wrap); only a plain list layout does.
bool listWraps(Node n) => n.prop(ListViewProps.wrap) && n.prop(ListViewProps.layout) == api.ListLayout.list;

/// Whether the list lays every item out in a Flex (or
/// a Wrap) rather than a viewport, so it can be measured.
bool listBuildsAllItems(Node n) {
  if (listWraps(n)) return true;
  final vertical = n.prop(CollectionScrollProps.scrollDirection) == api.Axis.vertical;
  final mainFit = vertical ? n.layout.height.fit : n.layout.width.fit;
  final crossFit = vertical ? n.layout.width.fit : n.layout.height.fit;
  final stretchesHuggedCross =
      n.prop(ListViewProps.stretchItems) &&
      n.prop(ListViewProps.layout) == api.ListLayout.list &&
      crossFit == SizeFit.hug;
  // Its set count (bound data is a runtime matter); endless when null.
  final knownCount = n.prop(CollectionScrollProps.itemCount) != null;
  return !n.prop(ListViewProps.scrollable) && (mainFit == SizeFit.hug || stretchesHuggedCross) && knownCount;
}
