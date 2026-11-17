// A second design system (design_systems/paper), written by
// design_systems/tool/new_design_system.py from a ten-line brand file: SSUI's
// components over another theme. It loads with every name SSUI's theme has:
// a design system is a drop-in.
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart';
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
  });

  test('density and type scale are brand choices: Harbor is SSUI roomier and a tenth larger', () async {
    final problems = <String>[];
    final harbor = await _load('design_systems/harbor', problems);
    final ssui = await _load('design_systems/ssui', []);
    expect(problems, isEmpty);
    // The theme: control sizes at 1.15, type at 1.1.
    expect(harbor.tokens.sizes['compact'], (ssui.tokens.sizes['compact']! * 1.15).round());
    expect(harbor.tokens.textStyles['body']!.fontSize, 14.5);
    expect(ssui.tokens.textStyles['body']!.fontSize, 13);
    // The components: a literal font size, a padding, and a size picked by a prop.
    final panel = _json('design_systems/harbor/components/Panel.json')['nodes'] as Map;
    expect((((panel['title'] as Map)['props'] as Map)['style'] as Map)['fontSize'], 13);
    expect(((panel['header'] as Map)['layout'] as Map)['padding'], [16, 12, 16, 12]);
    final search = _json('design_systems/harbor/components/SearchBar.json')['nodes'] as Map;
    expect(((search['strut'] as Map)['bind'] as Map)['layout.height'], contains("'sm' ? 37"));
    // A dot or a marker stays round whatever the corners.
    final steps = _json('design_systems/paper/components/StepIndicator.json')['nodes'] as Map;
    expect(((steps['marker'] as Map)['decoration'] as Map)['radius'], 9999);
  });
}
