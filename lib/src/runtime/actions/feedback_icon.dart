// The icon of a toast or a confirm dialog: an icon glyph's JSON (as icon
// nodes hold it), drawn [size] square.
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_api/codelessly_api.dart' show Json;
import 'package:flutter/widgets.dart';

import '../../render/paint/icon_glyph.dart';
import '../http_image_loader.dart';

/// Draws [icon] [size] square. A glyph takes its own color, else [color].
/// An image shows as is (a stamp, a colored check) unless the icon has a
/// visible color of its own to tint it with. Null when the icon shows
/// nothing.
Widget? feedbackIcon(Json icon, double size, Color color, {Key? key}) {
  if (icon['show'] == false || IconSources.urlOf(icon) == null) return null;
  final own = api.Color.fromJson(icon['color']);
  final isImage = icon['source'] == 'image';
  final Color tint;
  if (isImage) {
    tint = own != null && (own.value >> 24) > 0 ? Color(own.value) : const Color(0x00000000);
  } else {
    tint = own == null ? color : Color(own.value);
  }
  return SizedBox.square(
    key: key ?? (isImage ? const ValueKey('codelessly-toast-icon-image') : null),
    dimension: size,
    child: _IconGlyph(icon: icon, color: tint),
  );
}

class _IconGlyph extends LeafRenderObjectWidget {
  const _IconGlyph({required this.icon, required this.color});

  final Json icon;
  final Color color;

  @override
  RenderIconGlyph createRenderObject(BuildContext context) => RenderIconGlyph()
    // Outside a tree with a loader of its own, its SVG is fetched as the SDK does.
    ..imageLoader = const HttpImageLoader()
    ..icon = icon
    ..color = color;

  @override
  void updateRenderObject(BuildContext context, RenderIconGlyph renderObject) => renderObject
    ..icon = icon
    ..color = color;
}
