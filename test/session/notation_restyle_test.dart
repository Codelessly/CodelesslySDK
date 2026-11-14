// A screen written in the notation names its design system's tokens, so the
// same document, unchanged, is another design system's when shown under it:
// the layout is written once and the look is the theme's.
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

Future<api.DesignSystem> _load(String id) async {
  final problems = <String>[];
  final ds = await api.DesignSystem.load((ref) async {
    final f = File('design_systems/$id/$ref');
    return f.existsSync() ? f.readAsStringSync() : null;
  }, problems: problems);
  expect(problems, isEmpty);
  return ds;
}

const _card = '''
Card gap:8
  Text.title "Billing"
  Text.muted "Next invoice on the 1st"
  Badge.success "Paid"
  Progress 0.4
''';

void main() {
  test('written under SSUI, shown under Paper: no line or node rewritten, every look Paper\'s', () async {
    final ssui = await _load('ssui'), paper = await _load('paper');
    final session = UiSession(designSystem: ssui);
    addTearDown(session.dispose);
    final result = await session.applyNotation(Stream.value(_card));
    expect(session.notationIssues, isEmpty);
    expect(result.errors, isEmpty, reason: '${result.errors}');
    final written = session.document;
    final json = jsonEncode(written.toJson());
    // What the notation added as a look names a token: no color value of
    // SSUI's is written into the document.
    final card = written.nodes['column1']!.toJson();
    expect(((card['decoration'] as Map)['strokes'] as List).single, {'color': 'primaryBorder'});
    expect(RegExp(r'"color":"#').allMatches(json), isEmpty, reason: json);

    api.Json shown(api.DesignSystem ds) =>
        api.resolveThemeRefs(written, ds.themeUnder(api.ThemeTokens.none)).nodes['column1']!.toJson();
    String border(api.Json node) => (((node['decoration'] as Map)['strokes'] as List).single as Map)['color'] as String;
    String fill(api.Json node) => (((node['decoration'] as Map)['fills'] as List).single as Map)['color'] as String;
    expect(border(shown(ssui)), '#FFE5E7EB');
    expect(border(shown(paper)), '#FFE4E1DC');
    expect(fill(shown(paper)), '#FFFFFCF7');
  });
}
