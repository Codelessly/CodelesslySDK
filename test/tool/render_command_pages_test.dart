// The render command (tool/render) on whole pages: the guide's responsive
// and band examples, full-page captures, focus and key steps, comparing
// renders, and media rules. Run in-process on the fixtures next to this file.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import '../../tool/render/src/args.dart';
import '../../tool/render/src/compare.dart';
import '../../tool/render/src/render.dart';

const fixtures = 'test/tool/fixtures';
const a0 = '$fixtures/authoring';

List<String> codes(RenderReport r, [String? severity]) => [
      for (final d in r.diagnostics)
        if (severity == null || d['severity'] == severity) d['code'] as String,
    ];

void main() {
  late Directory out;
  setUp(() => out = Directory.systemTemp.createTempSync('render_command_pages_test'));
  tearDown(() => out.deleteSync(recursive: true));

  // The guide's responsive example (codelessly_api tool/reference/examples/
  // responsive_web.json, copied): the four web patterns at three widths.
  testWidgets('the guide\'s responsive example: header, 3-2-1 grid from one list, stacking split, type scale', (tester) async {
    final report = await runRender(tester, RenderArgs(inputs: ['$a0/responsive_web.json'], out: out.path, dumpLayout: true));
    expect(report.diagnostics, isEmpty, reason: '${report.diagnostics}');
    Map<String, List<Map>> boxes(String size) {
      final out0 = <String, List<Map>>{};
      for (final b in jsonDecode(File('${out.path}/home@$size.layout.json').readAsStringSync()) as List) {
        (out0[(b as Map)['id'] as String] ??= []).add(b);
      }
      return out0;
    }
    int columns(Map<String, List<Map>> b) => b['plan']!.where((p) => p['y'] == b['plan']!.first['y']).length;
    final m = boxes('390x844'), t = boxes('834x1112'), d = boxes('1440x900');
    expect([columns(m), columns(t), columns(d)], [1, 2, 3], reason: 'auto-fit columns from one bound list');
    expect(d['plan']!.map((p) => p['h']).toSet(), hasLength(1), reason: 'equal heights per row');
    // Desktop: text and photo side by side; phone: stacked, photo first.
    expect(d['split-text']!.single['x'], lessThan(d['split-photo']!.single['x'] as num));
    expect(m['split-photo']!.single['y'], lessThan(m['split-text']!.single['y'] as num));
    expect(m['split-photo']!.single['w'], 358);
    // Nav collapses to the menu icon below desktop: the hidden one takes no room.
    expect(d['nav']!.single['w'], greaterThan(0));
    expect(m['nav']!.single['w'], 0);
    // The content column is capped at 1200 and centered.
    expect(d['content']!.single['w'], 1200);
    expect(d['content']!.single['x'], 120);
  });

  // Sections and components (docs/design/06): a directory with site.json is
  testWidgets('a full-page capture keeps the window, so a drawer pinned to its top and bottom covers the first window only', (tester) async {
    final r = await runRender(tester, RenderArgs(inputs: ['$fixtures/fix3-drawer.json'], out: out.path, sizes: const [Size(390, 844)],
        fullPage: true, dumpLayout: true));
    expect(r.errors, 0, reason: '${r.diagnostics}');
    final boxes = (jsonDecode(File('${out.path}/drawerScreen@390x844.layout.json').readAsStringSync()) as List).cast<Map>();
    final drawer = boxes.singleWhere((b) => b['id'] == 'drawer');
    expect([drawer['y'], drawer['h']], [72, 772]);
    final bytes = File(r.images.single).readAsBytesSync();
    final image = await tester.runAsync(() async {
      final frame = await (await ui.instantiateImageCodec(bytes)).getNextFrame();
      return (await frame.image.toByteData(), frame.image.width, frame.image.height);
    });
    int px(int x, int y, int c) => image!.$1!.getUint8((y * image.$2 + x) * 4 + c);
    expect(image!.$3, 2400);
    expect([px(195, 500, 0), px(195, 500, 1)], [255, 0], reason: 'the drawer over the first window');
    expect([px(195, 1500, 0), px(195, 1500, 1)], [0, 255], reason: 'the page below it');
  });

  testWidgets('an unfocus step takes the focus from a field, and a key step presses a key on what has the focus', (tester) async {
    Future<double> moved(List<Step> steps) async {
      final o = Directory('${out.path}/${steps.length}-${steps.first.kind}')..createSync();
      final r = await runRender(tester, RenderArgs(inputs: ['$fixtures/fix3-keys.json'], out: o.path, sizes: const [Size(390, 844)],
          dumpLayout: true, steps: steps));
      expect(r.errors, 0, reason: '${r.diagnostics}');
      final boxes = (jsonDecode(File('${o.path}/keys@390x844.layout.json').readAsStringSync()) as List).cast<Map>();
      return (boxes.singleWhere((b) => b['id'] == 'moved')['h'] as num).toDouble();
    }

    expect(await moved(const [Step('key', 'ArrowRight')]), 40, reason: 'the screen\'s keyDown reaction ran');
    expect(await moved(const [Step('type', 'field', 'abc'), Step('key', 'ArrowRight')]), 0, reason: 'the focused field took the key');
    expect(await moved(const [Step('type', 'field', 'abc'), Step('unfocus', ''), Step('key', 'ArrowRight')]), 40);
    expect(parseArgs(['k.json', '--out', 'o', '--unfocus', '--key', 'shift+Tab']).steps.map((s) => s.kind), ['unfocus', 'key']);
  });

  testWidgets('comparing renders matches the same page and finds one pushed down, saying by how much', (tester) async {
    final r = await runRender(tester, RenderArgs(inputs: ['$fixtures/fix3-drawer.json'], out: out.path, sizes: const [Size(390, 844)],
        fullPage: true, compare: '$fixtures/fix3-drawer.json'.replaceFirst('fix3-drawer.json', 'none.png')));
    expect(codes(r), ['compare_failed'], reason: '${r.diagnostics}');
    final capture = r.images.single;
    // A reference: the capture 20 px lower under a 20 px band.
    final reference = '${out.path}/ref.png';
    await tester.runAsync(() async {
      final img = await decodePng(File(capture).readAsBytesSync());
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 390, 20), ui.Paint()..color = const ui.Color(0xFF000000));
      final c = Completer<ui.Image>();
      ui.decodeImageFromPixels(img.rgba, img.width, img.height, ui.PixelFormat.rgba8888, c.complete);
      canvas.drawImage(await c.future, const ui.Offset(0, 20), ui.Paint());
      final out = await recorder.endRecording().toImage(390, img.height + 20);
      File(reference).writeAsBytesSync((await out.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());
    });
    final same = (await tester.runAsync(() => compareImages(capture, capture)))!;
    expect(same.matching, 1.0);
    expect(same.bands, isEmpty);
    final shifted = (await tester.runAsync(() => compareImages(capture, reference)))!;
    expect(shifted.referenceHeight - shifted.captureHeight, 20);
    expect(shifted.bands.any((b) => b.shift == 20), isTrue, reason: shifted.summary());
    expect(shifted.summary(), contains('20 px shorter than the reference'));
    expect(File(capture.replaceFirst('.png', '.compare.png')).existsSync() && File(capture.replaceFirst('.png', '.diff.png')).existsSync(), isTrue);
  });

  testWidgets('overlapping a neighbor: motion moves what is painted, not the layout; a media rule patches it', (tester) async {
    final r = await runRender(tester, RenderArgs(inputs: ['$fixtures/fix3-overlap.json'], out: out.path, sizes: const [Size(390, 844), Size(1440, 900)]));
    expect(r.diagnostics, isEmpty, reason: '${r.diagnostics}');
    Future<List<int>> column(String png, int x, List<int> ys) async => (await tester.runAsync(() async {
          final img = await decodePng(File('${out.path}/$png').readAsBytesSync());
          return [for (final y in ys) img.rgba[(y * img.width + x) * 4] << 16 | img.rgba[(y * img.width + x) * 4 + 1] << 8 | img.rgba[(y * img.width + x) * 4 + 2]];
        }))!;
    // On a phone the card is drawn 36 px up, over the hero's bottom; its
    // slot (and the box after it, at 300) do not move.
    expect(await column('overlap@390x844.png', 195, [160, 170, 260, 270, 310]), [0x00FF00, 0xFF0000, 0xFF0000, 0xFFFFFF, 0x0000FF]);
    // At desktop width the media rule puts it back.
    expect(await column('overlap@1440x900.png', 720, [180, 280, 310]), [0x00FF00, 0xFF0000, 0x0000FF]);
  });

  testWidgets('a media rule may bind: visible on phones only while a variable allows, hidden elsewhere', (tester) async {
    Future<Map<String, double>> heights(List<Step> steps) async {
      final o = Directory('${out.path}/${steps.length}')..createSync();
      final r = await runRender(tester, RenderArgs(inputs: ['$fixtures/fix3-media-bind.json'], out: o.path,
          sizes: const [Size(390, 844), Size(1440, 900)], dumpLayout: true, steps: steps));
      expect(r.diagnostics, isEmpty, reason: '${r.diagnostics}');
      return {
        for (final w in ['390x844', '1440x900'])
          w: ((jsonDecode(File('${o.path}/mb@$w.layout.json').readAsStringSync()) as List).cast<Map>().singleWhere((b) => b['id'] == 'bar')['h'] as num)
              .toDouble(),
      };
    }

    expect(await heights(const []), {'390x844': 60, '1440x900': 0});
    expect(await heights(const [Step('set', 'open', 'true')]), {'390x844': 0, '1440x900': 0});
  });

  // The guide's band example (codelessly_api tool/reference/examples/band.json, copied): a full-width band whose
  // content is capped at 1200 and centered, and a table from one row and one cell template.
  testWidgets('the guide\'s band example: full-width band, content capped and centered, a table from one template', (tester) async {
    final r = await runRender(tester, RenderArgs(inputs: ['$a0/band.json'], out: out.path, sizes: const [Size(390, 844), Size(1700, 900)],
        dumpLayout: true));
    expect(r.diagnostics, isEmpty, reason: '${r.diagnostics}');
    List<Map> boxes(String size) => (jsonDecode(File('${out.path}/home@$size.layout.json').readAsStringSync()) as List).cast<Map>();
    final wide = boxes('1700x900');
    final band = wide.singleWhere((b) => b['id'] == 'band'), rail = wide.singleWhere((b) => b['id'] == 'rail');
    expect([band['x'], band['w']], [0, 1700.0]);
    expect([rail['x'], rail['w']], [250, 1200.0]);
    expect(wide.where((b) => b['id'] == 'cell'), hasLength(9), reason: 'three rows of three cells from one cell node');
    final narrow = boxes('390x844').singleWhere((b) => b['id'] == 'rail');
    expect([narrow['x'], narrow['w']], [24, 342.0]);
  });
}
