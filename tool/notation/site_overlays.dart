// Overlays per page: what site expansion does when two pages of a site give
// one overlay id (`Drawer#nav` on the board page and on the list page) and
// the two draw differently.
//
// A page and its overlays are screens of the whole site: an `open nav`
// opens the one canvas `nav` the site has, so two pages' `Drawer#nav` were
// one (the board's drawer showed the archive page's sidebar: test 9,
// kanban 9). Overlays that draw the same on every page that writes them
// (one shortcuts dialog written on each) stay that one shared overlay. Two
// that draw differently are each made the page's own: page board's `nav`
// becomes `nav--board` ([pageScopedId]), and every action of that page that
// names it (`open nav`, `go nav`, `confirm … dialog=nav`) names the new id.
// A notation id is letters, digits and `_` in parts joined by one hyphen
// (`m-logo`), so no id a writer writes has `--`: the new id is no writer's.
// The one id it could meet is a page's (a page file `nav--board.txt`); that
// is said, and that page's overlay is left as written.
//
// The canvas keeps the id as written as its `name`, so a render step may
// still name it as written on that page (`--tap nav/close`), and `print`
// gives the page back as written ([unscopeOverlays]).
//
// A component's `open nav` (its JSON is one for the whole site) cannot name
// one page's overlay: it becomes an event of the component
// (`componentEvent` "open--nav", the action itself its value, so its
// parameters are read where it runs), every call of a component that has it
// (and every call of a component that calls one, which passes it on) reacts
// to it, and a page's call opens that page's own overlay. A page that calls
// such a component and writes no `nav` while other pages write differing
// ones has no overlay to open: that is said, naming the component, the id
// and the pages.
import 'dart:convert';

import 'package:codelessly_api/codelessly_api.dart';

/// The id page [page]'s overlay [id] is given when it is made the page's
/// own: `nav--board`.
String pageScopedId(String id, String page) => '$id--$page';

/// The id as written of canvas [id] of a page whose canvas is [page] when
/// it is one made the page's own ([pageScopedId]) and its node [canvas]
/// keeps the written id as its name; else null.
String? writtenOverlayId(String id, String page, Json? canvas) {
  final name = readString(canvas?['name']);
  if (canvas?['type'] != 'canvas' || name == null || name.isEmpty) return null;
  return id == pageScopedId(name, page) ? name : null;
}

/// The events a component is given for an action naming a per-page overlay
/// (`open--nav`, `go--nav`, `open--nav--2`): no writer's event has `--`.
final _eventForm = RegExp(r'^(open|go)--');

/// Whether [event] is one [scopeOverlays] gave a component.
bool isOverlayEvent(String? event) => event != null && _eventForm.hasMatch(event);

/// One page of a site: its name (its canvas id), its source file and its
/// document (changed in place).
typedef ScopedPage = ({String name, String path, Json document});

/// One notation component of a site: its type, its source file and its
/// document (changed in place).
typedef ScopedComponent = ({String type, String path, Json document});

/// What [scopeOverlays] did and what it could not do.
final class OverlayScoping {
  /// The overlays made per page: written id → page → new id.
  final Map<String, Map<String, String>> renamed = {};

  /// What could not be done or must be said, each with the file it is about.
  final List<({String path, String message})> issues = [];

  /// The written id of each event given to the components (`open--nav` →
  /// `nav`).
  final Map<String, String> events = {};
}

const _common = {'when', 'enabled', 'nonBlocking'};

/// Makes the overlays of [pages] that two or more pages write with one id
/// and draw differently each page's own, and what names them follow (see
/// the head of this file). [components] are the site's notation components
/// (changed too); [otherComponents] the types of the site's components that
/// are not (JSON ones): an `open` of a per-page overlay in one of those is
/// said. [pages] and [components] hold documents changed in place.
OverlayScoping scopeOverlays(List<ScopedPage> pages, List<ScopedComponent> components,
    {Map<String, ({String path, Json document})> otherComponents = const {}}) {
  final out = OverlayScoping();
  final pageNames = {for (final p in pages) p.name};
  // The pages that write each overlay id.
  final written = <String, List<ScopedPage>>{};
  for (final p in pages) {
    final roots = readStrings(p.document['roots']);
    final nodes = readMap(p.document['nodes']) ?? const {};
    for (final id in roots.skip(1)) {
      if (readMap(nodes[id])?['type'] != 'canvas') continue;
      if (pageNames.contains(id) && id != p.name) {
        out.issues.add((
          path: p.path,
          message: 'the overlay "$id" has the id of the page $id: a page and its overlays are screens of the whole site, so the two are one '
              'and only one of them is shown. Give this one an id of its own.',
        ));
        continue;
      }
      written.putIfAbsent(id, () => []).add(p);
    }
  }
  // The overlay ids each component names, its own and those of the
  // components it calls.
  final opens = <String, Set<String>>{
    for (final c in components) c.type: _named(c.document),
    for (final e in otherComponents.entries) e.key: _named(e.value.document),
  };
  final called = {
    for (final c in components) c.type: _callTypes(c.document, opens.keys.toSet()),
    for (final e in otherComponents.entries) e.key: _callTypes(e.value.document, opens.keys.toSet()),
  };
  for (var grew = true; grew;) {
    grew = false;
    for (final t in opens.keys) {
      for (final callee in called[t]!) {
        for (final id in opens[callee]!) {
          grew = opens[t]!.add(id) || grew;
        }
      }
    }
  }
  // Which overlays draw otherwise on two pages: what an overlay names that
  // is a page's own (an `open` of it, a call of a component that opens it)
  // is that page's, so one that names such an overlay draws otherwise too.
  final differ = <String>{};
  for (var grew = true; grew;) {
    grew = false;
    for (final e in written.entries) {
      if (e.value.length < 2 || differ.contains(e.key)) continue;
      final drawn = {
        for (final p in e.value)
          _drawn(readMap(p.document['nodes']) ?? const {}, e.key, mark: (v) {
            if (v is String && differ.contains(v)) return '$v@${p.name}';
            if (v is Map && (opens[v['type']]?.any(differ.contains) ?? false)) return {...v, '@page': p.name};
            return null;
          }),
      };
      if (drawn.length > 1) grew = differ.add(e.key);
    }
  }
  final allIds = {...pageNames, ...written.keys};
  for (final id in differ) {
    final perPage = <String, String>{};
    final e = MapEntry(id, {for (final p in written[id]!) p.name: p});
    for (final page in e.value.keys) {
      final to = pageScopedId(e.key, page);
      if (allIds.contains(to)) {
        out.issues.add((
          path: pages.firstWhere((p) => p.name == page).path,
          message: 'the overlay "${e.key}" draws otherwise on ${_list(e.value.keys.where((x) => x != page))}, so each page is given its own, '
              'but this page\'s would be "$to", which is the id of a page: it is left "${e.key}", one screen with theirs. '
              'Rename the page $to, or give this overlay an id of its own.',
        ));
        continue;
      }
      perPage[page] = to;
    }
    if (perPage.isNotEmpty) out.renamed[e.key] = perPage;
  }
  if (out.renamed.isEmpty) return out;

  // The pages: each overlay made its own, and what names it.
  for (final p in pages) {
    final map = {
      for (final e in out.renamed.entries)
        if (e.value[p.name] case final String to) e.key: to,
    };
    if (map.isEmpty) continue;
    _renameCanvases(p.document, map);
    _renameReferences(p.document, map, (field, value) {
      out.issues.add((
        path: p.path,
        message: 'an action\'s $field is worked out ($value) and may name the overlay ${_list(map.keys.where((id) => value.contains("'$id'") || value.contains('"$id"')))}, '
            'which this page has as its own (${_list(map.entries.where((e) => value.contains("'${e.key}'") || value.contains('"${e.key}"')).map((e) => e.value))}): '
            'the expression is left as written. Name the overlay by its id (open ${map.keys.first}), or write the new id in it.',
      ));
    });
  }

  // The components: an action that names a per-page overlay is an event of
  // the component, and its calls answer it.
  final types = {for (final c in components) c.type};
  final own = <String, Set<String>>{}; // type → events it fires itself
  final opener = <String, Set<String>>{}; // event → the components that fire it
  final templates = <String, String>{}; // id|action → event
  final values = <String, Json>{}; // event → the action it stands for
  for (final c in components) {
    final fired = own[c.type] = <String>{};
    _eventize(c.document, out.renamed.keys.toSet(), (action) {
      final id = readString(action['to']) ?? '';
      final verb = action['type'] == OpenModalAction.typeName ? 'open' : 'go';
      final key = '$id|${jsonEncode(_sorted(action))}';
      final event = templates[key] ??= () {
        var name = '$verb--$id';
        for (var i = 2; out.events.containsKey(name); i++) {
          name = '$verb--$id--$i';
        }
        out.events[name] = id;
        values[name] = action;
        return name;
      }();
      fired.add(event);
      opener.putIfAbsent(event, () => {}).add(c.type);
      return event;
    }, (what, id) {
      out.issues.add((
        path: c.path,
        message: switch (what) {
          'confirm' || 'base' => 'the component ${c.type} ${what == 'confirm' ? 'confirms with the dialog' : 'goes to a page over'} "$id", which pages '
              '${_list(out.renamed[id]!.keys)} each have as their own (they draw it differently): a component is one for the whole site, so it cannot name '
              'one page\'s, and this is left as written. Have it emit an event and do this on each page (onEvent={…}).',
          _ => 'the component ${c.type} reads the result of the overlay "$id" (an action after its open reads result), which pages '
              '${_list(out.renamed[id]!.keys)} each have as their own: the page opens it for the component, so the result does not come back. '
              'Have the component emit an event, and open "$id" and act on its result on each page.',
        },
      ));
    });
  }
  for (final e in otherComponents.entries) {
    final named = <String>{};
    _renameReferences(e.value.document, {for (final id in out.renamed.keys) id: id}, (_, _) {}, found: named);
    for (final id in named) {
      out.issues.add((
        path: e.value.path,
        message: 'the component ${e.key} names the overlay "$id", which pages ${_list(out.renamed[id]!.keys)} each have as their own '
            '(they draw it differently: ${_list(out.renamed[id]!.values)}); it is not a notation component, so it is not made to open the calling page\'s. '
            'Write it in the notation (components/${e.key}.txt), or have it emit an event and open "$id" on each page.',
      ));
    }
  }
  // What each component fires, its own and its calls' (a call passes on
  // what the component it calls fires).
  final calls = {for (final c in components) c.type: _callTypes(c.document, types)};
  final needs = {for (final t in types) t: {...?own[t]}};
  for (var grew = true; grew;) {
    grew = false;
    for (final t in types) {
      for (final callee in calls[t]!) {
        for (final ev in needs[callee]!) {
          grew = needs[t]!.add(ev) || grew;
        }
      }
    }
  }
  for (final c in components) {
    _answer(c.document, needs, (event, node) => {'type': ComponentEventAction.typeName, 'event': event, 'value': r'${result}'});
  }
  for (final p in pages) {
    final said = <String>{};
    _answer(p.document, needs, (event, node) {
      final id = out.events[event]!;
      final to = out.renamed[id]?[p.name];
      if (to == null) {
        final callee = readString(node['type'])!;
        final from = opener[event]!.toList()..sort();
        if (said.add('$callee|$id')) {
          final through = from.contains(callee) ? '' : ' (through ${from.join(', ')})';
          out.issues.add((
            path: p.path,
            message: 'the page calls ${from.length == 1 && from.single == callee ? 'the component $callee' : '$callee$through'}, which opens the overlay "$id"; '
                'pages ${_list(out.renamed[id]!.keys)} each have their own "$id" (they draw it differently), and this page has none, so it opens nothing here. '
                'Write an overlay #$id on the page ${p.name} too, or have ${from.first} emit an event and open what each page has.',
          ));
        }
        return null;
      }
      return _handler(values[event]!, to);
    });
  }
  return out;
}

/// The action a page's call runs for an event whose value is [action] (the
/// component's, as it wrote it): the same action naming [to], what the
/// component worked out (its parameters, any field written as an
/// expression) read from the event's value, `${result}`, as the component
/// worked it out.
Json _handler(Json action, String to) {
  final simple = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');
  return {
    for (final e in action.entries)
      e.key: switch (e.key) {
        'to' => to,
        'params' when e.value is Map => {
            for (final p in (e.value as Map).entries)
              '${p.key}': simple.hasMatch('${p.key}') ? '\${result.params.${p.key}}' : p.value,
          },
        _ when e.value is String && (e.value as String).contains(r'${') && simple.hasMatch(e.key) => '\${result.${e.key}}',
        _ => e.value,
      },
  };
}

/// The canvas [id] and every node under it, as JSON: what it draws. The
/// nodes' ids are their places in the walk (and a text that is one of them,
/// as a `focus` names a node, that place): the same lines on two pages are
/// given other ids where the pages have more lines above them (`column12`,
/// `column9`), and draw the same.
String _drawn(Json nodes, String id, {Object? Function(Object? value)? mark}) {
  final order = <String>[];
  void walk(String k) {
    final n = readMap(nodes[k]);
    if (n == null || order.contains(k)) return;
    order.add(k);
    for (final c in [...readStrings(n['children']), ...?readMap(n['slots'])?.values.whereType<String>()]) {
      walk(c);
    }
  }

  walk(id);
  final place = {for (final (i, k) in order.indexed) k: '#$i'};
  Object? canonical(Object? v) => switch (mark?.call(v) ?? v) {
        final String s => place[s] ?? s,
        final Map m => {for (final e in m.entries) '${e.key}': canonical(e.value)},
        final List l => [for (final e in l) canonical(e)],
        _ => v,
      };
  return jsonEncode([for (final k in order) canonical(nodes[k])]);
}

/// [document]'s canvases renamed by [map] (old → new): its roots, its
/// nodes, and the variables and conditions kept by canvas id. The canvas
/// keeps the id as written as its name.
void _renameCanvases(Json document, Map<String, String> map) {
  final roots = readList(document['roots']);
  if (roots != null) document['roots'] = [for (final r in roots) map[r] ?? r];
  final nodes = readMap(document['nodes']);
  if (nodes != null) {
    document['nodes'] = {
      for (final e in nodes.entries)
        map[e.key] ?? e.key: map.containsKey(e.key) && e.value is Map ? {...(e.value as Map).cast<String, Object?>(), 'name': readString((e.value as Map)['name']) ?? e.key} : e.value,
    };
  }
  for (final scoped in const ['variables', 'conditions']) {
    final m = readMap(document[scoped]);
    if (m != null) document[scoped] = {for (final e in m.entries) map[e.key] ?? e.key: e.value};
  }
}

/// The fields of an action that name a screen: `navigate`'s `to` and
/// `base`, `openModal`'s `to`, `confirm`'s `dialog`.
const _screenFields = {
  'navigate': ['to', 'base'],
  'openModal': ['to'],
  'confirm': ['dialog'],
};

/// Every action of [json] that names an id of [map] by it names the new
/// one; [worked] is told of a field worked out by an expression that may
/// name one (left as written). [found] collects the ids named.
void _renameReferences(Object? json, Map<String, String> map, void Function(String field, String value) worked, {Set<String>? found}) {
  void walk(Object? v) {
    if (v is Map) {
      final fields = _screenFields[v['type']];
      for (final f in fields ?? const <String>[]) {
        final s = v[f];
        if (s is! String) continue;
        if (map[s] case final String to) {
          found?.add(s);
          v[f] = to;
        } else if (s.contains(r'${') && map.keys.any((id) => s.contains("'$id'") || s.contains('"$id"'))) {
          worked('${v['type']} $f', s);
        }
      }
      v.values.forEach(walk);
    } else if (v is List) {
      v.forEach(walk);
    }
  }

  walk(json);
}

/// In a component's [document], every `openModal` or `navigate` naming an
/// id of [ids] made a `componentEvent` ([event] names it), the action its
/// value; [cannot] is told of what cannot be (a `confirm` with such a
/// dialog: 'confirm'; an open whose result the actions after it read:
/// 'result').
void _eventize(Json document, Set<String> ids, String Function(Json action) event, void Function(String what, String id) cannot) {
  void walk(Object? v) {
    if (v is Map) {
      v.values.forEach(walk);
      return;
    }
    if (v is! List) return;
    final list = v;
    for (var i = 0; i < list.length; i++) {
      final a = list[i];
      if (a is Map) {
        final m = a.cast<String, Object?>();
        final type = m['type'];
        final names = (type == OpenModalAction.typeName || type == NavigateAction.typeName) && ids.contains(m['to']);
        if (type == ConfirmAction.typeName && ids.contains(m['dialog'])) cannot('confirm', m['dialog']! as String);
        if (type == NavigateAction.typeName && ids.contains(m['base'])) cannot('base', m['base']! as String);
        if (names) {
          if (type == OpenModalAction.typeName && list.skip(i + 1).any((later) => RegExp(r'\bresult\b').hasMatch(jsonEncode(later)))) {
            cannot('result', m['to']! as String);
          }
          final value = {for (final e in m.entries) if (!_common.contains(e.key)) e.key: e.value};
          final name = event(value);
          list[i] = {
            'type': ComponentEventAction.typeName,
            'event': name,
            'value': value,
            for (final e in m.entries)
              if (_common.contains(e.key)) e.key: e.value,
          };
          continue;
        }
      }
      walk(a);
    }
  }

  walk(document);
}

/// The screen ids [document]'s actions name ([_screenFields]).
Set<String> _named(Json document) {
  final out = <String>{};
  void walk(Object? v) {
    if (v is Map) {
      for (final f in _screenFields[v['type']] ?? const <String>[]) {
        if (v[f] case final String s when s.isNotEmpty && !s.contains(r'${')) out.add(s);
      }
      v.values.forEach(walk);
    } else if (v is List) {
      v.forEach(walk);
    }
  }

  walk(document);
  return out;
}

/// The component types [document]'s nodes call.
Set<String> _callTypes(Json document, Set<String> types) => {
      for (final n in (readMap(document['nodes']) ?? const {}).values)
        if (readMap(n)?['type'] case final String t when types.contains(t)) t,
    };

/// Every call in [document] of a component that fires events ([needs])
/// reacts to each: with [handler]'s action (null: none, said by it).
void _answer(Json document, Map<String, Set<String>> needs, Json? Function(String event, Json node) handler) {
  final nodes = readMap(document['nodes']);
  if (nodes == null) return;
  for (final e in nodes.entries) {
    final node = readMap(e.value);
    final type = readString(node?['type']);
    final events = type == null ? null : needs[type];
    if (node == null || events == null || events.isEmpty) continue;
    final reactions = [...?readList(node['actions'])];
    for (final ev in events.toList()..sort()) {
      final has = reactions.any((r) => readMap(readMap(r)?['trigger'])?['event'] == ev);
      if (has) continue;
      final a = handler(ev, node);
      if (a == null) continue;
      reactions.add({
        'trigger': {'type': 'event', 'event': ev},
        'actions': [a],
      });
    }
    if (reactions.isNotEmpty) nodes[e.key] = {...node, 'actions': reactions};
  }
}

/// [document] as its notation wrote it, before [scopeOverlays]: a page's
/// overlays made its own named as written again (and what names them), a
/// component's events for them its actions again, and the calls' reactions
/// to those events gone. [document] itself when it has none of them.
Json unscopeOverlays(Json document) {
  final copy = jsonDecode(jsonEncode(document)) as Json;
  var changed = false;
  final roots = readStrings(copy['roots']);
  final nodes = readMap(copy['nodes']) ?? const {};
  if (roots.isNotEmpty) {
    final map = {
      for (final id in roots.skip(1))
        if (writtenOverlayId(id, roots.first, readMap(nodes[id])) case final String written) id: written,
    };
    if (map.isNotEmpty) {
      changed = true;
      _renameCanvases(copy, map);
      _renameReferences(copy, map, (_, _) {});
    }
  }
  void walk(Object? v) {
    if (v is List) {
      for (var i = 0; i < v.length; i++) {
        final a = v[i];
        if (a is Map && a['type'] == ComponentEventAction.typeName && isOverlayEvent(readString(a['event'])) && a['value'] is Map) {
          v[i] = {...(a['value'] as Map).cast<String, Object?>(), for (final k in _common) if (a.containsKey(k)) k: a[k]};
          changed = true;
        } else {
          walk(a);
        }
      }
    } else if (v is Map) {
      final reactions = v['actions'];
      if (reactions is List && reactions.any((r) => r is Map && isOverlayEvent(readString(readMap(r['trigger'])?['event'])))) {
        reactions.removeWhere((r) => r is Map && isOverlayEvent(readString(readMap(r['trigger'])?['event'])));
        if (reactions.isEmpty) v.remove('actions');
        changed = true;
      }
      v.values.toList().forEach(walk);
    }
  }

  walk(copy['nodes']);
  return changed ? copy : document;
}

String _list(Iterable<String> items) {
  final l = items.toList();
  if (l.length < 2) return l.join();
  return '${l.sublist(0, l.length - 1).join(', ')} and ${l.last}';
}

Object? _sorted(Object? v) => switch (v) {
      final Map m => {for (final k in m.keys.map((k) => '$k').toList()..sort()) k: _sorted(m[k])},
      final List l => [for (final e in l) _sorted(e)],
      _ => v,
    };
