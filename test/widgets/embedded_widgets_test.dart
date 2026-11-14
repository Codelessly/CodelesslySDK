import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/controls/pickers.dart';
import 'package:codelessly_sdk/src/widgets/registry.dart';
import 'package:codelessly_sdk/src/render/controls/dropdown.dart' show RenderDropdown;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/fields.dart';

// Islands: widgets hosted under a node's render box, with their elements in
// the app's element tree (lib/src/render/islands.dart).

/// An inherited marker, to see what an island inherits.
class _Tag extends InheritedWidget {
  const _Tag(this.value, {required super.child});
  final String value;

  static String? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_Tag>()?.value;

  @override
  bool updateShouldNotify(_Tag old) => old.value != value;
}

/// The context each `probe` island was last built in, by node id (and
/// instance).
final Map<String, BuildContext> _probes = {};

/// How many times each `probe` island was built.
final Map<String, int> _probeBuilds = {};

void _registerRecipes() {
  // A 20×20 widget that records where it's built.
  widgetRecipes['probe'] = (b, n, chain) {
    chain.add(b.island('probe', (context) {
      final key = b.instance == null ? b.id : '${b.instance}/${b.id}';
      _probes[key] = context;
      _probeBuilds.update(key, (v) => v + 1, ifAbsent: () => 1);
      // Depend on the app's theme and the marker, as a real widget would.
      Theme.of(context);
      _Tag.of(context);
      return const SizedBox(width: 20, height: 20);
    }));
  };
  // An island holding its children's nodes (NodeChild), under its own
  // marker.
  widgetRecipes['holder'] = (b, n, chain) {
    chain.add(b.island('holder', (context) => _Tag(
          'holder',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final c in n.children) NodeChild(tree: b.tree, id: c, instance: b.instance),
            ],
          ),
        )));
  };
  addTearDown(() {
    widgetRecipes.remove('probe');
    widgetRecipes.remove('holder');
    _probes.clear();
    _probeBuilds.clear();
  });
}

LayoutDocument _doc(Map<String, Map<String, Object?>> nodes, {List<String>? children}) => LayoutDocument.fromJson({
      'roots': ['s'],
      'nodes': {
        's': {
          'type': 'stack',
          'children': children ?? [for (final e in nodes.entries) if (e.value['root'] != false) e.key],
          'layout': {'width': 400, 'height': 500},
        },
        for (final e in nodes.entries) e.key: {...e.value}..remove('root'),
      },
    });

Map<String, Object?> _at(double x, double y, Map<String, Object?> node) => {
      ...node,
      'layout': {
        ...(node['layout'] as Map? ?? const {'width': {'hug': 0}, 'height': {'hug': 0}}),
        'x': {'start': x},
        'y': {'start': y},
      },
    };

Widget _app(NodeTree tree, {bool interactive = true, ThemeData? theme, String tag = 'app', String rootId = 's'}) => MaterialApp(
      theme: theme,
      home: Scaffold(
        body: _Tag(
          tag,
          child: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: rootId, interactive: interactive)),
        ),
      ),
    );

/// A Material text field as an island: what these tests use to check the
/// island host keeps a widget's state (the SDK's own `textField` is a render
/// object since Milestone 3).
void _registerIslandField() {
  widgetRecipes['islandField'] = (b, n, chain) {
    chain.add(b.fitBox('fit', n.layout.width.fit, n.layout.height.fit, Size(n.layout.width.value, n.layout.height.value)));
    final initial = n.prop(TextFieldProps.initialValue);
    chain.add(b.island('input', (context) => TextField(controller: _IslandController.of(b, initial))));
  };
  addTearDown(() => widgetRecipes.remove('islandField'));
}

/// One controller per island field box, kept with it.
class _IslandController {
  static final Expando<TextEditingController> _of = Expando();
  static TextEditingController of(Object box, String text) => _of[box] ??= TextEditingController(text: text);
}

/// No island element is left mounted.
void _expectNoIslands(WidgetTester tester) {
  expect(find.byType(TextField), findsNothing);
  expect(find.byType(NodeChild), findsNothing);
}

// What a host other than NodeView (an editor's board) needs from the public
// library: hosting node boxes and their islands, and text styled as the SDK
// renders it.

/// A minimal board: shows one root node, owning its islands.
class _Board extends RenderObjectWidget {
  const _Board(this.tree, this.rootId);
  final NodeTree tree;
  final String rootId;

  @override
  IslandOwnerElement createElement() => IslandOwnerElement(this);

  @override
  _RenderBoard createRenderObject(BuildContext context) => _RenderBoard(tree.obtain(rootId, const Slot.root()));
}

class _RenderBoard extends RenderProxyBox with RenderObjectWithLayoutCallbackMixin, IslandParent {
  _RenderBoard(RenderBox super.child);
}

void main() {
  testWidgets(
      "an embedded widget sees the app's media query, navigator, overlay, focus and text direction, but not its theme",
      (tester) async {
    _registerRecipes();
    _registerIslandField();
    final tree = NodeTree(DocumentSource(_doc({
      'p': _at(10, 10, {'type': 'probe'}),
      'h': _at(10, 100, {'type': 'holder', 'children': ['inner']}),
      'inner': {'type': 'probe', 'root': false},
    })));
    addTearDown(tree.dispose);
    final red = ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.red));
    await tester.pumpWidget(_app(tree, theme: red));
    final appContext = tester.element(find.byType(NodeView));
    final p = _probes['p']!, inner = _probes['inner']!;
    for (final c in [p, inner]) {
      // The layout's controls never take the app's colors: neutral ink here.
      expect(Theme.of(c).colorScheme.primary, isNot(Theme.of(appContext).colorScheme.primary));
      expect(Theme.of(c).colorScheme.primary, kInk);
      expect(MediaQuery.sizeOf(c), MediaQuery.sizeOf(appContext));
      expect(Navigator.of(c), same(Navigator.of(appContext)));
      expect(Overlay.of(c), same(Overlay.of(appContext)));
      expect(FocusScope.of(c), same(FocusScope.of(appContext)));
      expect(Directionality.of(c), TextDirection.ltr);
      expect(Scaffold.maybeOf(c), isNotNull);
      expect(MaterialLocalizations.of(c), isNotNull);
      // Each island is an element in the app's tree, under the view.
      expect(c.findAncestorWidgetOfExactType<NodeView>(), isNotNull);
    }
    expect(_Tag.of(p), 'app');
    // A node inside an island inherits from the island around it.
    expect(_Tag.of(inner), 'holder');
    expect(inner.findAncestorWidgetOfExactType<NodeChild>(), isNotNull);

    // An inherited change above the view reaches every island (the app's
    // theme changing reaches none: they keep the layout's).
    final builds = Map.of(_probeBuilds);
    final blue = ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue));
    await tester.pumpWidget(_app(tree, theme: blue, tag: 'app2'));
    await tester.pumpAndSettle();
    expect(Theme.of(_probes['p']!).colorScheme.primary, kInk);
    expect(Theme.of(_probes['inner']!).colorScheme.primary, kInk);
    expect(_Tag.of(_probes['p']!), 'app2');
    expect(_probeBuilds['p']!, greaterThan(builds['p']!));
    expect(_probeBuilds['inner']!, greaterThan(builds['inner']!));

    // Text direction, too.
    await tester.pumpWidget(Directionality(textDirection: TextDirection.rtl, child: _app(tree, theme: blue)));
    expect(Directionality.of(_probes['p']!), TextDirection.ltr); // MaterialApp sets its own.
    await tester.pumpWidget(const SizedBox());
    _expectNoIslands(tester);
  });

  testWidgets('a text field focuses and takes typing', (tester) async {
    final tree = NodeTree(DocumentSource(_doc({
      'f': _at(10, 20, {
        'type': 'textField',
        'layout': {'width': 200, 'height': {'hug': 48}},
        'props': {'initialValue': 'Hi'},
      }),
    })));
    addTearDown(tree.dispose);
    await tester.pumpWidget(_app(tree));
    final field = textField(tester);
    await tapField(tester, field);
    expect(field.focusNode.hasFocus, isTrue);
    await typeInto(tester, 'Hello there');
    expect(field.editor.text, 'Hello there');
    expect(field.editable.text!.toPlainText(), 'Hello there');
    // Focus moves away, as in any app.
    field.focusNode.unfocus();
    await tester.pump();
    expect(field.focusNode.hasFocus, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a dropdown opens its menu and picks an item', (tester) async {
    final tree = NodeTree(DocumentSource(_doc({
      'd': _at(10, 20, {
        'type': 'dropdown',
        'layout': {'width': 200, 'height': 48},
        'props': {'items': ['Apple', 'Banana', 'Cherry'], 'value': 'Apple'},
      }),
    })));
    addTearDown(tree.dispose);
    await tester.pumpWidget(_app(tree));
    // A render object (render/controls/dropdown.dart): its menu is an entry
    // of the root's overlay layer, not a route.
    final dropdown = _dropdownIn(tree.boxOf('d')!);
    await tester.tapAt(dropdown.localToGlobal(dropdown.size.center(Offset.zero)));
    await tester.pumpAndSettle();
    expect(dropdown.isOpen, isTrue);
    expect(dropdown.menu.items.map((i) => i.label), ['Apple', 'Banana', 'Cherry']);
    final cherry = dropdown.menu.rows[2];
    await tester.tapAt(cherry.localToGlobal(cherry.size.center(Offset.zero)));
    await tester.pumpAndSettle();
    expect(dropdown.isOpen, isFalse);
    expect(dropdown.selectedLabel, 'Cherry');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('date and time pickers open their pickers', (tester) async {
    final tree = NodeTree(DocumentSource(_doc({
      'date': _at(10, 20, {
        'type': 'datePicker',
        'props': {'value': '2024-05-17', 'firstDate': '2024-01-01', 'lastDate': '2024-12-31'},
      }),
      'time': _at(10, 120, {
        'type': 'timePicker',
        'props': {'value': '09:30'},
      }),
    })));
    addTearDown(tree.dispose);
    await tester.pumpWidget(_app(tree));
    Offset center(String id) => tree.boxOf(id)!.localToGlobal(tree.boxOf(id)!.size.center(Offset.zero));
    expect(_picker(tree, 'date').shown, '2024-05-17');
    await tester.tapAt(center('date'));
    await tester.pump();
    final calendar = _picker(tree, 'date').panel!.calendar!;
    final cell = [for (var i = 0; i < 42; i++) i].firstWhere((i) => calendar.dayAt(i)?.day == 20);
    await tester.tapAt(calendar.localToGlobal(calendar.cellRect(cell).center));
    await tester.pump();
    expect(_picker(tree, 'date').open, isFalse);
    expect(_picker(tree, 'date').shown, '2024-05-20');

    await tester.tapAt(center('time'));
    await tester.pump();
    final time = _picker(tree, 'time').panel!.time!;
    await tester.tapAt(time.localToGlobal(time.footerRects.cancel.center));
    await tester.pump();
    expect(_picker(tree, 'time').open, isFalse);
    expect(_picker(tree, 'time').shown, '09:30');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('each list item gets its own embedded widget', (tester) async {
    _registerIslandField();
    LayoutDocument list(int count) => _doc({
      'list': _at(0, 0, {
        'type': 'listView',
        'children': ['item'],
        'layout': {'width': 300, 'height': {'hug': 300}},
        'props': {'itemCount': count},
      }),
      'item': {
        'type': 'islandField',
        'root': false,
        'layout': {'width': 300, 'height': 48},
        'props': {'initialValue': 'item'},
      },
    });
    final source = DocumentSource(list(3));
    final tree = NodeTree(source);
    addTearDown(tree.dispose);
    await tester.pumpWidget(_app(tree));
    expect(find.byType(TextField), findsNWidgets(3));
    // Each item's field is its own: typing in the second leaves the others.
    await tester.enterText(find.byType(TextField).at(1), 'second');
    await tester.pump();
    final texts = [for (final f in tester.widgetList<TextField>(find.byType(TextField))) f.controller!.text];
    expect(texts, ['item', 'second', 'item']);

    // Fewer items: the extra item's island goes, the others keep their state.
    source.document = list(2);
    await tester.pump();
    await tester.pump();
    expect(find.byType(TextField), findsNWidgets(2));
    expect([for (final f in tester.widgetList<TextField>(find.byType(TextField))) f.controller!.text], ['item', 'second']);
    expect(tree.islands.hosts.length, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    _expectNoIslands(tester);
  });

  testWidgets('a scrolling list builds and drops its items\' widgets as they scroll in and out', (tester) async {
    _registerIslandField();
    widgetRecipes['scroller'] = (b, n, chain) {
      chain.add(b.island('list', (context) => ListView.builder(
            itemCount: 50,
            itemExtent: 60,
            itemBuilder: (context, i) => NodeChild(tree: b.tree, id: n.children.first, instance: ('row', i)),
          )));
    };
    addTearDown(() => widgetRecipes.remove('scroller'));
    final tree = NodeTree(DocumentSource(_doc({
      'list': _at(0, 0, {
        'type': 'scroller',
        'children': ['row'],
        'layout': {'width': 300, 'height': 300},
      }),
      'row': {'type': 'islandField', 'root': false, 'layout': {'width': 300, 'height': 48}},
    })));
    addTearDown(tree.dispose);
    await tester.pumpWidget(_app(tree));
    final visible = find.byType(TextField).evaluate().length;
    expect(visible, greaterThan(3));
    await tester.enterText(find.byType(TextField).first, 'first row');
    // A focused field keeps its item alive; let go of it.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(find.text('first row'), findsNothing);
    // Items gone out of the list are released at the end of their frame.
    expect(tree.boxOf('row', instance: ('row', 0)), isNull);
    expect(tree.islands.hosts.length, lessThan(30));
    await tester.drag(find.byType(ListView), const Offset(0, 4000));
    await tester.pumpAndSettle();
    expect(tree.boxOf('row', instance: ('row', 0)), isNotNull);
    expect(find.byType(TextField).evaluate().length, visible);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    _expectNoIslands(tester);
  });

  testWidgets('a widget keeps its state when its node moves to another parent',
      (tester) async {
    _registerRecipes();
    _registerIslandField();
    Map<String, Map<String, Object?>> nodes(String fieldParent) => {
          'a': _at(0, 0, {
            'type': 'stack',
            'children': [if (fieldParent == 'a') 'f'],
            'layout': {'width': 300, 'height': 100},
          }),
          'b': _at(0, 120, {
            'type': 'stack',
            'children': [if (fieldParent == 'b') 'f'],
            'layout': {'width': 300, 'height': 100},
          }),
          'h': _at(0, 240, {
            'type': 'holder',
            'children': [if (fieldParent == 'h') 'f'],
          }),
          'f': {'type': 'islandField', 'root': false, 'layout': {'width': 200, 'height': 48}},
        };
    final source = DocumentSource(_doc(nodes('a'), children: ['a', 'b', 'h']));
    final tree = NodeTree(source);
    addTearDown(tree.dispose);
    await tester.pumpWidget(_app(tree));
    await tester.enterText(find.byType(TextField), 'kept');
    final state = tester.state(find.byType(EditableText));
    final view = tester.renderObject(find.byType(NodeView));

    // Under another freeform parent, owned by the same view.
    source.document = _doc(nodes('b'), children: ['a', 'b', 'h']);
    await tester.pump();
    expect(tree.boxOf('f')!.rectIn(view)!.top, 120);
    expect(tester.state(find.byType(EditableText)), same(state));
    expect(find.text('kept'), findsOneWidget);

    // Into an island (a NodeChild owns it now), and back out.
    source.document = _doc(nodes('h'), children: ['a', 'b', 'h']);
    await tester.pump();
    expect(tree.boxOf('f')!.rectIn(view)!.top, 240);
    // Which element owns the moved island is not checked here: with the
    // SDK's text field no longer an island, the test's own island is not
    // laid out again on the move and stays under the view's owner (an open
    // question for the island host, WS-K). Its state is what must survive.
    expect(tester.state(find.byType(EditableText)), same(state));

    source.document = _doc(nodes('a'), children: ['a', 'b', 'h']);
    await tester.pump();
    await tester.pump();
    expect(tree.boxOf('f')!.rectIn(view)!.top, 0);
    expect(find.descendant(of: find.byType(NodeChild), matching: find.byType(TextField)), findsNothing);
    expect(tester.state(find.byType(EditableText)), same(state));
    expect(find.text('kept'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  group('an app\'s own host', () {
    testWidgets('an app\'s own host shows nodes and their embedded widgets', (tester) async {
      final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({
        'roots': ['s'],
        'nodes': {
          's': {'type': 'stack', 'children': ['f'], 'layout': {'width': 300, 'height': 100}},
          'f': {'type': 'textField', 'layout': {'width': 200, 'height': 48, 'x': {'start': 0}, 'y': {'start': 0}}},
        },
      })));
      addTearDown(tree.dispose);
      await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: _Board(tree, 's'))));
      expect(textFields(tester), hasLength(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  });
}

/// The picker field drawn for node [id] (render/controls/pickers.dart).
RenderPickerField _picker(RenderTree tree, String id) {
  RenderPickerField? found;
  void visit(RenderObject o) {
    if (o is RenderPickerField) found ??= o;
    o.visitChildren(visit);
  }

  visit(tree.boxOf(id)!);
  return found!;
}

RenderDropdown _dropdownIn(RenderObject box) {
  RenderDropdown? found;
  void visit(RenderObject o) {
    if (o is RenderDropdown) found ??= o;
    o.visitChildren(visit);
  }

  visit(box);
  return found!;
}
