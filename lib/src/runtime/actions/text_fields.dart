// The text fields a tree shows, by node: what focus, edit text and submit
// form actions reach. A text field (render/controls/text_field.dart)
// registers itself on its node's box while it is on screen, through the
// services the widgets layer gives its recipe ([textFieldServices]).
import '../../render/components.dart' show componentInstanceOf;
import '../../render/controls/editable.dart' show FieldEditor;
import '../../render/controls/focus.dart' show ControlFocusNode;
import '../../render/controls/text_field.dart';
import '../../render/node_tree.dart';
import '../../render/recipe.dart';
import '../expressions/bindings.dart' show ProvidedItem;
import 'form_fields.dart';

/// A text field's value (its [controller]: text, selection, `clear()`) and
/// its place in the focus order.
class TextFieldHandle {
  TextFieldHandle(this.field);

  /// The field's render object.
  final RenderTextField field;

  /// Its value, as Flutter's `TextEditingController` holds it.
  FieldEditor get controller => field.editor;

  /// Its focus (`requestFocus`, `unfocus`, `hasFocus`).
  ControlFocusNode get focusNode => field.focusNode;

  static final Expando<TextFieldHandle> _handles = Expando('TextFieldHandle');
  static final Set<TextFieldHandle> _live = {};

  /// The field node [id] of [tree] shows (its first instance), if any.
  static TextFieldHandle? of(RenderTree tree, String id) {
    final box = tree.boxOf(id);
    return box == null ? null : _handles[box];
  }

  /// The field node [id] of [tree] shows nearest [instance] (the repeat of
  /// the node whose trigger fired): in the same list item, else one inside
  /// it or around it, else the first. A field in a kanban column's repeated
  /// quick add is the one of the column whose button was pressed.
  static TextFieldHandle? near(RenderTree tree, String id, Object? instance) {
    if (instance == null) return of(tree, id);
    bool within(Object? inner, Object? outer) {
      for (Object? i = inner; i != null; i = i is ProvidedItem ? i.outer : null) {
        if (i == outer) return true;
      }
      return false;
    }

    TextFieldHandle? related, sameComponent;
    final component = componentInstanceOf(instance);
    for (final box in tree.boxesOf(id)) {
      final handle = _handles[box];
      if (handle == null) continue;
      if (box.instance == instance) return handle;
      // Ids are local to a component's definition: the field of the
      // instance the action runs in.
      if (sameComponent == null && component != null && componentInstanceOf(box.instance) == component) sameComponent = handle;
      if (related == null && (within(box.instance, instance) || within(instance, box.instance))) related = handle;
    }
    return related ?? sameComponent ?? of(tree, id);
  }

  static void register(NodeBuilder box, TextFieldHandle handle) {
    final old = _handles[box];
    if (old != null) _live.remove(old);
    _handles[box] = handle;
    _live.add(handle);
  }

  static void unregister(NodeBuilder box, RenderTextField field) {
    final h = _handles[box];
    if (h == null || !identical(h.field, field)) return;
    _handles[box] = null;
    _live.remove(h);
  }

  /// Takes the focus from every text field.
  static void unfocusAll() {
    for (final h in _live.toList()) {
      h.focusNode.unfocus();
    }
  }
}

/// [box]'s tree's text field handle (for tests and tools).
TextFieldHandle? textFieldOf(NodeBox box) => TextFieldHandle.of(box.tree, box.id);

/// What the runtime does for the text fields on screen: registers each for
/// the focus and edit text actions and as its form's field.
class RuntimeTextFieldServices implements TextFieldServices {
  const RuntimeTextFieldServices();

  static final Expando<FormFieldEntry> _entries = Expando('FormFieldEntry');

  @override
  void attachField(NodeBuilder b, RenderTextField field) {
    if (identical(TextFieldHandle._handles[b]?.field, field) && _entries[field] != null) return;
    TextFieldHandle.register(b, TextFieldHandle(field));
    final entry = _entries[field] = FormFieldEntry(
      box: b,
      focusNode: field.focusNode,
      check: field.check,
      show: field.showError,
      label: () => field.config.decoration.labelText ?? b.id,
    )..shown = field.validationError;
    FormRegistry.of(b.tree).register(entry);
  }

  @override
  void detachField(NodeBuilder b, RenderTextField field) {
    TextFieldHandle.unregister(b, field);
    final entry = _entries[field];
    if (entry == null) return;
    _entries[field] = null;
    FormRegistry.of(b.tree).unregister(b, entry);
  }

  @override
  void fieldChanged(NodeBuilder b) {
    final field = TextFieldHandle._handles[b]?.field;
    if (field != null) _entries[field]?.shown = field.validationError;
    FormRegistry.of(b.tree).changed(b);
  }
}

/// The runtime's services for text fields (widgets/controls.dart passes
/// them to the recipe).
const TextFieldServices textFieldServices = RuntimeTextFieldServices();
