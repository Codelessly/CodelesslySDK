// The replay command (tool/stream/replay.sh, tool/stream/src/replay.dart)
// with a design system: a small hand-written recording of a card made of
// SSUI components and SSUI token names (test/tool/fixtures/replay/
// ssui_card.jsonl, whose meta names the design system) replays with
// UiSession(designSystem:): every op applies, every component call renders
// as its definition (not as an empty box of an unknown type), and the
// token names resolve to SSUI's colours, light by default and dark when
// asked.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import '../../tool/stream/src/replay.dart';

const _stream = 'test/tool/fixtures/replay/ssui_card.jsonl';

/// How many pixels of the last frame [out] wrote for 390x844 have each of
/// [colors] (ARGB).
Future<Map<int, int>> _countColors(WidgetTester tester, String out, Set<int> colors) async {
  final frames = Directory('$out/390x844/frames').listSync().whereType<File>().map((f) => f.path).toList()..sort();
  return (await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(File(frames.last).readAsBytesSync());
    final image = (await codec.getNextFrame()).image;
    final bytes = (await image.toByteData())!;
    image.dispose();
    final counts = {for (final c in colors) c: 0};
    for (var i = 0; i + 3 < bytes.lengthInBytes; i += 4) {
      final argb = bytes.getUint8(i + 3) << 24 | bytes.getUint8(i) << 16 | bytes.getUint8(i + 1) << 8 | bytes.getUint8(i + 2);
      if (counts.containsKey(argb)) counts[argb] = counts[argb]! + 1;
    }
    return counts;
  }))!;
}

void main() {
  for (final dark in [false, true]) {
    testWidgets('a recording made with SSUI replays with it${dark ? ' in dark' : ''}: its components render and its tokens resolve',
        (tester) async {
      final out = Directory.systemTemp.createTempSync('replay_ds').path;
      addTearDown(() => Directory(out).deleteSync(recursive: true));
      final metrics = await runReplay(
          tester,
          ReplayArgs(
            stream: _stream,
            out: out,
            sizes: const [ui.Size(390, 844)],
            fontDirs: [if (Directory('../references').existsSync()) '../references'],
            frames: 8,
            dark: dark,
          ));
      final m = metrics['390x844']! as Map<String, Object?>;
      expect(m['opsRejected'], 0, reason: '${m['rejections']}');
      expect(m['finalDiagnostics'], isEmpty);
      expect(m['renderExceptions'], isEmpty);
      expect(m['themeMode'], dark ? 'dark' : 'light');
      expect(m['designSystem'], {
        'id': 'ssui',
        'version': '1.0.0',
        'componentNodes': 4,
        'componentsRendered': 4,
        'componentsNotRendered': isEmpty,
        'replacedControls': isEmpty,
      });
      // The page's fill (secondaryBackground), the card's (primaryBackground)
      // and the confirm button's (primary), in the mode shown.
      final colors = dark ? {0xFF1C1C1C, 0xFF141414, 0xFF3B82F6} : {0xFFF9FAFB, 0xFFFFFFFF, 0xFF2563EB};
      final counts = await _countColors(tester, out, colors);
      for (final c in colors) {
        expect(counts[c], greaterThan(500), reason: '#${c.toRadixString(16)}: $counts');
      }
    });
  }

  test('the replay takes the design system from the recording\'s meta, or from --design-system', () {
    final stream = RecordedStream.read(_stream);
    expect(designSystemOf(stream, null), 'ssui');
    expect(designSystemOf(stream, 'design_systems/ssui'), 'design_systems/ssui');
    expect(designSystemOf(RecordedStream({'ui': 'flights'}, const []), null), isNull);
  });
}
