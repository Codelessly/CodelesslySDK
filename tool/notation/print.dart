// Prints a layout document in the compact notation: the other direction of
// expand.dart, so a UI that exists as a document is read (and edited) in the
// form it would be written in.
//
//   dart run tool/notation/print.dart <document.json> [--design-system <folder>] [--out <file.txt>] [--check]
//
// With --design-system (a folder holding design_system.json) a call of one
// of its components prints as that component's word. The print parses back
// to the same document (codelessly_api's printNotation is exact by
// construction: what its words do not say is a `{…}` tail on that line).
// --check does that parse and compares, and says how many lines still need a
// tail: the exit status is 1 when the document read back differs.
//
// A site's page or component that site expansion gave an overlay of its own
// (`nav--board`, site_overlays.dart) prints as it was written (`Drawer#nav`
// prints `Canvas#nav "nav"`, its opens `to=nav`; a component's event for it
// its open): --check compares with that, which expands to the site's
// document again.
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_api/notation.dart';

import 'notation_site.dart';

Future<void> main(List<String> args) async {
  String? opt(String name) {
    final i = args.indexOf(name);
    return i < 0 || i + 1 >= args.length ? null : args[i + 1];
  }

  final files = [
    for (var i = 0; i < args.length; i++)
      if (!args[i].startsWith('--') && (i == 0 || !const {'--design-system', '--out'}.contains(args[i - 1]))) args[i],
  ];
  if (files.length != 1 || !File(files.single).existsSync()) {
    stderr.writeln('usage: print.dart <document.json> [--design-system <folder>] [--out <file.txt>] [--check]');
    exit(2);
  }
  var catalog = standardCatalog;
  if (opt('--design-system') case final dir?) {
    final problems = <String>[];
    final ds = await DesignSystem.load((ref) async {
      final f = File('$dir/$ref');
      return f.existsSync() ? f.readAsStringSync() : null;
    }, problems: problems);
    if (problems.isNotEmpty) {
      stderr.writeln('The design system at $dir does not load cleanly: ${problems.join('; ')}');
      exit(2);
    }
    catalog = ds.catalogOver(standardCatalog);
  } else if (findSiteManifest(file: files.single) case final manifest?) {
    // A site's page calls the site's components: their words (a page that
    // called one printed as one `document {…}` line: test 9, admin 13).
    final site = await NotationSite.load(manifest);
    final library = {...?site.designSystem?.components.definitions, ...site.expanded};
    if (library.isNotEmpty) {
      catalog = DesignSystem(
        manifest: DesignSystemManifest.fromJson({
          'id': 'site',
          'components': [for (final t in library.keys) DesignSystem.componentRef(t)],
        }),
        components: ComponentLibrary(library),
      ).catalogOver(standardCatalog);
    }
  }
  final Object? json;
  try {
    json = jsonDecode(File(files.single).readAsStringSync());
  } on FormatException catch (e) {
    stderr.writeln('${files.single} is not JSON: ${e.message}');
    exit(2);
  }
  if (json is! Map<String, Object?> || json['nodes'] is! Map) {
    stderr.writeln('${files.single} is not a layout document (no "nodes").');
    exit(2);
  }
  // A site's page whose overlay site expansion made its own (`nav--board`,
  // site_overlays.dart) prints as it was written (`Drawer#nav`, `open nav`),
  // and a component's events for such an overlay as its `open`: the print is
  // the page's notation, which expands to the same document again.
  final document = unscopeOverlays(json);
  final text = Catalog.run(catalog, () => printNotation(document, catalog: catalog));
  if (opt('--out') case final out?) {
    File(out).writeAsStringSync('$text\n');
  } else {
    stdout.writeln(text);
  }
  if (!args.contains('--check')) return;

  final back = Catalog.run(catalog, () => parseNotation(text, catalog: catalog, options: notationOptionsFor(document)));
  for (final issue in back.issues) {
    stderr.writeln('${files.single}: ${issue.message}');
  }
  final same = jsonEncode(_sorted(back.document)) == jsonEncode(_sorted(document));
  final lines = text.split('\n').where((l) => l.trim().isNotEmpty && !l.trimLeft().startsWith('state ')).toList();
  final whole = lines.length == 1 && lines.single.startsWith('document ');
  final tailed = lines.where((l) => l.trimRight().endsWith('}') && l.contains(' {"')).length;
  stderr.writeln(same
      ? (whole
          ? 'Reads back the same, but as data: the notation has no words for this document\'s tree.'
          : 'Reads back the same: ${lines.length} lines, $tailed with a {…} tail.')
      : 'The print does not read back as the same document.');
  if (!same) exit(1);
}

Object? _sorted(Object? v) => switch (v) {
      final Map m => {for (final k in m.keys.map((k) => '$k').toList()..sort()) k: _sorted(m[k])},
      final List l => [for (final e in l) _sorted(e)],
      // 390 and 390.0 are one number in JSON.
      final double d when d == d.roundToDouble() && d.abs() < 1e15 => d.toInt(),
      _ => v,
    };
