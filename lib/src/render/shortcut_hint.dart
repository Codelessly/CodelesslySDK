import 'package:codelessly_api/core.dart' show KeyCombo;
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;

/// The visible and spoken key hint for a document shortcut. The same text is
/// rendered on a desktop, a phone, and in either theme.
String shortcutHint(String source, {TargetPlatform? platform}) {
  final combo = KeyCombo.tryParse(source);
  if (combo == null) return source;
  final apple = (platform ?? defaultTargetPlatform) == TargetPlatform.macOS ||
      (platform ?? defaultTargetPlatform) == TargetPlatform.iOS;
  final key = switch (combo.key) {
    'escape' => 'Esc',
    'enter' => apple ? '↵' : 'Enter',
    'space' => 'Space',
    'arrowup' => '↑',
    'arrowdown' => '↓',
    'arrowleft' => '←',
    'arrowright' => '→',
    final k when k.length == 1 => k.toUpperCase(),
    final k => k[0].toUpperCase() + k.substring(1),
  };
  if (apple) return '${combo.meta ? '⌘' : ''}${combo.alt ? '⌥' : ''}${combo.shift ? '⇧' : ''}$key';
  return [if (combo.meta) 'Ctrl', if (combo.alt) 'Alt', if (combo.shift) 'Shift', key].join(' ');
}
