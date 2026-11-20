// `tool/codelessly render` and `sheet`: the render command (tool/render/render.sh) with conveniences
// for agents.
//
//   tool/codelessly render <documents> --out <dir> [render options] [--outline] [--sheet]
//   tool/codelessly sheet <png | dir>... --out <png> [--height 480] [--columns n] [--title text]
//
// --outline also dumps the layout and prints every capture's outline (tool/codelessly outline). --sheet writes
// <out>/sheet.png, every capture of the run on one image. Every other option is the render command's
// (tool/render/README.md); the exit status is its.
import 'dart:io';

import 'common.dart';
import 'outline.dart';

/// Render options that take a value (so their value is not a document).
const renderValued = {
  '--out', '--sizes', '--screen', '--fonts', '--theme', '--tap', '--double-tap', '--long-press', '--right-click', '--wheel', '--pinch', '--drag', '--hover', '--focus', '--key', '--type',
  '--set', '--stage', '--frames', '--now', '--screen-timeout', '--scroll', '--navigate', '--wait', '--label', '--state', '--compare', '--compare-map', '--design-system',
  '--component', '--props', '--slots', '--image-map', '--pick-file',
};

/// The documents (positionals) and `--out` of render arguments.
(List<String>, String?) splitRenderArgs(List<String> args) {
  final docs = <String>[];
  String? out;
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (renderValued.contains(a)) {
      if (a == '--out' && i + 1 < args.length) out = args[i + 1];
      i++;
    } else if (!a.startsWith('--')) {
      docs.add(a);
    }
  }
  return (docs, out);
}

/// Draws a contact sheet of [inputs] into [out] through the render harness (the render server when it is up).
Future<(int, String)> sheet(List<String> inputs, String out, {int height = 480, int? columns, String? title}) {
  final file = absolute(out);
  final single = inputs.length == 1 && FileSystemEntity.isDirectorySync(inputs.first) ? absolute(inputs.first) : null;
  return runCaptured(renderScript, [
    '--sheet', file, '--out', File(file).parent.path, '--sheet-height', '$height',
    if (columns != null) ...['--sheet-columns', '$columns'],
    if (title != null) ...['--sheet-title', title],
    if (single != null) ...['--sheet-base', single],
    ...inputs.map(absolute),
  ]);
}

Future<int> renderMain(List<String> argv) async {
  if (argv.isEmpty || argv.contains('-h') || argv.contains('--help')) {
    stdout.writeln(_doc);
    final readme = File('${sdkRoot.path}/tool/render/README.md');
    if (readme.existsSync()) stdout.writeln(readme.readAsStringSync().split('## What it reports').first);
    return argv.isEmpty ? 2 : 0;
  }
  final outline = argv.contains('--outline'), wantSheet = argv.contains('--sheet');
  final args = [for (final a in argv) if (a != '--outline' && a != '--sheet') a];
  final (docs, out) = splitRenderArgs(args);
  if (out == null) {
    stderr.writeln('--out <dir> is required (where the PNGs and diagnostics.json go).');
    return 2;
  }
  if (outline && !args.contains('--dump-layout')) args.add('--dump-layout');
  // The outline is of this invocation's captures, not those earlier runs left in --out.
  final before = snapshotOf(out);
  final code = await runInherited(renderScript, args);
  if (code != 2) {
    if (outline) stdout.write('\n${outlineText(out, docs, fresh: writtenAfter(before))}');
    if (wantSheet) {
      final (_, text) = await sheet([out], '$out/sheet.png');
      stdout.write(text.split('\n').where((l) => l.startsWith('wrote ') || l.startsWith('No PNGs')).map((l) => '$l\n').join());
    }
  }
  return code;
}

Future<int> sheetMain(List<String> argv) async {
  final a = Args(argv, valued: {'--out', '--height', '--columns', '--title'});
  if (a.help || a.positional.isEmpty || a['--out'] == null) return usage(_sheetDoc, asked: a.help);
  final (code, text) = await sheet(a.positional, a['--out']!,
      height: int.tryParse(a['--height'] ?? '') ?? 480, columns: int.tryParse(a['--columns'] ?? ''), title: a['--title']);
  final report = text.split('\n').where((l) => l.startsWith('wrote ') || l.startsWith('No PNGs')).join('\n');
  stdout.writeln(report.isEmpty ? text : report);
  return code;
}

const _doc = '''tool/codelessly render <documents> --out <dir> [render options] [--outline] [--sheet]

--outline also dumps the layout and prints the outline of every capture this run made (each node's box and text
with its problems; captures earlier runs left in --out are not listed).
--sheet writes <out>/sheet.png, every capture of the run on one image. Every other option is the render command's;
the exit status is its.''';

const _sheetDoc = '''tool/codelessly sheet <png | dir>... --out <png> [--height 480] [--columns n] [--title text]

Many screenshots as one labelled contact sheet: each scaled to --height (aspect kept) under its file name; a
directory adds its PNGs (not *.diff.png, *.compare.png, nor earlier sheets). Without --columns, the captures of one
state (the name around its @size) share a row, narrowest first. Drawn by the render harness (dart:ui).''';
