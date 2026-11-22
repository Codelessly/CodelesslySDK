// Cards' page words (design_systems/cards/tool/page_words): the parts of an
// app window written in the notation. Each is built, listed in the manifest
// and the one a page calls; a page of them expands without a word at a
// desktop's and at a phone's width; the sidebar is a rail at a tablet's width
// and its words fold there; a page written for a phone is as it was.
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_api/notation.dart';
import 'package:flutter_test/flutter_test.dart';

const _dir = 'design_systems/cards';
const _src = '$_dir/tool/page_words';

Future<DesignSystem> _load(List<String> problems, {String Function(String ref, String text)? change}) => DesignSystem.load((ref) async {
      final file = File('$_dir/$ref');
      if (!file.existsSync()) return null;
      final text = file.readAsStringSync();
      return change == null ? text : change(ref, text);
    }, problems: problems);

Set<String> _words() => Directory('$_src/components')
    .listSync()
    .whereType<File>()
    .where((f) => f.path.endsWith('.txt'))
    .map((f) => f.uri.pathSegments.last.replaceFirst('.txt', ''))
    .toSet();

const _page = '''
state tab="members"
state chosen=["a","b"]
state openId="m1"
App
  Sidebar
    Brand "Northstar" "Admin console" icon="hub"
    SideButton "Invite member" icon="person_add" shortcut="N"
    NavSection "People"
    NavItem "Members" icon="group" badge="50" selected={tab == "members"} onTap={tab="members"}
    NavItem "Sign out" icon="logout" danger
    Footer
      NavItem "Shortcuts" icon="keyboard" shortcut="?"
      Account "Amara Okafor" "Workspace owner"
  Main
    PageHeader "Members" "Everyone with access." overline="People" count="50"
      Button "Invite" icon="add"
    BulkBar count={length(chosen)} noun="members selected" onClear={chosen=[]}
      Button.outline "Change role" size=small
    Panel "Recent sign-ins" "The last 24 hours." action="See all" flush onAction={toast "all"}
      ListRow "Maya Chen" "maya@northline.design" preview="Signed in from Lisbon." meta="2 min ago" avatar="Maya Chen" unread selected={openId == "m1"} onTap={openId="m1"}
      ListRow "Invoice #1042" "PDF, 164 KB" icon="description" starred attachment divider=false
        Badge.success "Paid"
  Pane w=340
    PaneHeader "Maya Chen" "Owner" avatar="Maya Chen" onClose={openId=""}
      IconButton "edit" tooltip="Edit"
''';

void main() {
  test('every page word is built, listed in the manifest and the component a page calls', () async {
    final problems = <String>[];
    final cards = await _load(problems);
    expect(problems, isEmpty);
    final words = _words();
    expect(words, containsAll(['Brand', 'SideButton', 'NavSection', 'NavItem', 'Account', 'PageHeader', 'Panel', 'ListRow', 'BulkBar', 'PaneHeader']));
    final manifest = (jsonDecode(File('$_dir/design_system.json').readAsStringSync()) as Map).cast<String, Object?>();
    final listed = (manifest['components'] as List).cast<String>();
    for (final word in words) {
      const run = 'run python3 design_systems/cards/tool/build.py --no-showcase';
      expect(listed, contains('components/$word.json'), reason: '$word is not in the manifest: $run');
      expect(cards.components.definitions, contains(word));
      // What the build installed is what the sources last expanded to.
      expect(jsonDecode(File('$_dir/components/$word.json').readAsStringSync()), jsonDecode(File('$_src/built/$word.json').readAsStringSync()),
          reason: '$word: components/ is not what tool/page_words/built has: $run');
    }
    // The sidebar's words each have a rail form.
    for (final word in const ['Brand', 'SideButton', 'NavSection', 'NavItem', 'Account']) {
      final props = cards.components[word]!.widget!.props.map((p) => p.key);
      expect(props, contains('rail'), reason: word);
      expect(jsonEncode(cards.components[word]!.toJson()['nodes']), contains('screen.width >= 700 && screen.width < 1024'), reason: word);
    }
    // One set of names with Desk: the same parameters, in the same order, where Desk has the word.
    final desk = await DesignSystem.load((ref) async => File('design_systems/desk/$ref').existsSync() ? File('design_systems/desk/$ref').readAsStringSync() : null);
    for (final word in words) {
      final theirs = desk.components[word]?.widget?.props.map((p) => p.key).toList();
      if (theirs == null) continue;
      final ours = cards.components[word]!.widget!.props.map((p) => p.key).toList();
      expect(ours.take(theirs.length), theirs, reason: '$word takes Desk\'s parameters first, in Desk\'s order');
    }
  });

  test('a page of them expands without a word at 1440 and at 390, each as Cards\' component', () async {
    final cards = await _load([]);
    final catalog = cards.catalogOver(standardCatalog);
    for (final width in const [1440.0, 390.0]) {
      final options = NotationOptions.fromDesignSystem(cards, width: width, named: true);
      final result = Catalog.run(catalog, () => parseNotation(_page, catalog: catalog, options: options));
      expect(result.issues, isEmpty, reason: 'at $width');
      final types = (result.document['nodes'] as Map).values.cast<Map>().map((n) => n['type']).toSet();
      expect(types, containsAll(_words()), reason: 'at $width');
    }
  });

  test('the sidebar is a rail at a tablet\'s width and leaves the window on a phone', () async {
    final manifest = (jsonDecode(File('$_dir/design_system.json').readAsStringSync()) as Map).cast<String, Object?>();
    expect(((manifest['theme'] as Map)['sizes'] as Map)['rail'], 64);
    final cards = await _load([]);
    final catalog = cards.catalogOver(standardCatalog);
    final options = NotationOptions.fromDesignSystem(cards, width: 1440, named: true);
    final result = Catalog.run(catalog, () => parseNotation(_page, catalog: catalog, options: options));
    final nodes = (result.document['nodes'] as Map).values.cast<Map>();
    final sidebar = nodes.firstWhere((n) => n['type'] == 'column' && ((n['children'] as List?)?.any((c) => '$c'.startsWith('Brand')) ?? false));
    expect((sidebar['layout'] as Map)['width'], 248);
    final media = (sidebar['media'] as List).cast<Map>();
    expect(media.any((m) => m['maxWidth'] == 1023 && ((m['patch'] as Map)['layout'] as Map?)?['width'] == 64), isTrue, reason: jsonEncode(media));
    expect(media.any((m) => m['maxWidth'] == 699 && (m['patch'] as Map)['visible'] == false), isTrue, reason: jsonEncode(media));
  });

  test('a page written for a phone is the same with the rail and without it', () async {
    final cards = await _load([]);
    final before = await _load([], change: (ref, text) {
      if (ref != 'design_system.json') return text;
      final manifest = (jsonDecode(text) as Map).cast<String, Object?>();
      ((manifest['theme'] as Map)['sizes'] as Map).remove('rail');
      return jsonEncode(manifest);
    });
    Map<String, Object?> at390(DesignSystem system) {
      final catalog = system.catalogOver(standardCatalog);
      final options = NotationOptions.fromDesignSystem(system, width: 390, named: true);
      return Catalog.run(catalog, () => parseNotation(_page, catalog: catalog, options: options)).document;
    }

    expect(jsonEncode(at390(cards)), jsonEncode(at390(before)));
  });
}
