// "Works when used": a short scripted interaction with a generated UI,
// driven headless after its stream, that checks the UI responds. Steps find
// what to touch the way a person would, without knowing the ids the model
// chose: by the text on screen, the n-th thing that reacts to a tap, or the
// n-th thing that can be dragged. A step that expects a change passes when
// the captured screen differs afterwards or the UI sent an event to the
// host; the run passes when every such step does and the texts it expects
// appear. A UI that renders but does nothing fails.
//
// The interactions per brief are in tool/stream/interactions/<ui>.json:
//   {"steps": [{"tap": {"text": "13:45|easyJet"}}, {"tap": {"reactive": 0}},
//              {"drag": {"draggable": 0, "dx": 0, "dy": -160}}, {"wait": 1500}],
//    "expectText": "required"}
// Every tap or drag expects a change unless it says "change": false.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:crypto/crypto.dart' show sha1;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' show GlobalKey;
import 'package:flutter_test/flutter_test.dart';

/// The interactions for brief [ui], when tool/stream/interactions has them.
Map<String, Object?>? interactionsFor(String ui) {
  final f = File('${Directory.current.path}/tool/stream/interactions/$ui.json');
  return f.existsSync() ? (jsonDecode(f.readAsStringSync()) as Map).cast<String, Object?>() : null;
}

/// Runs [script] on the UI [session] shows under [boundary]; returns
/// `{"ok", "steps": [{"step", "found", "changed", "events"}], "expectText"}`.
Future<Map<String, Object?>> runInteractions(WidgetTester tester, UiSession session, GlobalKey boundary, Map<String, Object?> script,
    {bool realTime = true}) async {
  final events = <UiEvent>[];
  final sub = session.events.listen(events.add);
  final steps = <Map<String, Object?>>[];
  var ok = true;
  // What a person would see change, and the state behind it: the views'
  // variable values, the texts on screen and where every node box is.
  Future<String> shot() async {
    final b = StringBuffer(_encode(session.values));
    _visit(tester, (o) {
      if (o is RenderParagraph && o.attached) b.write('|${o.text.toPlainText()}');
      if (o is NodeBox && o.attached && o.hasSize) b.write('|${o.id}@${o.localToGlobal(Offset.zero)}${o.size}');
    });
    return sha1.convert(utf8.encode(b.toString())).toString();
  }

  Future<void> settle(int ms) async {
    // Real time for script runs (an FFI engine, a worker) and timers.
    for (var t = 0; t < ms; t += 100) {
      if (realTime) await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  for (final raw in (script['steps'] as List? ?? const [])) {
    final step = (raw as Map).cast<String, Object?>();
    if (step['wait'] case final num ms) {
      await settle(ms.toInt());
      steps.add({'step': step});
      continue;
    }
    final before = await shot();
    final eventsBefore = events.length;
    Offset? at;
    if (step['tap'] case final Map t) {
      at = _find(tester, session, t.cast<String, Object?>());
      if (at != null) await tester.tapAt(at);
    } else if (step['drag'] case final Map d) {
      final m = d.cast<String, Object?>();
      at = _find(tester, session, m);
      if (at != null) {
        final delta = Offset((m['dx'] as num? ?? 0).toDouble(), (m['dy'] as num? ?? 0).toDouble());
        final g = await tester.startGesture(at);
        for (var i = 1; i <= 10; i++) {
          await g.moveTo(at + delta * (i / 10));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await g.up();
      }
    }
    await settle((step['settleMs'] as num? ?? 600).toInt());
    final changed = at != null && (await shot() != before || events.length > eventsBefore);
    final expects = step['change'] != false;
    if (expects && !changed) ok = false;
    steps.add({'step': step, 'found': at != null, 'changed': changed, 'events': [for (final e in events.skip(eventsBefore)) e.event]});
  }
  bool? textOk;
  if (script['expectText'] case final String pattern) {
    final re = RegExp(pattern, caseSensitive: false);
    textOk = _texts(tester).any(re.hasMatch);
    if (!textOk) ok = false;
  }
  // Not awaited: a broadcast subscription's cancel future does not
  // complete inside the test's fake async zone.
  unawaited(sub.cancel());
  return {'ok': ok, 'steps': steps, 'expectText': ?script['expectText'], 'textFound': ?textOk};
}

/// Where to touch for finder [f]: `{"text": regex}` (the text on screen),
/// `{"reactive": n}` (the n-th node, top to bottom then left to right, with
/// a tap reaction), `{"draggable": n}` (the n-th node that can be dragged:
/// a drag reaction or a pan, draggable, track or transform behavior).
Offset? _find(WidgetTester tester, UiSession session, Map<String, Object?> f) {
  if (f['text'] case final String pattern) {
    final re = RegExp(pattern, caseSensitive: false);
    final hits = <RenderParagraph>[];
    // Only the UI's own text (inside a node box), not the chat around it.
    _visitInUi(tester, (o) {
      if (o is RenderParagraph && o.attached && o.hasSize && re.hasMatch(o.text.toPlainText())) hits.add(o);
    });
    final n = (f['index'] as num? ?? 0).toInt();
    return n < hits.length ? hits[n].localToGlobal(hits[n].size.center(Offset.zero)) : null;
  }
  final reactive = f['reactive'] as num?;
  final draggable = f['draggable'] as num?;
  if (reactive == null && draggable == null) return null;
  final boxes = <NodeBox>[];
  _visit(tester, (o) {
    if (o is! NodeBox || !o.attached || !o.hasSize || o.size.isEmpty) return;
    final n = session.document[o.id];
    if (n == null) return;
    final json = n.toJson();
    final triggers = {for (final r in api.readList(json['actions']) ?? const []) api.readString(api.readMap(api.readMap(r)?['trigger'])?['type'])};
    final isReactive = triggers.contains('click') || triggers.contains('tap');
    final isDraggable = triggers.contains('drag') ||
        triggers.contains('dragEnd') ||
        const ['pan', 'draggable', 'track', 'transformGesture', 'dismissible'].any(json.containsKey);
    if ((reactive != null && isReactive) || (draggable != null && isDraggable)) boxes.add(o);
  });
  Offset pos(NodeBox b) => b.localToGlobal(Offset.zero);
  boxes.sort((a, b) {
    final dy = pos(a).dy.round() - pos(b).dy.round();
    return dy != 0 ? dy : (pos(a).dx - pos(b).dx).sign.toInt();
  });
  final n = (reactive ?? draggable)!.toInt();
  return n < boxes.length ? boxes[n].localToGlobal(boxes[n].size.center(Offset.zero)) : null;
}

String _encode(Object? v) {
  try {
    return jsonEncode(v, toEncodable: (x) => '$x');
  } catch (_) {
    return '$v';
  }
}

Iterable<String> _texts(WidgetTester tester) {
  final out = <String>[];
  _visitInUi(tester, (o) {
    if (o is RenderParagraph && o.attached) out.add(o.text.toPlainText());
  });
  return out;
}

/// [f] on every render object inside a node box.
void _visitInUi(WidgetTester tester, void Function(RenderObject) f) {
  void visit(RenderObject o, bool inUi) {
    final inside = inUi || o is NodeBox;
    if (inside) f(o);
    o.visitChildren((c) => visit(c, inside));
  }

  for (final v in tester.binding.renderViews) {
    visit(v, false);
  }
}

void _visit(WidgetTester tester, void Function(RenderObject) f) {
  void visit(RenderObject o) {
    f(o);
    o.visitChildren(visit);
  }

  for (final v in tester.binding.renderViews) {
    visit(v);
  }
}
