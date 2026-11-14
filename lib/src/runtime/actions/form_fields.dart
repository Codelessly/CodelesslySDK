// The validating fields a tree shows, and the forms they belong to:
// Flutter's FormFieldState and FormState as data. A text field with a
// validator registers here while it lives; a node with a `form` behavior is
// a Form around the fields inside it. The `validate` action
// (FormState.validate()) checks a form's fields, and each form publishes
// `form` ({valid, errors}) to the nodes inside it.
import 'package:codelessly_api/codelessly_api.dart' show AutovalidateMode;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart' show FocusNode;

import '../../render/node_tree.dart';
import '../../render/recipe.dart';
import '../../render/source.dart';

/// One validating field: Flutter's `FormFieldState`.
class FormFieldEntry {
  FormFieldEntry({required this.box, required this.focusNode, required this.check, required this.show, required this.label});

  /// The field's node box.
  final NodeBuilder box;
  final FocusNode focusNode;

  /// The validator's message for the field's value now; null when valid.
  final String? Function() check;

  /// Shows [error] under the field (null: none), as `FormFieldState.validate`
  /// does.
  final void Function(String? error) show;

  /// What a summary calls the field (its label, else its id).
  final String Function() label;

  /// The error the field shows now.
  String? shown;
}

/// The validating fields of one tree.
class FormRegistry {
  FormRegistry._(this.tree);

  final RenderTree tree;
  static final Expando<FormRegistry> _of = Expando('FormRegistry');

  /// The registry of [tree].
  static FormRegistry of(RenderTree tree) => _of[tree] ??= FormRegistry._(tree);

  final Map<NodeBuilder, FormFieldEntry> _fields = {};

  void register(FormFieldEntry entry) {
    _fields[entry.box] = entry;
    changed(entry.box);
  }

  void unregister(NodeBuilder box, FormFieldEntry entry) {
    if (!identical(_fields[box], entry)) return;
    _fields.remove(box);
    changed(box);
  }

  /// The id of the form node [id] is in (itself, or its nearest ancestor
  /// with a `form` behavior), or null.
  static String? formOf(NodeSource source, String id) {
    for (String? at = id; at != null; at = source.parentOf(at)) {
      if (source.node(at)?.behaviors.form != null) return at;
    }
    return null;
  }

  /// The form's own autovalidate mode for the field at [box].
  static AutovalidateMode formModeOf(NodeBuilder box) {
    final form = formOf(box.source, box.id);
    return form == null
        ? AutovalidateMode.disabled
        : box.source.node(form)?.behaviors.form?.autovalidateMode ?? AutovalidateMode.disabled;
  }

  /// The fields of form [form] (null: every field of the tree), in the order
  /// they show, top to bottom, then start to end.
  List<FormFieldEntry> fieldsOf(String? form) {
    final out = [
      for (final e in _fields.values)
        if (form == null || formOf(e.box.source, e.box.id) == form) e,
    ];
    Offset at(FormFieldEntry e) {
      if (e.box case final RenderBox box when box.attached) return box.localToGlobal(Offset.zero);
      return Offset.infinite;
    }

    out.sort((a, b) {
      final pa = at(a), pb = at(b);
      final dy = pa.dy.compareTo(pb.dy);
      return dy != 0 ? dy : pa.dx.compareTo(pb.dx);
    });
    return out;
  }

  /// Flutter's `FormState.validate()` on form [form] (null: every field):
  /// each field shows its validator's error, the first invalid one takes
  /// the focus when [focusFirstError]. Whether all are valid.
  bool validate(String? form, {bool focusFirstError = true}) {
    FormFieldEntry? first;
    for (final f in fieldsOf(form)) {
      final error = f.check();
      f.shown = error;
      f.show(error);
      if (error != null) first ??= f;
    }
    if (focusFirstError) first?.focusNode.requestFocus();
    if (form != null) _publishSoon(form);
    for (final f in _fields.values) {
      final own = formOf(f.box.source, f.box.id);
      if (own != null && own != form) _publishSoon(own);
    }
    return first == null;
  }

  /// A field at [box] changed its value or the error it shows: its form
  /// publishes `form` again (after the frame, never while building).
  void changed(NodeBuilder box) {
    final form = formOf(box.source, box.id);
    if (form != null) _publishSoon(form, source: box.source, instance: box.instance);
  }

  final Map<String, (NodeSource?, Object?)> _pending = {};

  void _publishSoon(String form, {NodeSource? source, Object? instance}) {
    final had = _pending.containsKey(form);
    final was = _pending[form];
    _pending[form] = (source ?? was?.$1, instance ?? was?.$2);
    if (had) return;
    void publish() {
      final p = _pending.remove(form);
      if (p == null) return;
      _publish(form, p.$1, p.$2);
    }

    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      publish();
    } else {
      SchedulerBinding.instance.addPostFrameCallback((_) => publish());
      SchedulerBinding.instance.ensureVisualUpdate();
    }
  }

  void _publish(String form, NodeSource? source, Object? instance) {
    final fields = fieldsOf(form);
    final src = source ?? (fields.isEmpty ? null : fields.first.box.source);
    if (src == null) return;
    tree.bindings?.publish(src, form, instance, 'form', {
      'valid': fields.every((f) => f.check() == null),
      'errors': [
        for (final f in fields)
          if (f.shown != null) {'field': f.box.id, 'label': f.label(), 'message': f.shown},
      ],
    });
  }
}
