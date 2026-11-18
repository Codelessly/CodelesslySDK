// A pointer step with modifier keys held (`--tap shift+row`, `--drag
// alt+clip=40,0`): the reaction reads them as a user's Shift-click, on a box
// and on a button alike (result.shift, result.ctrl, result.meta, result.alt).
// Run in-process on test/tool/fixtures/modifiers.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import '../../tool/render/src/args.dart';
import '../../tool/render/src/render.dart';

void main() {
  late Directory out;
  setUp(() => out = Directory.systemTemp.createTempSync('render_modifier_steps_test'));
  tearDown(() => out.deleteSync(recursive: true));

  String logOf(RenderReport report) {
    final boxes = jsonDecode(File(report.images.single.replaceFirst('.png', '.layout.json')).readAsStringSync()) as List;
    return boxes.cast<Map>().firstWhere((b) => b['id'] == 'log')['text'] as String;
  }

  testWidgets('shift+, ctrl+, alt+ before a target hold those keys through the step', (tester) async {
    final report = await runRender(
      tester,
      RenderArgs(
        inputs: ['test/tool/fixtures/modifiers/modifiers.json'],
        out: out.path,
        sizes: const [Size(390, 400)],
        dumpLayout: true,
        steps: const [
          Step('tap', 'btn'),
          Step('tap', 'shift+btn'),
          Step('tap', 'ctrl+btn'),
          Step('tap', 'alt+shift+btn'),
          Step('tap', 'shift+row'),
          Step('tap', 'row'),
        ],
      ),
    );
    expect(report.errors, 0, reason: '${report.diagnostics}');
    expect(logOf(report), 'log=.S.C.SA.s,,');
  });

  test('the step grammar: a modifier is a prefix of the target', () {
    final args = parseArgs(['doc.json', '--out', 'o', '--tap', 'shift+row#2', '--drag', 'alt+clip=40,0']);
    expect(args.steps.map((s) => '$s'), ['--tap shift+row#2', '--drag alt+clip=40,0']);
  });
}
