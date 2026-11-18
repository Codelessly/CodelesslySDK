// Desk (design_systems/desk), the desktop design system: it loads cleanly,
// every component written in the notation is built and listed, its dark
// theme names every colour its light one does, and plain words of the
// notation take its looks (its own NavItem, Dialog and Menu frames, outline
// icons, the sidebar on the chrome).
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_api/notation.dart';
import 'package:flutter_test/flutter_test.dart';

const _dir = 'design_systems/desk';

Future<DesignSystem> _load(List<String> problems) =>
    DesignSystem.load((ref) async => File('$_dir/$ref').existsSync() ? File('$_dir/$ref').readAsStringSync() : null, problems: problems);

void main() {
  test('Desk loads cleanly, with every component its sources write', () async {
    final problems = <String>[];
    final desk = await _load(problems);
    expect(problems, isEmpty);
    expect(desk.id, 'desk');
    final sources = Directory('$_dir/components/src/components')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.txt'))
        .map((f) => f.uri.pathSegments.last.replaceFirst('.txt', ''))
        .toSet();
    expect(desk.components.definitions.keys.toSet(), sources, reason: 'run bash design_systems/desk/tool/build.sh');
    // The words of the notation Desk draws itself.
    for (final word in const ['NavItem', 'NavSection', 'Brand', 'Dialog', 'MenuItem', 'MenuPopover']) {
      expect(desk.components.definitions, contains(word));
    }
  });

  test('its dark theme names every colour its light theme does', () {
    final manifest = (jsonDecode(File('$_dir/design_system.json').readAsStringSync()) as Map).cast<String, Object?>();
    final theme = (manifest['theme'] as Map).cast<String, Object?>();
    final light = (theme['colors'] as Map).keys.toSet();
    final dark = (((theme['dark'] as Map)['colors']) as Map).keys.toSet();
    expect(light.difference(dark), isEmpty);
    expect(theme['iconStyle'], 'outlined');
  });

  test('plain words take its looks', () async {
    final desk = await _load([]);
    final catalog = desk.catalogOver(standardCatalog);
    final options = NotationOptions.fromDesignSystem(desk, width: 1440, named: true);
    final result = Catalog.run(
        catalog,
        () => parseNotation(
            'App\n  Sidebar\n    NavItem "Inbox" icon="inbox" selected=true\n  Main\n    Icon "archive"\n    Toolbar\n      Text "1 of 9"\n',
            catalog: catalog,
            options: options));
    expect(result.issues, isEmpty);
    final nodes = (result.document['nodes'] as Map).values.cast<Map>().toList();
    // Desk's NavItem (on the page, and in the drawer a phone opens).
    expect(nodes.where((n) => n['type'] == 'NavItem'), isNotEmpty);
    final icon = nodes.firstWhere((n) => n['type'] == 'icon');
    expect((icon['props'] as Map)['icon'], 'archive_outlined');
    final sidebar = nodes.firstWhere((n) => jsonEncode(n).contains('"sidebar"'), orElse: () => const {});
    expect(sidebar, isNotEmpty, reason: 'the sidebar is drawn on the theme\'s colors.sidebar');
    // A text written under a Toolbar is laid out as a row's child: as wide as its words.
    final text = nodes.firstWhere((n) => n['type'] == 'text');
    expect(((text['layout'] as Map)['width'] as Map).containsKey('hug'), isTrue);
  });
}
