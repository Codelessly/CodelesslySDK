// Rewrites notation to the grammar codelessly_api reads now.
//
//   dart run tool/notation/migrate.dart <file or folder>... [options]
//       --check                         change nothing; list each file that would change, and each line
//                                       that still writes bind= the tool cannot rewrite; exit 1 when any
//       --stdout                        print the one file instead of rewriting it
//       --design-system <folder>        the blocks the files call (repeatable); without it, every design
//                                       system under the SDK's design_systems/
//       --site <site.json>              the site whose variables the files read (declared there, so no
//                                       state line is added for them); without it, the nearest site.json
//                                       above each file
//       --notation | --markdown | --dart | --python | --json | --html
//                                       read every file as that kind (else by its extension: .txt and
//                                       .notation, .md, .dart, .py, .json, .html; a prompt*.txt or brief*.txt
//                                       is prose, rewritten line by line with no state line)
//       --from 32                       the files are older still (the grammar up to 32.x): rewritten to
//                                       33's first, then to this one's
//
// A folder is every file of a known kind under it (hidden folders, build and
// .dart_tool left out). Each file rewritten says what changed: each line
// before and after, and each state line added.
//
// From 33 to 34 (migrate_bind.dart; the rewrite of a line is codelessly_api's
// notationBindRewrite, which the parser's message for an old line shows too):
//
//   Slider bind=heat min=14 max=24        Slider @heat min=14 max=24
//   Input "Email" bind={email}            Input "Email" @email
//   Slider bind=lo bindEnd=hi             Slider @lo @hi
//   Calendar bind=a bindEnd=b             Calendar @a @b
//   RangeSlider low=a high=b              RangeSlider @a @b
//   Column selectable bind=picked         Column selectable selected=@picked
//   SortMenu bind=sort direction=dir      SortMenu @sort direction=@dir      (a block's variables, from its catalog)
//   Progress bind=done                    Progress value={done}              (a value shown keeps none)
//   Text bind=label                       Text "{label}"
//   Thing bindStart=from                  Thing start=@from                  (a word the notation does not have)
//   define Stepper "label" bind=value     define Stepper "label" @value
//   (a variable a screen binds that nothing declares)
//                                         state heat=14 added at the screen's head (under its ### line, after
//                                         its state lines, else at the top), with the control's empty value
//
// In a Markdown file the fenced blocks of notation (no language, text, txt,
// notation) are rewritten as pages; any other line's notation (a code span, a
// line of prose that writes bind=) line by line, with no state lines. In a
// Dart or Python file, the string literals: one of several lines as a page,
// one of a single line alone. In a JSON file, its strings; in an HTML file,
// its lines. A file of definitions as a design system keeps them (each
// signature at the margin, its lines under it) gets no state lines.
//
// From 32 (the original grammar, --from 32: key:value, =name, key:=expression,
// -> actions, to 33's key=value, key={expression}, bind=name, onTap={actions})
// this file carries its own copy of how the original grammar split a line (at
// its end). It cannot run the old parser, so it cannot check itself: the proof
// that a rewritten file expands to the same document is
// tool/notation/expand_all.dart run on the old files with the old packages and
// on the new with the new, compared with compare_runs.dart.
//
//   =name                         bind=name
//   key:value  key:"text"         key=value  key="text"
//   key:=expression               key={expression}      (also an expression written bare after a key)
//   -> actions                    onTap={actions}       (onChange on a control; a block's own first event)
//   onCta: actions  (own line)    onCta={actions}       on the node's line
//   swipe:left -> actions         onSwipeLeft={actions}
//   drop:group -> actions         drop=group onDrop={actions}
//   every 1s -> actions           every 1s onTick={actions}
//   go lower(result)              go {lower(result)}
//   show:cond  if:cond  when:cond visible={cond}
//   Heading "Why" #why  id:why    Heading "Why" id=why
//   Text.strong row.name          Text.strong "{row.name}"
//   List =rows                    each row in rows
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_api/notation.dart' show notationTypes;

import 'migrate_bind.dart';

Future<void> main(List<String> args) async {
  final paths = <String>[], folders = <String>[];
  String? site, kind, from;
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a == '--design-system' && i + 1 < args.length) {
      folders.add(args[++i]);
    } else if (a == '--site' && i + 1 < args.length) {
      site = args[++i];
    } else if (a == '--from' && i + 1 < args.length) {
      from = args[++i];
    } else if (const {'--notation', '--markdown', '--dart', '--python', '--json', '--html'}.contains(a)) {
      kind = a.substring(2);
    } else if (!a.startsWith('--')) {
      paths.add(a);
    }
  }
  if (paths.isEmpty || (from != null && from != '32')) {
    stderr.writeln('usage: migrate.dart <file or folder>... [--check] [--stdout] [--design-system <folder>]... [--site <site.json>] '
        '[--notation | --markdown | --dart | --python | --json | --html] [--from 32]');
    exit(2);
  }
  final check = args.contains('--check'), print = args.contains('--stdout');
  // The blocks the files call: the design systems given, else the SDK's.
  if (folders.isEmpty) {
    final sdk = File.fromUri(Platform.script).parent.parent.parent;
    final all = Directory('${sdk.path}/design_systems');
    if (all.existsSync()) {
      for (final d in all.listSync()..sort((a, b) => a.path.compareTo(b.path))) {
        if (d is Directory && File('${d.path}/design_system.json').existsSync()) folders.add(d.path);
      }
    }
  }
  var catalog = standardCatalog;
  final catalogs = <Catalog>[];
  for (final dir in folders) {
    final ds = await DesignSystem.load((ref) async {
      final f = File('$dir/$ref');
      return f.existsSync() ? f.readAsStringSync() : null;
    });
    catalog = ds.catalogOver(catalog);
    catalogs.add(ds.catalogOver(standardCatalog));
  }
  final files = <String>[];
  for (final p in paths) {
    if (Directory(p).existsSync()) {
      for (final e in Directory(p).listSync(recursive: true, followLinks: false)) {
        final parts = e.path.replaceAll(r'\', '/').split('/');
        if (e is! File || parts.any((s) => s.startsWith('.') && s.length > 1 || s == 'build' || s == 'node_modules')) continue;
        if (bindKindOf(e.path) != null) files.add(e.path);
      }
    } else {
      files.add(p);
    }
  }
  files.sort();
  var changed = 0, leftLines = 0;
  for (final path in files) {
    final file = File(path);
    if (!file.existsSync()) {
      stderr.writeln('$path: no such file');
      exitCode = 2;
      continue;
    }
    final String text;
    try {
      text = file.readAsStringSync();
    } on FileSystemException {
      stderr.writeln('$path: not text');
      continue;
    }
    // A prompt or a list of briefs kept as .txt is prose that quotes the
    // notation: its lines are rewritten one by one, with no state line.
    final prose = RegExp(r'(^|[\\/])(prompt|briefs?)[^\\/]*\.txt$').hasMatch(path);
    final as = kind ?? (prose ? 'html' : bindKindOf(path));
    if (as == null) {
      stderr.writeln('$path: not a kind of file this reads (.txt, .md, .dart, .py, .json, .html): give --notation or another');
      continue;
    }
    var start = text;
    final log = <String>[];
    if (from == '32') {
      start = switch (as) {
        'dart' => migrateDart(text, catalogs, log),
        'markdown' => migrateMarkdown(text, catalogs, log),
        'notation' => migrateNotation(text, catalogs: catalogs),
        _ => text,
      };
    }
    // A design system's definitions: design_systems/<name>/vocabulary/<Word>.txt.
    final segments = File(path).absolute.path.replaceAll(r'\', '/').split('/');
    final definitionFile = segments.length > 2 && segments[segments.length - 2] == 'vocabulary' && File('${segments.sublist(0, segments.length - 2).join('/')}/design_system.json').existsSync();
    final m = BindMigration(catalog, declared: _siteVariables(site, path), definitionFile: definitionFile);
    final migrated = m.file(start, as);
    log.addAll(m.log);
    final left = BindMigration.left(migrated, as);
    if (print) {
      stdout.write(migrated);
      continue;
    }
    if (migrated != text) changed++;
    if (check) {
      if (migrated != text) stdout.writeln('$path: in the old form (${log.length} change${log.length == 1 ? '' : 's'})');
      for (final l in left) {
        stdout.writeln('$path:$l: still writes bind= after the rewrite: ${migrated.split('\n')[l - 1].trim()}');
      }
      if (migrated != text || left.isNotEmpty) exitCode = 1;
    } else {
      if (migrated != text) file.writeAsStringSync(migrated);
      for (final l in log) {
        stdout.writeln('$path: $l');
      }
      for (final l in left) {
        stdout.writeln('$path:$l: still writes bind=, not rewritten: ${migrated.split('\n')[l - 1].trim()}');
      }
    }
    leftLines += left.length;
  }
  if (!print) stderr.writeln('${files.length} files: $changed ${check ? 'to rewrite' : 'rewritten'}${leftLines == 0 ? '' : ', $leftLines lines still writing bind= to look at'}');
}

/// The variables of the site [path] belongs to: [given]'s site.json, else
/// the nearest one in a folder above it.
final _sites = <String, Set<String>>{};
Set<String> _siteVariables(String? given, String path) {
  File? site = given == null ? null : File(given);
  if (site == null) {
    var dir = File(path).absolute.parent;
    for (var i = 0; i < 6 && site == null; i++) {
      final f = File('${dir.path}/site.json');
      if (f.existsSync()) site = f;
      if (dir.parent.path == dir.path) break;
      dir = dir.parent;
    }
  }
  if (site == null) return const {};
  return _sites.putIfAbsent(site.path, () {
    try {
      final vars = (jsonDecode(site!.readAsStringSync()) as Map)['variables'];
      if (vars is Map) return {for (final k in vars.keys) '$k'};
      if (vars is List) return {for (final v in vars) if (v is Map && v['name'] is String) v['name'] as String};
    } catch (_) {
      // Not a site's manifest: nothing declared.
    }
    return const {};
  });
}

final _nodeHead = RegExp(r'^([A-Za-z][A-Za-z0-9]*)((?:\.[A-Za-z][A-Za-z0-9]*)*)(#[A-Za-z_][A-Za-z0-9_]*)?');
final _lineWords = RegExp(r'^(state|project|let|derived|const|var|if|else|each|for|every|document|node)\b');
final _handlerLine = RegExp(r'^(on[A-Z][A-Za-z]*|tap|press|click|change)\s*:\s*(.+)$');
final _oldHandlerKey = RegExp(r'^(on[A-Z][A-Za-z]*|tap|press|click|change)$');
final _bareState = RegExp(r'^[a-z_][A-Za-z0-9_]*\s*=(?!=)');
final _name = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');
final _bindName = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)*$');
final _notationLine = RegExp(r'^\s*([A-Z][A-Za-z0-9]*([.#][A-Za-z0-9_]+)*(\s|$)|state\s|every\s)');
const _controls = {'slider', 'switch', 'checkbox', 'textField', 'dropdown', 'radio', 'segmentedButton', 'datePicker', 'timePicker', 'pageView'};
const _pageWords = {
  'Page', 'App', 'AppShell', 'Window', 'Section', 'Footer', 'Hero', 'Nav', 'Navbar', 'NavBar', 'TopBar', 'Topbar', 'Header', 'AppBar', 'Sidebar', 'Aside', 'SideNav', 'Sidenav', 'Rail', //
  'Main', 'Content', 'Pane', 'Panel', 'NavItem', 'NavLink', 'SidebarItem', 'MenuItem', 'Badge', 'Brand', 'Logo', 'Search', 'SearchField', 'IconTile', 'Link', 'Heading', 'Title', 'H1', 'H2', 'H3', 'H4',
  'Dialog', 'Modal', 'Sheet', 'BottomSheet', 'Drawer', 'Menu', 'Dropdown', 'Popover', 'Popup', 'Lightbox',
};
const _soft = {'Gauge', 'Dial', 'Ring', 'Sparkline', 'Avatar', 'Donut', 'DonutChart', 'PieChart', 'Pie', 'AreaChart'};

// ---------------------------------------------------------------------------
// From the original grammar (32.x) to 33's (--from 32).
// ---------------------------------------------------------------------------

bool _isNodeLine(String trimmed) =>
    !_lineWords.hasMatch(trimmed) && !_handlerLine.hasMatch(trimmed) && !trimmed.startsWith('->') && !_bareState.hasMatch(trimmed) && _nodeHead.hasMatch(trimmed);

/// Where [what] first is in [line] outside quotes, from [from] (-1: nowhere).
int _outsideQuotes(String line, Pattern what, [int from = 0]) {
  var quoted = false;
  for (var i = 0; i < line.length; i++) {
    if (line[i] == '"' && (i == 0 || line[i - 1] != r'\')) quoted = !quoted;
    if (!quoted && i >= from && what.matchAsPrefix(line, i) != null) return i;
  }
  return -1;
}

/// Where the `{…}` merged into the node starts in [line] (its length when
/// there is none).
int _jsonTail(String line) {
  var quoted = false;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (c == '"' && (i == 0 || line[i - 1] != r'\')) quoted = !quoted;
    if (!quoted && c == '{' && i > 0 && line[i - 1] == ' ' && line.trimRight().endsWith('}')) {
      try {
        if (jsonDecode(line.substring(i)) is Map) return i;
      } catch (_) {}
    }
  }
  return line.length;
}

/// The type a line's first word is, as the original parser found it: a
/// core type (by its short name too), or a block of one of [catalogs].
({String type, WidgetSpec? spec, bool component}) _typeOf(String written, List<Catalog> catalogs) {
  for (final catalog in [...catalogs, standardCatalog]) {
    final short = _soft.contains(written) && catalog.widget(written) != null ? null : notationTypes[written];
    final type = short?.type ?? '${written[0].toLowerCase()}${written.substring(1)}';
    final core = catalog.widget(type);
    if (short != null || core != null) return (type: type, spec: core, component: false);
    final block = catalog.widget(written);
    if (block != null) return (type: written, spec: block, component: true);
  }
  return (type: '${written[0].toLowerCase()}${written.substring(1)}', spec: null, component: false);
}

/// The event `->` ran on a line of [written], by the name it is written with.
String _ownEvent(String written, List<Catalog> catalogs, {required bool drops}) {
  if (drops) return 'onDrop';
  final t = _typeOf(written, catalogs);
  // A word the notation has a plain reading for too (a MenuItem, a Hero) is
  // written the way that reads with and without the design system: onTap,
  // which on a block is what it does when it is used.
  if (t.component) return _pageWords.contains(written) ? 'onTap' : t.spec!.events.firstOrNull?.key ?? 'onTap';
  return _controls.contains(t.type) ? 'onChange' : 'onTap';
}

/// The event a handler written [key] ran on, by the name it is written with.
String _eventOf(String key, String written, List<Catalog> catalogs, {required bool drops}) {
  if (drops) return 'onDrop';
  final t = _typeOf(written, catalogs);
  if (t.component) {
    final events = t.spec!.events;
    final named = events.where((e) => e.key == key).firstOrNull ?? (key == 'change' || key == 'onChange' ? events.where((e) => e.key == 'onChanged').firstOrNull : null) ?? events.firstOrNull;
    if (named != null) return named.key;
  }
  final bare = key.startsWith('on') && key.length > 2 ? '${key[2].toLowerCase()}${key.substring(3)}' : key;
  if (const {'swipeLeft', 'swipeRight', 'swipeUp', 'swipeDown', 'longPress', 'doubleTap'}.contains(bare)) return 'on${bare[0].toUpperCase()}${bare.substring(1)}';
  if (const {'rightClick', 'secondaryClick', 'contextMenu'}.contains(bare)) return 'onRightClick';
  final changes = key == 'change' || key == 'onChange' || key == 'onChanged';
  return changes || _controls.contains(t.type) && !key.contains('ress') && key != 'tap' && key != 'click' ? 'onChange' : 'onTap';
}

/// [actions] with a page that is worked out written in braces.
String _actions(String actions) {
  final parts = <String>[];
  var depth = 0, quoted = false, start = 0;
  for (var i = 0; i <= actions.length; i++) {
    if (i < actions.length) {
      final c = actions[i];
      if (c == '"' && (i == 0 || actions[i - 1] != r'\')) quoted = !quoted;
      if (quoted) continue;
      if (c == '{' || c == '[' || c == '(') depth++;
      if (c == '}' || c == ']' || c == ')') depth--;
      if (!(c == ';' && depth == 0)) continue;
    }
    var part = actions.substring(start, i);
    start = i + 1;
    final go = RegExp(r'^(\s*go\s+)(\S.*?)(\s*)$').firstMatch(part);
    if (go != null) {
      final s = go[2]!;
      final fixed = s.startsWith('"') || _identifier.hasMatch(s) || RegExp(r'^[A-Za-z_][A-Za-z0-9_-]*$').hasMatch(s) || (s.startsWith(r'${') && s.endsWith('}')) || (s.startsWith('{') && s.endsWith('}'));
      if (!fixed) part = '${go[1]}{$s}${go[3]}';
    }
    parts.add(part);
  }
  return parts.join(';');
}

/// The names [actions] set (each is a variable from then on).
Iterable<String> _sets(String actions) =>
    RegExp(r'(?:^|;)\s*([A-Za-z_][A-Za-z0-9_]*)\s*(?:[-+*/]?=(?!=)|\+\+|--|\.(?:add|push|append|remove)\()').allMatches(actions).map((m) => m[1]!);

/// What is known as the lines go by: the variables declared so far and the
/// loops open over a line.
class _Scope {
  final variables = <String>{};
  final loops = <({int indent, String name})>[];

  void at(int indent) => loops.removeWhere((l) => l.indent >= indent);

  /// Whether a word written bare after a key was read as a variable: one
  /// declared, or the element of the loop right over the line when that
  /// loop calls it `item`.
  bool reads(String raw) {
    final head = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*').stringMatch(raw)!;
    final at = loops.indexWhere((l) => l.name == head);
    if (at >= 0) return at == loops.length - 1 && head == 'item';
    if (head == 'item' && loops.isNotEmpty) return false;
    return variables.contains(head);
  }
}

/// Whether [text] holds anything of the original grammar: a `key:value`, an
/// arrow or a `=name` on a line, outside its texts and braces. A text
/// already rewritten holds none, and is left as it is.
bool _isOriginal(String text) {
  for (final raw in const LineSplitter().convert(text)) {
    final t = raw.trim();
    if (t.isEmpty || t.startsWith('//') || t.startsWith('{') || t.startsWith('"')) continue;
    if (_handlerLine.hasMatch(t) || t.startsWith('->')) return true;
    if (_lineWords.hasMatch(t) && !t.startsWith('every ')) continue;
    var bare = t.replaceAll(RegExp(r'"(?:[^"\\]|\\.)*"'), '""');
    for (var before = ''; before != bare;) {
      before = bare;
      bare = bare.replaceAll(RegExp(r'[\[{][^\[\]{}]*[\]}]'), '0');
    }
    if (RegExp(r'\s->(\s|$)|\s[A-Za-z][A-Za-z0-9_-]*:\S|\s:?=[A-Za-z_(!]|\s#[A-Za-z_][A-Za-z0-9_-]*(\s|$)').hasMatch(' $bare')) return true;
  }
  return false;
}

/// [text] in the grammar of 33.0.0.
String migrateNotation(String text, {List<Catalog> catalogs = const []}) {
  if (!_isOriginal(text)) return text;
  final crlf = text.contains('\r\n');
  final lines = text.split('\n').map((l) => l.endsWith('\r') ? l.substring(0, l.length - 1) : l).toList();
  final out = <String>[];
  final scope = _Scope();
  for (var i = 0; i < lines.length; i++) {
    var raw = lines[i];
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed.startsWith('//') || trimmed.startsWith('```')) {
      out.add(raw);
      continue;
    }
    // A node or a document written whole: its JSON, over the lines it takes.
    if (_wholeJsonLine.hasMatch(raw)) {
      var all = raw;
      out.add(raw);
      while (_jsonOpen(all) && i + 1 < lines.length) {
        i++;
        all = '$all\n${lines[i]}';
        out.add(lines[i]);
      }
      continue;
    }
    // An `every` whose actions are on the next line.
    if (RegExp(r'^every\s+\S+').hasMatch(raw) && !raw.contains('->') && !raw.trimRight().endsWith(':') && !RegExp(r'\b(do|on[A-Z])').hasMatch(raw) && i + 1 < lines.length && lines[i + 1].trimLeft().startsWith('->')) {
      raw = '${raw.trimRight()} ${lines[++i].trimLeft()}';
    }
    // A list or a call left open at the end of a line goes on over the next
    // lines: read as the one line it is.
    final from = i;
    if (RegExp(r'[\[(,]\s*$').hasMatch(raw) && _opened(raw) > 0) {
      var all = raw.trimRight();
      var taken = 0;
      while (i + 1 < lines.length && _opened(all) > 0 && taken < 60) {
        i++;
        taken++;
        all = '$all ${lines[i].trim()}';
      }
      raw = all;
    }
    final indent = raw.length - raw.trimLeft().length;
    scope.at(indent);
    final line = _migrateLine(raw, scope, catalogs);
    if (line.handler case (final String key, final String body)) {
      // A handler on a line of its own goes on its node's line: the nearest
      // line above that is further out.
      var at = out.length - 1;
      while (at >= 0) {
        final above = out[at];
        final t = above.trim();
        if (t.isNotEmpty && !t.startsWith('//') && above.length - above.trimLeft().length < indent) break;
        at--;
      }
      if (at >= 0 && _isNodeLine(out[at].trim())) {
        final target = out[at];
        final written = _nodeHead.firstMatch(target.trim())![1]!;
        final event = _eventOf(key, written, catalogs, drops: RegExp(r'\sdrop=').hasMatch(target));
        final tail = _jsonTail(target);
        final head = target.substring(0, tail).trimRight();
        out[at] = '$head $event={$body}${tail < target.length ? ' ${target.substring(tail)}' : ''}';
        continue;
      }
      out.add(raw);
      continue;
    }
    if (line.text == raw && i > from) {
      out.addAll(lines.sublist(from, i + 1));
    } else {
      out.add(line.text);
    }
  }
  return out.join(crlf ? '\r\n' : '\n');
}

/// One line in the new grammar, and, for a handler on a line of its own,
/// its key and its actions.
({String text, (String, String)? handler}) _migrateLine(String raw, _Scope scope, List<Catalog> catalogs) {
  final indent = raw.length - raw.trimLeft().length;
  final margin = raw.substring(0, indent);
  final trimmed = raw.trimRight().substring(indent);
  ({String text, (String, String)? handler}) same() => (text: raw, handler: null);
  ({String text, (String, String)? handler}) now(String text) => (text: '$margin$text' == raw.trimRight() ? raw : '$margin$text', handler: null);
  if (trimmed.isEmpty || trimmed.startsWith('//')) return same();
  // What an action's `value` was called: `result`, unless the text has a variable of that name.
  String statements(String body) => scope.variables.contains('value') ? body : _rename(body, 'value', 'result');

  if (trimmed.startsWith('every ')) {
    var line = trimmed;
    final tick = RegExp(r'^every\s+(\d+(?:\.\d+)?(?:ms|s)?)\s+(?:when|while)\s*:?\s*\{?(.+?)\}?\s*(?:->|on[A-Z][A-Za-z]*\s*:|do\s*:|:)\s*\{?(.+?)\}?$').firstMatch(line);
    if (tick != null && !line.contains('->')) line = 'every ${tick[1]} when ${tick[2]} -> ${statements(tick[3]!)}';
    final every = RegExp(r'^(every\s+\d+(?:\.\d+)?(?:ms|s)?(?:\s+when\s+.+?)?)\s*->\s*(.+)$').firstMatch(line);
    if (every == null) return same();
    final actions = _actions(every[2]!.trim());
    scope.variables.addAll(_sets(actions));
    return now('${every[1]} onTick={$actions}');
  }
  final handler = _handlerLine.firstMatch(trimmed);
  if (handler != null) {
    var body = handler[2]!.trim();
    if (body.startsWith('{') && body.endsWith('}')) body = body.substring(1, body.length - 1).trim();
    final actions = _actions(statements(body));
    scope.variables.addAll(_sets(actions));
    return (text: raw, handler: (handler[1]!, actions));
  }
  // What a line declares, and the loop it opens.
  final declared = RegExp(r'^(?:state|project|let|derived|const|var)\s+([A-Za-z_][A-Za-z0-9_]*)').firstMatch(trimmed) ?? (indent == 0 ? RegExp(r'^([a-z_][A-Za-z0-9_]*)\s*=(?!=)').firstMatch(trimmed) : null);
  if (declared != null && !const {'state', 'let', 'derived', 'const', 'var', 'project'}.contains(declared[1])) scope.variables.add(declared[1]!);
  final loop = RegExp(r'^(?:each|for)\s+(?:[A-Za-z_][A-Za-z0-9_]*\s*,\s*)?([A-Za-z_][A-Za-z0-9_]*)\s+in\s').firstMatch(trimmed);
  if (loop != null) {
    scope.loops.add((indent: indent, name: loop[1]!));
    final stagger = RegExp(r'\sstagger:(\S+)$').firstMatch(trimmed);
    return stagger == null ? same() : now('${trimmed.substring(0, stagger.start)} stagger=${stagger[1]}');
  }
  if (RegExp(r'^each\s+\S+$').hasMatch(trimmed)) {
    scope.loops.add((indent: indent, name: 'row'));
    return same();
  }
  if (_lineWords.hasMatch(trimmed)) return same();
  // `List =rows`: the rows of a list, as the each it is.
  final list = RegExp(r'^List\s+=(\S+)$').firstMatch(trimmed);
  if (list != null) {
    scope.loops.add((indent: indent, name: 'row'));
    return now('each row in ${list[1]}');
  }
  if (!_isNodeLine(trimmed)) return same();

  // Props written after the actions, moved before the arrow, where they were read.
  var line = trimmed;
  final late = RegExp(r'^(.*?)(\s->\s.*?)((?:\s+(?:enabled|visible|selected|disabled|tone|icon):(?:=?\{[^{}]*\}|=\S+|"[^"]*"|[A-Za-z_][A-Za-z0-9_.]*))+)\s*$').firstMatch(line);
  if (late != null) line = '${late[1]}${late[3]}${late[2]}';
  final arrowAt = _outsideQuotes(line, ' -> ');
  if (arrowAt >= 0) {
    final after = line.substring(arrowAt + 4);
    final moved = RegExp(r' [a-z][A-Za-z]*:=').allMatches(after).where((m) => _outsideQuotes(after.substring(0, m.start + 1), '"') < 0 || '"'.allMatches(after.substring(0, m.start)).length.isEven).firstOrNull;
    if (moved != null) line = '${line.substring(0, arrowAt)}${after.substring(moved.start)} -> ${after.substring(0, moved.start)}';
  }
  // A value written bare where a text goes (Text.strong row.name) is that value shown.
  final bareText = RegExp(r'^((?:Text|Avatar|Heading|Badge|Button)(?:[.#][\w.#]*)?)\s+([a-z_]\w*(?:\.[A-Za-z_]\w*)+)(?=\s|$)').firstMatch(line);
  if (bareText != null) line = '${bareText[1]} "{${bareText[2]}}"${line.substring(bareText.end)}';

  final head = _nodeHead.firstMatch(line)!;
  final written = head[1]!;
  final type = _typeOf(written, catalogs);
  // Read as the parser read it, 'single quotes' as "double" (the same
  // length: what is written out is taken from the line itself).
  final t = _Tokens(line.contains("'") ? _doubleQuoted(line) : line)..at = head.end;
  final out = StringBuffer(line.substring(0, head.end));
  var copied = head.end;
  void copy(int to) {
    out.write(line.substring(copied, to));
    copied = to;
  }

  String? swipe;
  var drops = false;
  while (true) {
    t.skipSpace();
    if (t.done) break;
    final from = t.at;
    if (t.rest.startsWith(':=')) t.at++;
    if (t.peek == '"') {
      t.string();
    } else if (t.rest.startsWith('->')) {
      t.at += 2;
      final rest = line.substring(t.at);
      final end = _jsonTail(' $rest') - 1;
      final actions = _actions(rest.substring(0, end).trim());
      scope.variables.addAll(_sets(actions));
      final event = swipe ?? _ownEvent(written, catalogs, drops: drops);
      copy(from);
      out.write('$event={$actions}${end < rest.length ? ' ' : ''}');
      swipe = null;
      t.at += end;
      copied = t.at;
    } else if (t.peek == '{') {
      break;
    } else if (t.peek == '=') {
      t.at++;
      final start = t.at;
      t.expression();
      final expr = line.substring(start, t.at).trim();
      if (expr.isEmpty || expr.startsWith('=')) continue;
      copy(from);
      out.write(_bindName.hasMatch(expr) ? 'bind=$expr' : 'bind={$expr}');
      copied = t.at;
      if (_name.hasMatch(expr)) scope.variables.add(expr);
    } else {
      // An expression where the string goes (`Button open ? "Hide" : "Show"`).
      final bare = t.expression();
      if (bare.contains(' ') && bare.contains('?') && !RegExp(r'^[A-Za-z]+:').hasMatch(bare)) {
        final expr = line.substring(from, t.at).trim();
        copy(from);
        out.write(type.type == 'text' ? 'bind={$expr}' : '"{$expr}"');
        copied = t.at;
        continue;
      }
      t.at = from;
      final word = t.word();
      if (word.isEmpty) {
        t.at++;
        continue;
      }
      final colon = word.indexOf(':');
      if (colon < 0) {
        // An anchor written after the text (`Heading "Why" #why`).
        if (RegExp(r'^#[A-Za-z_][A-Za-z0-9_-]*$').hasMatch(word)) {
          copy(from);
          out.write('id=${word.substring(1)}');
          copied = t.at;
        } else if (type.component && !const {'grow', 'fill', 'hidden', 'sticky'}.contains(word) && !type.spec!.props.any((p) => p.key == word)) {
          // On a block's line: key=value where key:=value was meant, and a
          // bare word that is the value of its one enumerated parameter.
          final eq = word.indexOf('=');
          if (eq > 0 && type.spec!.props.any((p) => p.key == word.substring(0, eq))) {
            final value = word.substring(eq + 1);
            if (!_isLiteral(value)) {
              copy(from + eq + 1);
              out.write('{$value}');
              copied = t.at;
            }
          } else if (eq < 0) {
            final takers = type.spec!.props.where((p) => p.type.kind == PropKind.enumeration && p.type.values.contains(word)).toList();
            if (takers.length == 1) {
              copy(from);
              out.write('${takers.single.key}=$word');
              copied = t.at;
            }
          }
        }
        continue;
      }
      var key = word.substring(0, colon);
      final sizeWord = (key == 'show' || key == 'hide') && const {'phone', 'mobile', 'tablet', 'desktop'}.contains(word.substring(colon + 1));
      final isProp = type.spec?.props.any((p) => p.key == key) ?? false;
      // A parameter named like a handler (a quote's change:1.84) is the parameter.
      final plainValue = _isLiteral(word.substring(colon + 1)) && !key.startsWith('on');
      if (_oldHandlerKey.hasMatch(key) && !isProp && !plainValue) {
        t.at = from + colon + 1;
        t.skipSpace();
        String body;
        if (t.peek == '{') {
          final open = t.at;
          t.balanced();
          body = line.substring(open + 1, t.at - 1);
        } else if (t.peek == '"') {
          body = t.string();
        } else {
          body = line.substring(t.at);
          t.at = line.length;
        }
        final actions = _actions(statements(body));
        scope.variables.addAll(_sets(actions));
        copy(from);
        out.write('${_eventOf(key, written, catalogs, drops: drops)}={$actions}');
        copied = t.at;
        continue;
      }
      // The key, with = for its colon.
      void keyAs(String name) {
        copy(from);
        out.write('$name=');
        copied = from + colon + 1;
      }

      if (key == 'if' || key == 'when' || (key == 'show' && !sizeWord)) {
        key = 'visible';
      } else if (key == 'anchor') {
        key = 'id';
      }
      var value = word.substring(colon + 1);
      final valueAt = from + colon + 1;
      bool odd(Pattern p, String s) => p.allMatches(s).length.isOdd;
      void more() => t.expression(opened: _opened(value), quoted: odd('"', value), single: odd(RegExp(r"(?<![A-Za-z0-9])'"), value));
      // The value, in braces: an expression.
      void braced(int exprAt) {
        keyAs(key);
        final expr = line.substring(exprAt, t.at);
        out.write(_bracedExpression(expr) || _bracedValue.hasMatch(expr) ? expr : '{$expr}');
        copied = t.at;
      }

      if (key == 'swipe' && const {'left', 'right', 'up', 'down'}.contains(value) && _outsideQuotes(line, ' -> ', t.at) >= 0 && swipe == null) {
        // Left out here; the arrow that follows is written as its handler.
        var start = from;
        while (start > copied && line[start - 1] == ' ') {
          start--;
        }
        copy(start);
        copied = t.at;
        swipe = 'onSwipe${value[0].toUpperCase()}${value.substring(1)}';
        continue;
      }
      if (key == 'drop') drops = true;
      if (value.startsWith('=')) {
        more();
        if (t.at == valueAt + 1) {
          keyAs(key);
          continue;
        }
        braced(valueAt + 1);
        continue;
      }
      if (value.isEmpty && t.peek == '"') {
        keyAs(key);
        t.string();
        continue;
      }
      if (value.isEmpty && (t.peek == '[' || t.peek == '{')) {
        value = t.balanced();
        if (_operatorAhead.matchAsPrefix(t.s, t.at) != null) {
          more();
          braced(valueAt);
        } else if (_bracedValue.hasMatch(value) || _bracedExpression(value)) {
          keyAs(key);
        } else {
          try {
            jsonDecode(value);
            keyAs(key);
          } catch (_) {
            // A list holding expressions (votes:[a+1,b]): the formula it was read as.
            braced(valueAt);
          }
        }
        continue;
      }
      // An expression written bare goes on past its spaces (key:count > 0).
      if (!value.startsWith('"') && value.isNotEmpty && _operatorAhead.matchAsPrefix(t.s, t.at) != null) {
        more();
        braced(valueAt);
      } else if (value.startsWith('(') && !_isLiteral(value)) {
        more();
        braced(valueAt);
      } else if (key != 'drag' && key != 'drop' && _expressionStart.hasMatch(value) && !_isLiteral(value)) {
        more();
        braced(valueAt);
      } else if (value != 'fill' && value != 'hug' && !sizeWord && _variablePath.hasMatch(value) && !_isLiteral(value) && scope.reads(value) &&
          !(type.spec?.props.any((p) => p.key == key && p.type.kind == PropKind.enumeration && p.type.values.contains(value)) ?? false)) {
        // A bare word that was a variable the text had declared.
        braced(valueAt);
      } else {
        keyAs(key);
      }
    }
  }
  copy(line.length);
  return now('$out');
}

bool _isLiteral(String raw) => raw == 'true' || raw == 'false' || raw == 'null' || num.tryParse(raw) != null || raw.startsWith('"') && raw.endsWith('"') && raw.length >= 2;

/// The notation inside a Dart file's string literals.
String migrateDart(String source, List<Catalog> catalogs, List<String> log) {
  final out = StringBuffer();
  var i = 0;
  while (i < source.length) {
    final c = source[i];
    if (source.startsWith('//', i)) {
      final end = source.indexOf('\n', i);
      final to = end < 0 ? source.length : end;
      out.write(source.substring(i, to));
      i = to;
      continue;
    }
    if (c != "'" && c != '"') {
      out.write(c);
      i++;
      continue;
    }
    final raw = i > 0 && source[i - 1] == 'r' && (i < 2 || !RegExp(r'[A-Za-z0-9_]').hasMatch(source[i - 2]));
    final triple = source.startsWith(c * 3, i);
    final quote = triple ? c * 3 : c;
    var j = i + quote.length;
    while (j < source.length && !source.startsWith(quote, j)) {
      if (!raw && source[j] == r'\') j++;
      if (!raw && source.startsWith(r'${', j)) {
        var depth = 0;
        while (j < source.length) {
          if (source[j] == '{') depth++;
          if (source[j] == '}' && --depth == 0) break;
          j++;
        }
      }
      j++;
    }
    final body = source.substring(i + quote.length, j);
    final lines = triple || raw ? body : body.replaceAll(r'\n', '\n');
    var next = body;
    if (lines.split('\n').any(_notationLine.hasMatch)) {
      final migrated = migrateNotation(lines, catalogs: catalogs);
      if (migrated != lines) {
        next = triple || raw ? migrated : migrated.replaceAll('\n', r'\n');
        log.add('a literal: ${next.length > 100 ? '${next.substring(0, 100)}…' : next}'.replaceAll('\n', r'\n'));
      }
    }
    out.write('$quote$next$quote');
    i = j + quote.length;
  }
  return out.toString();
}

/// The notation in a Markdown file: its fenced blocks (no language, `text`
/// or `notation`) and the code spans that are a line of notation.
String migrateMarkdown(String source, List<Catalog> catalogs, List<String> log) {
  final crlf = source.contains('\r\n');
  final lines = source.replaceAll('\r\n', '\n').split('\n');
  final out = <String>[];
  for (var i = 0; i < lines.length; i++) {
    final fence = RegExp(r'^(\s*)(```+|~~~+)\s*(\w*)\s*$').firstMatch(lines[i]);
    if (fence != null) {
      final end = lines.indexWhere((l) => l.trim() == fence[2], i + 1);
      if (end < 0) {
        out.add(lines[i]);
        continue;
      }
      final body = lines.sublist(i + 1, end);
      out.add(lines[i]);
      if (const {'', 'text', 'notation', 'txt'}.contains(fence[3]) && body.any(_notationLine.hasMatch)) {
        final migrated = migrateNotation(body.join('\n'), catalogs: catalogs);
        if (migrated != body.join('\n')) log.add('the block at line ${i + 2}');
        out.addAll(migrated.split('\n'));
      } else {
        out.addAll(body);
      }
      out.add(lines[end]);
      i = end;
      continue;
    }
    out.add(lines[i].replaceAllMapped(RegExp(r'`([^`\n]+)`'), (m) {
      final span = m[1]!;
      if (!_notationLine.hasMatch(span)) return m[0]!;
      final migrated = migrateNotation(span, catalogs: catalogs);
      if (migrated != span) log.add('line ${i + 1}: `$migrated`');
      return '`$migrated`';
    }));
  }
  return out.join(crlf ? '\r\n' : '\n');
}

// ---------------------------------------------------------------------------
// How the original grammar split a line into words: copied from
// codelessly_api's lib/src/core/notation (notation.dart, page_words.dart) as
// they were at 32.x, unchanged but for being top-level here.
// ---------------------------------------------------------------------------

final _wholeJsonLine = RegExp(r'^\s*(?:node(?:#[A-Za-z_][A-Za-z0-9_]*)?|document)\s*\{');

bool _jsonOpen(String s) {
  var depth = 0, quoted = false;
  for (var i = s.indexOf('{'); i >= 0 && i < s.length; i++) {
    final c = s[i];
    if (quoted) {
      if (c == r'\') {
        i++;
      } else if (c == '"') {
        quoted = false;
      }
    } else if (c == '"') {
      quoted = true;
    } else if (c == '{' || c == '[') {
      depth++;
    } else if (c == '}' || c == ']') {
      depth--;
    }
  }
  return depth > 0 || quoted;
}

final _operatorAhead = RegExp(r' +(==|!=|>=|<=|&&|\|\||[<>?+*/]|-(?!>)|and\b|or\b) *[A-Za-z0-9_("!\x27-]');

final _bracedValue = RegExp(r'^\{[^{}":,]+\}$');

int _opened(String raw) {
  var depth = 0, quoted = false;
  for (var i = 0; i < raw.length; i++) {
    final c = raw[i];
    if (c == '"' && (i == 0 || raw[i - 1] != r'\')) quoted = !quoted;
    if (quoted) continue;
    if (c == '(' || c == '[' || c == '{') depth++;
    if (c == ')' || c == ']' || c == '}') depth--;
  }
  return depth;
}

bool _bracedExpression(String raw) {
  if (!raw.startsWith('{') || !raw.endsWith('}') || raw.length < 3) return false;
  if (RegExp(r'^\{\s*("[^"]*"|[A-Za-z_][A-Za-z0-9_]*)\s*:').hasMatch(raw)) return false;
  try {
    jsonDecode(raw);
    return false;
  } catch (_) {
    return true;
  }
}

final _expressionStart = RegExp(r'^(![A-Za-z_(]|[A-Za-z_][A-Za-z0-9_.\[\]]*(\(|==|!=|>=|<=|>|<|&&|\|\||\?|\+|\*))');

final _variablePath = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*|\[[^\]\s]*\])*$');

final _identifier = RegExp(r'^[A-Za-z_][A-Za-z0-9_.]*$');

String _rename(String line, String name, [String to = 'item']) {
  // A short loop name may also be a layout key (`each h ... Text ... h:120`).
  // A key followed by ':' is notation, not a reference to the item.
  final word = RegExp('(?<![A-Za-z0-9_.#])${RegExp.escape(name)}(?![A-Za-z0-9_])');
  final out = StringBuffer();
  var quoted = false, inner = false, depth = 0, start = 0;
  void flush(int end, bool code) {
    final part = line.substring(start, end);
    out.write(code
        ? part.replaceAllMapped(word, (m) {
            // In `h:120` the `h` is a prop key. In `live ? h:4` it
            // is still the loop value, despite the following colon.
            final before = part.substring(0, m.start).trimRight();
            final key = m.end < part.length && part[m.end] == ':' &&
                (m.start == 0 || RegExp(r'\s').hasMatch(part[m.start - 1])) &&
                !before.endsWith('?');
            return key ? m[0]! : to;
          })
        : part);
    start = end;
  }

  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (c == '"' && quoted && depth > 0) {
      // A text inside an expression inside a text: "{late ? "Late" : name}".
      flush(i, !inner);
      inner = !inner;
    } else if (inner) {
      continue;
    } else if (c == '"' && (i == 0 || line[i - 1] != r'\')) {
      flush(i, !quoted || depth > 0);
      quoted = !quoted;
      depth = 0;
    } else if (quoted && c == '{') {
      if (depth == 0) flush(i, false);
      depth++;
    } else if (quoted && c == '}' && depth > 0) {
      depth--;
      if (depth == 0) flush(i, true);
    }
  }
  flush(line.length, !quoted);
  return out.toString();
}

String _doubleQuoted(String t) {
  final out = StringBuffer();
  var inDouble = false;
  for (var i = 0; i < t.length; i++) {
    final c = t[i];
    if (inDouble) {
      out.write(c);
      if (t.codeUnitAt(i) == 0x5C && i + 1 < t.length) {
        out.write(t[++i]);
      } else if (c == '"') {
        inDouble = false;
      }
      continue;
    }
    if (c == '"') {
      inDouble = true;
      out.write(c);
      continue;
    }
    if (c == "'") {
      final end = t.indexOf("'", i + 1);
      final before = i == 0 ? ' ' : t[i - 1];
      if (end > i && !t.substring(i + 1, end).contains('"') && '=(,?:[!<>+&| '.contains(before)) {
        out.write('"${t.substring(i + 1, end)}"');
        i = end;
        continue;
      }
    }
    out.write(c);
  }
  return out.toString();
}

class _Tokens {
  _Tokens(this.s);
  final String s;
  int at = 0;

  bool get done => at >= s.length;
  String get peek => done ? '' : s[at];
  String get rest => done ? '' : s.substring(at);

  void skipSpace() {
    while (!done && s[at] == ' ') {
      at++;
    }
  }

  /// A quoted string at the cursor (JSON escapes).
  String string() {
    final start = at;
    at++;
    var braced = false;
    while (!done && !(s[at] == '"' && s[at - 1] != r'\')) {
      // {an expression} may hold quotes of its own ("{plan=="pro" ? "$9" : "$0"}").
      if (s[at] == '{') {
        final close = _closeOf(at);
        if (close > at) {
          braced = braced || s.substring(at, close).contains('"');
          at = close;
        }
      }
      at++;
    }
    at++;
    final raw = s.substring(start, at > s.length ? s.length : at);
    if (braced) {
      return raw.substring(1, raw.endsWith('"') && raw.length > 1 ? raw.length - 1 : raw.length).replaceAll(r'\"', '"').replaceAll(r'\\', r'\');
    }
    try {
      return jsonDecode(raw.endsWith('"') && raw.length > 1 ? raw : '$raw"') as String;
    } catch (_) {
      return raw.replaceAll('"', '');
    }
  }

  /// Where the `{` at [open] closes on this line (quotes inside it paired),
  /// or -1.
  int _closeOf(int open) {
    var depth = 0, quoted = false;
    for (var i = open; i < s.length; i++) {
      final c = s[i];
      if (c == '"' && s[i - 1] != r'\\') quoted = !quoted;
      if (quoted) continue;
      if (c == '{') depth++;
      if (c == '}' && --depth == 0) return quoted ? -1 : i;
    }
    return -1;
  }

  static final _opAhead = RegExp(r' +(&&|\|\||\?|:(?![=A-Za-z])|==|!=|>=|<=|[<>+*/%]|-(?!>)|(?:and|or)(?= ))');
  static final _opBehind = RegExp(r'(&&|\|\||\?|[^A-Za-z0-9_"\])]:|==|!=|>=|<=|[<>+*/%]|(?:^| )(?:and|or|not))$');

  /// Up to the next space (a `key:"quoted value"` stops before its quote).
  String word() {
    final start = at;
    while (!done && s[at] != ' ') {
      if (s[at] == '"' || ((s[at] == '[' || s[at] == '{') && at > start && s[at - 1] == ':')) break;
      at++;
    }
    return s.substring(start, at);
  }

  /// The rest of an expression: to the next space outside quotes and
  /// brackets (`to!=""&&len(subject)>0`).
  String expression({int opened = 0, bool quoted = false, bool single = false}) {
    final start = at;
    var depth = opened;
    while (!done) {
      final c = s[at];
      if (c == '"' && !single && (at == 0 || s[at - 1] != r'\')) quoted = !quoted;
      // 'Living Room' in an expression is one value, its space included
      // (an apostrophe inside a word, don't, is not a quote).
      if (c == "'" && !quoted && (single || at == start || !RegExp(r'[A-Za-z0-9]').hasMatch(s[at - 1]))) single = !single;
      if (!quoted && !single) {
        if (c == '(' || c == '[' || c == '{') depth++;
        if (c == ')' || c == ']' || c == '}') depth--;
        if (c == ' ' && depth <= 0) {
          // An operator on either side of the space carries on
          // (`a!="" && b!=""`, `open ? "Hide" : "Show"`).
          final ahead = _opAhead.matchAsPrefix(s, at);
          if (ahead != null) {
            at = ahead.end;
            continue;
          }
          if (at > start && (_opBehind.hasMatch(s.substring(start, at)) || s[at - 1] == ':' && s.substring(start, at).contains('?'))) {
            while (!done && s[at] == ' ') {
              at++;
            }
            continue;
          }
          break;
        }
      }
      at++;
    }
    return s.substring(start, at);
  }

  /// A bracketed value at the cursor, to its matching close.
  String balanced() {
    final start = at;
    var depth = 0, quoted = false;
    while (!done) {
      final c = s[at];
      if (c == '"' && s[at - 1] != r'\') quoted = !quoted;
      if (!quoted) {
        if (c == '[' || c == '{') depth++;
        if (c == ']' || c == '}') depth--;
      }
      at++;
      if (depth == 0) break;
    }
    return s.substring(start, at);
  }

  /// Up to the first of [stops] outside quotes (or the end).
  String until(List<String> stops) {
    final start = at;
    var quoted = false;
    while (!done) {
      if (s[at] == '"') quoted = !quoted;
      if (!quoted && stops.any((x) => s.startsWith(x, at))) break;
      at++;
    }
    return s.substring(start, at);
  }
}
