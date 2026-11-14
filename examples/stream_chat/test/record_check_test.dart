// What tool/record.dart checks a recorded turn with, offline (no request):
// with --design-system the ops are applied as UiSession(designSystem:)
// applies them (its components are types the agent may call, its token
// names are colours and text styles), and the counts say how much of the UI
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
}
