import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/services.dart';

import 'property_value_delegate.dart';
import 'scoped_values.dart';

/// Whether [trigger]'s [TriggerModel.when] holds in [scopedValues]: true when
/// it has none, else when it gives `true` (or the text `true`).
bool triggerWhenHolds(TriggerModel trigger, ScopedValues scopedValues) {
  final String? when = trigger.when;
  if (when == null || when.trim().isEmpty) return true;
  final Object? value = PropertyValueDelegate.substituteJsonValue(
    when.trim(),
    scopedValues,
  );
  return switch (value) {
    bool b => b,
    String s => s.trim().toLowerCase() == 'true',
    _ => false,
  };
}

/// Whether a Key Down [trigger] is for [key] pressed with the modifiers
/// [keyboard] holds: its [TriggerModel.key] combination matches (see
/// [KeyCombo.matches]), or it has no key and listens for every key. A key
/// that doesn't read as a combination matches nothing.
bool keyTriggerMatches(
  TriggerModel trigger,
  LogicalKeyboardKey key, [
  HardwareKeyboard? keyboard,
]) {
  final KeyCombo? combo = trigger.keyCombo;
  if (combo == null) return trigger.key?.trim().isEmpty ?? true;
  final HardwareKeyboard pressed = keyboard ?? HardwareKeyboard.instance;
  return combo.matches(
    keyTriggerLabel(key),
    meta: pressed.isMetaPressed || pressed.isControlPressed,
    shift: pressed.isShiftPressed,
    alt: pressed.isAltPressed,
  );
}

/// What a Key Down trigger's `${result}` holds about the key: `key` (see
/// [keyTriggerLabel]), `shift`, `alt` and `meta` (Command or Control).
Map<String, Object> keyTriggerResult(
  LogicalKeyboardKey key, [
  HardwareKeyboard? keyboard,
]) {
  final HardwareKeyboard pressed = keyboard ?? HardwareKeyboard.instance;
  return {
    'key': keyTriggerLabel(key),
    'shift': pressed.isShiftPressed,
    'alt': pressed.isAltPressed,
    'meta': pressed.isMetaPressed || pressed.isControlPressed,
  };
}

/// Whether [key] is a modifier (Shift, Control, Alt, Meta, Caps Lock, Fn):
/// pressed alone it is part of the next key's combination.
bool isModifierKey(LogicalKeyboardKey key) => _modifierKeys.contains(key);

final Set<LogicalKeyboardKey> _modifierKeys = {
  LogicalKeyboardKey.shift,
  LogicalKeyboardKey.shiftLeft,
  LogicalKeyboardKey.shiftRight,
  LogicalKeyboardKey.control,
  LogicalKeyboardKey.controlLeft,
  LogicalKeyboardKey.controlRight,
  LogicalKeyboardKey.alt,
  LogicalKeyboardKey.altLeft,
  LogicalKeyboardKey.altRight,
  LogicalKeyboardKey.meta,
  LogicalKeyboardKey.metaLeft,
  LogicalKeyboardKey.metaRight,
  LogicalKeyboardKey.capsLock,
  LogicalKeyboardKey.fn,
};

/// A key label in the form key press triggers compare: lower case, without
/// spaces, so `Arrow Right`, `ArrowRight` and `arrowright` all match.
String normalizeKeyLabel(String label) =>
    label.replaceAll(' ', '').toLowerCase();

/// The label a "Key Down" trigger's `${result.key}` reads for [key]: the
/// character of a character key (`a`, `1`, `/`), else the key's name
/// without spaces (`ArrowLeft`, `Delete`, `Escape`, `Enter`, `Space`).
String keyTriggerLabel(LogicalKeyboardKey key) {
  if (key == LogicalKeyboardKey.space) return 'Space';
  final String label = key.keyLabel;
  if (label.length == 1) return label.toLowerCase();
  return label.replaceAll(' ', '');
}
