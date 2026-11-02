import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/widgets.dart';

import '../../functions/action_chain.dart';

/// A text field on screen that an [EditTextAction] can edit.
abstract interface class EditableTextField {
  /// The field's context.
  BuildContext get context;

  /// When the field last had focus, as a [TextFieldRegistry.tick]; 0 if it
  /// never had.
  int get lastFocused;

  /// The route the field shows in, if any.
  ModalRoute<Object?>? get route;

  /// Applies [operation] with its inputs (variables already substituted) at
  /// the field's cursor. Returns whether the field could be edited.
  bool editText(
    EditTextOperation operation, {
    String text,
    String before,
    String? after,
    bool numbered,
  });
}

/// The text fields on screen by node id, so an [EditTextAction] finds the
/// field it names. Fields register while they are mounted and running (not
/// on a design canvas).
abstract final class TextFieldRegistry {
  static final Map<String, List<EditableTextField>> _fields = {};
  static int _clock = 0;

  /// A number larger than every one given before: an order of events.
  static int tick() => ++_clock;

  /// Adds [field], the text field of node [nodeId].
  static void register(String nodeId, EditableTextField field) {
    final List<EditableTextField> fields = _fields[nodeId] ??= [];
    if (!fields.contains(field)) fields.add(field);
  }

  /// Removes [field] of node [nodeId].
  static void unregister(String nodeId, EditableTextField field) {
    final List<EditableTextField>? fields = _fields[nodeId];
    if (fields == null) return;
    fields.remove(field);
    if (fields.isEmpty) _fields.remove(nodeId);
  }

  /// The text field of node [nodeId] an action running in [context] means.
  /// When the node shows more than once (a field in each list row, a screen
  /// under a dialog, a layout embedded twice), the one in the same layout as
  /// [context] wins, then one on the route on top, then the one focused
  /// last.
  static EditableTextField? find(BuildContext context, String nodeId) {
    final List<EditableTextField> fields = [
      for (final EditableTextField field in _fields[nodeId] ?? const [])
        if (field.context.mounted) field,
    ];
    if (fields.length <= 1) return fields.firstOrNull;
    final BuildContext? host = context.mounted
        ? ActionChainHost.maybeOf(context)
        : null;
    int score(EditableTextField field) =>
        (host != null && ActionChainHost.maybeOf(field.context) == host
            ? 4
            : 0) +
        (field.route?.isCurrent ?? true ? 2 : 0);
    EditableTextField best = fields.first;
    for (final EditableTextField field in fields.skip(1)) {
      final int a = score(field), b = score(best);
      if (a > b || (a == b && field.lastFocused >= best.lastFocused)) {
        best = field;
      }
    }
    return best;
  }
}
