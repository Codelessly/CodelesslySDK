import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const Color ink = Color(0xFF1F2B2E);
const Color card = Color(0xFFFBF7EE);
const Color foam = Color(0xFFD4E7DF);
const Color tide = Color(0xFF1F6F78);

const List<Map<String, String>> species = [
  {'name': 'Ochre sea star', 'image': 'https://plates.test/ochre.png'},
  {'name': 'Giant green anemone', 'image': 'https://plates.test/anemone.png'},
  {'name': 'Purple urchin', 'image': 'https://plates.test/urchin.png'},
];

/// The Tidepool species menu: a card under the field with an ink outline,
/// a stamped shadow and the selected row on foam with a check mark.
final Map<String, dynamic> menuStyle = {
  'color': '#FBF7EE',
  'border': {'color': '#1F2B2E', 'width': 1.5},
  'radius': 4,
  'shadows': [
    {
      'type': 'dropShadow',
      'radius': 0,
      'spread': 0,
      'color': '#1F2B2E',
      'offset': {'x': 4, 'y': 4},
    },
  ],
  'itemHeight': 40,
  'selectedItemColor': '#D4E7DF',
  'selectedTextStyle': {'fontWeight': 'w600'},
  'showCheck': true,
  'checkColor': '#1F6F78',
  'minWidth': 240,
};

DropdownNode dropdown({Map<String, dynamic>? style, Object? value}) =>
    DropdownNode(
      id: 'species',
      name: 'Species',
      basicBoxLocal: NodeBox(0, 0, 200, 44),
      value: value,
      properties: DropdownProperties.fromJson({
        'items': <String>[],
        'useDataSource': true,
        'itemLabel': r'${item.name}',
        'itemImage': r'${item.image}',
        'itemImageSize': 28,
        'menuStyle': ?style,
      }),
    )..variables['data'] = 'species';

Future<List<(int, Object)>> pumpDropdown(
  WidgetTester tester,
  DropdownNode node,
) async {
  final List<(int, Object)> changes = [];
  final CodelesslyContext ctx = CodelesslyContext.empty()
    ..variables['species'] = Observable(
      VariableData(
        id: 'species',
        name: 'species',
        value: species,
        type: VariableType.list,
      ),
    );
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: ctx,
      child: MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: 200,
                height: 44,
                child: PassiveDropdownWidget(
                  node: node,
                  settings: const WidgetBuildSettings(debugLabel: 'test'),
                  onChanged: (index, value) => changes.add((index, value)),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return changes;
}

void main() {
  testWidgets('a styled dropdown opens an anchored, stamped menu card', (
    tester,
  ) async {
    final List<(int, Object)> changes = await pumpDropdown(
      tester,
      dropdown(style: menuStyle, value: species[1]),
    );
    // The field shows the selected item with its plate.
    expect(find.text('Giant green anemone'), findsOneWidget);

    await tester.tap(find.byType(PassiveDropdownWidget));
    await tester.pumpAndSettle();
    final Finder menu = find.byKey(const ValueKey('codelessly-dropdown-menu'));
    expect(menu, findsOneWidget);

    // Under the field, at least 240 wide.
    final Rect field = tester.getRect(find.byType(PassiveDropdownWidget));
    final Rect box = tester.getRect(menu);
    expect(box.top, field.bottom + 6);
    expect(box.left, field.left);
    expect(box.width, 240);

    final BoxDecoration decoration =
        tester.widget<Container>(menu).decoration! as BoxDecoration;
    expect(decoration.color, card);
    expect(decoration.borderRadius, BorderRadius.circular(4));
    expect(
      decoration.border,
      const Border.fromBorderSide(BorderSide(color: ink, width: 1.5)),
    );
    expect(decoration.boxShadow, const [
      BoxShadow(color: ink, offset: Offset(4, 4)),
    ]);

    // Rows: each with its plate, the selected one on foam, bold, checked.
    Finder inMenu(Finder finder) => find.descendant(of: menu, matching: finder);
    expect(inMenu(find.text('Ochre sea star')), findsOneWidget);
    final List<String> urls = tester
        .widgetList<Image>(inMenu(find.byType(Image)))
        .map((image) => (image.image as NetworkImage).url)
        .toList();
    expect(urls, [for (final s in species) s['image']]);
    expect(
      tester
          .getSize(
            inMenu(find.byKey(const ValueKey('codelessly-dropdown-item-0'))),
          )
          .height,
      40,
    );

    final Material selectedRow = tester.widget<Material>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('codelessly-dropdown-item-1')),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(selectedRow.color, foam);
    final Material otherRow = tester.widget<Material>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('codelessly-dropdown-item-0')),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(otherRow.color, Colors.transparent);
    final RichText selectedLabel = tester.widget<RichText>(
      find.descendant(
        of: inMenu(find.text('Giant green anemone')),
        matching: find.byType(RichText),
      ),
    );
    expect(selectedLabel.text.style!.fontWeight, FontWeight.w600);
    final Icon check = tester.widget<Icon>(
      find.byKey(const ValueKey('codelessly-dropdown-check')),
    );
    expect(check.icon, Icons.check);
    expect(check.color, tide);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('codelessly-dropdown-item-1')),
        matching: find.byKey(const ValueKey('codelessly-dropdown-check')),
      ),
      findsOneWidget,
    );

    // Picking a row closes the menu and reports it.
    await tester.tap(inMenu(find.text('Purple urchin')));
    await tester.pumpAndSettle();
    expect(menu, findsNothing);
    expect(changes.single.$1, 2);
    expect(changes.single.$2, species[2]);

    // Tapping outside closes it without a change.
    await tester.tap(find.byType(PassiveDropdownWidget));
    await tester.pumpAndSettle();
    expect(menu, findsOneWidget);
    await tester.tapAt(const Offset(700, 500));
    await tester.pumpAndSettle();
    expect(menu, findsNothing);
    expect(changes, hasLength(1));
  });

  testWidgets('a dropdown without a menu style keeps the platform menu', (
    tester,
  ) async {
    await pumpDropdown(tester, dropdown(value: species[0]));
    await tester.tap(find.byType(PassiveDropdownWidget));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('codelessly-dropdown-menu')),
      findsNothing,
    );
    // The platform menu lists the items, with their plates.
    expect(find.text('Purple urchin'), findsWidgets);
    expect(
      find.byKey(const ValueKey('codelessly-dropdown-item-image')),
      findsWidgets,
    );
  });
}
