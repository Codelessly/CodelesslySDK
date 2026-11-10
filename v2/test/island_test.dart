// Islands: widgets hosted under a node's render box, with their elements in
// the app's element tree (lib/src/render/islands.dart).
import 'package:codelessly_sdk_v2/codelessly_sdk.dart';
import 'package:codelessly_sdk_v2/src/widgets/registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

/// No island element is left mounted.
void _expectNoIslands(WidgetTester tester) {
  expect(find.byType(TextField), findsNothing);
  expect(find.byType(NodeChild), findsNothing);
}

void main() {
  testWidgets('a recipe can host a widget island with a node inside', (tester) async {
    widgetRecipes['testButton'] = (b, n, chain) {
      chain.add(b.island('button', (context) => Padding(
            padding: const EdgeInsets.all(5),
            child: NodeChild(tree: b.tree, id: n.children.first),
          )));
    };
    addTearDown(() => widgetRecipes.remove('testButton'));
    final doc = LayoutDocument.fromJson({
      'roots': ['s'],
      'nodes': {
        's': {'type': 'stack', 'children': ['btn'], 'layout': {'width': 300, 'height': 200}},
        'btn': {'type': 'testButton', 'children': ['label'], 'layout': {'width': {'hug': 0}, 'height': {'hug': 0}, 'x': {'start': 10}, 'y': {'start': 20}}},
        'label': {'type': 'box', 'layout': {'width': 40, 'height': 16}},
      },
    });
    final source = DocumentSource(doc);
    final tree = NodeTree(source);
    await tester.pumpWidget(MaterialApp(home: Center(child: NodeView(tree: tree, rootId: 's'))));
    final view = tester.renderObject(find.byType(NodeView));
    expect(tree.boxOf('btn')!.rectIn(view), const Rect.fromLTWH(10, 20, 50, 26));
    expect(tree.boxOf('label')!.rectIn(view), const Rect.fromLTWH(15, 25, 40, 16));

    // An edit to the node inside re-lays out through the island.
    source.document = doc.copyWith(nodes: {
      ...doc.nodes,
      'label': doc['label']!.copyWith(layout: doc['label']!.layout.copyWith(width: const AxisSize.fixed(60))),
    });
    await tester.pump();
    expect(tree.boxOf('btn')!.rectIn(view)!.width, 70);
    await tester.pumpWidget(const SizedBox());
    tree.dispose();
  });

  testWidgets("islands inherit the app's widgets: theme, media query, navigator, overlay, focus, directionality",
      (tester) async {
    _registerRecipes();
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
      expect(Theme.of(c).colorScheme.primary, Theme.of(appContext).colorScheme.primary);
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

    // An inherited change above the view reaches every island.
    final builds = Map.of(_probeBuilds);
    final blue = ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue));
    await tester.pumpWidget(_app(tree, theme: blue, tag: 'app2'));
    await tester.pumpAndSettle();
    expect(Theme.of(_probes['p']!).colorScheme.primary, blue.colorScheme.primary);
    expect(Theme.of(_probes['inner']!).colorScheme.primary, blue.colorScheme.primary);
    expect(_Tag.of(_probes['p']!), 'app2');
    expect(_probeBuilds['p']!, greaterThan(builds['p']!));
    expect(_probeBuilds['inner']!, greaterThan(builds['inner']!));

    // Text direction, too.
    await tester.pumpWidget(Directionality(textDirection: TextDirection.rtl, child: _app(tree, theme: blue)));
    expect(Directionality.of(_probes['p']!), TextDirection.ltr); // MaterialApp sets its own.
    await tester.pumpWidget(const SizedBox());
    _expectNoIslands(tester);
  });

  testWidgets('islands shown outside an app still get the ambient widgets they need', (tester) async {
    _registerRecipes();
    final tree = NodeTree(DocumentSource(_doc({'p': _at(0, 0, {'type': 'probe'})})));
    addTearDown(tree.dispose);
    await tester.pumpWidget(NodeView(tree: tree, rootId: 's'));
    final p = _probes['p']!;
    expect(Directionality.of(p), TextDirection.ltr);
    expect(Overlay.maybeOf(p), isNotNull);
    expect(MediaQuery.maybeOf(p), isNotNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an interactive text field focuses and takes typing', (tester) async {
    final tree = NodeTree(DocumentSource(_doc({
      'f': _at(10, 20, {
        'type': 'textField',
        'layout': {'width': 200, 'height': {'hug': 48}},
        'props': {'initialValue': 'Hi'},
      }),
    })));
    addTearDown(tree.dispose);
    await tester.pumpWidget(_app(tree));
    final field = find.byType(TextField);
    expect(field, findsOneWidget);
    await tester.tap(field);
    await tester.pump();
    final editable = tester.state<EditableTextState>(find.byType(EditableText));
    expect(editable.widget.focusNode.hasFocus, isTrue);
    await tester.enterText(field, 'Hello there');
    await tester.pump();
    expect(tester.widget<TextField>(field).controller!.text, 'Hello there');
    expect(find.text('Hello there'), findsOneWidget);
    // Focus moves away, as in any app.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(editable.widget.focusNode.hasFocus, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets("a dropdown's menu opens and picks", (tester) async {
    final tree = NodeTree(DocumentSource(_doc({
      'd': _at(10, 20, {
        'type': 'dropdown',
        'layout': {'width': 200, 'height': 48},
        'props': {'items': ['Apple', 'Banana', 'Cherry'], 'value': 'Apple'},
      }),
    })));
    addTearDown(tree.dispose);
    await tester.pumpWidget(_app(tree));
    await tester.tap(find.byType(DropdownButton<Object>));
    await tester.pumpAndSettle();
    // The menu is a route on the app's navigator: every item shows.
    expect(find.text('Cherry'), findsWidgets);
    await tester.tap(find.text('Cherry').last);
    await tester.pumpAndSettle();
    expect(tester.widget<DropdownButton<Object>>(find.byType(DropdownButton<Object>)).value, 'Cherry');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('date and time pickers open their dialogs', (tester) async {
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
    await tester.tap(find.text('2024-05-17'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('20'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsNothing);
    expect(find.text('2024-05-20'), findsOneWidget);

    await tester.tap(find.text('09:30'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('islands in list items: one per item, released with them', (tester) async {
    LayoutDocument list(int count) => _doc({
      'list': _at(0, 0, {
        'type': 'listView',
        'children': ['item'],
        'layout': {'width': 300, 'height': {'hug': 300}},
        'props': {'itemCount': count},
      }),
      'item': {
        'type': 'textField',
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

  testWidgets('a scrolling list island builds and drops its items (nodes with islands) as they scroll', (tester) async {
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
      'row': {'type': 'textField', 'root': false, 'layout': {'width': 300, 'height': 48}},
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

  testWidgets('releasing a subtree unmounts its islands, nested ones included', (tester) async {
    _registerRecipes();
    final doc = _doc({
      'group': _at(0, 0, {
        'type': 'stack',
        'children': ['f', 'h'],
        'layout': {'width': 300, 'height': 300},
      }),
      'f': {'type': 'textField', 'root': false, 'layout': {'width': 200, 'height': 48}},
      'h': {
        'type': 'holder',
        'root': false,
        'children': ['inner', 'innerField'],
        'layout': {'width': {'hug': 0}, 'height': {'hug': 0}, 'x': {'start': 0}, 'y': {'start': 100}},
      },
      'inner': {'type': 'probe', 'root': false},
      'innerField': {'type': 'textField', 'root': false, 'layout': {'width': 200, 'height': 48}},
      'other': _at(0, 400, {'type': 'probe'}),
    });
    final source = DocumentSource(doc);
    final tree = NodeTree(source);
    addTearDown(tree.dispose);
    await tester.pumpWidget(_app(tree));
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.byType(NodeChild), findsNWidgets(2));
    // The field inside the holder types too.
    await tester.enterText(find.byType(TextField).last, 'nested');
    expect(find.text('nested'), findsOneWidget);

    // The group goes: its islands, and the islands of nodes inside them.
    source.document = doc.copyWith(nodes: {
      for (final e in doc.nodes.entries)
        if (!const {'group', 'f', 'h', 'inner', 'innerField'}.contains(e.key)) e.key: e.value,
      's': doc['s']!.copyWith(children: ['other']),
    });
    await tester.pump();
    await tester.pump();
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(NodeChild), findsNothing);
    expect([for (final h in tree.islands.hosts) h.debugLabel], ['other#probe']);
    expect(tree.boxOf('innerField'), isNull);
    expect(_probes['other']!.mounted, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets("a node moving under another parent, or into another island, keeps its island's state",
      (tester) async {
    _registerRecipes();
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
          'f': {'type': 'textField', 'root': false, 'layout': {'width': 200, 'height': 48}},
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
    expect(find.descendant(of: find.byType(NodeChild), matching: find.byType(TextField)), findsOneWidget);
    expect(tester.state(find.byType(EditableText)), same(state));
    expect(_Tag.of(tester.element(find.byType(TextField))), 'holder');

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

  testWidgets('a view shown again rebuilds its islands; views sharing a tree each own theirs', (tester) async {
    _registerRecipes();
    final source = DocumentSource(LayoutDocument.fromJson({
      'roots': ['s1', 's2'],
      'nodes': {
        's1': {'type': 'stack', 'children': ['p1'], 'layout': {'width': 100, 'height': 100}},
        's2': {'type': 'stack', 'children': ['p2'], 'layout': {'width': 100, 'height': 100}},
        'p1': {'type': 'probe', 'layout': {'width': 20, 'height': 20}},
        'p2': {'type': 'probe', 'layout': {'width': 20, 'height': 20}},
      },
    }));
    final tree = NodeTree(source);
    addTearDown(tree.dispose);
    Widget views() => MaterialApp(
          home: Column(children: [
            _Tag('one', child: NodeView(tree: tree, rootId: 's1')),
            _Tag('two', child: NodeView(tree: tree, rootId: 's2')),
          ]),
        );
    await tester.pumpWidget(views());
    expect(_Tag.of(_probes['p1']!), 'one');
    expect(_Tag.of(_probes['p2']!), 'two');

    // Gone, then shown again with the same tree: built afresh under the new
    // view.
    await tester.pumpWidget(const SizedBox());
    expect(_probes['p1']!.mounted, isFalse);
    await tester.pumpWidget(views());
    expect(_probes['p1']!.mounted, isTrue);
    expect(_Tag.of(_probes['p1']!), 'one');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  // A spinner that ticks while its island is rebuilt from the top (its node
  // re-applies, or the tree is shown under a new view): rebuilt by its parent
  // while marked dirty, it used to stay in the island's dirty list and assert
  // in BuildOwner.scheduleBuildFor at its next tick.
  testWidgets('a ticking island rebuilt as its node re-applies, and under a new view, goes on ticking', (tester) async {
    widgetRecipes['spin'] = (b, n, chain) {
      // Not const: rebuilding the island rebuilds the spinner.
      chain.add(b.island(
          'spin', (context) => SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Theme.of(context).primaryColor))));
    };
    addTearDown(() => widgetRecipes.remove('spin'));
    LayoutDocument doc(double x) => LayoutDocument.fromJson({
          'roots': ['s'],
          'nodes': {
            's': {'type': 'stack', 'children': ['p'], 'layout': {'width': 100, 'height': 100}},
            'p': {'type': 'spin', 'layout': {'width': 20, 'height': 20, 'x': {'start': x}, 'y': {'start': 0}}},
          },
        });
    final source = DocumentSource(doc(0));
    final tree = NodeTree(source);
    addTearDown(tree.dispose);
    Widget view() => MaterialApp(
        home: Align(alignment: Alignment.topLeft, child: NodeView(key: UniqueKey(), tree: tree, rootId: 's')));
    await tester.pumpWidget(view());
    for (var i = 1; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      source.document = doc(i * 5.0);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpWidget(view());
    for (var i = 1; i < 6; i++) {
      source.document = doc(i * 3.0);
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
