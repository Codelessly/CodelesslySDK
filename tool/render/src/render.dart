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
import 'package:flutter/services.dart' show FontLoader, LogicalKeyboardKey, MethodCall, SystemChannels;
import 'package:flutter_test/flutter_test.dart';
import 'package:codelessly_sdk/src/render/paint/icon_glyph.dart' show IconSources, RenderIconGlyph;
import 'package:codelessly_sdk/src/render/paint/path_paint.dart' show parseSvgPath;
import 'package:codelessly_sdk/src/render/view_scroll.dart' show RenderSticky;

import 'args.dart';
import 'compare.dart';
import 'fonts.dart';
import 'prepare.dart';
import 'publish.dart';
import 'site.dart';

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
  ('fill_fallback', 'warning', 'A node fills an axis its parent measures with no limit (a hugging row or column, a wrapping line, a grid row sized to its content): it takes the design number of its {"fill": n}. The message names the parent and the fix.'),
  ('compare_failed', 'warning', '--compare found no reference screenshot for a capture (or could not read it).'),
  ('offscreen', 'warning', 'A node extends past the screen edge where nothing scrolls: on a device it is cut off.'),
  ('text_clipped', 'warning', 'A text does not fit its box: its lines are taller than the box, or a word is wider.'),
  ('text_truncated', 'warning', 'A text was cut at maxLines with overflow "clip" (an ellipsis or fade is taken as meant).'),
  ('text_no_color', 'warning', 'A text has no color: the engine paints it white (invisible on a light background). Set props.style.color.'),
  ('font_fallback', 'warning', 'A font family (or weight/style) is not in the fonts directories: the text is drawn in another font.'),
  ('image_failed', 'error', 'An image could not be loaded or decoded (missing file, bad data: URL).'),
  ('image_network', 'warning', 'An image is on the network: the render command does not fetch it, so it is blank in the screenshot.'),
  ('empty_screen', 'warning', 'The screen drew no node boxes (nothing to show).'),
  ('component_missing', 'error', 'A call rendered without its component\'s definition (or nested past the depth limit): an empty box of its size. The message names the call by path.'),
];

/// The result of a run.
final class RenderReport {
  final List<api.Json> diagnostics = [];
  final List<String> images = [];

  /// `--compare`: each capture against its reference.
  final List<ImageComparison> comparisons = [];

  /// Files a `downloadFile` action saved (written under `<out>/downloads`).
  final List<api.Json> downloads = [];

  /// Texts a `copyToClipboard` action copied, in order.
  final List<api.Json> clipboard = [];
  int get errors => diagnostics.where((d) => d['severity'] == 'error').length;
  int get warnings => diagnostics.where((d) => d['severity'] == 'warning').length;
}

/// Saves a `downloadFile` action's file under `<out>/downloads/<capture>/`
/// (a headless run has no save dialog), and lists it in the report.
final class _OutDirExporter implements FileExporter {
  _OutDirExporter(this.out, this.report);
  final String out;
  final RenderReport report;

  /// The capture's name (`home@390x844-label`), set per screen and size.
  String capture = '';
  String screen = '', size = '';

  @override
  Future<bool> saveText({required String fileName, required String text, String mimeType = 'text/plain'}) async {
    final name = exportFileName(fileName);
    final file = File('$out/downloads/$capture/$name');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(text);
    report.downloads.add({'file': file.path, 'fileName': name, 'mimeType': mimeType, 'bytes': utf8.encode(text).length, 'screen': screen, 'size': size});
    return true;
  }
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
  // A directory with site.json (or components/) is a site: pages and components.
  final site = loadSite(args.inputs, loadInputs);
  final inputs = site.inputs;
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
    for (final v in api.readList(site.manifest?['variables']) ?? const [])
      if (api.readMap(v) case final api.Json m when (api.readList(m['parameters'])?.isNotEmpty ?? false) && m['name'] is String) m['name'] as String,
  };
  FormulaReport check(String formula) =>
      (error: FormulaEvaluator.errorOf(formula, functionNames: functions), paths: FormulaEvaluator.referencedPaths(formula));
  final manifest = site.manifest == null ? null : api.SiteManifest.fromJson(site.manifest);
  final diagnostics = validateProject(docs, options: ValidateOptions(formulas: check, variables: functions), manifest: manifest);
  // Notes (a schema-2 document, migrated as it loads) are not findings.
  report.diagnostics.addAll(diagnostics.where((d) => d.severity != Severity.info).map((d) => d.toJson()));
  // The site's theme: its named colors and text styles.
  final themeJson = api.readMap(site.manifest?['theme']);
  report.diagnostics.addAll(validateTheme(themeJson,
          breakpoints: site.manifest?['breakpoints'] == null ? null : api.Breakpoints.fromJson(site.manifest!['breakpoints']))
      .map((d) => d.withFile(api.SiteManifest.fileName).toJson()));
  if (args.validateOnly || docs.isEmpty) return _finish(report, args);

  // 2. Fonts and assets. A font handler left by an earlier run in this
  // process would load into a disposed instance.
  FontDemand.handler = null;
  final root = flutterRoot ?? Platform.environment['FLUTTER_ROOT'] ?? '';
  unreadFonts.clear();
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
  // The site's components: what its pages' calls render.
  final components = ComponentRegistry();
  // `--component <Type>`: that component alone, on a page of its own per
  // parameter set (each preview at its size).
  final alone = <({String name, api.Json page, double? width, double? height})>[];
  // `--components-all`: every component of the site, so (an AI author
  // above all) can see each part it may call.
  final aloneTypes = [
    ?args.component,
    if (args.componentsAll)
      for (final d in docs.values)
        if (isComponentJson(d))
          if (api.readMap(d[api.kWidgetKey])?['type'] case final String t when t != args.component) t,
  ];
  if (args.componentsAll && aloneTypes.isEmpty) {
    issue(RuntimeIssue('unknown_screen_arg', 'error', '--components-all: no component documents in ${args.inputs.join(', ')}.'));
    return _finish(report, args);
  }
  for (final type in aloneTypes) {
    final def = docs.values.where((d) => isComponentJson(d) && api.readMap(d[api.kWidgetKey])?['type'] == type).firstOrNull;
    if (def == null) {
      issue(RuntimeIssue('unknown_screen_arg', 'error', '--component $type: no component of that type in ${args.inputs.join(', ')}.'));
      return _finish(report, args);
    }
    try {
      final slots = args.slots == null || type != args.component ? null : jsonDecode(File(args.slots!).readAsStringSync()) as api.Json;
      alone.addAll(componentPages(type, def, props: type == args.component ? args.props : null, slots: slots));
    } catch (e) {
      issue(RuntimeIssue('invalid_json', 'error', '--props or --slots: ${_firstLine('$e')}'));
      return _finish(report, args);
    }
  }
  for (final a in alone) {
    docs[a.name] = a.page;
    dirs[a.name] = Directory.current.path;
  }
  for (final e in docs.entries) {
    final p = prepare(e.value, dir: dirs[e.key]!, defaultFamily: 'Roboto', codepoints: codepoints);
    if (isComponentJson(e.value)) {
      components.define(api.LayoutDocument.fromJson(p.json));
    } else if (alone.isEmpty || alone.any((a) => a.name == e.key)) {
      pages.add((name: e.key, json: p.json));
    }
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
  final published = publishPages(pages,
      variables: publishVariables(site.manifest),
      breakpoints: site.manifest?['breakpoints'],
      components: [for (final t in components.types) components[t]!.document.toJson()],
      theme: prepareTheme(themeJson ?? const {}, defaultFamily: 'Roboto'));
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
  // The clipboard, in memory (a headless run has none): what is copied is
  // listed in the report, and reads give it back.
  String? clipboardText;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) async {
    switch (call.method) {
      case 'Clipboard.setData':
        clipboardText = (call.arguments as Map?)?['text'] as String?;
        report.clipboard.add({'text': clipboardText, if (clipboardAt != null) 'screen': clipboardAt!.$1, if (clipboardAt != null) 'size': clipboardAt!.$2});
        return null;
      case 'Clipboard.getData':
        return clipboardText == null ? null : {'text': clipboardText};
      case 'Clipboard.hasStrings':
        return {'value': clipboardText?.isNotEmpty ?? false};
    }
    return null;
  });
  // `--now`: the time now() returns.
  FormulaClock.pinned = args.now;
  // Icons named without a codepoint (a bound name) draw from the font.
  IconSources.codepointOf = (name, style) =>
      codepoints[style == 'filled' ? '${name}_baseline' : '${name}_$style'] ?? codepoints[name];
  try {
    if (alone.isEmpty) {
      await _renderAll(tester, args, faces, published, docs, fileOfNode, fetcher, issue, report, components: components);
    }
    for (final a in alone) {
      // A preview renders at its own size; ad-hoc parameters at each size.
      final sizes = a.width != null && a.height != null ? [ui.Size(a.width!, a.height!)] : args.sizes;
      await _renderAll(tester, args.copyWith(sizes: sizes, screens: [a.name]), faces, published, docs, fileOfNode, fetcher, issue,
          report, components: components);
    }
    for (final e in components.missing.entries) {
      for (final path in e.value) {
        issue(RuntimeIssue('component_missing', 'error', 'Call "$path" renders ${e.key}, which no component document of the site defines.',
            nodeId: path));
      }
    }
  } finally {
    debugDisableShadows = true;
    FlutterError.onError = previousOnError;
    IconSources.codepointOf = null;
    FormulaClock.pinned = null;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
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
  RenderReport report, {
  ComponentRegistry? components,
}) async {
  // 3. Which screens.
  final screens = _screens(published, docs, args.screens, (s) => issue(s));
  final recorder = _Recorder();
  final binding = tester.binding;
  final exporter = _OutDirExporter(args.out, report);
  for (final screen in screens) {
    final label = _screenName(published, docs, screen);
    for (final size in args.sizes) {
      final sizeName = '${size.width.round()}x${size.height.round()}';
      exporter
        ..capture = '${_fileSafe(label)}@$sizeName${args.label == null ? '' : '-${_fileSafe(args.label!)}'}'
        ..screen = label
        ..size = sizeName;
      clipboardAt = (label, sizeName);
      final codelessly = Codelessly(
        loader: MemoryPublishLoader(published.bundle),
        components: components,
        fonts: fetcher,
        config: CodelesslyConfig(services: Services(analytics: recorder, exports: exporter), fontTimeout: const Duration(seconds: 5)),
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
                  : 'Node "${node.tree.pathOf(node.id, node.instance)}" (${node.node?.type ?? '?'}): $text',
              nodeId: node?.tree.pathOf(node.id, node.instance),
              screen: label,
              size: sizeName,
              file: node == null ? null : _fileOf(node, fileOfNode, docs)));
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
          // The layout's controls take the project's theme, never this one;
          // their font without one is the platform's (Roboto, as on Android
          // and the web), given to the published theme ([prepareTheme]).
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
        final problem = await _apply(tester, step, controller, navigator, codelessly, screens: _screenList(published, docs),
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
      // Full page: the page's own scroll view (the largest one a user can
      // scroll; a decorative list that does not scroll, or one inside the
      // page, adds nothing) captured over its whole extent while the window
      // keeps its size, as a browser's full-page screenshot does: the
      // window's height, `screen.height` and whatever is sized or pinned to
      // the window stay as on the device, and content fixed to the window
      // (a header, a drawer, a bar pinned to the bottom) is drawn where a
      // user first sees it, in the first window. The capture starts at the
      // page's top, whatever a step scrolled it to.
      RenderDesignScroll? fullPage;
      if (args.fullPage) {
        var page = _pageScroll(binding);
        if (page != null && page.pixels.abs() > 0.01) {
          page.jumpTo(0);
          await _settle(tester);
          collect();
          page = _pageScroll(binding);
        }
        if (page != null && page.maxScrollExtent >= 1) fullPage = page;
      }

      // A --set holds against what no step did: a timer or a load reaction
      // that wrote the variable after it (a clock) is undone, and said.
      final held = <String, Object?>{};
      for (final step in args.steps) {
        if (step.kind == 'set') {
          held[step.target] = _stepValue(step);
        } else if (!const {'wait', 'set'}.contains(step.kind)) {
          held.clear();
        }
      }
      for (final e in held.entries) {
        final now = _readVariable(binding, controller, e.key);
        if (jsonEncode(now) == jsonEncode(e.value)) continue;
        _writeVariable(binding, controller, e.key, e.value);
        await tester.pump();
        issue(RuntimeIssue('set_overwritten', 'warning',
            '--set ${e.key}: a reaction (a timer, a load) set it to ${jsonEncode(now)} after the step; the capture shows it as set, ${jsonEncode(e.value)}. '
            'A clock written from now() stays put with --now <ISO time> (now() returns it).',
            screen: label, size: sizeName));
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
        final style = '${m.weight}${m.italic ? ' italic' : ''}';
        final has = [for (final f in faces) if (f.family.toLowerCase() == m.family.toLowerCase()) '${f.weight}${f.italic ? ' italic' : ''}'];
        final slug = m.family.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
        final unread = [
          for (final u in unreadFonts)
            if (u.path.toLowerCase().replaceAll(RegExp(r'[^a-z0-9/]+'), '').contains(slug)) '${u.path}: ${u.reason}',
        ];
        final looked = [
          'the built-in Roboto and Material Icons',
          if (args.fontDirs.isNotEmpty) fontDirsOf(args.fontDirs).join(', ') else 'no --fonts directory',
        ].join('; ');
        issue(RuntimeIssue('font_fallback', 'warning',
            'Font "${m.family}" $style (fontFamily "${m.family}", fontWeight ${m.weight}, fontStyle ${m.italic ? 'italic' : 'normal'}) was asked for; '
            '${has.isEmpty ? 'no file of that family was found' : 'the family has only ${has.join(', ')}'} in $looked. '
            '${m.substitute == null ? 'Its text is drawn in the default font.' : 'Drawn with ${m.substitute}.'}'
            '${unread.isEmpty ? '' : ' Found but not read: ${unread.take(3).join('; ')}.'}'
            ' Add its files with --fonts <dir> (.ttf, .otf or .woff: a font package folder such as node_modules/@fontsource/<family>, '
            'or `--fonts system` for the system\'s fonts).'));
      }
      final name = '${_fileSafe(label)}@$sizeName${args.label == null ? '' : '-${_fileSafe(args.label!)}'}.png';
      final file = '${args.out}/$name';
      final ro = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final page = fullPage;
      if (page == null || !page.attached) {
        await tester.runAsync(() async {
          final image = await ro.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          File(file).writeAsBytesSync(bytes!.buffer.asUint8List());
        });
      } else {
        File(file).writeAsBytesSync(await _captureFullPage(tester, ro, page, binding));
      }
      report.images.add(file);
      if (args.compare case final String reference) {
        final found = referenceFor(file, reference);
        if (found.file == null) {
          issue(RuntimeIssue('compare_failed', 'warning',
              '--compare: no reference for $name in $reference${found.candidates.isEmpty ? '' : ' among ${found.candidates.map((c) => c.split('/').last).join(', ')}'}: '
              'name the file, or give the state a --label the reference file names.',
              screen: label, size: sizeName));
        } else {
          try {
            report.comparisons.add((await tester.runAsync(() => compareImages(file, found.file!)))!);
          } catch (e) {
            issue(RuntimeIssue('compare_failed', 'warning', '--compare: ${found.file} could not be compared: ${_firstLine('$e')}',
                screen: label, size: sizeName));
          }
        }
      }
      if (args.dumpLayout) {
        final boxes = [
          for (final b in _boxes(binding))
            {
              'id': b.id,
              if (b.instance != null) 'instance': '${b.instance}',
              if (componentInstanceOf(b.instance) != null) 'path': b.tree.pathOf(b.id, b.instance),
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

/// Every screen by what a step may name it: its canvases' paths, else
/// their screen names, else the canvas ids.
List<String> _screenList(
  ({api.PublishBundle bundle, Map<String, String> layoutOfCanvas, Map<String, List<String>> screens}) published,
  Map<String, api.Json> docs,
) =>
    [
      for (final d in docs.values)
        for (final e in (api.readMap(d['nodes']) ?? const {}).entries)
          if (api.readMap(e.value) case final api.Json n when n['type'] == 'canvas' && published.layoutOfCanvas.containsKey(e.key))
            n['path'] is String && (n['path'] as String).isNotEmpty ? n['path'] as String : e.key,
    ];

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

Iterable<RenderObject> _descendants(RenderObject root, {Set<RenderObject> skip = const {}}) sync* {
  final stack = <RenderObject>[root];
  while (stack.isNotEmpty) {
    final o = stack.removeLast();
    if (skip.contains(o)) continue;
    yield o;
    final kids = <RenderObject>[];
    o.visitChildren(kids.add);
    stack.addAll(kids.reversed);
  }
}

final Map<String, Set<int>?> _coverage = {};

/// The screen and size a copy to the clipboard happens at.
(String, String)? clipboardAt;

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

/// The PNG of the whole of [page] (the page's scroll view) as a window
/// [ro] keeps its size: the first window as it shows, then the rest of the
/// page a viewport at a time, stitched below it; the window's part below
/// the page view as it is at the page's end. As tall as the window plus
/// what the page scrolls. The page is left at its top.
///
/// What a reader sees once is drawn once: in the windows after the first,
/// the boxes fixed to the window over the page (painted after it: a header,
/// a drawer, a bottom bar) are left out, a sticky node is drawn where it is
/// in the page (not pinned at the top of each window), and only the page's
/// own route is drawn (a modal, a dialog or a sheet open over it, and its
/// barrier, show in the first window only).
Future<List<int>> _captureFullPage(WidgetTester tester, RenderRepaintBoundary ro, RenderDesignScroll page, WidgetsBinding binding) async {
  final window = ro.size;
  final view = _rectOf(page);
  final max = page.maxScrollExtent;
  final pageBox = _nodeBoxAbove(page);
  final all = _boxes(binding);
  final pageIndex = pageBox == null ? -1 : all.indexOf(pageBox);
  final over = pageBox == null
      ? const <NodeBox>[]
      : [for (final b in _fixedAround(binding, pageBox)) if (all.indexOf(b) > pageIndex && !_isInside(b, page)) b];
  // The page's route alone: the outermost repaint boundary between the
  // page and its navigator's theater (routes over it are its siblings).
  final theaters = {for (final (_, t) in _theaters()) t};
  RenderRepaintBoundary? route;
  for (RenderObject? p = page; p != null && !identical(p, ro); p = p.parent) {
    if (theaters.contains(p)) break;
    if (p is RenderRepaintBoundary) route = p;
  }
  // Only when something is open over the page; else the window is the route.
  final covered = route != null && _boxes(binding).any((b) => !_isInside(b, route!) && !over.contains(b) && all.indexOf(b) > pageIndex);
  final layer = covered ? route : ro;
  final layerAt = covered ? route.localToGlobal(Offset.zero) - ro.localToGlobal(Offset.zero) : Offset.zero;
  Future<ui.Image> shot(RenderRepaintBoundary b) async => (await tester.runAsync(() => b.toImage(pixelRatio: 1)))!;
  final first = await shot(ro);
  final slices = <(ui.Image, double)>[];
  const hidden = Offset(0, -1e6);
  for (final b in over) {
    b.capturePaintShift = hidden;
  }
  try {
    for (var o = view.height; ; o += view.height) {
      final at = math.min(o, max);
      page.jumpTo(at);
      await _settle(tester);
      // Sticky nodes in place, as the page lays them out.
      var unpinned = false;
      for (final s in _descendants(page).whereType<RenderSticky>()) {
        if (s.shift == 0) continue;
        s.shift = 0;
        s.markNeedsPaint();
        unpinned = true;
      }
      if (unpinned) {
        page.markNeedsPaint();
        await tester.pump();
      }
      slices.add((await shot(layer), at));
      if (at >= max) break;
    }
  } finally {
    for (final b in over) {
      b.capturePaintShift = Offset.zero;
    }
    page.jumpTo(0);
    await _settle(tester);
  }
  final total = (window.height + max).ceilToDouble();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final paint = Paint()..filterQuality = FilterQuality.none;
  // Rows of [img] (a capture of [layer]) in window coordinates.
  void rows(ui.Image img, double top, double height, double to) => canvas.drawImageRect(
      img, Rect.fromLTWH(-layerAt.dx, top - layerAt.dy, window.width, height), Rect.fromLTWH(0, to, window.width, height), paint);
  for (final (img, at) in slices) {
    // The viewport's rows: the page from offset [at].
    rows(img, view.top, view.height, view.top + at);
  }
  // Below the page view at the page's end (the fixed boxes left out).
  final (last, lastAt) = slices.last;
  rows(last, view.bottom, window.height - view.bottom, view.bottom + lastAt);
  // The first window on top, as it shows.
  canvas.drawImage(first, Offset.zero, paint);
  final picture = recorder.endRecording();
  return (await tester.runAsync(() async {
    final image = await picture.toImage(window.width.ceil(), total.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    first.dispose();
    for (final (img, _) in slices) {
      img.dispose();
    }
    return bytes!.buffer.asUint8List();
  }))!;
}

/// The fit boxes of node box [b]'s own chain (not those of the nodes
/// inside it).
Iterable<RenderFitBox> _ownFitBoxes(NodeBox b) sync* {
  final stack = <RenderObject>[];
  b.visitChildren(stack.add);
  while (stack.isNotEmpty) {
    final o = stack.removeLast();
    if (o is NodeBox) continue;
    if (o is RenderFitBox) yield o;
    o.visitChildren(stack.add);
  }
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

/// The overlays' theaters (each navigator's stack of routes).
List<(Element, RenderObject)> _theaters() {
  final out = <(Element, RenderObject)>[];
  for (final overlay in find.byType(Overlay, skipOffstage: false).evaluate()) {
    Element? el = overlay;
    while (el != null && el is! RenderObjectElement) {
      Element? next;
      el.visitChildren((c) => next ??= c);
      el = next;
    }
    final ro = el?.renderObject;
    if (el != null && ro != null) out.add((el, ro));
  }
  return out;
}

/// The render objects of the routes a navigator keeps offstage (a page
/// covered by the page pushed over it): still attached with their last
/// layout, but neither painted nor hit. Steps, checks and captures skip them.
Set<RenderObject> _offstage() {
  final out = <RenderObject>{};
  for (final (theater, _) in _theaters()) {
    final all = <Element>[];
    theater.visitChildren(all.add);
    final onstage = <Element>{};
    theater.debugVisitOnstageChildren(onstage.add);
    for (final e in all) {
      if (onstage.contains(e)) continue;
      final ro = e.renderObject;
      if (ro != null) out.add(ro);
    }
  }
  return out;
}

/// Every node box on screen, in paint order (later ones are on top); not
/// those of a page covered by another.
List<NodeBox> _boxes(WidgetsBinding binding) {
  final skip = _offstage();
  return [
    for (final view in binding.renderViews)
      for (final o in _descendants(view, skip: skip))
        if (o is NodeBox && o.attached && o.hasSize) o,
  ];
}

/// The box of node [id] on screen: the topmost (the last painted), or with
/// `id#n` the n-th (0-based) of the copies a list repeats.
NodeBox? _boxOf(WidgetsBinding binding, String id) {
  // A node inside a component, by path: `plans/card1/cta`; a call by its
  // id (its box is its definition root's): `send`, `sizes#3`.
  final byPath = id.contains('/') || _boxes(binding).any((b) => b.id != id.split('#').first && b.tree.isInstanceRoot(b.id, b.instance) && b.tree.pathOf(b.id, b.instance) == id.split('#').first);
  if (byPath) {
    for (final b in _boxes(binding)) {
      final found = b.tree.boxAtPath(id);
      if (found != null && found.attached && found.hasSize) return found;
    }
    return null;
  }
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
  final skip = _offstage();
  for (final view in binding.renderViews) {
    for (final o in _descendants(view, skip: skip)) {
      if (o is RenderDesignScroll && o.attached && o.hasSize && o.interactive && o.userScrollable && o.maxScrollExtent > 0) {
        final vertical = o.child != null && o.child!.size.height > o.size.height;
        if (!vertical) continue;
        if (best == null || o.size.width * o.size.height > best.size.width * best.size.height) best = o;
      }
    }
  }
  return best;
}

/// [b]'s box in [parent]'s coordinates by layout alone (the parent data
/// offsets between them, no paint transform; a proxy places its child at
/// its own origin); null when something between them positions its child
/// another way (a sliver).
ui.Rect? _laidOutIn(RenderBox b, RenderBox parent) {
  var offset = ui.Offset.zero;
  for (RenderObject? o = b; o != null && !identical(o, parent); o = o.parent) {
    final data = o.parentData;
    if (data is BoxParentData) {
      offset += data.offset;
    } else if (data.runtimeType != ParentData) {
      // Not a box offset, and not a proxy's bare parent data (no offset).
      return null;
    }
  }
  return offset & b.size;
}

ui.Rect _rectOf(RenderBox b) {
  final o = b.localToGlobal(ui.Offset.zero);
  return o & b.size;
}

Future<String?> _apply(WidgetTester tester, Step step, CodelesslyWidgetController controller,
    GlobalKey<NavigatorState> navigator, Codelessly codelessly,
    {required void Function(String code, String message, String? nodeId) warn, List<String> screens = const []}) async {
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
      _writeVariable(binding, controller, step.target, _stepValue(step));
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
      // A URL path (`/project?id=x`), a canvas id or a screen name, with a
      // query string the screen reads as `${route.<name>}`.
      final location = step.target.trim().replaceFirst(RegExp(r'^/+'), '');
      final model = codelessly.publishModel;
      // ignore: invalid_use_of_visible_for_testing_member
      if (model != null && location.isNotEmpty && CodelesslyWidget.resolveScreen(model, location) == null) {
        return '--navigate ${step.target}: no screen "${location.split('?').first}". Name a canvas id, a screen name or a URL path '
            '(with a query string for its params: speaker?id=ada). Screens: ${screens.join(', ')}.';
      }
      final route = CodelesslyWidget.onGenerateRoute(codelessly)(RouteSettings(name: '/$location'));
      if (route == null) return '--navigate ${step.target}: no such screen.';
      unawaited(navigator.currentState!.push(route));
      return null;
    case 'wait':
      final ms = int.tryParse(step.target) ?? 0;
      await tester.pump(Duration(milliseconds: ms));
      return null;
    case 'unfocus':
      final focused = FocusManager.instance.primaryFocus;
      if (focused == null || focused.context == null) return null;
      focused.unfocus();
      tester.testTextInput.hide();
      await tester.pump();
      return null;
    case 'key':
      final parts = step.target.split('+').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
      if (parts.isEmpty) return '--key: name a key (ArrowRight, Enter, Escape, Tab, shift+Tab...).';
      final key = _keyNamed(parts.last);
      if (key == null) {
        return '--key ${step.target}: "${parts.last}" is not a key the command knows. Keys: ${_keyNames.keys.join(', ')}, a letter or a digit; modifiers: shift, ctrl, alt, meta.';
      }
      final modifiers = <LogicalKeyboardKey>[];
      for (final m in parts.take(parts.length - 1)) {
        final k = switch (m.toLowerCase()) {
          'shift' => LogicalKeyboardKey.shiftLeft,
          'ctrl' || 'control' => LogicalKeyboardKey.controlLeft,
          'alt' || 'option' => LogicalKeyboardKey.altLeft,
          'meta' || 'cmd' || 'command' => LogicalKeyboardKey.metaLeft,
          _ => null,
        };
        if (k == null) return '--key ${step.target}: "$m" is not a modifier (shift, ctrl, alt, meta).';
        modifiers.add(k);
      }
      for (final m in modifiers) {
        await tester.sendKeyDownEvent(m);
      }
      await tester.sendKeyEvent(key);
      for (final m in modifiers.reversed) {
        await tester.sendKeyUpEvent(m);
      }
      await tester.pump();
      return null;
  }
  return 'Unknown step ${step.kind}.';
}

const _keyNames = <String, LogicalKeyboardKey>{
  'ArrowLeft': LogicalKeyboardKey.arrowLeft,
  'ArrowRight': LogicalKeyboardKey.arrowRight,
  'ArrowUp': LogicalKeyboardKey.arrowUp,
  'ArrowDown': LogicalKeyboardKey.arrowDown,
  'Enter': LogicalKeyboardKey.enter,
  'Escape': LogicalKeyboardKey.escape,
  'Tab': LogicalKeyboardKey.tab,
  'Space': LogicalKeyboardKey.space,
  'Home': LogicalKeyboardKey.home,
  'End': LogicalKeyboardKey.end,
  'Backspace': LogicalKeyboardKey.backspace,
  'Delete': LogicalKeyboardKey.delete,
  'PageUp': LogicalKeyboardKey.pageUp,
  'PageDown': LogicalKeyboardKey.pageDown,
};

/// The key named [name] (as the web's `KeyboardEvent.key`: `ArrowRight`,
/// `Enter`; any case), a letter or a digit.
LogicalKeyboardKey? _keyNamed(String name) {
  for (final e in _keyNames.entries) {
    if (e.key.toLowerCase() == name.toLowerCase() || (name.toLowerCase() == 'esc' && e.key == 'Escape')) return e.value;
  }
  if (RegExp(r'^[A-Za-z]$').hasMatch(name)) return LogicalKeyboardKey(LogicalKeyboardKey.keyA.keyId + name.toLowerCase().codeUnitAt(0) - 0x61);
  if (RegExp(r'^[0-9]$').hasMatch(name)) return LogicalKeyboardKey(LogicalKeyboardKey.digit0.keyId + name.codeUnitAt(0) - 0x30);
  return null;
}

/// A `--set` step's value: JSON, else the text as it is.
Object? _stepValue(Step step) {
  try {
    return jsonDecode(step.value ?? 'null');
  } catch (_) {
    return step.value;
  }
}

/// The root scope of the screen shown when it is not [controller]'s (a
/// screen navigated to), else null: steps act on the screen in view.
ValueScope? _shownScope(WidgetsBinding binding, CodelesslyWidgetController controller) {
  final own = controller.tree;
  final canvases = [for (final b in _boxes(binding)) if (b.node?.type == 'canvas') b];
  if (own == null || canvases.isEmpty || canvases.any((b) => identical(b.tree, own))) return null;
  final top = canvases.last;
  final bindings = top.tree.bindings;
  return bindings is NodeBinder ? bindings.rootScopeOf(top.id) : null;
}

/// Sets variable [name] of the screen in view.
void _writeVariable(WidgetsBinding binding, CodelesslyWidgetController controller, String name, Object? value) {
  final scope = _shownScope(binding, controller);
  if (scope != null) {
    setVariableIn(scope, name, value);
  } else {
    controller.setVariable(name, value);
  }
}

/// Variable [name] of the screen in view.
Object? _readVariable(WidgetsBinding binding, CodelesslyWidgetController controller, String name) {
  final scope = _shownScope(binding, controller);
  return scope != null ? readPath(scope, name) : controller.read(name);
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
    // The file the fetcher serves for the family's regular face.
    final face = DirectoryFontFetcher(faces).match(fam, 400, false);
    final used = face != null && face.family.toLowerCase() == fam.toLowerCase()
        ? face
        : faces.where((f) => f.family == 'Roboto' && !f.italic).firstOrNull;
    if (used == null) return null;
    return _coverage.putIfAbsent(used.path, () => fontCoverage(used.path));
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
    // A node of a component definition (inside an instance).
    for (final b in boxes) {
      if (b.id == id) return b.source.node(id);
    }
    return null;
  }



  String? fileOfComponent(String type) =>
      docs.entries.where((e) => api.readMap(e.value[api.kWidgetKey])?['type'] == type).firstOrNull?.key;
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

  // A node inside a component instance is named by its instance path.
  String nameOf(NodeBox b) => componentInstanceOf(b.instance) != null ? b.tree.pathOf(b.id, b.instance) : b.id;

  for (final b in boxes) {
    // The node as it is shown at this size: its media rules and any active
    // state applied (the document's own node is its base).
    final node = b.node ?? nodeOf(b.id);
    if (node == null || node.type == 'canvas') continue;
    final r = _rectOf(b);
    if (r.width <= 0 && r.height <= 0) continue;
    final component = componentInstanceOf(b.instance);
    // A node of a component is its definition's (ids are local to it).
    final file = component == null ? fileOfNode[b.id] : fileOfComponent(component.component);
    // What of it can be seen: its box within every ancestor's clip.
    final clip = _visibleClip(b);
    final seen = clip == null ? r : r.intersect(clip);
    // Past its parent.
    // Its parent in its own document (a page's, or the component's
    // definition), found as the node box around it: a page node and a
    // component's node of the same id are never confused.
    final pid = b.source.parentOf(b.id);
    NodeBox? parentBox;
    for (RenderObject? o = b.parent; o != null && pid != null; o = o.parent) {
      if (o is NodeBox && o.id == pid) {
        parentBox = o;
        break;
      }
    }
    parentBox ??= pid == null ? null : byKey['$pid|${b.instance}'];
    final parent = parentBox?.node ?? (pid == null ? null : b.source.node(pid));
    final parentName = parentBox == null ? pid : nameOf(parentBox);
    if (parentBox != null && parent != null && parent.type != 'canvas' && parent.type != 'stack' && !seen.isEmpty) {
      final pr = _rectOf(parentBox);
      var dx = math.max(pr.left - seen.left, seen.right - pr.right);
      var dy = math.max(pr.top - seen.top, seen.bottom - pr.bottom);
      // Laid out inside its parent and only painted past it (a `motion`
      // translate, scale or rotation, as a Transform in Flutter): not a
      // layout overflow.
      final laid = _laidOutIn(b, parentBox);
      if (laid != null) {
        if (laid.left >= -1 && laid.right <= parentBox.size.width + 1) dx = 0;
        if (laid.top >= -1 && laid.bottom <= parentBox.size.height + 1) dy = 0;
      }
      if (dx > 1 && !scrollsAlong(b, true, upTo: parentBox)) {
        out.add(RuntimeIssue('layout_overflow', 'warning',
            '"${nameOf(b)}" (${node.type}, ${r.width.toStringAsFixed(0)} wide) overflows its parent "$parentName" (${parent.type}, ${pr.width.toStringAsFixed(0)} wide) by ${dx.toStringAsFixed(0)} px horizontally.',
            nodeId: nameOf(b), screen: screen, size: size, file: file));
      }
      if (dy > 1 && !scrollsAlong(b, false, upTo: parentBox)) {
        out.add(RuntimeIssue('layout_overflow', 'warning',
            '"${nameOf(b)}" (${node.type}, ${r.height.toStringAsFixed(0)} tall) overflows its parent "$parentName" (${parent.type}, ${pr.height.toStringAsFixed(0)} tall) by ${dy.toStringAsFixed(0)} px vertically.',
            nodeId: nameOf(b), screen: screen, size: size, file: file));
      }
    }
    // A fill with no room to fill: its parent measured it unbounded on
    // that axis, so the number in {"fill": n} decided its size.
    for (final fb in _ownFitBoxes(b)) {
      for (final horizontal in const [true, false]) {
        final used = horizontal ? fb.designWidthUsed : fb.designHeightUsed;
        final design = horizontal ? fb.width : fb.height;
        // A spacer (or a fill of design size 0) with no room takes none, as
        // Flutter's Spacer in a hugging column: that is what it is for.
        if (!used || design == null || design <= 0 || node.type == 'spacer' || !fb.hasSize) continue;
        final actual = horizontal ? fb.size.width : fb.size.height;
        if ((actual - design).abs() > 0.5) continue;
        final dim = horizontal ? 'width' : 'height';
        final why = parent == null
            ? 'what holds it measures it with no $dim limit'
            : (horizontal ? parent.layout.width : parent.layout.height).fit == api.SizeFit.hug && const {'row', 'column', 'flex'}.contains(parent.type) && !parent.prop(api.FlexProps.wrap)
                ? 'its parent "$parentName" (${parent.type}) hugs its $dim, so there is no $dim to fill'
                : parent.type == 'gridView'
                    ? 'its grid "$parentName" sizes each row to its content, so there is no $dim to fill'
                    : 'its parent "$parentName" (${parent.type}) measures it with no $dim limit (a hugging or wrapping parent, a grid row sized to its content, or a scroll view)';
        out.add(RuntimeIssue('fill_fallback', 'warning',
            '"${nameOf(b)}" (${node.type}) fills its $dim, but $why: it takes its design $dim, ${design.toStringAsFixed(0)} px (the number in {"fill": ${design.toStringAsFixed(0)}}). '
            '${horizontal ? '' : 'To line up the bottoms of cards in a row, put the decoration on the stretched child itself and push its footer with a spacer (a spacer fills what stretching adds); or '}'
            'give the parent a definite $dim (fixed, or fill inside a parent that has one), or make this node hug its $dim.',
            nodeId: nameOf(b), screen: screen, size: size, file: file));
      }
    }
    // Past the screen (the part not clipped away by an ancestor).
    if (!seen.isEmpty && seen.right > view.width + 1 && !scrollsAlong(b, true)) {
      out.add(RuntimeIssue('offscreen', 'warning',
          '"${nameOf(b)}" (${node.type}) ends at x=${seen.right.toStringAsFixed(0)}, past the ${view.width.toStringAsFixed(0)} px wide screen.',
          nodeId: nameOf(b), screen: screen, size: size, file: file));
    }
    if (!seen.isEmpty && seen.bottom > view.height + 1 && !scrollsAlong(b, false)) {
      out.add(RuntimeIssue('offscreen', 'warning',
          '"${nameOf(b)}" (${node.type}) ends at y=${seen.bottom.toStringAsFixed(0)}, below the ${view.height.toStringAsFixed(0)} px tall screen, and nothing scrolls: make the body column scrollable ("scrollable": true).',
          nodeId: nameOf(b), screen: screen, size: size, file: file));
    }
    // Icons that draw nothing.
    if (node.type == 'icon' && b.drawn) {
      final glyph = _descendants(b).whereType<RenderIconGlyph>().firstOrNull;
      final icon = glyph?.icon ?? const {};
      final image = icon['image'] ?? icon['svg'];
      if (glyph != null && image == null && IconSources.glyphOf(icon) == null) {
        out.add(RuntimeIssue('icon_not_drawn', 'warning',
            'Icon "${nameOf(b)}" draws nothing: ${icon.isEmpty ? 'it names no icon' : '${jsonEncode(icon)} is not a Material icon the renderer knows'}. '
            'Write a Material icon name ("search", "arrow_forward", "menu"), as listed at fonts.google.com/icons.',
            nodeId: nameOf(b), screen: screen, size: size, file: file));
      }
    }
    // A path drawn past its box, where that part shows (no ancestor clips
    // it away).
    if (node.type == 'path' && b.drawn) {
      final data = node.prop(api.PathProps.data);
      final viewBox = node.prop(api.PathProps.viewBox);
      final bounds = _pathBounds(data);
      if (bounds != null && viewBox == null) {
        final drawn = bounds.shift(r.topLeft);
        final shown = clip == null ? drawn : drawn.intersect(clip);
        final past = shown.isEmpty
            ? 0.0
            : math.max(math.max(r.left - shown.left, shown.right - r.right), math.max(r.top - shown.top, shown.bottom - r.bottom));
        if (past > 1) {
          out.add(RuntimeIssue('path_overflow', 'warning',
              'The path of "${nameOf(b)}" reaches ${past.toStringAsFixed(0)} px past its ${b.size.width.toStringAsFixed(0)}x${b.size.height.toStringAsFixed(0)} box '
              '(path coordinates are the box\'s own pixels, from its top left), and nothing clips that part away. '
              'Give it "viewBox": [w, h] to scale it into the box, or set "decoration": {"clip": "hardEdge"} on an ancestor.',
              nodeId: nameOf(b), screen: screen, size: size, file: file));
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
            'Text "${nameOf(b)}" shows "$short" on screen: its expression did not evaluate. Check the formula (names, functions, quotes); '
            'a binding of "props.text" or "props.runs" must not also be written as text, and a "\${...}" inside a formula is not read.',
            nodeId: nameOf(b), screen: screen, size: size, file: file));
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
            'Text "${nameOf(b)}" has ${missing.map((c) => '"$c" (U+${c.runes.first.toRadixString(16).toUpperCase().padLeft(4, '0')})').join(', ')}, which its font has no glyph for: drawn as an empty box. '
            'Use a character the font has, an icon node, or a box with a "path" for a small mark.',
            nodeId: nameOf(b), screen: screen, size: size, file: file));
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
        out.add(RuntimeIssue('text_no_color', 'warning', 'Text "${nameOf(b)}" ("$short") has no color, so it is painted white: set props.style.color.',
            nodeId: nameOf(b), screen: screen, size: size, file: file));
      }
      final cut = node.prop(api.TextProps.overflow) != api.TextOverflow.clip;
      if (p.didExceedMaxLines && !cut) {
        out.add(RuntimeIssue('text_truncated', 'warning', 'Text "${nameOf(b)}" ("$short") is cut at maxLines: set "overflow": "ellipsis" if that is meant, or give it more lines.',
            nodeId: nameOf(b), screen: screen, size: size, file: file));
      }
      final needH = p.getMaxIntrinsicHeight(b.size.width);
      final needW = p.getMinIntrinsicWidth(double.infinity);
      if (needH > b.size.height + 1.5 && !p.didExceedMaxLines) {
        out.add(RuntimeIssue('text_clipped', 'warning',
            'Text "${nameOf(b)}" ("$short") needs ${needH.toStringAsFixed(0)} px of height at ${b.size.width.toStringAsFixed(0)} wide but its box is ${b.size.height.toStringAsFixed(0)}: give it {"hug": n} height or more room.',
            nodeId: nameOf(b), screen: screen, size: size, file: file));
      }
      if (needW > b.size.width + 1.5 && node.prop(api.TextProps.maxLines) == null) {
        out.add(RuntimeIssue('text_clipped', 'warning',
            'Text "${nameOf(b)}" ("$short") has a word ${needW.toStringAsFixed(0)} px wide in a box ${b.size.width.toStringAsFixed(0)} wide: it is cut. '
            'Give the text more width (a fill or larger width), a smaller font size, or "scaleDown": true.',
            nodeId: nameOf(b), screen: screen, size: size, file: file));
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
    if (report.comparisons.isNotEmpty) 'comparisons': [for (final c in report.comparisons) c.toJson()],
    if (report.downloads.isNotEmpty) 'downloads': report.downloads,
    if (report.clipboard.isNotEmpty) 'clipboard': report.clipboard,
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
  for (final c in report.comparisons) {
    b.writeln(c.summary());
  }
  for (final d in report.downloads) {
    b.writeln('downloaded ${d['file']} (${d['bytes']} bytes, ${d['mimeType']}) [screen ${d['screen']} ${d['size']}]');
  }
  for (final c in report.clipboard) {
    final t = '${c['text']}';
    b.writeln('copied to the clipboard: ${jsonEncode(t.length > 120 ? '${t.substring(0, 120)}...' : t)}${c['screen'] == null ? '' : ' [screen ${c['screen']} ${c['size']}]'}');
  }
  b.writeln('${report.errors} error(s), ${report.warnings} warning(s).');
  return b.toString();
}

/// The file node box [b] comes from: its component's for a node inside an
/// instance (ids are local to their document), else its page's.
String? _fileOf(NodeBox b, Map<String, String> fileOfNode, Map<String, api.Json> docs) {
  final c = componentInstanceOf(b.instance);
  if (c == null) return fileOfNode[b.id];
  return docs.entries.where((e) => api.readMap(e.value[api.kWidgetKey])?['type'] == c.component).firstOrNull?.key;
}
