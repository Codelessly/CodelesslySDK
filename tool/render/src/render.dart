// The render command's core: strict validation, then each screen rendered
// by the SDK at each size (CodelesslyWidget over the published bundle, as
// an app shows it), interactions applied, PNGs written, and the runtime
// problems validation can't see reported as diagnostics.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_api/validate.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Page, Step; // ignore: deprecated_member_use
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:codelessly_sdk/src/render/paint/icon_glyph.dart' show IconSources, RenderIconGlyph;
import 'package:codelessly_sdk/src/render/paint/path_paint.dart' show parseSvgPath;

import 'args.dart';
import 'fonts.dart';
import 'prepare.dart';
import 'publish.dart';

/// A problem found while rendering (validation's [Diagnostic]s have the
/// same JSON shape).
final class RuntimeIssue {
  RuntimeIssue(this.code, this.severity, this.message, {this.nodeId, this.screen, this.size, this.file, this.path});
  final String code;
  final String severity;
  final String message;
  final String? nodeId;
  final String? screen;
  final String? size;
  final String? file;
  final String? path;

  api.Json toJson() => {
        'code': code,
        'severity': severity,
        'path': path ?? '',
        'message': message,
        'nodeId': ?nodeId,
        'screen': ?screen,
        'size': ?size,
        'file': ?file,
      };

  String get key => '$code|$nodeId|$message';
}

/// Every code the render step reports beyond validation's, with its
/// severity and meaning (for the README and the reference).
const runtimeCodes = <(String, String, String)>[
  ('invalid_json', 'error', 'A file is not valid JSON (the message gives the line and column).'),
  ('no_documents', 'error', 'No .json documents were found at the paths given.'),
  ('unknown_screen_arg', 'error', '--screen names no canvas, screen or layout.'),
  ('render_exception', 'error', 'Flutter threw while building, laying out or painting the screen.'),
  ('action_error', 'error', 'An action chain failed (a load reaction, or one an interaction ran).'),
  ('interaction_failed', 'error', 'A --tap/--hover/--focus/--type/--scroll/--set/--navigate step could not be applied (no such node, not on screen, covered by another node: the message names it).'),
  ('tap_no_reaction', 'warning', 'A --tap hit its node, but neither it nor anything around it reacts to a tap (no click reaction, no button or input): nothing happens.'),
  ('missing_glyph', 'warning', 'A text has characters its font has no glyph for: they are drawn as empty boxes. Use another character, an icon, or a box with a path.'),
  ('icon_not_drawn', 'warning', 'An icon names no glyph the renderer can draw (an unknown Material icon name, or an object without a type or name).'),
  ('expression_not_evaluated', 'warning', 'A text shows "\${" on screen: an expression that did not evaluate (a formula error, or a binding that replaced the text).'),
  ('path_overflow', 'warning', 'A path draws outside its node\'s box: a path is not clipped to its box (as Flutter\'s CustomPaint). Give it a viewBox, or clip an ancestor.'),
  ('layout_overflow', 'warning', 'A node extends past its parent\'s box (by the pixels shown) where the parent does not scroll that way.'),
  ('offscreen', 'warning', 'A node extends past the screen edge where nothing scrolls: on a device it is cut off.'),
  ('text_clipped', 'warning', 'A text does not fit its box: its lines are taller than the box, or a word is wider.'),
  ('text_truncated', 'warning', 'A text was cut at maxLines with overflow "clip" (an ellipsis or fade is taken as meant).'),
  ('text_no_color', 'warning', 'A text has no color: the engine paints it white (invisible on a light background). Set props.style.color.'),
  ('font_fallback', 'warning', 'A font family (or weight/style) is not in the fonts directories: the text is drawn in another font.'),
  ('image_failed', 'error', 'An image could not be loaded or decoded (missing file, bad data: URL).'),
  ('image_network', 'warning', 'An image is on the network: the render command does not fetch it, so it is blank in the screenshot.'),
  ('empty_screen', 'warning', 'The screen drew no node boxes (nothing to show).'),
];

/// The result of a run.
final class RenderReport {
  final List<api.Json> diagnostics = [];
  final List<String> images = [];
  int get errors => diagnostics.where((d) => d['severity'] == 'error').length;
  int get warnings => diagnostics.where((d) => d['severity'] == 'warning').length;
}

final class _Recorder implements AnalyticsService {
  final List<(Object, String?)> errors = [];
  @override
  void logError(Object error, {StackTrace? stackTrace, String? message, String? type, Map<String, Object?> context = const {}}) =>
      errors.add((error, message));
  @override
  void logEvent(String name, [Map<String, Object?> parameters = const {}]) {}
  @override
  void logScreen(String name, {String? layoutId}) {}
}

/// Loads the documents [args] names: each `.json` file, or each in a
/// directory (not starting with `_`, not `diagnostics.json`).
List<({String name, String path, String text})> loadInputs(List<String> inputs) {
  final out = <({String name, String path, String text})>[];
  for (final input in inputs) {
    final type = FileSystemEntity.typeSync(input);
    final files = <File>[];
    if (type == FileSystemEntityType.directory) {
      files.addAll(Directory(input).listSync().whereType<File>().where((f) {
        final base = f.uri.pathSegments.last;
        return base.endsWith('.json') && !base.startsWith('_') && !RegExp(r'^diagnostics(-.*)?\.json$').hasMatch(base);
      }).toList()
        ..sort((a, b) => a.path.compareTo(b.path)));
    } else if (type == FileSystemEntityType.file) {
      files.add(File(input));
    }
    for (final f in files) {
      final base = f.uri.pathSegments.last;
      out.add((name: base.endsWith('.json') ? base.substring(0, base.length - 5) : base, path: f.path, text: f.readAsStringSync()));
    }
  }
  return out;
}

String _jsonError(Object e, String text) {
  if (e is FormatException && e.offset != null) {
    final before = text.substring(0, e.offset!.clamp(0, text.length));
    final line = '\n'.allMatches(before).length + 1;
    final col = before.length - (before.lastIndexOf('\n') + 1) + 1;
    return '${e.message} at line $line, column $col';
  }
  return '$e';
}

/// Runs the command in a widget test.
Future<RenderReport> runRender(WidgetTester tester, RenderArgs args, {String? flutterRoot}) async {
  final report = RenderReport();
  final seen = <String>{};
  void issue(RuntimeIssue i) {
    if (seen.add('${i.key}|${i.screen}|${i.size}')) report.diagnostics.add(i.toJson());
  }

  Directory(args.out).createSync(recursive: true);
  final inputs = loadInputs(args.inputs);
  if (inputs.isEmpty) {
    issue(RuntimeIssue('no_documents', 'error', 'No .json documents at ${args.inputs.join(', ')}.'));
    return _finish(report, args);
  }

  // 1. Parse and validate.
  final docs = <String, api.Json>{};
  final dirs = <String, String>{};
  for (final i in inputs) {
    try {
      final j = jsonDecode(i.text);
      if (j is! Map) throw const FormatException('the top level is not an object');
      docs[i.name] = j.cast<String, Object?>();
      dirs[i.name] = File(i.path).parent.path;
    } catch (e) {
      issue(RuntimeIssue('invalid_json', 'error', 'Not valid JSON: ${_jsonError(e, i.text)}.', file: i.name));
    }
  }
  final functions = <String>{
    for (final d in docs.values)
      for (final scope in (api.readMap(d['variables']) ?? const {}).values)
        for (final v in api.readList(scope) ?? const [])
          if (api.readMap(v) case final api.Json m when (api.readList(m['parameters'])?.isNotEmpty ?? false) && m['name'] is String) m['name'] as String,
  };
  FormulaReport check(String formula) =>
      (error: FormulaEvaluator.errorOf(formula, functionNames: functions), paths: FormulaEvaluator.referencedPaths(formula));
  final diagnostics = validateProject(docs, options: ValidateOptions(formulas: check, variables: functions));
  report.diagnostics.addAll(diagnostics.map((d) => d.toJson()));
  if (args.validateOnly || docs.isEmpty) return _finish(report, args);

  // 2. Fonts and assets. A font handler left by an earlier run in this
  // process would load into a disposed instance.
  FontDemand.handler = null;
  final root = flutterRoot ?? Platform.environment['FLUTTER_ROOT'] ?? '';
  final faces = [...defaultFonts(root), ...scanFonts(args.fontDirs)];
  final fetcher = DirectoryFontFetcher(faces);
  await tester.runAsync(() async {
    // The default family and the icon font, registered up front.
    for (final family in const ['Roboto', 'Material Icons']) {
      final files = [for (final f in faces) if (f.family == family) f.path];
      if (files.isEmpty) continue;
      final loader = FontLoader(family == 'Material Icons' ? 'MaterialIcons' : family);
      for (final p in files) {
        loader.addFont(Future.value(File(p).readAsBytesSync().buffer.asByteData()));
      }
      await loader.load();
    }
  });
  final codepoints = materialCodepoints(root);
  final pages = <Page>[];
  for (final e in docs.entries) {
    final p = prepare(e.value, dir: dirs[e.key]!, defaultFamily: 'Roboto', codepoints: codepoints);
    pages.add((name: e.key, json: p.json));
    for (final img in p.images) {
      if (img.status == 'failed') {
        issue(RuntimeIssue('image_failed', 'error', 'Image ${img.url}: ${img.detail}.', nodeId: img.nodeId, file: e.key, path: img.path));
      } else if (img.status == 'network') {
        issue(RuntimeIssue('image_network', 'warning',
            'Image ${img.url} is on the network: not fetched here, so it is blank in the screenshots. Use a file next to the document (assets/...) to see it.',
            nodeId: img.nodeId, file: e.key, path: img.path));
      }
    }
    // Raster data: URLs (local files included) must decode.
    await tester.runAsync(() async {
      for (final img in p.images.where((i) => i.status == 'local' || i.status == 'inline')) {
        final url = _valueAt(p.json, img.path);
        if (url is! String || !url.startsWith('data:') || url.startsWith('data:image/svg')) continue;
        try {
          final codec = await ui.instantiateImageCodec(UriData.parse(url).contentAsBytes());
          codec.dispose();
        } catch (err) {
          issue(RuntimeIssue('image_failed', 'error', 'Image ${img.url} does not decode: $err.', nodeId: img.nodeId, file: e.key, path: img.path));
        }
      }
    });
  }
  final published = publishPages(pages);
  final fileOfNode = <String, String>{
    for (final e in docs.entries)
      for (final id in (api.readMap(e.value['nodes']) ?? const {}).keys) id: e.key,
  };

  // Tests draw shadows without blur unless told otherwise (an app blurs them).
  debugDisableShadows = false;
  // The details of each error, to name the node it came from.
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    _errorDetails[details.exception] = details;
    _errorLog.add(details);
    previousOnError?.call(details);
  };
  // Icons named without a codepoint (a bound name) draw from the font.
  IconSources.codepointOf = (name, style) =>
      codepoints[style == 'filled' ? '${name}_baseline' : '${name}_$style'] ?? codepoints[name];
  try {
    await _renderAll(tester, args, faces, published, docs, fileOfNode, fetcher, issue, report);
  } finally {
    debugDisableShadows = true;
    FlutterError.onError = previousOnError;
    IconSources.codepointOf = null;
    _errorDetails.clear();
    _errorLog.clear();
  }
  tester.view.reset();
  return _finish(report, args);
}

Future<void> _renderAll(
  WidgetTester tester,
  RenderArgs args,
  List<FontFace> faces,
  ({api.PublishBundle bundle, Map<String, String> layoutOfCanvas, Map<String, List<String>> screens}) published,
  Map<String, api.Json> docs,
  Map<String, String> fileOfNode,
  DirectoryFontFetcher fetcher,
  void Function(RuntimeIssue) issue,
  RenderReport report,
) async {
  // 3. Which screens.
  final screens = _screens(published, docs, args.screens, (s) => issue(s));
  final recorder = _Recorder();
  final binding = tester.binding;
  for (final screen in screens) {
    final label = _screenName(published, docs, screen);
    for (final size in args.sizes) {
      final sizeName = '${size.width.round()}x${size.height.round()}';
      final codelessly = Codelessly(
        loader: MemoryPublishLoader(published.bundle),
        fonts: fetcher,
        config: CodelesslyConfig(services: Services(analytics: recorder), fontTimeout: const Duration(seconds: 5)),
      );
      final controller = CodelesslyWidgetController();
      final navigator = GlobalKey<NavigatorState>();
      final boundary = GlobalKey();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = ui.Size(size.width, size.height);
      void collect() {
        // Every error Flutter reported since the last look, each with its
        // own details (flutter_test keeps only one: several in a frame
        // become "Multiple exceptions (n) were detected", which names none).
        final taken = <Object>[];
        Object? e;
        while ((e = tester.takeException()) != null) {
          taken.add(e!);
        }
        final reported = [..._errorLog];
        _errorLog.clear();
        final errors = <(Object, FlutterErrorDetails?)>[
          for (final d in reported) (d.exception, d),
          // One flutter_test caught some other way (not reported to FlutterError).
          for (final t in taken)
            if (!reported.any((d) => identical(d.exception, t)) && !'$t'.startsWith('Multiple exceptions (')) (t, null),
        ];
        for (final (err, details) in errors) {
          final text = _firstLine('$err');
          // A flex "overflowed by 1.04e-7 pixels" is rounding, not a problem.
          final by = RegExp(r'overflowed by ([0-9.eE+-]+) pixels').firstMatch(text);
          if (by != null && (double.tryParse(by[1]!) ?? 1) < 0.01) continue;
          final node = _nodeOfError(details ?? _errorDetails[err]);
          _errorDetails.remove(err);
          issue(RuntimeIssue('render_exception', 'error',
              node == null
                  ? '$text (Flutter named no render object for it: it was thrown outside a node\'s layout and paint, while building or in a callback.)'
                  : 'Node "${node.id}" (${node.node?.type ?? '?'}): $text',
              nodeId: node?.id, screen: label, size: sizeName, file: node == null ? null : fileOfNode[node.id]));
        }
        for (final (err, message) in recorder.errors) {
          final node = err is ActionFailed ? err.nodeId : null;
          issue(RuntimeIssue('action_error', 'error', '${message ?? 'Action failed'}: ${_firstLine('$err')}',
              nodeId: node, screen: label, size: sizeName, file: node == null ? null : fileOfNode[node]));
        }
        recorder.errors.clear();
      }

      await tester.pumpWidget(RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          navigatorKey: navigator,
          debugShowCheckedModeBanner: false,
          // Material widgets (buttons, fields) draw their text in the
          // platform's font: Roboto, as on Android and the web.
          theme: ThemeData(fontFamily: 'Roboto'),
          builder: (context, child) => DefaultTextStyle.merge(style: const TextStyle(fontFamily: 'Roboto'), child: child!),
          onGenerateRoute: CodelesslyWidget.onGenerateRoute(codelessly),
          home: CodelesslyWidget(codelessly: codelessly, layoutId: screen, controller: controller),
        ),
      ));
      // Loading waits for the layout's fonts (registered with the engine in
      // real time) up to its font timeout (on the test's clock): let both run.
      for (var i = 0; i < 100 && !controller.isLoaded && controller.error == null; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await _settle(tester);
      collect();
      if (!controller.isLoaded) {
        issue(RuntimeIssue('render_exception', 'error', 'Screen "$label" did not load: ${controller.error ?? 'timed out'}',
            screen: label, size: sizeName));
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 10));
        controller.dispose();
        codelessly.dispose();
        continue;
      }

      // 4. Interactions, in order.
      final skipped = <String>[];
      for (final step in args.steps) {
        final problem = await _apply(tester, step, controller, navigator, codelessly,
            warn: (code, message, nodeId) => issue(RuntimeIssue(code, 'warning', message,
                nodeId: nodeId, screen: label, size: sizeName, file: nodeId == null ? null : fileOfNode[nodeId])));
        if (problem != null) {
          // A node of another canvas of the screen (another breakpoint's
          // design) is absent here by design: a warning, not an error.
          final target = step.target.split('#').first;
          final elsewhere = problem.contains('no node') &&
              (fileOfNode.containsKey(target) ||
                  docs.values.any((d) => (api.readMap(d['nodes']) ?? const {}).values.any((n) => api.readMap(n)?['name'] == target)));
          if (elsewhere) {
            skipped.add('$step');
          } else {
            issue(RuntimeIssue('interaction_failed', 'error', problem, screen: label, size: sizeName));
          }
        }
        await _settle(tester);
        collect();
      }

      // 5. Full page: the view as tall as the content scrolls.
      if (skipped.isNotEmpty) {
        // One line per size, not one per step: these nodes are on another
        // breakpoint's canvas of the screen.
        issue(RuntimeIssue('interaction_failed', 'warning',
            'Skipped at this size (their nodes are on another breakpoint\'s canvas): ${skipped.join(', ')}. '
            'To reach whichever canvas is shown with one step, give the matching nodes the same "name" and name it in the step.',
            screen: label, size: sizeName));
      }
      // The page's own scroll view only (the largest one a user can
      // scroll): a decorative list that does not scroll, or one inside the
      // page, adds nothing. Content fixed to the window (outside the page's
      // scroll view: a bar pinned to the bottom, a canvas's bottom bar or
      // button) is drawn where a user first sees it, in the first window.
      final shifted = <NodeBox>[];
      if (args.fullPage) {
        var page = _pageScroll(binding);
        // A full page is the whole page from its top, whatever the steps
        // scrolled it to (a tap scrolls its node into view first).
        if (page != null && page.pixels.abs() > 0.01) {
          page.jumpTo(0);
          await _settle(tester);
          collect();
          page = _pageScroll(binding);
        }
        if (page != null && page.maxScrollExtent >= 1) {
          final pageBox = _nodeBoxAbove(page);
          final fixed = pageBox == null ? const <NodeBox>[] : _fixedAround(binding, pageBox);
          final before = {for (final b in fixed) b: _rectOf(b).topLeft};
          for (var round = 0; round < 3; round++) {
            if (!page.attached || page.maxScrollExtent < 1) break;
            final h = math.min(20000.0, tester.view.physicalSize.height + page.maxScrollExtent);
            tester.view.physicalSize = ui.Size(size.width, h.ceilToDouble());
            await _settle(tester);
            collect();
          }
          for (final b in fixed) {
            if (!b.attached || !b.hasSize) continue;
            final delta = before[b]! - _rectOf(b).topLeft;
            if (delta.distance < 0.5) continue;
            b.capturePaintShift = delta;
            shifted.add(b);
          }
          if (shifted.isNotEmpty) await tester.pump();
        }
      }

      // 6. Runtime checks, then the PNG.
      for (final i in _check(binding, published, docs, fileOfNode, label, sizeName, faces)) {
        issue(i);
      }
      for (final m in fetcher.misses) {
        // A weight next to one the family has is drawn with it, as on a
        // device whose font lacks it: not worth a warning.
        final near = m.substitute != null && m.substitute!.toLowerCase().startsWith('${m.family.toLowerCase()} ') && RegExp(r' (\d+)').firstMatch(m.substitute!) != null &&
            (int.parse(RegExp(r' (\d+)').firstMatch(m.substitute!)!.group(1)!) - m.weight).abs() <= 100 &&
            m.substitute!.contains('italic') == m.italic;
        if (near) continue;
        issue(RuntimeIssue('font_fallback', 'warning',
            m.substitute == null
                ? 'Font "${m.family}" ${m.weight}${m.italic ? ' italic' : ''} is not in the fonts directories: its text is drawn in the default font. Add the font file with --fonts <dir>, or use Roboto.'
                : 'Font "${m.family}" ${m.weight}${m.italic ? ' italic' : ''} is not in the fonts directories: drawn with ${m.substitute}. Add the font file with --fonts <dir> to see the real one.'));
      }
      final name = '${_fileSafe(label)}@$sizeName${args.label == null ? '' : '-${_fileSafe(args.label!)}'}.png';
      final file = '${args.out}/$name';
      await tester.runAsync(() async {
        final ro = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await ro.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        File(file).writeAsBytesSync(bytes!.buffer.asUint8List());
      });
      report.images.add(file);
      for (final b in shifted) {
        b.capturePaintShift = Offset.zero;
      }
      if (args.dumpLayout) {
        final boxes = [
          for (final b in _boxes(binding))
            {
              'id': b.id,
              if (b.instance != null) 'instance': '${b.instance}',
              'x': _rectOf(b).left.round(),
              'y': _rectOf(b).top.round(),
              'w': double.parse(b.size.width.toStringAsFixed(1)),
              'h': double.parse(b.size.height.toStringAsFixed(1)),
            },
        ];
        File(file.replaceFirst(RegExp(r'\.png$'), '.layout.json'))
            .writeAsStringSync(const JsonEncoder.withIndent(' ').convert(boxes));
      }

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
      collect();
      controller.dispose();
      codelessly.dispose();
    }
  }
}

Object? _valueAt(api.Json json, String pointer) {
  Object? v = json;
  for (final part in pointer.split('/').skip(1)) {
    if (v is Map) {
      v = v[part];
    } else if (v is List) {
      v = v[int.parse(part)];
    } else {
      return null;
    }
  }
  return v;
}

String _firstLine(String s) {
  final lines = s.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty && !l.startsWith('═') && !l.startsWith('══')).toList();
  final text = lines.take(3).join(' ');
  return text.length > 400 ? '${text.substring(0, 400)}...' : text;
}

String _fileSafe(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9_.-]+'), '_');

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.runAsync(() async {
    // Bounded: a load started under another test's fake clock never ends.
    await CodelesslyFonts.settled.timeout(const Duration(milliseconds: 500), onTimeout: () {});
    await PaintImages.settled(timeout: const Duration(seconds: 3));
  });
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// What a screen is called in file names and reports: its canvases'
/// `props.screen`, else its layout id.
String _screenName(
  ({api.PublishBundle bundle, Map<String, String> layoutOfCanvas, Map<String, List<String>> screens}) published,
  Map<String, api.Json> docs,
  String layout,
) {
  for (final d in docs.values) {
    final n = api.readMap(api.readMap(d['nodes'])?[layout]);
    final screen = api.readMap(n?['props'])?['screen'];
    if (screen is String && screen.isNotEmpty) return screen;
  }
  return layout;
}

/// The layouts to render: those [wanted] names (a canvas id, a layout id,
/// a screen name or a canvas name), else every screen.
List<String> _screens(
  ({api.PublishBundle bundle, Map<String, String> layoutOfCanvas, Map<String, List<String>> screens}) published,
  Map<String, api.Json> docs,
  List<String> wanted,
  void Function(RuntimeIssue) issue,
) {
  final all = published.screens.keys.toList();
  if (wanted.isEmpty) {
    final model = published.bundle.model;
    return [for (final s in all) if (!model.overlayLayoutIds.contains(s) && !model.backdropLayoutIds.contains(s)) s];
  }
  final out = <String>[];
  for (final w in wanted) {
    String? hit = published.screens.containsKey(w) ? w : published.layoutOfCanvas[w];
    if (hit == null) {
      for (final d in docs.values) {
        for (final e in (api.readMap(d['nodes']) ?? const {}).entries) {
          final n = api.readMap(e.value);
          if (n?['type'] != 'canvas') continue;
          final props = api.readMap(n!['props']) ?? const {};
          if (n['name'] == w || props['screen'] == w || n['path'] == w) hit ??= published.layoutOfCanvas[e.key];
        }
      }
    }
    if (hit == null) {
      issue(RuntimeIssue('unknown_screen_arg', 'error', '--screen "$w" names no canvas, screen or layout. Screens: ${all.join(', ')}.'));
    } else if (!out.contains(hit)) {
      out.add(hit);
    }
  }
  return out;
}

Iterable<RenderObject> _descendants(RenderObject root) sync* {
  final stack = <RenderObject>[root];
  while (stack.isNotEmpty) {
    final o = stack.removeLast();
    yield o;
    final kids = <RenderObject>[];
    o.visitChildren(kids.add);
    stack.addAll(kids.reversed);
  }
}

final Map<String, Set<int>?> _coverage = {};

/// The bounds of SVG path [data] in its own units, or null.
ui.Rect? _pathBounds(String data) {
  try {
    final path = parseSvgPath(data);
    return path?.getBounds();
  } catch (_) {
    return null;
  }
}

/// The details Flutter reported each error with (to name its node).
final Map<Object, FlutterErrorDetails> _errorDetails = Map.identity();

/// The errors reported since the last collection, in order.
final List<FlutterErrorDetails> _errorLog = [];

/// The node box an error came from: the render object its details name
/// (the overflowing flex, the object being laid out), up to its node.
NodeBox? _nodeOfError(FlutterErrorDetails? details) {
  if (details == null) return null;
  final infos = <DiagnosticsNode>[...?details.informationCollector?.call()];
  for (final d in infos) {
    final v = d.value;
    if (v is RenderObject) return _nodeBoxAbove(v);
  }
  return null;
}

/// The part of the screen [b] can be drawn in: the intersection of the
/// paint clips the document asks for above it (a clipping decoration, a
/// scroll view's viewport), in global coordinates; null when none clips it.
/// The screen's own edge (its canvas, the app around it) is not one: what
/// that cuts off is what `offscreen` reports.
ui.Rect? _visibleClip(RenderBox b) {
  ui.Rect? out;
  RenderObject child = b;
  for (RenderObject? p = b.parent; p != null; child = p, p = p.parent) {
    if (p is NodeBox && (p.node?.type == 'canvas' || p.node == null)) break;
    ui.Rect? local = p.describeApproximatePaintClip(child);
    if (local == null && p is RenderDesignScroll && p.clipBehavior != Clip.none && p.hasSize) local = ui.Offset.zero & p.size;
    if (local == null || p is! RenderBox || !p.hasSize) continue;
    final global = MatrixUtils.transformRect(p.getTransformTo(null), local);
    out = out == null ? global : out.intersect(global);
  }
  return out;
}

/// [o] or its nearest ancestor that is a node box.
NodeBox? _nodeBoxAbove(RenderObject o) {
  for (RenderObject? p = o; p != null; p = p.parent) {
    if (p is NodeBox) return p;
  }
  return null;
}

/// The node boxes beside [page]'s path to the root (not inside it, not
/// around it): what stays where it is while the page scrolls.
List<NodeBox> _fixedAround(WidgetsBinding binding, NodeBox page) {
  final above = <RenderObject>{};
  for (RenderObject? p = page; p != null; p = p.parent) {
    above.add(p);
  }
  final out = <NodeBox>[];
  for (final b in _boxes(binding)) {
    if (above.contains(b)) continue;
    // The topmost box of its branch: its nearest node box ancestor is on
    // the page's path.
    NodeBox? parent;
    for (RenderObject? p = b.parent; p != null; p = p.parent) {
      if (p is NodeBox) {
        parent = p;
        break;
      }
    }
    if (parent != null && above.contains(parent)) out.add(b);
  }
  return out;
}

/// Every node box on screen, in paint order (later ones are on top).
List<NodeBox> _boxes(WidgetsBinding binding) => [
      for (final view in binding.renderViews)
        for (final o in _descendants(view))
          if (o is NodeBox && o.attached && o.hasSize) o,
    ];

/// The box of node [id] on screen: the topmost (the last painted), or with
/// `id#n` the n-th (0-based) of the copies a list repeats.
NodeBox? _boxOf(WidgetsBinding binding, String id) {
  final hash = id.lastIndexOf('#');
  final index = hash < 0 ? null : int.tryParse(id.substring(hash + 1));
  final name = index == null ? id : id.substring(0, hash);
  var all = [for (final b in _boxes(binding)) if (b.id == name) b];
  // A node may be named by its `name` too: the same name on a screen's
  // breakpoint canvases reaches whichever is shown.
  if (all.isEmpty) all = [for (final b in _boxes(binding)) if (b.node?.name == name) b];
  if (all.isEmpty) return null;
  if (index == null) return all.last;
  return index < all.length ? all[index] : null;
}

/// The page's scroll view: of the vertical ones a user can scroll that have
/// something to scroll, the one with the largest viewport (outermost on a
/// tie).
RenderDesignScroll? _pageScroll(WidgetsBinding binding) {
  RenderDesignScroll? best;
  for (final view in binding.renderViews) {
    for (final o in _descendants(view)) {
      if (o is RenderDesignScroll && o.attached && o.hasSize && o.interactive && o.userScrollable && o.maxScrollExtent > 0) {
        final vertical = o.child != null && o.child!.size.height > o.size.height;
        if (!vertical) continue;
        if (best == null || o.size.width * o.size.height > best.size.width * best.size.height) best = o;
      }
    }
  }
  return best;
}

ui.Rect _rectOf(RenderBox b) {
  final o = b.localToGlobal(ui.Offset.zero);
  return o & b.size;
}

Future<String?> _apply(WidgetTester tester, Step step, CodelesslyWidgetController controller,
    GlobalKey<NavigatorState> navigator, Codelessly codelessly,
    {required void Function(String code, String message, String? nodeId) warn}) async {
  final binding = tester.binding;
  ui.Rect viewRect() => ui.Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio);

  // The render objects hit at [p], innermost first.
  List<RenderObject> hitAt(ui.Offset p) {
    final result = HitTestResult();
    binding.hitTestInView(result, p, tester.view.viewId);
    return [for (final e in result.path) if (e.target is RenderObject) e.target as RenderObject];
  }

  // The first point of [box]'s visible part (its center, then a grid over
  // it) whose hit test reaches the box (it or something inside it).
  ui.Offset? reachable(NodeBox box) {
    final r = _rectOf(box).intersect(viewRect());
    if (r.isEmpty) return null;
    // Its center, the centers of what it draws (its reaction layer first:
    // a text or icon is smaller than a box stretched or aligned in its
    // slot), then a grid over it.
    final inside = [
      for (final o in _descendants(box))
        if (o is RenderBox && o.attached && o.hasSize && !o.size.isEmpty) o,
    ]..sort((a, b) => (a is RenderReactions ? 0 : 1).compareTo(b is RenderReactions ? 0 : 1));
    final points = [
      r.center,
      for (final o in inside.take(200))
        if (o.localToGlobal(o.size.center(ui.Offset.zero)) case final c when r.contains(c)) c,
      for (var j = 0; j < 5; j++)
        for (var i = 0; i < 5; i++) ui.Offset(r.left + r.width * (i + 0.5) / 5, r.top + r.height * (j + 0.5) / 5),
    ];
    for (final p in points) {
      if (hitAt(p).contains(box)) return p;
    }
    return null;
  }

  // Scrolls [box]'s scrolling ancestors so its center is in the middle of
  // their viewport: below a header that overlays the top of the page.
  Future<void> centerInView(NodeBox box) async {
    for (RenderObject? o = box.parent; o != null; o = o.parent) {
      if (o is RenderDesignScroll && o.interactive) {
        final r = _rectOf(box), v = _rectOf(o);
        final vertical = o.axis == Axis.vertical;
        final delta = vertical ? r.center.dy - v.center.dy : r.center.dx - v.center.dx;
        if (delta.abs() < 1) continue;
        o.jumpTo((o.pixels + delta).clamp(0.0, o.maxScrollExtent));
        await _settle(tester);
      }
    }
  }

  // Where to put the pointer for [id], or the problem.
  Future<(ui.Offset?, String?)> pointAt(String id, String verb) async {
    final box = _boxOf(binding, id);
    if (box == null) return (null, '--$verb $id: no node "$id" is on screen.');
    var at = reachable(box);
    if (at == null) {
      await centerInView(box);
      at = reachable(box);
    }
    if (at != null) return (at, null);
    final r = _rectOf(box).intersect(viewRect());
    if (r.isEmpty) return (null, '--$verb $id: the node is outside the screen and nothing scrolls it into view; scroll to it first (--scroll).');
    final over = hitAt(r.center).whereType<NodeBox>().firstOrNull;
    if (over != null && _isInside(box, over)) {
      return (
        null,
        '--$verb $id: nothing in the node takes pointer events: it has no fill and no reaction, so a tap passes through to "${over.id}" (${over.node?.type}). '
            'Tap the node that has the reaction, or give this one a "click" reaction.',
      );
    }
    return (
      null,
      over == null
          ? '--$verb $id: nothing at the node\'s place takes pointer events (it is hidden, or drawn under something that is not a node).'
          : '--$verb $id: the node is covered by "${over.id}" (${over.node?.type}) wherever it shows; nothing was ${verb == 'tap' ? 'tapped' : 'hovered'}. '
              'Scroll it from under what overlays it (--scroll), or tap the covering node if that is what was meant.',
    );
  }

  // Whether anything along [path] reacts to a tap: a node's tap reaction,
  // or a widget inside the node hit (a button, an input) that handles taps.
  bool reactsToTap(List<RenderObject> path) {
    var inWidget = true;
    for (final o in path) {
      if (o is NodeBox) inWidget = false;
      if (o is RenderReactions && o.triggers.intersection(const {
        api.TriggerType.click, api.TriggerType.doubleTap, api.TriggerType.longPress, api.TriggerType.hold, //
        api.TriggerType.pointerDown, api.TriggerType.pointerUp, api.TriggerType.secondaryClick,
      }).isNotEmpty) {
        return true;
      }
      if (inWidget && o is RenderPointerListener && (o.onPointerDown != null || o.onPointerUp != null)) return true;
      if (inWidget && o is RenderSemanticsGestureHandler && o.onTap != null) return true;
      if (o is RenderEditable) return true;
    }
    return false;
  }

  // The text field ([EditableText]) inside node [id].
  Element? fieldIn(String id) {
    final box = _boxOf(binding, id);
    if (box == null) return null;
    for (final e in find.byType(EditableText).evaluate()) {
      final ro = e.renderObject;
      if (ro != null && _isInside(ro, box)) return e;
    }
    return null;
  }

  switch (step.kind) {
    case 'tap':
      final (at, problem) = await pointAt(step.target, 'tap');
      if (at == null) return problem;
      if (!reactsToTap(hitAt(at))) {
        warn('tap_no_reaction',
            '--tap ${step.target}: neither the node nor anything around it reacts to a tap (no "click" reaction, button or input), so the tap did nothing. '
                'Add {"trigger": "click", "actions": [...]} to the node, or tap the node that has it.',
            step.target.split('#').first);
      }
      await tester.tapAt(at);
      return null;
    case 'hover':
      final (at, problem) = await pointAt(step.target, 'hover');
      if (at == null) return problem;
      final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await g.addPointer(location: ui.Offset.zero);
      await g.moveTo(at);
      return null;
    case 'focus' || 'type':
      final verb = step.kind;
      var field = fieldIn(step.target);
      if (field == null) {
        if (_boxOf(binding, step.target) == null) return '--$verb ${step.target}: no node "${step.target}" is on screen.';
        return '--$verb ${step.target}: the node has no text field in it (only a textField, or a node around one, can be focused or typed into).';
      }
      final box = _boxOf(binding, step.target)!;
      if (reachable(box) == null) await centerInView(box);
      final finder = find.byElementPredicate((e) => identical(e, field));
      await tester.showKeyboard(finder);
      await tester.pump();
      if (verb == 'type') {
        field = fieldIn(step.target);
        if (field == null) return '--type ${step.target}: the text field went away when it was focused.';
        await tester.enterText(find.byElementPredicate((e) => identical(e, field)), step.value ?? '');
      }
      return null;
    case 'set':
      Object? value;
      try {
        value = jsonDecode(step.value ?? 'null');
      } catch (_) {
        value = step.value;
      }
      controller.setVariable(step.target, value);
      return null;
    case 'scroll':
      final px = double.tryParse(step.value ?? '');
      if (px == null) return '--scroll ${step.target}=${step.value}: the amount is not a number.';
      RenderDesignScroll? scroll;
      if (step.target == 'screen' || step.target.isEmpty) {
        scroll = _pageScroll(binding);
      } else {
        final b = _boxOf(binding, step.target);
        if (b == null) return '--scroll ${step.target}: no node "${step.target}" on screen.';
        scroll = _descendants(b).whereType<RenderDesignScroll>().firstOrNull;
        if (scroll == null) {
          // A list or other Flutter scrollable inside the node.
          final positions = [
            for (final e in find.byType(Scrollable).evaluate())
              if ((e.renderObject as RenderBox?) != null && _isInside(e.renderObject!, b)) (e as StatefulElement).state as ScrollableState,
          ];
          if (positions.isEmpty) return '--scroll ${step.target}: the node does not scroll (set props.scrollable: true).';
          positions.first.position.jumpTo(px);
          return null;
        }
      }
      if (scroll == null) return '--scroll ${step.target}: nothing on the screen scrolls.';
      scroll.jumpTo(px);
      return null;
    case 'navigate':
      final route = CodelesslyWidget.onGenerateRoute(codelessly)(RouteSettings(name: '/${step.target}'));
      if (route == null) return '--navigate ${step.target}: no such screen.';
      unawaited(navigator.currentState!.push(route));
      return null;
    case 'wait':
      final ms = int.tryParse(step.target) ?? 0;
      await tester.pump(Duration(milliseconds: ms));
      return null;
  }
  return 'Unknown step ${step.kind}.';
}

bool _isInside(RenderObject o, RenderObject ancestor) {
  for (RenderObject? p = o; p != null; p = p.parent) {
    if (identical(p, ancestor)) return true;
  }
  return false;
}

/// Overflows, text that doesn't fit or can't be seen, empty screens.
List<RuntimeIssue> _check(
  WidgetsBinding binding,
  ({api.PublishBundle bundle, Map<String, String> layoutOfCanvas, Map<String, List<String>> screens}) published,
  Map<String, api.Json> docs,
  Map<String, String> fileOfNode,
  String screen,
  String size,
  List<FontFace> faces,
) {
  final out = <RuntimeIssue>[];
  final boxes = _boxes(binding);
  // The glyphs a family has: its regular face's (else Roboto's).
  Set<int>? coverage(String? family) {
    final fam = (family == null || family.isEmpty) ? 'Roboto' : family;
    final face = faces.where((f) => f.family.toLowerCase() == fam.toLowerCase() && !f.italic).firstOrNull ??
        faces.where((f) => f.family == 'Roboto' && !f.italic).firstOrNull;
    if (face == null) return null;
    return _coverage.putIfAbsent(face.path, () => fontCoverage(face.path));
  }
  if (boxes.isEmpty) {
    out.add(RuntimeIssue('empty_screen', 'warning', 'Screen "$screen" drew no nodes.', screen: screen, size: size));
    return out;
  }
  final layouts = published.bundle.layouts;
  api.Node? nodeOf(String id) {
    for (final l in layouts.values) {
      final n = l.document[id];
      if (n != null) return n;
    }
    return null;
  }

  String? parentOf(String id) {
    for (final l in layouts.values) {
      final p = l.document.parentOf(id);
      if (p != null) return p;
    }
    return null;
  }

  final view = binding.renderViews.first.size;
  final byKey = <String, NodeBox>{for (final b in boxes) '${b.id}|${b.instance}': b};
  const repeaters = {'listView', 'gridView', 'pageView', 'tableView', 'tabs'};
  // Whether something between [b] and [upTo] (included; null: the screen)
  // scrolls along an axis, as rendered: a scroll view or viewport on that
  // axis, or a node that scrolls (or repeats items) that way as shown at
  // this size, its media rules and states applied.
  bool scrollsAlong(NodeBox b, bool horizontal, {RenderObject? upTo}) {
    for (RenderObject? o = b.parent; o != null; o = o.parent) {
      if (o is RenderDesignScroll && (o.axis == Axis.horizontal) == horizontal) return true;
      if (o is RenderViewportBase && (axisDirectionToAxis(o.axisDirection) == Axis.horizontal) == horizontal) return true;
      if (o is NodeBox) {
        final n = o.node;
        if (n != null && repeaters.contains(n.type)) return true;
        final sp = n?.spec?.prop('scrollable');
        if (n != null && sp != null && n.props.get(sp) == true) {
          final dir = n.spec!.prop('scrollDirection');
          final h = dir != null && n.props.get(dir) == api.Axis.horizontal;
          if (h == horizontal) return true;
        }
      }
      if (identical(o, upTo)) break;
    }
    return false;
  }

  for (final b in boxes) {
    // The node as it is shown at this size: its media rules and any active
    // state applied (the document's own node is its base).
    final node = b.node ?? nodeOf(b.id);
    if (node == null || node.type == 'canvas') continue;
    final r = _rectOf(b);
    if (r.width <= 0 && r.height <= 0) continue;
    final file = fileOfNode[b.id];
    // What of it can be seen: its box within every ancestor's clip.
    final clip = _visibleClip(b);
    final seen = clip == null ? r : r.intersect(clip);
    // Past its parent.
    final pid = parentOf(b.id);
    final parentBox = pid == null ? null : (byKey['$pid|${b.instance}'] ?? byKey['$pid|null']);
    final parent = parentBox?.node ?? (pid == null ? null : nodeOf(pid));
    if (parentBox != null && parent != null && parent.type != 'canvas' && parent.type != 'stack' && !seen.isEmpty) {
      final pr = _rectOf(parentBox);
      final dx = math.max(pr.left - seen.left, seen.right - pr.right);
      final dy = math.max(pr.top - seen.top, seen.bottom - pr.bottom);
      if (dx > 1 && !scrollsAlong(b, true, upTo: parentBox)) {
        out.add(RuntimeIssue('layout_overflow', 'warning',
            '"${b.id}" (${node.type}, ${r.width.toStringAsFixed(0)} wide) overflows its parent "$pid" (${parent.type}, ${pr.width.toStringAsFixed(0)} wide) by ${dx.toStringAsFixed(0)} px horizontally.',
            nodeId: b.id, screen: screen, size: size, file: file));
      }
      if (dy > 1 && !scrollsAlong(b, false, upTo: parentBox)) {
        out.add(RuntimeIssue('layout_overflow', 'warning',
            '"${b.id}" (${node.type}, ${r.height.toStringAsFixed(0)} tall) overflows its parent "$pid" (${parent.type}, ${pr.height.toStringAsFixed(0)} tall) by ${dy.toStringAsFixed(0)} px vertically.',
            nodeId: b.id, screen: screen, size: size, file: file));
      }
    }
    // Past the screen (the part not clipped away by an ancestor).
    if (!seen.isEmpty && seen.right > view.width + 1 && !scrollsAlong(b, true)) {
      out.add(RuntimeIssue('offscreen', 'warning',
          '"${b.id}" (${node.type}) ends at x=${seen.right.toStringAsFixed(0)}, past the ${view.width.toStringAsFixed(0)} px wide screen.',
          nodeId: b.id, screen: screen, size: size, file: file));
    }
    if (!seen.isEmpty && seen.bottom > view.height + 1 && !scrollsAlong(b, false)) {
      out.add(RuntimeIssue('offscreen', 'warning',
          '"${b.id}" (${node.type}) ends at y=${seen.bottom.toStringAsFixed(0)}, below the ${view.height.toStringAsFixed(0)} px tall screen, and nothing scrolls: make the body column scrollable ("scrollable": true).',
          nodeId: b.id, screen: screen, size: size, file: file));
    }
    // Icons that draw nothing.
    if (node.type == 'icon' && b.drawn) {
      final glyph = _descendants(b).whereType<RenderIconGlyph>().firstOrNull;
      final icon = glyph?.icon ?? const {};
      final image = icon['image'] ?? icon['svg'];
      if (glyph != null && image == null && IconSources.glyphOf(icon) == null) {
        out.add(RuntimeIssue('icon_not_drawn', 'warning',
            'Icon "${b.id}" draws nothing: ${icon.isEmpty ? 'it names no icon' : '${jsonEncode(icon)} is not a Material icon the renderer knows'}. '
            'Write a Material icon name ("search", "arrow_forward", "menu"), as listed at fonts.google.com/icons.',
            nodeId: b.id, screen: screen, size: size, file: file));
      }
    }
    // A path drawn past its box, where that part shows (no ancestor clips
    // it away).
    if ((node.type == 'path' || (node.type == 'box' && node.prop(api.BoxProps.path).isNotEmpty)) && b.drawn) {
      final data = node.type == 'path' ? node.prop(api.PathProps.data) : node.prop(api.BoxProps.path);
      final viewBox = node.type == 'path' ? node.prop(api.PathProps.viewBox) : null;
      final bounds = _pathBounds(data);
      if (bounds != null && viewBox == null) {
        final drawn = bounds.shift(r.topLeft);
        final shown = clip == null ? drawn : drawn.intersect(clip);
        final past = shown.isEmpty
            ? 0.0
            : math.max(math.max(r.left - shown.left, shown.right - r.right), math.max(r.top - shown.top, shown.bottom - r.bottom));
        if (past > 1) {
          out.add(RuntimeIssue('path_overflow', 'warning',
              'The path of "${b.id}" reaches ${past.toStringAsFixed(0)} px past its ${b.size.width.toStringAsFixed(0)}x${b.size.height.toStringAsFixed(0)} box '
              '(path coordinates are the box\'s own pixels, from its top left), and nothing clips that part away. '
              '${node.type == 'path' ? 'Give it "viewBox": [w, h] to scale it into the box, or ' : 'Make the box as large as the path, or '}set "decoration": {"clip": "hardEdge"} on an ancestor.',
              nodeId: b.id, screen: screen, size: size, file: file));
        }
      }
    }
    // Text.
    if (node.type == 'text') {
      final p = _descendants(b).whereType<RenderParagraph>().firstOrNull;
      if (p == null || !p.hasSize) continue;
      final text = p.text.toPlainText();
      if (text.trim().isEmpty) continue;
      final short = text.length > 30 ? '${text.substring(0, 30)}...' : text;
      if (text.contains(r'${')) {
        out.add(RuntimeIssue('expression_not_evaluated', 'warning',
            'Text "${b.id}" shows "$short" on screen: its expression did not evaluate. Check the formula (names, functions, quotes); '
            'a binding of "props.text" or "props.runs" must not also be written as text, and a "\${...}" inside a formula is not read.',
            nodeId: b.id, screen: screen, size: size, file: file));
      }
      final missing = <String>{};
      p.text.visitChildren((span) {
        if (span is TextSpan && span.text != null) {
          final cov = coverage(span.style?.fontFamily ?? p.text.style?.fontFamily);
          if (cov != null) {
            for (final r in span.text!.runes) {
              if (r > 0x20 && r != 0xA0 && !cov.contains(r)) missing.add(String.fromCharCode(r));
            }
          }
        }
        return true;
      });
      if (missing.isNotEmpty) {
        out.add(RuntimeIssue('missing_glyph', 'warning',
            'Text "${b.id}" has ${missing.map((c) => '"$c" (U+${c.runes.first.toRadixString(16).toUpperCase().padLeft(4, '0')})').join(', ')}, which its font has no glyph for: drawn as an empty box. '
            'Use a character the font has, an icon node, or a box with a "path" for a small mark.',
            nodeId: b.id, screen: screen, size: size, file: file));
      }
      var colorless = false;
      p.text.visitChildren((span) {
        if (span is TextSpan && (span.text?.trim().isNotEmpty ?? false) && span.style?.color == null && span.style?.foreground == null) {
          colorless = true;
        }
        return !colorless;
      });
      final rootStyle = p.text.style;
      if (colorless && (rootStyle?.color == null && rootStyle?.foreground == null)) {
        out.add(RuntimeIssue('text_no_color', 'warning', 'Text "${b.id}" ("$short") has no color, so it is painted white: set props.style.color.',
            nodeId: b.id, screen: screen, size: size, file: file));
      }
      final cut = node.prop(api.TextProps.overflow) != api.TextOverflow.clip;
      if (p.didExceedMaxLines && !cut) {
        out.add(RuntimeIssue('text_truncated', 'warning', 'Text "${b.id}" ("$short") is cut at maxLines: set "overflow": "ellipsis" if that is meant, or give it more lines.',
            nodeId: b.id, screen: screen, size: size, file: file));
      }
      final needH = p.getMaxIntrinsicHeight(b.size.width);
      final needW = p.getMinIntrinsicWidth(double.infinity);
      if (needH > b.size.height + 1.5 && !p.didExceedMaxLines) {
        out.add(RuntimeIssue('text_clipped', 'warning',
            'Text "${b.id}" ("$short") needs ${needH.toStringAsFixed(0)} px of height at ${b.size.width.toStringAsFixed(0)} wide but its box is ${b.size.height.toStringAsFixed(0)}: give it {"hug": n} height or more room.',
            nodeId: b.id, screen: screen, size: size, file: file));
      }
      if (needW > b.size.width + 1.5 && node.prop(api.TextProps.maxLines) == null) {
        out.add(RuntimeIssue('text_clipped', 'warning',
            'Text "${b.id}" ("$short") has a word ${needW.toStringAsFixed(0)} px wide in a box ${b.size.width.toStringAsFixed(0)} wide: it is cut. '
            'Give the text more width (a fill or larger width), a smaller font size, or "scaleDown": true.',
            nodeId: b.id, screen: screen, size: size, file: file));
      }
    }
  }
  return out;
}

/// Where a run's diagnostics go: `diagnostics.json`, or with a label
/// `diagnostics-<label>.json` (one run per state keeps each state's).
String diagnosticsFileName(String? label) => label == null ? 'diagnostics.json' : 'diagnostics-${_fileSafe(label)}.json';

RenderReport _finish(RenderReport report, RenderArgs args) {
  // Errors first, then warnings; each group in document order.
  report.diagnostics.sort((a, b) => (a['severity'] == 'error' ? 0 : 1).compareTo(b['severity'] == 'error' ? 0 : 1));
  Directory(args.out).createSync(recursive: true);
  File('${args.out}/${diagnosticsFileName(args.label)}').writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
    'errors': report.errors,
    'warnings': report.warnings,
    'images': [for (final i in report.images) i.split('/').last],
    'diagnostics': report.diagnostics,
  }));
  return report;
}

/// The report as text, one diagnostic per line.
String formatReport(RenderReport report) {
  final b = StringBuffer();
  for (final d in report.diagnostics) {
    final where = [
      if (d['file'] != null) d['file'],
      if (d['screen'] != null) 'screen ${d['screen']}',
      if (d['size'] != null) d['size'],
    ].join(' ');
    b.writeln('${(d['severity'] as String).toUpperCase().padRight(7)} ${d['code']}${where.isEmpty ? '' : ' [$where]'}'
        '${(d['path'] as String?)?.isNotEmpty ?? false ? ' ${d['path']}' : (d['nodeId'] != null ? ' node ${d['nodeId']}' : '')}');
    b.writeln('        ${d['message']}${d['suggestion'] != null ? ' Did you mean "${d['suggestion']}"?' : ''}');
  }
  for (final i in report.images) {
    b.writeln('wrote $i');
  }
  b.writeln('${report.errors} error(s), ${report.warnings} warning(s).');
  return b.toString();
}
