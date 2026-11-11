import 'package:codelessly_api_v2/codelessly_api.dart' show KeyCombo;

/// Modified letter shortcuts distinguish Mod+Z from Mod+Shift+Z. Printable
/// punctuation may still require Shift to type its character (for example ?).
bool runtimeKeyMatches(
  KeyCombo? combo,
  String label, {
  bool meta = false,
  bool shift = false,
  bool alt = false,
}) {
  if (combo == null) return true;
  if ((meta || alt) &&
      RegExp(r'^[a-z0-9]$').hasMatch(combo.key) &&
      shift != combo.shift)
    return false;
  return combo.matches(
    label == ' ' ? 'Space' : label,
    meta: meta,
    shift: shift,
    alt: alt,
  );
}
