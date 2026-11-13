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
  ('interaction_failed', 'error', 'A --tap/--hover/--scroll/--set/--navigate step could not be applied (no such node, not on screen...).'),
  ('layout_overflow', 'warning', 'A node extends past its parent\'s box (by the pixels shown) where the parent does not scroll that way.'),
  ('offscreen', 'warning', 'A node extends past the screen edge where nothing scrolls: on a device it is cut off.'),
  ('text_clipped', 'warning', 'A text does not fit its box: its lines are taller than the box, or a word is wider.'),
  ('text_truncated', 'warning', 'A text was cut at maxLines.'),
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
        return base.endsWith('.json') && !base.startsWith('_') && base != 'diagnostics.json';
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

  // 2. Fonts and assets.
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
        Object? e;
        while ((e = tester.takeException()) != null) {
          issue(RuntimeIssue('render_exception', 'error', _firstLine('$e'), screen: label, size: sizeName));
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
          onGenerateRoute: CodelesslyWidget.onGenerateRoute(codelessly),
          home: CodelesslyWidget(codelessly: codelessly, layoutId: screen, controller: controller),
        ),
      ));
      await _settle(tester);
      collect();
      if (!controller.isLoaded) {
        issue(RuntimeIssue('render_exception', 'error', 'Screen "$screen" did not load: ${controller.error}', screen: screen, size: sizeName));
        continue;
      }

      // 4. Interactions, in order.
      for (final step in args.steps) {
        final problem = await _apply(tester, step, controller, navigator, codelessly);
        if (problem != null) {
          // A node of another canvas of the screen (another breakpoint's
          // design) is absent here by design: a warning, not an error.
          final elsewhere = problem.contains('no node') && fileOfNode.containsKey(step.target);
          issue(RuntimeIssue('interaction_failed', elsewhere ? 'warning' : 'error',
              elsewhere ? '$problem It is in the document but not on the canvas shown at this size.' : problem,
              screen: label, size: sizeName));
        }
        await _settle(tester);
        collect();
      }

      // 5. Full page: the view as tall as the content scrolls.
      if (args.fullPage) {
        for (var round = 0; round < 3; round++) {
          final scroll = _pageScroll(binding);
          if (scroll == null || scroll.maxScrollExtent < 1) break;
          final h = math.min(20000.0, tester.view.physicalSize.height + scroll.maxScrollExtent);
          tester.view.physicalSize = ui.Size(size.width, h.ceilToDouble());
          await _settle(tester);
          collect();
        }
      }

      // 6. Runtime checks, then the PNG.
      for (final i in _check(binding, published, docs, fileOfNode, label, sizeName)) {
        issue(i);
      }
      for (final m in fetcher.misses) {
        issue(RuntimeIssue('font_fallback', 'warning',
            m.substitute == null
                ? 'Font "${m.family}" ${m.weight}${m.italic ? ' italic' : ''} is not in the fonts directories: its text is drawn in the default font. Add the font file with --fonts <dir>, or use Roboto.'
                : 'Font "${m.family}" ${m.weight}${m.italic ? ' italic' : ''} is not in the fonts directories: drawn with ${m.substitute}.'));
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

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
      collect();
      controller.dispose();
      codelessly.dispose();
    }
  }
  tester.view.reset();
  return _finish(report, args);
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
    await CodelesslyFonts.settled;
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

/// Every node box on screen, in paint order (later ones are on top).
List<NodeBox> _boxes(WidgetsBinding binding) => [
      for (final view in binding.renderViews)
        for (final o in _descendants(view))
          if (o is NodeBox && o.attached && o.hasSize) o,
    ];

NodeBox? _boxOf(WidgetsBinding binding, String id) {
  NodeBox? hit;
  for (final b in _boxes(binding)) {
    if (b.id == id) hit = b;
  }
  return hit;
}

RenderDesignScroll? _pageScroll(WidgetsBinding binding) {
  RenderDesignScroll? best;
  for (final view in binding.renderViews) {
    for (final o in _descendants(view)) {
      if (o is RenderDesignScroll && o.attached && o.hasSize && o.interactive && o.maxScrollExtent > 0) {
        final vertical = o.child != null && o.child!.size.height > o.size.height;
        if (!vertical) continue;
        if (best == null || o.size.height > best.size.height) best = o;
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
    GlobalKey<NavigatorState> navigator, Codelessly codelessly) async {
  final binding = tester.binding;
  ui.Offset? centerOf(String id) {
    final b = _boxOf(binding, id);
    if (b == null) return null;
    final r = _rectOf(b);
    final view = ui.Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio);
    final visible = r.intersect(view);
    if (visible.isEmpty) return null;
    return visible.center;
  }

  switch (step.kind) {
    case 'tap':
      final at = centerOf(step.target);
      if (at == null) {
        if (_boxOf(binding, step.target) == null) return '--tap ${step.target}: no node "${step.target}" is on screen.';
        return '--tap ${step.target}: the node is outside the screen; scroll to it first (--scroll).';
      }
      await tester.tapAt(at);
      return null;
    case 'hover':
      final at = centerOf(step.target);
      if (at == null) return '--hover ${step.target}: no node "${step.target}" is visible on screen.';
      final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await g.addPointer(location: ui.Offset.zero);
      await g.moveTo(at);
      return null;
    case 'set':
      Object? value;
      try {
        value = jsonDecode(step.value ?? 'null');
      } catch (_) {
        value = step.value;
      }
      if (controller.read(step.target) == null && controller.scope?.read(step.target) == null) {
        // Still set it: a variable may be null by default.
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
) {
  final out = <RuntimeIssue>[];
  final boxes = _boxes(binding);
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
  // Nodes inside something that scrolls (or a list) along an axis.
  bool scrollsAlong(String id, bool horizontal) {
    for (var p = parentOf(id); p != null; p = parentOf(p)) {
      final n = nodeOf(p);
      if (n == null) continue;
      if (const {'listView', 'gridView', 'pageView', 'tableView', 'tabs'}.contains(n.type)) return true;
      final scrollable = n.spec?.prop('scrollable') != null && n.props.get(n.spec!.prop('scrollable')!) == true;
      if (scrollable) {
        final dir = n.spec!.prop('scrollDirection');
        final h = dir != null && n.props.get(dir) == api.Axis.horizontal;
        if (h == horizontal) return true;
      }
    }
    return false;
  }

  for (final b in boxes) {
    final node = nodeOf(b.id);
    if (node == null || node.type == 'canvas') continue;
    final r = _rectOf(b);
    if (r.width <= 0 && r.height <= 0) continue;
    final file = fileOfNode[b.id];
    // Past its parent.
    final pid = parentOf(b.id);
    final parentBox = pid == null ? null : (byKey['$pid|${b.instance}'] ?? byKey['$pid|null']);
    final parent = pid == null ? null : nodeOf(pid);
    if (parentBox != null && parent != null && parent.type != 'canvas' && parent.type != 'stack') {
      final pr = _rectOf(parentBox);
      final dx = math.max(pr.left - r.left, r.right - pr.right);
      final dy = math.max(pr.top - r.top, r.bottom - pr.bottom);
      if (dx > 1 && !scrollsAlong(b.id, true)) {
        out.add(RuntimeIssue('layout_overflow', 'warning',
            '"${b.id}" (${node.type}, ${r.width.toStringAsFixed(0)} wide) overflows its parent "$pid" (${parent.type}, ${pr.width.toStringAsFixed(0)} wide) by ${dx.toStringAsFixed(0)} px horizontally.',
            nodeId: b.id, screen: screen, size: size, file: file));
      }
      if (dy > 1 && !scrollsAlong(b.id, false)) {
        out.add(RuntimeIssue('layout_overflow', 'warning',
            '"${b.id}" (${node.type}, ${r.height.toStringAsFixed(0)} tall) overflows its parent "$pid" (${parent.type}, ${pr.height.toStringAsFixed(0)} tall) by ${dy.toStringAsFixed(0)} px vertically.',
            nodeId: b.id, screen: screen, size: size, file: file));
      }
    }
    // Past the screen.
    if (r.right > view.width + 1 && !scrollsAlong(b.id, true)) {
      out.add(RuntimeIssue('offscreen', 'warning',
          '"${b.id}" (${node.type}) ends at x=${r.right.toStringAsFixed(0)}, past the ${view.width.toStringAsFixed(0)} px wide screen.',
          nodeId: b.id, screen: screen, size: size, file: file));
    }
    if (r.bottom > view.height + 1 && !scrollsAlong(b.id, false)) {
      out.add(RuntimeIssue('offscreen', 'warning',
          '"${b.id}" (${node.type}) ends at y=${r.bottom.toStringAsFixed(0)}, below the ${view.height.toStringAsFixed(0)} px tall screen, and nothing scrolls: make the body column scrollable ("scrollable": true).',
          nodeId: b.id, screen: screen, size: size, file: file));
    }
    // Text.
    if (node.type == 'text') {
      final p = _descendants(b).whereType<RenderParagraph>().firstOrNull;
      if (p == null || !p.hasSize) continue;
      final text = p.text.toPlainText();
      if (text.trim().isEmpty) continue;
      final short = text.length > 30 ? '${text.substring(0, 30)}...' : text;
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
      if (p.didExceedMaxLines) {
        out.add(RuntimeIssue('text_truncated', 'warning', 'Text "${b.id}" ("$short") is cut at maxLines.',
            nodeId: b.id, screen: screen, size: size, file: file));
      }
      final needH = p.getMaxIntrinsicHeight(b.size.width);
      final needW = p.getMinIntrinsicWidth(double.infinity);
      if (needH > b.size.height + 1.5 && !p.didExceedMaxLines) {
        out.add(RuntimeIssue('text_clipped', 'warning',
            'Text "${b.id}" ("$short") needs ${needH.toStringAsFixed(0)} px of height at ${b.size.width.toStringAsFixed(0)} wide but its box is ${b.size.height.toStringAsFixed(0)}: give it {"hug": n} height or more room.',
            nodeId: b.id, screen: screen, size: size, file: file));
      }
      if (needW > b.size.width + 1.5) {
        out.add(RuntimeIssue('text_clipped', 'warning',
            'Text "${b.id}" ("$short") has a word ${needW.toStringAsFixed(0)} px wide in a box ${b.size.width.toStringAsFixed(0)} wide.',
            nodeId: b.id, screen: screen, size: size, file: file));
      }
    }
  }
  return out;
}

RenderReport _finish(RenderReport report, RenderArgs args) {
  // Errors first, then warnings; each group in document order.
  report.diagnostics.sort((a, b) => (a['severity'] == 'error' ? 0 : 1).compareTo(b['severity'] == 'error' ? 0 : 1));
  Directory(args.out).createSync(recursive: true);
  File('${args.out}/diagnostics.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
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
