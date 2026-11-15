// What the storyboard lists: the running app and each generated screen for
// each person as pages (the viewer puts a page in a phone frame, and a
// subcategory's header shows its pages side by side), and one flow.
import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../skip/skip_flow.dart';
import '../../skip/skip_screen.dart';
import '../../skip_app.dart';
import '../models/storyboard_item.dart';

/// The route of the story of [screen] for [person].
String storyRoute(String screen, String person) => '/page_${screen}_$person';

/// The route of the running app.
const String runRoute = '/page_run';

/// The route of the flow.
const String sessionFlowRoute = '/flow_session';

String _named(String s) => s[0].toUpperCase() + s.substring(1);

/// The person and the screen a story's route names, or null for another item.
({String person, String screen})? storyOf(StoryboardItem? item) {
  if (item == null) return null;
  for (final p in people.keys) {
    for (final s in screens) {
      if (item.route == storyRoute(s, p)) return (person: p, screen: s);
    }
  }
  return null;
}

/// The person a subcategory of Pages is for, or null.
String? personOfSubcategory(String name) => people.keys.where((p) => _named(p) == name).firstOrNull;

const _icons = {'home': LucideIcons.house, 'history': LucideIcons.chart_column, 'session': LucideIcons.timer};

/// The subcategories of Pages, in this order.
List<String> getSubcategoryOrder() => ['App', for (final p in people.keys) _named(p)];

List<StoryboardCategory> getStoryboardCategories() => [
  StoryboardCategory(name: 'Flows', items: getFlowItems()),
  StoryboardCategory(name: 'Pages', items: getPageItems()),
];

/// The running app, then the stories: one per generated screen and person,
/// grouped by person. A person is the thing that varies, and their three
/// screens are one app, so the header of a group shows that app whole.
List<StoryboardItem> getPageItems() => [
  StoryboardItem(
    name: 'Run the app',
    route: runRoute,
    icon: LucideIcons.play,
    category: 'Pages',
    subcategory: 'App',
    filePath: 'lib/skip_app.dart',
    builder: () => const Detached(child: RunScreen()),
  ),
  for (final p in people.keys)
    for (final s in screens)
      StoryboardItem(
        name: '${_named(s)}, ${_named(p)}',
        route: storyRoute(s, p),
        icon: _icons[s]!,
        category: 'Pages',
        subcategory: _named(p),
        filePath: 'assets/screens/$s.$p.json',
        builder: () => Detached(
          key: ValueKey('story-$s-$p'),
          child: SkipScreen(screen: s, person: p),
        ),
      ),
];

List<StoryboardItem> getFlowItems() => [
  StoryboardItem(
    name: 'A session, start to finish',
    route: sessionFlowRoute,
    icon: LucideIcons.git_branch,
    category: 'Flows',
    builder: () => const Detached(child: SessionFlowPage()),
  ),
];
