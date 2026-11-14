// A second design system (design_systems/paper), written by
// design_systems/tool/new_design_system.py from a ten-line brand file: SSUI's
// components over another theme. It loads, every component validates
// against its own tokens, and a UI made for SSUI validates with it
// unchanged: a design system is a drop-in.
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_api/validate.dart';
import 'package:flutter_test/flutter_test.dart';

Future<DesignSystem> _load(String dir, List<String> problems) =>
    DesignSystem.load((ref) async => File('$dir/$ref').existsSync() ? File('$dir/$ref').readAsStringSync() : null, problems: problems);

Map<String, Object?> _json(String path) => (jsonDecode(File(path).readAsStringSync()) as Map).cast<String, Object?>();

void main() {
  test('Paper loads with its own theme and SSUI\'s component set', () async {
    final problems = <String>[];
    final paper = await _load('design_systems/paper', problems);
    final ssui = await _load('design_systems/ssui', []);
    expect(problems, isEmpty);
    expect(paper.id, 'paper');
    expect(paper.components.definitions.keys.toSet(), ssui.components.definitions.keys.toSet());
    expect(paper.tokens.primary, const Color(0xFF0F766E));
    expect(paper.tokens.radii['control'], 2);
    expect(paper.tokens.color('primaryBackground'), const Color(0xFFFFFCF7));
    expect(paper.tokens.forBrightness(dark: true).color('primaryBackground'), const Color(0xFF1C1917));
    // Every name SSUI's theme has, Paper's has: a component finds each one.
    expect(paper.tokens.colors.keys.toSet(), ssui.tokens.colors.keys.toSet());
    expect(paper.tokens.textStyles.keys.toSet(), ssui.tokens.textStyles.keys.toSet());
    expect(validateTheme(paper.tokens.toJson()), isEmpty);
  });

  test('every component validates against Paper, and SSUI\'s cards validate with it unchanged', () async {
    final paper = await _load('design_systems/paper', []);
    final docs = {
      for (final f in Directory('design_systems/paper/components').listSync().whereType<File>()) 'components/${f.uri.pathSegments.last}': _json(f.path),
    };
    expect(validateProject(docs, options: ValidateOptions(theme: paper.tokens)).where((d) => d.severity != Severity.info).map((d) => '$d'), isEmpty);
    for (final card in ['flight_picker', 'order_summary', 'contact_form']) {
      final doc = _json('design_systems/ssui/examples/cards/$card.json');
      final problems = validateDocument(doc, options: ValidateOptions(theme: paper.tokens, components: paper.components))
          .where((d) => d.severity != Severity.info)
          .map((d) => '$d');
      expect(problems, isEmpty, reason: card);
    }
  });
}
