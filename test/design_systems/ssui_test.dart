// SSUI as data (design_systems/ssui): it loads from its folder, and its
// three cards use none of the base controls it replaces.
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter_test/flutter_test.dart';

const _dir = 'design_systems/ssui';

Future<DesignSystem> _load(List<String> problems) =>
    DesignSystem.load((ref) async => File('$_dir/$ref').existsSync() ? File('$_dir/$ref').readAsStringSync() : null, problems: problems);

Map<String, Object?> _json(String path) => (jsonDecode(File(path).readAsStringSync()) as Map).cast<String, Object?>();

void main() {
  test('SSUI loads from its folder: its documents, tokens light and dark, and every component', () async {
    final problems = <String>[];
    final ds = await _load(problems);
    expect(problems, isEmpty);
    expect(ds.name, 'Soft SaaS UI');
    expect(ds.design, contains('## In brief'));
    expect(ds.patterns, contains('## In brief'));
    expect(ds.components.definitions.length, ds.manifest.components.length);
    expect(ds.tokens.sizes['compact'], 28);
    expect(ds.tokens.radii['control'], 7);
    expect(ds.tokens.color('primaryBackground'), const Color(0xFFFFFFFF));
    expect(ds.tokens.forBrightness(dark: true).color('primaryBackground'), const Color(0xFF141414));
  });

  test('the cards use no base control SSUI replaces', () async {
    final ds = await _load([]);
    for (final card in ['flight_picker', 'order_summary', 'contact_form']) {
      final doc = _json('$_dir/examples/cards/$card.json');
      final types = {for (final n in (doc['nodes']! as Map).values) (n as Map)['type']};
      expect(types.intersection(ds.manifest.replaces.toSet()), isEmpty, reason: '$card uses a base control SSUI replaces');
    }
  });
}
