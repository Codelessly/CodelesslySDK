// Components by reference in the render tree
// (codelessly_api docs/design/06-sections-and-components.md §6).
//
// A call node renders as the boxes of its component's definition, one
// ordinary box per definition node per instance: the boxes of an instance are
// keyed by (node id, [ComponentInstance]) as a list item's are by (node id,
// item instance), so a component inside a list item, a list inside a
// component and a component inside a component compose without new rules.
// Ids stay local to each document: [ComponentInstance] says which document an
// id is in, and [InstanceSource] gives that document's nodes.
import 'package:codelessly_api/core.dart';
import 'package:flutter/foundation.dart';

import 'contracts.dart' show BoundNode;
import 'source.dart';

/// How many components may nest inside each other (a cycle stops here): a
/// call deeper than this renders as its empty box.
const int kMaxComponentDepth = 32;

/// An instance of a component: the call node [call] (an id of the document
/// [outer] is in) rendering definition [component]. [outer] is the call's
/// own instance: null on a page, a list item, another [ComponentInstance].
///
/// Equal by ([outer], [call]), as list item instances are by their list and
/// index. Prints as the path tools name nodes inside it by (`plans/card1`).
@immutable
final class ComponentInstance {
  const ComponentInstance(this.outer, this.call, this.component);

  final Object? outer;

  /// The call node's id, in the document of [outer].
  final String call;

  /// The definition's type name.
  final String component;

  /// How many components this one is nested in, itself included.
  int get depth {
    var d = 0;
    for (Object? i = this; i != null; i = outerInstanceOf(i)) {
      if (i is ComponentInstance) d++;
    }
    return d;
  }

  @override
  bool operator ==(Object other) => other is ComponentInstance && other.call == call && other.outer == outer;

  @override
  int get hashCode => Object.hash(call, outer);

  /// Unique per instance (box keys print it): the outer instance, then the
  /// call (`plans/card1`, `(item, null, list, 2)/card`). Tools name it by
  /// [componentPath].
  @override
  String toString() => outer == null ? call : '$outer/$call';
}

/// An instance that repeats nodes inside another (a provided list item, a
/// table cell): what [outerInstanceOf] walks through.
abstract interface class NestedInstance {
  Object? get outer;
}

/// The instance [instance] is nested in: a component instance's call
/// instance, a list item's list instance (`('item', outer, list, k)`), a
/// [NestedInstance]'s outer; null for none.
Object? outerInstanceOf(Object? instance) => switch (instance) {
      ComponentInstance(:final outer) => outer,
      NestedInstance(:final outer) => outer,
      (String _, Object? outer, String _, int _) => outer,
      _ => null,
    };

/// The innermost component instance [instance] is in (itself, or the one a
/// list item inside a definition repeats in); null on a page.
ComponentInstance? componentInstanceOf(Object? instance) {
  for (Object? i = instance; i != null; i = outerInstanceOf(i)) {
    if (i is ComponentInstance) return i;
  }
  return null;
}

/// The path tools name an instance by: the call ids from the page down,
/// joined by `/`; a call repeated by a list adds `#<index>`
/// (`faq/faqItem#2`). Empty outside components.
String componentPath(Object? instance) {
  final parts = <String>[];
  for (Object? i = instance; i != null; i = outerInstanceOf(i)) {
    if (i is ComponentInstance) {
      final k = switch (i.outer) {
        (String _, Object? _, String _, int k) => '#$k',
        _ => '',
      };
      parts.add('${i.call}$k');
    }
  }
  return parts.reversed.join('/');
}

/// The path of node [id] in [instance] for tools (`plans/card1/cta`): a
/// definition's root is named by its call (`plans/card1`).
String nodePath(String id, Object? instance, {String? rootOf}) {
  final prefix = componentPath(instance);
  if (prefix.isEmpty) return id;
  return instance is ComponentInstance && rootOf == id ? prefix : '$prefix/$id';
}

/// One component definition: its document (the source every instance reads,
/// replaced in place by an edit), its declaration and its root.
final class RegisteredComponent {
  RegisteredComponent._(this.type, LayoutDocument document) : source = DocumentSource(document);

  final String type;

  /// The definition's nodes, shared by every instance: replacing its
  /// document notifies only the nodes that changed, in every instance.
  final DocumentSource source;

  LayoutDocument get document => source.document;

  /// Its declaration (`widget`).
  WidgetSpec get spec => document.widget!;

  /// Its root node's id.
  String get root => document.componentRoot!;
}

/// The component definitions a tree renders calls with, by type name. One
/// per app (or render command, or editor); filled from a site's files, a
/// publish or an editor's store. Notifies with the types that arrived,
/// changed their declaration or left; an edit to a definition's nodes goes
/// through its [RegisteredComponent.source] and notifies only those nodes.
class ComponentRegistry extends ChangeNotifier {
  ComponentRegistry([Iterable<LayoutDocument> definitions = const []]) {
    for (final d in definitions) {
      define(d);
    }
    _changed.clear();
  }

  final Map<String, RegisteredComponent> _definitions = {};
  final Map<String, LayoutDocument> _written = {};
  final Set<String> _changed = {};

  /// The project's theme as the screen shows it: the definitions' named
  /// colors and text styles are resolved against it ([resolveThemeRefs]);
  /// a change re-applies only the nodes whose values differ.
  ThemeTokens get theme => _theme;
  ThemeTokens _theme = ThemeTokens.none;
  set theme(ThemeTokens value) {
    if (value == _theme) return;
    _theme = value;
    for (final e in _definitions.entries) {
      final written = _written[e.key];
      if (written != null) e.value.source.document = resolveThemeRefs(written, value);
    }
  }

  /// The types the last notification was about.
  Set<String> get changed => Set.unmodifiable(_changed);

  /// Calls rendered without their definition, by type: each call's path.
  final Map<String, Set<String>> missing = {};

  RegisteredComponent? operator [](String type) => _definitions[type];
  Iterable<String> get types => _definitions.keys;
  bool get isEmpty => _definitions.isEmpty;

  /// The declarations, as a catalog: what the documents that call them are
  /// decoded with (over the app's).
  Catalog get catalog => _catalog ??= Catalog(id: 'components', widgets: [for (final d in _definitions.values) d.spec]);
  Catalog? _catalog;

  /// Adds or replaces the definition [document] is (it must be a component
  /// document). A replaced one's instances update in place: only nodes that
  /// differ re-apply. A new type, or a changed declaration, notifies.
  void define(LayoutDocument document) {
    final type = document.componentType;
    if (type == null) return;
    _written[type] = document;
    document = resolveThemeRefs(document, _theme);
    final existing = _definitions[type];
    if (existing != null) {
      final declared = jsonEquality.equals(existing.document.extra[kWidgetKey], document.extra[kWidgetKey]) &&
          existing.root == document.componentRoot;
      existing.source.document = document;
      if (declared) return;
      _catalog = null;
      _notify({type});
      return;
    }
    _definitions[type] = RegisteredComponent._(type, document);
    _catalog = null;
    missing.remove(type);
    _notify({type});
  }

  /// Removes definition [type]: its calls render as empty boxes.
  void remove(String type) {
    _written.remove(type);
    if (_definitions.remove(type) == null) return;
    _catalog = null;
    _notify({type});
  }

  /// Told of each call rendered without its definition, once per call
  /// path (`component_missing`): an app logs it and may fetch the
  /// definition, whose arrival ([define]) renders the call.
  void Function(String type, String path)? onMissing;

  /// Records that the call at [path] has no definition [type].
  void reportMissing(String type, String path) {
    final paths = missing[type] ??= {};
    if (paths.add(path)) {
      assert(() {
        debugPrint('Codelessly: component_missing: "$path" calls $type, which is not defined.');
        return true;
      }());
      onMissing?.call(type, path);
    }
  }

  void _notify(Set<String> types) {
    _changed
      ..clear()
      ..addAll(types);
    notifyListeners();
  }
}

/// The nodes of the definition an instance renders, with where its call is:
/// what the tree resolves an instance's ids with, and the runtime reads the
/// instance's parameters through.
final class InstanceSource implements NodeSource {
  InstanceSource(this.instance, this.definition, this.callSource, this._resolveCall);

  final ComponentInstance instance;
  final RegisteredComponent definition;

  /// The source of the document the call is in.
  final NodeSource callSource;
  final BoundNode? Function() _resolveCall;

  /// The call node as stored.
  Node? get call => callSource.node(instance.call);

  /// The call node as shown, bound in the caller's scope: its parameters'
  /// values, its size and placement.
  BoundNode? resolveCall() => _resolveCall();

  @override
  Node? node(String id) => definition.source.node(id);

  @override
  String? parentOf(String id) => definition.source.parentOf(id);

  @override
  ValueListenable<Node?> watch(String id) => definition.source.watch(id);
}
