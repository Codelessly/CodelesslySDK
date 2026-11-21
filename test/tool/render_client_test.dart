// tool/codelessly render's own request to the render server (tool/cli/src/render_client.dart): the arguments it
// hands the harness are those render.sh hands it (paths absolute, as Dart reads them), and the command's phases
// are told with --timings.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/cli/src/render_client.dart';
import '../../tool/render/src/timings.dart';

void main() {
  group('mixedPath (cygpath -m)', () {
    test('a drive path keeps its drive, as a capital, with forward slashes', () {
      expect(mixedPath(r'C:\Users\me\site'), 'C:/Users/me/site');
      expect(mixedPath('c:/a'), 'C:/a');
      expect(mixedPath('C:/a/b/'), 'C:/a/b/');
    });

    test('a POSIX path of a drive is that drive\'s', () {
      expect(mixedPath('/c/Users/me/out'), 'C:/Users/me/out');
      expect(mixedPath('/d'), 'D:/');
    });

    test('. and .. and doubled separators are worked out', () {
      expect(mixedPath(r'C:\a\b\..\c'), 'C:/a/c');
      expect(mixedPath('/c/a/./b//c/'), 'C:/a/b/c/');
      expect(mixedPath('C:/a/../../b'), 'C:/b');
      expect(mixedPath('/c/Users/../x y'), 'C:/x y');
    });

    test('a POSIX path that is no drive\'s is left to the shell', () {
      expect(mixedPath('/tmp/x'), isNull);
      expect(mixedPath('//server/share/x'), isNull);
      expect(mixedPath('relative/x'), isNull);
    });
  });

  group('prepareRenderArgs', () {
    PreparedRender? unix(List<String> argv) => prepareRenderArgs(argv, cwd: '/work', windows: false);
    PreparedRender? win(List<String> argv) => prepareRenderArgs(argv, cwd: r'C:\work', windows: true);

    test('documents and path options are made absolute; values are left as written', () {
      final p = unix(['site', '--out', 'out', '--sizes', '390x844', '--screen', 'home', '--tap', 'open', '--label', 'a b', '--fonts', 'fonts'])!;
      expect(p.args, ['/work/site', '--out', '/work/out', '--sizes', '390x844', '--screen', 'home', '--tap', 'open', '--label', 'a b', '--fonts', '/work/fonts']);
      expect(p.out, '/work/out');
      expect(p.timings, isFalse);
      expect(p.designSystem, isNull);
    });

    test('on Windows the paths are written as Dart reads them', () {
      final p = win([r'..\site', '--out', '/c/out/x', '--compare', r'D:\ref', '--key', '/'])!;
      expect(p.args, ['C:/site', '--out', 'C:/out/x', '--compare', 'D:/ref', '--key', '/']);
      expect(p.out, 'C:/out/x');
    });

    test('--fonts system names the system\'s fonts, not a folder', () {
      expect(unix(['a.json', '--out', '/o', '--fonts', 'system'])!.args, ['/work/a.json', '--out', '/o', '--fonts', 'system']);
    });

    test('--timings is the command\'s own, and --design-system is taken out with its folder', () {
      final p = unix(['card.json', '--timings', '--out', 'o', '--design-system', 'ds'])!;
      expect(p.args, ['/work/card.json', '--out', '/work/o']);
      expect(p.timings, isTrue);
      expect(p.designSystem, '/work/ds');
    });

    test('an --image-map\'s folder (and a table\'s file) is made absolute', () {
      expect(unix(['a.json', '--out', '/o', '--image-map', 'https://x.test/img=assets'])!.args.last, 'https://x.test/img=/work/assets');
      expect(unix(['a.json', '--out', '/o', '--image-map', 'map.json'])!.args.last, '/work/map.json=/work/map.json');
    });

    test('a state\'s steps keep their values; a document after a flag is a document', () {
      final p = unix(['site', '--out', '/o', '--full-page', 'more.json', '--state', 'open', '--tap', 'menu', '--type', 'name=one\ntwo'])!;
      expect(p.args, ['/work/site', '--out', '/o', '--full-page', '/work/more.json', '--state', 'open', '--tap', 'menu', '--type', 'name=one\ntwo']);
    });

    test('a path only the shell can read leaves the run to render.sh', () {
      expect(win(['/tmp/site', '--out', 'o']), isNull);
      expect(win(['site', '--out', '/tmp/o']), isNull);
    });
  });

  test('the timings line names each phase, how often it ran when more than once, and the total', () {
    final t = RenderTimings()
      ..add('read', 12400)
      ..add('show', 100000)
      ..add('show', 50000);
    expect(t.line, matches(RegExp(r'^read 12 ms, show 150 ms \(2\); total \d+ ms$')));
    final c = CommandTimings()..lap('start');
    expect(c.line, matches(RegExp(r'^start \d+ ms; total \d+ ms$')));
  });

  test('a server whose sources are older than its start is current; a newer source is not', () {
    final root = Directory.systemTemp.createTempSync('render_client_test');
    addTearDown(() => root.deleteSync(recursive: true));
    final sdk = '${root.path}/sdk'.replaceAll(r'\', '/');
    for (final f in ['$sdk/lib/a.dart', '$sdk/tool/render/render.sh', '$sdk/pubspec.yaml', '$sdk/build/.render-server/ready']) {
      File(f)
        ..createSync(recursive: true)
        ..writeAsStringSync('x');
    }
    final ready = File('$sdk/build/.render-server/ready');
    // (The files and their folders were made just now: the server "started" a minute from now.)
    final at = DateTime.now();
    ready.setLastModifiedSync(at.add(const Duration(minutes: 1)));
    expect(serverIsCurrent(sdk, null, ready), isTrue);
    File('$sdk/lib/a.dart').setLastModifiedSync(at.add(const Duration(minutes: 5)));
    expect(serverIsCurrent(sdk, null, ready), isFalse);
    expect(serverIsCurrent(sdk, null, File('$sdk/build/.render-server/none')), isFalse);
  });
}
