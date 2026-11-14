// SSUI as data (design_systems/ssui): it loads from its folder, every
// component and the gallery validate against it with no problem, and its
// three cards only report the events they send to the host (a top-level
// componentEvent, which a generated UI's session routes to the model).
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_api/validate.dart';
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
    expect(validateTheme(ds.tokens.toJson()), isEmpty);
  });

  test('every SSUI component and the gallery validate against it', () async {
    final ds = await _load([]);
    final docs = {
      for (final f in Directory('$_dir/components').listSync().whereType<File>()) 'components/${f.uri.pathSegments.last}': _json(f.path),
      'gallery.json': _json('$_dir/examples/gallery.json'),
    };
    final problems = validateProject(docs, options: ValidateOptions(theme: ds.tokens))
        .where((d) => d.severity != Severity.info)
        .map((d) => '$d');
    expect(problems, isEmpty);
  });

  test('the cards use only SSUI components, tokens and core nodes, and only send events to the host', () async {
    final ds = await _load([]);
    for (final card in ['flight_picker', 'order_summary', 'contact_form']) {
      final doc = _json('$_dir/examples/cards/$card.json');
      final problems = validateDocument(doc, options: ValidateOptions(theme: ds.tokens, components: ds.components))
          .where((d) => d.severity != Severity.info && d.code.name != 'unknown_event')
          .map((d) => '$d');
      expect(problems, isEmpty, reason: card);
      final types = {for (final n in (doc['nodes']! as Map).values) (n as Map)['type']};
      expect(types.intersection(ds.manifest.replaces.toSet()), isEmpty, reason: '$card uses a base control SSUI replaces');
    }
  });
}
