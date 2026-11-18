import 'package:codelessly_api/core.dart' show KeyCombo;

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
      shift != combo.shift) {
    return false;
  }
  return combo.matches(label == ' ' ? 'Space' : label, meta: meta, shift: shift, alt: alt);
}

/// Whether [character] (the text a key event types) is printable: a key
/// that types it belongs to a focused text field, not to a shortcut.
bool typesText(String? character) =>
    character != null && character.isNotEmpty && character.runes.every((r) => r >= 0x20 && r != 0x7F);

/// [runtimeKeyMatches] by the key's label, or by the [character] it types
/// (`?` is Shift+/ on a US keyboard: a combo of `?` matches it).
bool runtimeKeyEventMatches(
  KeyCombo? combo,
  String label, {
  String? character,
  bool meta = false,
  bool shift = false,
  bool alt = false,
}) {
  // A one-character combo names the character typed: `?` and not `/` when
  // Shift+/ types `?`. A letter is its own key with Shift or without: `j`
  // is not Shift+J (which `shift+j` names), whatever Caps Lock types.
  if (combo != null && combo.key.length == 1 && !meta && !alt && !combo.meta && !combo.alt && typesText(character)) {
    final typed = KeyCombo.normalizeKey(character!);
    if (RegExp(r'^[a-z]$').hasMatch(combo.key)) return typed == combo.key && shift == combo.shift;
    return typed == combo.key;
  }
  return runtimeKeyMatches(combo, label, meta: meta, shift: shift, alt: alt);
}
