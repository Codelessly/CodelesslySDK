// The validating fields a tree shows, and the forms they belong to:
// Flutter's FormFieldState and FormState as data. A text field with a
// validator registers here while it lives; a node with a `form` behavior is
// a Form around the fields inside it. The `validate` action
// (FormState.validate()) checks a form's fields, and each form publishes
// `form` ({valid, errors}) to the nodes inside it.
import 'package:codelessly_api/core.dart' show AutovalidateMode;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../../render/controls/focus.dart' show ControlFocusNode;
import '../../render/node_tree.dart';
import '../../render/recipe.dart';
import '../../render/source.dart';
import '../expressions/bindings.dart' show ProvidedItem;

/// One validating field: Flutter's `FormFieldState`.
class FormFieldEntry {
  FormFieldEntry({required this.box, required this.focusNode, required this.check, required this.show, required this.label});

  /// The field's node box.
  final NodeBuilder box;
  final ControlFocusNode focusNode;

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

  /// The instance form [form] is shown in, for a node shown in [instance]
  /// inside it: the items of a list inside the form (or of the form itself,
  /// when it is the list) are the form's, as a Form's fields are however
  /// deep its builders put them; a form a list repeats is its item's.
  static Object? formInstanceOf(NodeSource source, String form, Object? instance) {
    bool inside(String id) {
      for (String? at = id; at != null; at = source.parentOf(at)) {
        if (at == form) return true;
      }
      return false;
    }

    var at = instance;
    while (at is ProvidedItem && inside(at.owner)) {
      at = at.outer;
    }
    return at;
  }

  /// The form instance (form id, instance) the field at [box] belongs to.
  static (String, Object?)? _formOfBox(NodeBuilder box) {
    final form = formOf(box.source, box.id);
    return form == null ? null : (form, formInstanceOf(box.source, form, box.instance));
  }

  /// The form's own autovalidate mode for the field at [box].
  static AutovalidateMode formModeOf(NodeBuilder box) {
    final form = formOf(box.source, box.id);
    return form == null
        ? AutovalidateMode.disabled
        : box.source.node(form)?.behaviors.form?.autovalidateMode ?? AutovalidateMode.disabled;
  }

  /// The fields of form [form] (null: every field of the tree) shown in
  /// [instance] ([anyInstance]: every instance of the form), in the order
  /// they show, top to bottom, then start to end.
  List<FormFieldEntry> fieldsOf(String? form, {Object? instance = anyInstance}) {
    final out = [
      for (final e in _fields.values)
        if (form == null ||
            (formOf(e.box.source, e.box.id) == form &&
                (identical(instance, anyInstance) || formInstanceOf(e.box.source, form, e.box.instance) == instance)))
          e,
    ];
    Offset at(FormFieldEntry e) {
      // A field hidden by a condition can still be attached while its
      // parents no longer lead to the view: it has no place, and sorts last.
      if (e.box case final RenderBox box when box.attached && box.hasSize && _inView(box)) return box.localToGlobal(Offset.zero);
      return Offset.infinite;
    }

    out.sort((a, b) {
      final pa = at(a), pb = at(b);
      final dy = pa.dy.compareTo(pb.dy);
      return dy != 0 ? dy : pa.dx.compareTo(pb.dx);
    });
    return out;
  }

  /// Whether [box]'s parents lead to the root of its pipeline.
  static bool _inView(RenderObject box) {
    final root = box.owner?.rootNode;
    for (RenderObject? p = box; p != null; p = p.parent) {
      if (identical(p, root)) return true;
    }
    return false;
  }

  /// Stands for every instance of a form ([fieldsOf], [validate]).
  static const Object anyInstance = _AnyInstance();

  /// Flutter's `FormState.validate()` on form [form] (null: every field)
  /// shown in [instance] ([anyInstance]: every instance of it): each field
  /// shows its validator's error, the first invalid one takes the focus
  /// when [focusFirstError]. Whether all are valid.
  bool validate(String? form, {Object? instance = anyInstance, bool focusFirstError = true}) {
    FormFieldEntry? first;
    for (final f in fieldsOf(form, instance: instance)) {
      final error = f.check();
      f.shown = error;
      f.show(error);
      if (error != null) first ??= f;
    }
    if (focusFirstError) first?.focusNode.requestFocus();
    // Every form instance a field belongs to publishes again.
    for (final f in _fields.values) {
      if (_formOfBox(f.box) case (final own, final at)) _publishSoon(own, f.box.source, at);
    }
    return first == null;
  }

  /// A field at [box] changed its value or the error it shows: its form
  /// publishes `form` again (after the frame, never while building).
  void changed(NodeBuilder box) {
    if (_formOfBox(box) case (final form, final at)) _publishSoon(form, box.source, at);
  }

  final Map<(String, Object?), NodeSource> _pending = {};

  void _publishSoon(String form, NodeSource source, Object? instance) {
    final key = (form, instance);
    final had = _pending.containsKey(key);
    _pending[key] = source;
    if (had) return;
    void publish() {
      final p = _pending.remove(key);
      if (p == null) return;
      _publish(form, p, instance);
    }

    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      publish();
    } else {
      SchedulerBinding.instance.addPostFrameCallback((_) => publish());
      SchedulerBinding.instance.ensureVisualUpdate();
    }
  }

  void _publish(String form, NodeSource source, Object? instance) {
    final fields = fieldsOf(form, instance: instance);
    tree.bindings?.publish(source, form, instance, 'form', {
      'valid': fields.every((f) => f.check() == null),
      'errors': [
        for (final f in fields)
          if (f.shown != null) {'field': f.box.id, 'label': f.label(), 'message': f.shown},
      ],
    });
  }
}

final class _AnyInstance {
  const _AnyInstance();
}
