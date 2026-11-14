// What tool/record.dart checks a recorded turn with, offline (no request):
// with --design-system the ops are applied as UiSession(designSystem:)
// applies them (its components are types the agent may call, its token
// names are colors and text styles), and the counts say how much of the UI
// is the design system's.
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat/src/record_check.dart';

/// The ui_apply input of the SDK's hand-written SSUI recording (the replay
/// test's fixture).
String _ssuiCard() => File('../../test/tool/fixtures/replay/ssui_card.jsonl')
    .readAsLinesSync()
    .skip(1)
    .map((l) => (jsonDecode(l) as Map)['delta'] as String)
    .join();

void main() {
  test('--design-system ssui finds the SDK\'s design system folder, and the meta names its id and version', () async {
    final ds = await loadDesignSystem('ssui');
    expect(ds.id, 'ssui');
    expect(designSystemMeta(ds), {'id': 'ssui', 'name': 'Soft SaaS UI', 'version': '1.0.0'});
    expect((await loadDesignSystem('../../design_systems/ssui')).components.definitions.length, ds.components.definitions.length);
    expect(() => loadDesignSystem('nope'), throwsStateError);
  });

  test('a UI made of SSUI components and tokens passes the per-op check with SSUI, and is counted as SSUI\'s', () async {
    final ds = await loadDesignSystem('ssui');
    final checked = checkToolInput(LayoutDocument(catalog: catalogFor(ds)), _ssuiCard(),
        profile: TrustProfile.agent, protect: false, rev: 1, designSystem: ds);
    expect(checked.result.errors, isEmpty, reason: '${checked.result.errors}');
    expect(checked.needsFix, isFalse);
    expect(checked.counts(), containsPair('designSystemComponents', 4));
    expect(checked.counts(), containsPair('replacedControls', 0));
  });

  test('the same UI without the design system is rejected, so a retry would be asked for', () {
    final checked = checkToolInput(LayoutDocument(), _ssuiCard(), profile: TrustProfile.agent, protect: false, rev: 1);
    expect(checked.result.errors.map((d) => d.code), containsAll(['capability_not_allowed', 'unknown_theme_name']));
    expect(checked.needsFix, isTrue);
    expect(checked.counts().containsKey('designSystemComponents'), isFalse);
  });

  test('a base control the design system replaces is counted as such', () async {
    final ds = await loadDesignSystem('ssui');
    final ops = jsonEncode({
      'ops': [
        {'op': 'roots', 'roots': ['c']},
        {'op': 'set', 'id': 'c', 'node': {'type': 'canvas', 'slots': {'body': 'ok'}, 'layout': {'width': 390, 'height': 100}}},
        {
          'op': 'set',
          'id': 'ok',
          'node': {'type': 'filledButton', 'props': {'label': 'OK'}, 'layout': {'width': 80, 'height': 32}},
        },
      ],
    });
    final checked = checkToolInput(LayoutDocument(catalog: catalogFor(ds)), ops, profile: TrustProfile.agent, protect: false, rev: 1, designSystem: ds);
    expect(checked.counts(), containsPair('designSystemComponents', 0));
    expect(checked.counts(), containsPair('replacedControls', 1));
  });

  test('a recorded turn\'s formulas are checked with the SDK\'s parser, and references unresolved at the end are errors', () async {
    // reservation@claude-sonnet-5-5 wrote a slot formula as JavaScript;
    // data_table@claude-sonnet-5-5 filtered with a condition, not a lambda.
    // Neither was reported to the model when recorded.
    final ds = await loadDesignSystem('ssui');
    String ops(String file) => File('../../tool/stream/streams/live/2026-11-14-ssui/$file')
        .readAsLinesSync()
        .skip(1)
        .map((l) => (jsonDecode(l) as Map)['delta'] as String? ?? '')
        .join();
    final reservation = checkToolInput(LayoutDocument(catalog: catalogFor(ds)), ops('reservation@claude-sonnet-5-5.compact.ssui.r1.jsonl'),
        profile: TrustProfile.agent, protect: false, rev: 1, designSystem: ds);
    expect([for (final d in reservation.result.errors) '${d.code} ${d.path}'], ['expression_syntax /variables/book/6/formula']);
    expect(reservation.needsFix, isTrue);
    expect(reservation.toolResult(1)['next'], isNotNull);
    final table = checkToolInput(LayoutDocument(catalog: catalogFor(ds)), ops('data_table@claude-sonnet-5-5.compact.ssui.r1.jsonl'),
        profile: TrustProfile.agent, protect: false, rev: 1, designSystem: ds);
    final status = table.result.errors.firstWhere((d) => d.code == 'unknown_name' && d.message.contains('"status" is not a variable'));
    expect(status.op, -1, reason: 'reported when the stream ends');
    expect(status.message, contains('filter(invoices, r => r.status == x)'));
  });
}
