// What a render names its files so that one run does not overwrite another's:
// the diagnostics file carries the --screen and the sizes (when not the
// default ones) besides the label, and `tool/codelessly render --outline`
// reads only the files its own run wrote, matching each capture to the
// diagnostics file that lists it.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import '../../tool/cli/src/outline.dart';
import '../../tool/render/src/args.dart';
import '../../tool/render/src/render.dart';

void main() {
  test('the diagnostics file names the screen and the sizes a run was limited to', () {
    expect(diagnosticsFileName(null), 'diagnostics.json');
    expect(diagnosticsFileName('dark'), 'diagnostics-dark.json');
    expect(diagnosticsFileName('dark', sizes: RenderArgs.defaultSizes), 'diagnostics-dark.json');
    expect(diagnosticsFileName('dark', screens: const ['home']), 'diagnostics-home-dark.json');
    expect(diagnosticsFileName('dark', screens: const ['home'], sizes: const [Size(1440, 900)]), 'diagnostics-home@1440x900-dark.json');
    expect(diagnosticsFileName('dark', screens: const ['home', 'about us'], sizes: const [Size(390, 844), Size(1440, 900)]),
        'diagnostics-home+about_us@390x844+1440x900-dark.json');
    expect(diagnosticsFileName(null, sizes: const [Size(390, 844)]), 'diagnostics@390x844.json');
    expect(diagnosticsFileName(null, screens: const ['home']), 'diagnostics-home.json');
  });

  group('the outline of one invocation', () {
    late Directory out;
    setUp(() => out = Directory.systemTemp.createTempSync('render_output_names_test'));
    tearDown(() => out.deleteSync(recursive: true));

    void write(String name, Object json, {DateTime? at}) {
      final f = File('${out.path}/$name')..writeAsStringSync(jsonEncode(json));
      if (at != null) f.setLastModifiedSync(at);
    }

    Map<String, Object?> issue(String code, String screen) =>
        {'code': code, 'severity': 'warning', 'message': code, 'nodeId': 'x', 'screen': screen, 'size': '390x844'};

    test('lists only the captures its run wrote, each with its own diagnostics file\'s problems', () {
      // An earlier run's capture and its diagnostics, left in the folder a moment before (the same second).
      write('home@390x844-dark.png.layout.json', []);
      write('diagnostics-home-dark.json', {'images': ['home@390x844-dark.png'], 'diagnostics': [issue('old_issue', 'home')]});
      final before = snapshotOf(out.path);
      // This run: another screen, the same label; a capture after --navigate.
      write('about@390x844-dark.png.layout.json', []);
      write('detail@390x844-dark.png.layout.json', []);
      write('diagnostics-about-dark.json', {
        'images': ['about@390x844-dark.png'],
        'diagnostics': [issue('about_issue', 'about')],
      });
      write('diagnostics-start-dark.json', {
        'images': ['detail@390x844-dark.png'],
        'startedOn': {'detail@390x844-dark.png': 'start'},
        'diagnostics': [issue('detail_issue', 'start')],
      });
      final fresh = writtenAfter(before);
      final text = outlineText(out.path, const [], fresh: fresh);
      expect(text, allOf(contains('== about@390x844-dark'), contains('== detail@390x844-dark'), isNot(contains('home@390x844-dark'))));
      expect(captureDiagnostics(out.path, 'about@390x844-dark', fresh: fresh).map((d) => d['code']), ['about_issue']);
      expect(captureDiagnostics(out.path, 'detail@390x844-dark', fresh: fresh).map((d) => d['code']), ['detail_issue']);
      // A capture of the earlier run that this run wrote again is this run's.
      write('home@390x844-dark.png.layout.json', [], at: DateTime.now().add(const Duration(seconds: 5)));
      expect(outlineText(out.path, const [], fresh: fresh), contains('== home@390x844-dark'));
      // Without a run (tool/codelessly outline <dir>), every capture in the folder.
      expect(outlineText(out.path, const []), contains('== home@390x844-dark'));
    });
  });
}
