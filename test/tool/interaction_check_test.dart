// The replay's "works when used" checker (tool/stream/src/interact.dart),
// offline: for every brief with an interaction script, a small hand-written
// UI that works passes, and the same UI with its reactions removed (it
// renders but does nothing) fails. The sudoku fixture's pad runs a script
// (the scripts op, TrustProfile.agentApps) in QuickJS, as the replay does.
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart'; // ignore: deprecated_member_use
import 'package:flutter_test/flutter_test.dart';

import '../../tool/stream/src/interact.dart';
import '../../tool/stream/src/replay.dart' show ReplayServices;

Object? _withoutReactions(Object? v) => switch (v) {
      final Map m => {
          for (final e in m.entries)
            if (!(e.key == 'actions' && e.value is List && (e.value as List).every((r) => r is Map && r.containsKey('trigger'))))
              e.key: _withoutReactions(e.value),
        },
      final List l => [for (final x in l) _withoutReactions(x)],
      _ => v,
    };

void main() {
  final dir = Directory('tool/stream/interactions/fixtures');
  final quickJs = ReplayServices.useLocalQuickJs();
  for (final f in dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json'))) {
    final ui = f.uri.pathSegments.last.replaceFirst('.json', '');
    final ops = jsonDecode(f.readAsStringSync());
    final usesScripts = f.readAsStringSync().contains('runScript');
    for (final working in [true, false]) {
      testWidgets('$ui: ${working ? 'a working UI passes' : 'the same UI with no reactions fails'}', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final session = UiSession(catalog: Catalog.core, profile: TrustProfile.agentApps);
        final r = session.apply(working ? ops : _withoutReactions(ops));
        expect(r.errors, isEmpty, reason: '${r.errors}');
        final boundary = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(
          key: boundary,
          child: MaterialApp(home: Material(child: CodelesslyView(session: session, services: const ReplayServices()))),
        ));
        await tester.pump();
        final result = await runInteractions(tester, session, boundary, interactionsFor(ui)!, realTime: usesScripts);
        expect(result['ok'], working, reason: const JsonEncoder.withIndent(' ').convert(result));
        await tester.pumpWidget(const SizedBox());
        session.dispose();
      }, skip: usesScripts && !quickJs); // QuickJS not built: tool/build_quickjs.sh
    }
  }
}
