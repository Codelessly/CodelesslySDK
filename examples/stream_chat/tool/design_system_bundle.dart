// Bundles a design system folder (the SDK's design_systems/ssui by default)
// into one JSON file the app ships as an asset: DesignSystem.load over the
// folder, then DesignSystem.toJson.
//
//   dart run tool/design_system_bundle.dart [folder] [out]
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/core.dart';

Future<void> main(List<String> args) async {
  final folder = args.isNotEmpty ? args[0] : '../../design_systems/ssui';
  final problems = <String>[];
  final ds = await DesignSystem.load((ref) async {
    final f = File('$folder/$ref');
    return f.existsSync() ? f.readAsStringSync() : null;
  }, problems: problems);
  for (final p in problems) {
    stderr.writeln(p);
  }
  final out = File(args.length > 1 ? args[1] : 'assets/design_systems/${ds.id}.json')..createSync(recursive: true);
  out.writeAsStringSync(jsonEncode(ds.toJson()));
  stdout.writeln('${out.path}: ${ds.name}, ${ds.components.definitions.length} components, ${out.lengthSync()} bytes');
}
