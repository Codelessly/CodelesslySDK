// Icons chosen by name at runtime (a toast's or a dialog's `icon` binding):
// SDK 8.x's `iconWithName`.
import 'package:codelessly_api_v2/codelessly_api.dart' show Json;

import 'material_icon_versions.dart';

/// [base] (an icon's JSON) showing Material icon [name] (`check_circle`,
/// `info_outlined`): a bare name keeps [base]'s style (an outlined icon
/// stays outlined), a suffix (`_outlined`, `_rounded`, `_sharp`) sets it.
/// [base] itself when [name] isn't an icon name.
Json iconWithName(Json base, String? name) {
  final key = (name ?? '').trim().toLowerCase();
  if (!RegExp(r'^[a-z0-9_]+$').hasMatch(key)) return base;
  var style = base['type'] == 'MATERIAL_ICON' && base['style'] is String ? base['style'] as String : 'filled';
  var iconName = key;
  for (final (suffix, suffixStyle) in const [('_outlined', 'outlined'), ('_rounded', 'rounded'), ('_sharp', 'sharp')]) {
    if (key.endsWith(suffix)) {
      style = suffixStyle;
      iconName = key.substring(0, key.length - suffix.length);
      break;
    }
  }
  return {
    for (final e in base.entries)
      if (!const {'image', 'codepoint', 'fontFamily', 'name', 'style', 'version', 'type', 'source', 'show'}.contains(e.key))
        e.key: e.value,
    'source': 'icon',
    'type': 'MATERIAL_ICON',
    'codepoint': 0,
    'name': iconName,
    'style': style,
    // The icon's SVG is served from the version the icon was added in.
    'version': materialIconVersions[iconName] ?? 1,
  };
}
