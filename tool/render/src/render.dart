// The render command's core: each screen rendered by the SDK at each size
// (CodelesslyWidget over the published bundle, as an app shows it),
// interactions applied, PNGs written, and the problems met while rendering
// reported as diagnostics.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/controls/focus.dart' show ControlFocusLayer, ControlFocusNode, ControlFocusScope;
import 'package:codelessly_sdk/src/render/controls/kit.dart' show LabeledControl, firstTextUnder;
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Page, Step; // ignore: deprecated_member_use
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart'
    show FontLoader, LogicalKeyboardKey, MethodCall, SystemChannels, TextEditingValue, TextInputAction, TextSelection;
import 'package:flutter_test/flutter_test.dart';
import 'package:codelessly_sdk/src/runtime/gestures/drag_and_drop.dart' show RenderDragSource;
import 'package:codelessly_sdk/src/runtime/actions/wiring.dart' show viewportTriggersPaused;
import 'package:codelessly_sdk/src/render/paint/icon_glyph.dart' show IconSources, RenderIconGlyph;
import 'package:codelessly_sdk/src/render/controls/buttons.dart' show RenderButton;
import 'package:codelessly_sdk/src/render/layout/text_box.dart' show RenderWholeWords;
import 'package:codelessly_sdk/src/render/controls/calendar.dart' show RenderCalendar;
import 'package:codelessly_sdk/src/render/controls/dropdown.dart' show RenderDropdown;
import 'package:codelessly_sdk/src/render/controls/menu.dart' show RenderMenu, RenderMenuRow;
import 'package:codelessly_sdk/src/render/controls/slider.dart' show RenderSlider;
import 'package:codelessly_sdk/src/widgets/collections_table.dart' show RenderRunningTable;
import 'package:codelessly_sdk/src/render/controls/kit.dart' show RenderControl;
import 'package:codelessly_sdk/src/render/controls/kit_bars.dart' show RenderItemBar;
import 'package:codelessly_sdk/src/render/controls/segmented.dart' show RenderSegmentedButton;
import 'package:codelessly_sdk/src/render/controls/root.dart' show RenderControlRoot;
import 'package:codelessly_sdk/src/render/controls/tile.dart' show RenderListTile;
import 'package:codelessly_sdk/src/render/paint/path_paint.dart' show parseSvgPath;
import 'package:codelessly_sdk/src/render/paint/svg_fonts.dart' show SvgFonts;
import 'package:codelessly_sdk/src/render/view_scroll.dart' show RenderSticky;
import 'package:codelessly_sdk/src/runtime/expressions/formula.dart' show FormulaEvaluator;
import 'package:codelessly_sdk/src/render/layout/fit_box.dart' show RenderCodelesslyFlex;
import 'package:codelessly_sdk/src/render/controls/text_field.dart' show RenderTextField, textFieldIn;

import 'args.dart';
import 'compare.dart';
import 'fonts.dart';
import 'google_fonts.dart';
import 'prepare.dart';
import 'publish.dart';
import 'site.dart';
import '../../notation/formula_check.dart';

/// A problem found while rendering.
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

/// Every code the render step reports, with its
/// severity and meaning (for the README and the reference).
const runtimeCodes = <(String, String, String)>[
  ('invalid_json', 'error', 'A file is not valid JSON (the message gives the line and column).'),
  ('schema_unsupported', 'error', 'A document is not of schema 3 (`"schema": 3`), the only one read: the message names the schema it has. It is not rendered.'),
  ('page_not_written', 'warning', 'A page site.json lists has no file yet: one note per file.'),
  ('no_documents', 'error', 'No .json documents were found at the paths given.'),
  ('unknown_screen_arg', 'error', '--screen names no canvas, screen or layout.'),
  ('render_exception', 'error', 'Flutter threw while building, laying out or painting the screen.'),
  ('action_error', 'error', 'An action chain failed (a load reaction, or one an interaction ran).'),
  ('formula_failed', 'warning', 'A formula an action works out does not parse, or fails as it is worked out (an unknown field or function, a list function given a text): the action got null. The message gives the expression and why.'),
  ('interaction_failed', 'error', 'A --tap/--hover/--focus/--type/--scroll/--set/--navigate step could not be applied (no such node, not on screen, covered by another node: the message names it).'),
  ('step_skipped', 'warning', 'A step names a node not shown at this size (hidden by a media rule or a binding, or on another breakpoint\'s canvas): it is skipped at this size, the other steps run and the capture is made. One note per size.'),
  ('tap_no_reaction', 'warning', 'A --tap hit its node, but neither it nor anything around it reacts to a tap (no click reaction, no button or input): nothing happens.'),
  ('long_press_no_reaction', 'warning', 'A --long-press held its node, but nothing there reacts to a long press: the hold ends as a tap does (its tap reactions run).'),
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
  ('text_no_color', 'warning', 'A text has no color (the engine paints it white: invisible on a light background), or a transparent one. Set props.style.color.'),
  ('font_fallback', 'warning', 'A font family (or weight/style) a text style names is neither declared in site.json\'s "fonts" nor in a --fonts directory: the text is drawn in another font. The message names the family and the nodes that use it.'),
  ('font_missing', 'error', 'A font file site.json\'s "fonts" declares is not there (the path is relative to the site), or is not a font file it can read.'),
  ('design_system_missing', 'error', 'The design system site.json names ("designSystem": a folder relative to it, or an absolute path) has no readable design_system.json.'),
  ('image_failed', 'error', 'An image could not be loaded or decoded: a file named by a path relative to the site that is not there (the message names it), or a bad data: URL.'),
  ('image_network', 'warning', 'An image is on the network: the render command does not fetch it, so it is blank in the screenshot.'),
  ('empty_screen', 'warning', 'The screen drew no node boxes (nothing to show).'),
  ('formula_invalid', 'warning', 'A formula of a node (a binding, a value, an action) or of a variable does not parse, so it gives nothing where it is used: a list with no rows, a text with no value. The message names the node, the field, the expression and why it does not parse (an unbalanced bracket, a stray word).'),
  ('transparent_background', 'warning', 'At least 2% of a capture has nothing painted behind it: there a reader sees the host\'s background (black in an app with none, the page\'s color in a browser), not the document\'s. Give the screen\'s canvas a fill.'),
  ('set_overwritten', 'warning', 'A reaction (a timer, a load) wrote a variable a --set step set, after the step: the capture shows the --set value. Pin a clock with --now.'),
  ('placeholder_word', 'warning', 'A word the notation, the design system and the site do not have stood in as a placeholder when the page was expanded with an open vocabulary (or, closed, was refused and draws nothing): the message names the word, its kind, its line and the shape it was written in. Define it, or it is recorded for support: read from the vocabulary record `notation.sh expand` saves beside the site (vocabulary.json).'),
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

  /// Where the keyboard focus is in each capture that has one (after
  /// `--key Tab`, a `--focus`): the node, and whether its ring shows.
  final List<api.Json> focus = [];

  /// What a screen reader was told, in order: an `announce` action's text
  /// and a live region's (a toast, a text marked `live`) when it changed,
  /// each with its politeness and the step after which it was said.
  final List<api.Json> announcements = [];

  /// The screen a capture's run started on, by the capture's file name,
  /// when the capture is named after another (a screen navigated to).
  final Map<String, String> startedOn = {};
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
        return base.endsWith('.json') && !base.startsWith('_') && !RegExp(r'^diagnostics([-@].*)?\.json$').hasMatch(base);
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
  // Before the documents are prepared (their images inlined); cleared when the run ends.
  renderImageMap = args.imageMap;
  void issue(RuntimeIssue i) {
    if (seen.add('${i.key}|${i.screen}|${i.size}')) report.diagnostics.add(i.toJson());
  }

  Directory(args.out).createSync(recursive: true);
  // A directory with site.json (or components/) is a site: pages and components.
  designSystemProblems.clear();
  final site = loadSite(args.inputs, loadInputs);
  for (final p in designSystemProblems) {
    issue(RuntimeIssue('design_system_missing', 'error', p, file: api.SiteManifest.fileName));
  }
  final inputs = site.inputs;
  if (inputs.isEmpty) {
    issue(RuntimeIssue('no_documents', 'error', 'No .json documents at ${args.inputs.join(', ')}.'));
    return _finish(report, args);
  }

  // 1. Parse.
  final docs = <String, api.Json>{};
  final dirs = <String, String>{};
  for (final i in inputs) {
    try {
      final j = jsonDecode(i.text);
      if (j is! Map) throw const FormatException('the top level is not an object');
      if (j['schema'] != api.kSchemaVersion) {
        issue(RuntimeIssue('schema_unsupported', 'error', api.UnsupportedSchemaException(j['schema']).message, file: i.name));
        continue;
      }
      docs[i.name] = j.cast<String, Object?>();
      dirs[i.name] = File(i.path).parent.path;
    } catch (e) {
      issue(RuntimeIssue('invalid_json', 'error', 'Not valid JSON: ${_jsonError(e, i.text)}.', file: i.name));
    }
  }
  final manifest = site.manifest == null ? null : api.SiteManifest.fromJson(site.manifest);
  // Pages site.json lists whose files are not there yet (a site written
  // page by page): one note per file.
  for (final i in args.inputs) {
    if (!File('$i/${api.SiteManifest.fileName}').existsSync()) continue;
    for (final p in manifest?.pages ?? const <String>[]) {
      // (A page named without its extension, `"pages": ["month"]`, is
      // `month.json`, as site.md says and the site loads it: round 11b,
      // calendar-app, clip-editor and admin-console had a warning for every
      // page of a site that drew them all.)
      if (!File('$i/$p').existsSync() && (p.contains('.') || !File('$i/$p.json').existsSync())) {
        issue(RuntimeIssue('page_not_written', 'warning', '$p is listed in site.json, file not written yet.', file: p));
      }
    }
  }
  // A formula the engine cannot read gives nothing where it is used (a
  // list with no rows, a text with no value), with no word at run time
  // (test 10's kanban board: `sortBy(filter(…))),x=>…)` drew no cards).
  for (final e in docs.entries) {
    for (final f in unreadableFormulas(e.value)) {
      issue(RuntimeIssue('formula_invalid', 'warning',
          'Node "${f.node}" (${f.field}): the formula does not parse, so it gives nothing: ${f.why}. The expression: ${f.expression}',
          nodeId: f.node.startsWith('variable ') ? null : f.node, file: e.key));
    }
  }
  // The words that stood in as placeholders when the site's notation was
  // expanded (the vocabulary record expand saves beside it): one warning
  // each, on its node, so a render says what is missing.
  for (final i in args.inputs) {
    if (!File('$i/${api.SiteManifest.fileName}').existsSync()) continue;
    for (final p in sitePlaceholders(i)) {
      final page = '${p['page'] ?? ''}';
      final refused = p['kind'] == 'refused';
      // What the expand made of it: nothing (a behaviour with no picture, or
      // a word beside the frame at the top of the page), the lines under it
      // with no box round them, or the labelled box.
      final node = [
        for (final e in docs.entries)
          if (page.isEmpty || e.key.split('/').last.replaceAll('.json', '') == page)
            if (api.readMap(e.value['nodes'])?[p['node']] case final Map n) n,
      ].firstOrNull;
      final silent = p['node'] is String && node == null;
      final bare = node != null && p['kind'] == 'primitive' && node['decoration'] == null;
      issue(RuntimeIssue(
        'placeholder_word',
        'warning',
        '"${p['word']}" (${refused ? 'type, refused' : p['kind']}) at ${p['file']}:${p['line']}'
            '${p['signature'] == null ? '' : ', written `${p['signature']}`'}: '
            '${refused ? 'a word the notation does not have, refused: nothing is drawn for it' : silent ? '${p['kind'] == 'primitive' ? 'declared a primitive' : 'a word the notation, the design system and the site do not have'}, with nothing to draw (a behaviour with no picture, or a line beside the App or Page at the top of the page): it draws nothing and takes no room' : bare ? 'declared a primitive: the lines under it are drawn, with no box round them' : p['kind'] == 'primitive' ? 'declared a primitive: a labelled box stands in for it' : p['kind'] == 'overlay' ? 'opened and never written: a placeholder sheet opens' : 'a word the notation, the design system and the site do not have: a placeholder stands in for it'}. '
            'Define it, or it is recorded for support (${p['record']}).',
        nodeId: silent ? null : p['node'] as String?,
        screen: page.isEmpty ? null : page,
        file: '${p['file']}',
      ));
    }
  }
  // The site's theme: its named colors and text styles.
  final themeJson = api.readMap(site.manifest?['theme']);
  if (docs.isEmpty) return _finish(report, args);

  // 2. Fonts and assets. A font handler left by an earlier run in this
  // process would load into a disposed instance.
  FontDemand.handler = null;
  FontDemand.symbolFallback = const [];
  _mouse = null;
  final root = flutterRoot ?? Platform.environment['FLUTTER_ROOT'] ?? '';
  unreadFonts.clear();
  // The site's folder: what its fonts' and images' relative paths start from.
  final siteDir = [
    for (final i in args.inputs)
      if (File('$i/${api.SiteManifest.fileName}').existsSync()) Directory(i).absolute.path,
  ].firstOrNull;
  final declared = manifest?.fonts ?? const <api.FontFamily>[];
  final declaredProblems = <DeclaredFontProblem>[];
  final faces = [
    ...defaultFonts(root),
    if (siteDir != null) ...declaredFonts(declared, siteDir, declaredProblems),
    ...scanFonts(args.fontDirs),
  ];
  for (final p in declaredProblems) {
    issue(RuntimeIssue('font_missing', 'error',
        'Font "${p.family}" declares ${p.asset}: ${p.reason}. ${p.missing ? 'Put the file there (paths are relative to site.json)' : 'Declare a .ttf, .otf or .woff file'}; its text falls back meanwhile.',
        file: api.SiteManifest.fileName));
  }
  final fetcher = DirectoryFontFetcher(faces);
  final symbolFont = systemSymbolFont();
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
    // The symbols the default fonts lack (← → ↑ ↓ ↵ ⌘ ✓), from the system's
    // symbol font: every style falls back to it, as a device's text does.
    if (symbolFont case final path?) {
      final loader = FontLoader(symbolFamily)..addFont(Future.value(File(path).readAsBytesSync().buffer.asByteData()));
      await loader.load();
      FontDemand.symbolFallback = const [symbolFamily];
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
  // SVG images by the data: URL they are inlined as, to name the ones
  // whose text asks for a family the run has no font for.
  final svgSources = <String, String>{};
  final svgUsers = <String, Set<String>>{};
  SvgFonts.onFamily = (family, url) => svgUsers.putIfAbsent(family.toLowerCase(), () => {}).add(svgSources[url] ?? url);
  // An SVG family no font file has is drawn in the next one, or the site's.
  final hadFamilies = {for (final f in faces) f.family.toLowerCase()};
  SvgFonts.isAvailable = (family) => hadFamilies.contains(family.toLowerCase());
  for (final e in docs.entries) {
    // Relative image paths start from the site's folder (as at run time),
    // else from the document's.
    final p = prepare(e.value, dir: siteDir ?? dirs[e.key]!, docDir: dirs[e.key], defaultFamily: 'Roboto', codepoints: codepoints);
    for (final img in p.images) {
      if (_valueAt(p.json, img.path) case final String v when v.startsWith('data:image/svg')) svgSources[v] = img.url;
    }
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
      theme: prepareTheme(themeJson ?? const {}, defaultFamily: 'Roboto'),
      fonts: declared);
  // The families the pages use that no file here provides, from Google
  // Fonts (as an app has them), or the open face that stands for them; kept
  // in the cache, so a second run needs no network.
  final google = renderUsesGoogleFonts
      ? GoogleFontCache(dir: GoogleFontCache.defaultDir(Directory.current.path), enabled: args.googleFonts && !GoogleFontCache.offByEnvironment)
      : null;
  googleFonts = google;
  if (google != null) {
    await tester.runAsync(() => addGoogleFonts(faces, [
          for (final f in published.bundle.model.fonts.values)
            if (f.url == null) (family: f.family, weight: f.weight, italic: f.italic),
        ], google));
  }
  // A page's nodes before a component's of the same id (a page's row3 was
  // reported in a component's file: test 9, admin 4 and kanban 9); a node
  // box is placed by its canvas or its component instead ([_fileOf]).
  final fileOfNode = <String, String>{};
  for (final pages in [true, false]) {
    for (final e in docs.entries) {
      if ((api.readMap(e.value[api.kWidgetKey]) == null) != pages) continue;
      for (final id in (api.readMap(e.value['nodes']) ?? const {}).keys) {
        fileOfNode.putIfAbsent(id, () => e.key);
      }
    }
  }

  // Tests draw shadows without blur unless told otherwise (an app blurs them).
  debugDisableShadows = false;
  // An overflowing row or column is drawn as the published app draws it, without the debug build's stripes; the
  // overflow is still reported (render_exception, with the node).
  RenderCodelesslyFlex.debugPaintOverflowStripes = false;
  // The details of each error, to name the node it came from.
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    _errorDetails[details.exception] = details;
    _errorLog.add(details);
    if (Platform.environment['RENDER_DEBUG_STACKS'] != null) {
      stderr.writeln('--- ${details.exceptionAsString().split('\n').first}\n${'${details.stack}'.split('\n').take(18).join('\n')}');
    }
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
  // `--now`: the time now() returns. Without it, now() is the test's clock,
  // which `--wait` (and every settle) moves as it moves the timers: a clock
  // or a deadline written from now() passes with them (round 10, R22: a
  // timer ticked through a nine-second wait while now() stood still).
  FormulaClock.pinned = args.now;
  final testClock = tester.binding.clock;
  FormulaClock.source = testClock.now;
  // Icons named without a codepoint (a bound name) draw from the font.
  IconSources.codepointOf = (name, style) =>
      codepoints[style == 'filled' ? '${name}_baseline' : '${name}_$style'] ?? codepoints[name];
  try {
    if (alone.isEmpty) {
      await _renderAll(tester, args, faces, published, docs, fileOfNode, fetcher, issue, report,
          components: components, fontUsers: _fontUsers(docs, manifest?.theme ?? api.ThemeTokens.none), svgUsers: svgUsers, siteDir: siteDir);
    }
    for (final a in alone) {
      // A preview renders at its own size; ad-hoc parameters at each size.
      final sizes = a.width != null && a.height != null ? [ui.Size(a.width!, a.height!)] : args.sizes;
      await _renderAll(tester, args.copyWith(sizes: sizes, screens: [a.name]), faces, published, docs, fileOfNode, fetcher, issue,
          report, components: components, fontUsers: _fontUsers(docs, manifest?.theme ?? api.ThemeTokens.none), svgUsers: svgUsers, siteDir: siteDir);
    }
    for (final e in components.missing.entries) {
      for (final path in e.value) {
        issue(RuntimeIssue('component_missing', 'error', 'Call "$path" renders ${e.key}, which no component document of the site defines.',
            nodeId: path));
      }
    }
  } finally {
    disposeDecodedFonts();
    debugDisableShadows = true;
    RenderCodelesslyFlex.debugPaintOverflowStripes = true;
    renderImageMap = const {};
    FlutterError.onError = previousOnError;
    IconSources.codepointOf = null;
    FormulaClock.pinned = null;
    FormulaClock.source = null;
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
  Map<String, List<String>> fontUsers = const {},
  Map<String, Set<String>> svgUsers = const {},
  String? siteDir,
}) async {
  // 3. Which screens.
  final screens = _screens(published, docs, args.screens, (s) => issue(s),
      includeModals: args.modals,
      components: [if (components != null) for (final t in components.types) components[t]!.document.toJson()]);
  final recorder = _Recorder();
  // A formula an action works out that does not parse or fails (an unknown
  // field or function, a list function given a text): said, not silent.
  final formulaFailures = <(String, String, String)>{};
  FormulaEvaluator.onActionFailure = (expression, action, why) => formulaFailures.add((expression, action, why));
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
      // What the app keeps on the device (a variable marked saved, a
      // storage action, the theme mode): fresh for each capture, and handed
      // on to the app a --reload step starts.
      var storage = MemoryLocalStorage();
      // `--pick-file`: what a file chooser gives (a headless run has none).
      final picker = FixedFilePicker([
        for (final path in args.pickFiles)
          PickedFile(name: path.split(RegExp(r'[\\/]')).last, bytes: File(path).readAsBytesSync(), contentType: mimeTypeOfFileName(path)),
      ]);
      Codelessly start() => Codelessly(
            // The site's files (declared fonts), read from its folder.
            loader: MemoryPublishLoader(published.bundle, readAsset: siteDir == null ? null : (path) async {
              final f = File('$siteDir/$path');
              return f.existsSync() ? f.readAsBytesSync() : null;
            }),
            components: components,
            fonts: fetcher,
            config: CodelesslyConfig(
                services: Services(analytics: recorder, exports: exporter, storage: storage, filePicker: picker), fontTimeout: const Duration(seconds: 5)),
          );
      var codelessly = start();
      var controller = CodelesslyWidgetController();
      final navigator = GlobalKey<NavigatorState>();
      final boundary = GlobalKey();
      // `--theme`: the mode the site starts in, as a setThemeMode action
      // sets it (steps may change it).
      if (args.theme != null) codelessly.setThemeMode(api.ThemeMode.tryParse(args.theme));
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = ui.Size(size.width, size.height);
      // The harness runs on a desktop even when it captures a phone. Give
      // desktop captures a connected mouse and narrower captures touch
      // capability, so a page reading device.hover sees the simulated device.
      if (size.width >= 1024) {
        _mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await _mouse!.moveTo(const Offset(1, 1));
        await tester.pump();
      }
      void collect() {
        // Every error Flutter reported since the last look, each with its
        // own details (flutter_test keeps only one: several in a frame
        // become "Multiple exceptions (n) were detected", which names none).
        final taken = <Object>[];
        Object? e;
        while ((e = tester.takeException()) != null) {
          taken.add(e!);
          if (Platform.environment['RENDER_DEBUG_STACKS'] != null && e is Error) {
            stderr.writeln('--- taken: ${'$e'.split('\n').first}\n${'${e.stackTrace}'.split('\n').take(16).join('\n')}');
          }
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
          // A flex "overflowed by 1.04e-7 pixels" is rounding, and under
          // half a pixel (a label a fraction wider than a fifth of a row)
          // nothing shows: neither is a problem.
          final by = RegExp(r'overflowed by ([0-9.eE+-]+) pixels').firstMatch(text);
          if (by != null && (double.tryParse(by[1]!) ?? 1) < 0.5) continue;
          final node = _nodeOfError(details ?? _errorDetails[err]);
          _errorDetails.remove(err);
          final advice = node == null || by == null ? null : _overflowAdvice(binding, node, double.parse(by[1]!), text);
          issue(RuntimeIssue('render_exception', 'error',
              node == null
                  ? '$text (Flutter named no render object for it: it was thrown outside a node\'s layout and paint, while building or in a callback.)'
                  : advice ?? 'Node "${node.tree.pathOf(node.id, node.instance)}" (${node.node?.type ?? '?'}): $text',
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
        for (final (expression, action, why) in formulaFailures) {
          issue(RuntimeIssue('formula_failed', 'warning',
              'A formula of a $action action gave nothing: ${_firstLine(why)}. The expression: $expression',
              screen: label, size: sizeName));
        }
        formulaFailures.clear();
      }

      // The page shown (the last one navigated to): what a --reload starts
      // again on, as a browser reloads the address it is at.
      final pages = _PageObserver();
      Future<void> show() async {
        await tester.pumpWidget(RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            navigatorKey: navigator,
            navigatorObservers: [pages],
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
      }

      // What a screen reader is told: an `announce` action's text as it
      // runs, a live region's as it changes (not as it first shows).
      final heard = <api.Json>[];
      var live = <RenderObject, String>{};
      void hear(String after, {bool baseline = false}) {
        for (final a in tester.takeAnnouncements()) {
          heard.add({'text': a.message, 'politeness': a.assertiveness.name, 'source': 'announce', 'after': after});
        }
        final now = _liveRegions(binding);
        if (!baseline) {
          for (final e in now.entries) {
            if (live[e.key] != e.value) heard.add({'text': e.value, 'politeness': 'polite', 'source': 'live', 'after': after});
          }
        }
        live = now;
      }

      tester.takeAnnouncements();
      await show();
      hear('load', baseline: true);
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
        // --reload: the app is closed and started again on the same screen,
        // with what it kept on the device (and nothing else: every variable
        // not marked saved starts from its declared value).
        if (step.kind == 'reload') {
          final kept = {...storage.getAll()};
          final at = pages.shown;
          await _removeMouse();
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));
          collect();
          controller.dispose();
          codelessly.dispose();
          storage = MemoryLocalStorage(kept);
          codelessly = start();
          // `--theme` is the mode the site starts in, again on a reload
          // (unless a step stored another, which the app reads back).
          if (args.theme != null && !kept.containsKey(Codelessly.themeModeStorageKey)) {
            codelessly.setThemeMode(api.ThemeMode.tryParse(args.theme));
          }
          controller = CodelesslyWidgetController();
          if (size.width >= 1024) {
            _mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
            await _mouse!.moveTo(const Offset(1, 1));
            await tester.pump();
          }
          pages.reset();
          await show();
          // On the page navigated to before, not the one the run began on.
          if (at != null && controller.isLoaded) {
            final route = CodelesslyWidget.onGenerateRoute(codelessly)(RouteSettings(name: at.name, arguments: at.arguments));
            if (route != null) {
              unawaited(navigator.currentState!.pushReplacement(route));
              await _settle(tester);
              collect();
            }
          }
          hear('$step', baseline: true);
          if (!controller.isLoaded) {
            issue(RuntimeIssue('interaction_failed', 'error', '--reload: screen "$label" did not load again: ${controller.error ?? 'timed out'}',
                screen: label, size: sizeName));
            break;
          }
          continue;
        }
        // `--tap shift+row#2`, `--drag alt+clip=40,0`: the step with those
        // keys held, as a user Shift-clicks (a click's result.shift reads it).
        final (held, plain) = _heldKeys(step);
        for (final k in held) {
          await tester.sendKeyDownEvent(k);
        }
        final String? problem;
        try {
          problem = await _apply(tester, plain, controller, navigator, codelessly, screens: _screenList(published, docs),
              warn: (code, message, nodeId) => issue(RuntimeIssue(code, 'warning', message,
                  nodeId: nodeId, screen: label, size: sizeName, file: nodeId == null ? null : fileOfNode[nodeId])));
        } finally {
          // Held until what the step started has run (a button's tap
          // reaction reads the keys as it fires, a frame on).
          if (held.isNotEmpty) await _settle(tester);
          for (final k in held.reversed) {
            await tester.sendKeyUpEvent(k);
          }
        }
        if (problem != null) {
          // A node hidden at this width, or of another canvas of the screen
          // (another breakpoint's design), is absent here by design: the
          // step is skipped at this size, with a note, not an error.
          // (A page's or a modal's node: a component's node is named by its
          // path, and one of a design system's components is no other canvas.)
          final target = step.target.split('/').last.split('#').first;
          final pages = [for (final d in docs.values) if (!isComponentJson(d)) d];
          final elsewhere = problem.contains('no node "$target"') &&
              pages.any((d) {
                final nodes = api.readMap(d['nodes']) ?? const {};
                return nodes.containsKey(target) || nodes.values.any((n) => api.readMap(n)?['name'] == target);
              });
          if (problem.startsWith(_notShownHere)) {
            skipped.add('$step (hidden at this width)');
          } else if (elsewhere) {
            skipped.add('$step (not on the canvas shown at this width)');
          } else {
            issue(RuntimeIssue('interaction_failed', 'error', problem, screen: label, size: sizeName));
          }
        }
        await _settle(tester);
        collect();
        hear('$step');
      }

      // 5. Full page: the view as tall as the content scrolls.
      if (skipped.isNotEmpty) {
        // One line per size, not one per step: these nodes are on another
        // breakpoint's canvas of the screen.
        issue(RuntimeIssue('step_skipped', 'warning',
            'Skipped at this size, their nodes not being shown here: ${skipped.join(', ')}. The other steps ran and the capture was made; '
            'nothing is wrong when the node is meant to be hidden at this width.'
            '${skipped.any((s) => s.endsWith('(not on the canvas shown at this width)')) ? ' A node on a breakpoint\'s own canvas: to reach whichever canvas is shown with one step, give the matching nodes the same "name" and name it in the step.' : ''}',
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
        var page = _pageScroll(binding, fullPage: true);
        if (page != null && page.pixels.abs() > 0.01) {
          page.jumpTo(0);
          await _settle(tester);
          collect();
          page = _pageScroll(binding, fullPage: true);
        }
        // A dialog, a drawer or a menu open over the page is captured as the
        // window shows it: its scrim covers the window, not a picture
        // taller than it (it dimmed only the first window's height).
        if (page != null && page.maxScrollExtent >= 1 && !_overlayOver(page)) fullPage = page;
      }

      // Counters still counting (animate ... animateTo on a variable, one
      // after another in a load reaction) end before the capture: it shows
      // the numbers they arrive at, not a frame on the way.
      await _countersSettled(tester);

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

      // 6. Runtime checks, then the PNG. A font asked for by name late (by
      // a text that appeared after the screen settled) is waited for first:
      // its text is measured, checked and drawn in it, not in the fallback.
      await _fontsSettled(tester, fetcher);
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
          if (googleFonts != null)
            !googleFonts!.enabled
              ? 'not Google Fonts (fetching is off: --no-google-fonts or CODELESSLY_NO_GOOGLE_FONTS; the cache was read)'
              : googleFonts!.failed.contains(m.family)
                  ? 'Google Fonts, which gave no file for it (not a Google Fonts family, or no network)'
                  : 'Google Fonts',
          if (fontUsers.isNotEmpty) 'site.json\'s fonts',
          if (args.fontDirs.isNotEmpty) fontDirsOf(args.fontDirs).join(', ') else 'no --fonts directory',
        ].join('; ');
        final users = [
          ...?fontUsers[m.family.toLowerCase()],
          // An SVG image whose <text> names the family.
          for (final svg in svgUsers[m.family.toLowerCase()] ?? const <String>{}) 'the text of $svg',
        ];
        issue(RuntimeIssue('font_fallback', 'warning',
            'Font "${m.family}" $style (fontFamily "${m.family}", fontWeight ${m.weight}, fontStyle ${m.italic ? 'italic' : 'normal'}) was asked for'
            '${users.isEmpty ? '' : ' by ${users.take(8).map((u) => '"$u"').join(', ')}${users.length > 8 ? ' and ${users.length - 8} more' : ''}'}; '
            '${has.isEmpty ? 'no file of that family was found' : 'the family has only ${has.join(', ')}'} in $looked. '
            '${m.substitute == null ? 'Its text is drawn in the default font.' : 'Drawn with ${m.substitute}.'}'
            '${unread.isEmpty ? '' : ' Found but not read: ${unread.take(3).join('; ')}.'}'
            ' Declare it in site.json: "fonts": [{"family": "${m.family}", "fonts": [{"asset": "fonts/<file>.ttf", "weight": ${m.weight}${m.italic ? ', "style": "italic"' : ''}}]}] '
            '(.ttf, .otf or .woff beside site.json), or pass --fonts <dir> (a font package folder such as node_modules/@fontsource/<family>, '
            'or `--fonts system` for the system\'s fonts).',
            nodeId: fontUsers[m.family.toLowerCase()]?.firstOrNull));
      }
      // Named after the screen it shows: after a --navigate (or a tap that
      // navigates) the page navigated to, not the one the run started on.
      var shown = label;
      if (pages.shown?.name case final String route when codelessly.publishModel != null) {
        // ignore: invalid_use_of_visible_for_testing_member
        final resolved = CodelesslyWidget.resolveScreen(codelessly.publishModel!, route.replaceFirst(RegExp(r'^/+'), ''));
        if (resolved != null) shown = _screenName(published, docs, resolved.$1);
      }
      final name = '${_fileSafe(shown)}@$sizeName${args.theme == null ? '' : '-${args.theme}'}${args.label == null ? '' : '-${_fileSafe(args.label!)}'}.png';
      if (shown != label) report.startedOn[name] = label;
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
      // Nothing painted behind part of the screen: there, a reader sees the host's background (an app's or a
      // browser page's), which the document does not choose.
      final bare = await tester.runAsync(() => _transparentShare(File(file).readAsBytesSync()));
      if (bare != null && bare >= 0.02) {
        final canvasId = published.layoutOfCanvas.keys.firstWhere((c) => published.layoutOfCanvas[c] == screen, orElse: () => '');
        issue(RuntimeIssue('transparent_background', 'warning',
            '${(bare * 100).toStringAsFixed(bare < 0.1 ? 1 : 0)}% of the capture has nothing painted behind it (transparent in the PNG): '
            'what shows there is the host\'s background, not the document\'s (an app\'s, often black; a browser page\'s, often white). '
            'Give the screen\'s canvas a fill: "decoration": {"fills": [{"color": "#FFFFFFFF"}]} (or a theme color).',
            nodeId: canvasId.isEmpty ? null : canvasId, screen: label, size: sizeName,
            file: canvasId.isEmpty ? null : fileOfNode[canvasId]));
      }
      if (args.compare case final String reference) {
        final found = referenceFor(file, reference, map: args.compareMap);
        if (found.file == null) {
          issue(RuntimeIssue('compare_failed', 'warning',
              '--compare: no reference for $name in $reference${found.candidates.isEmpty ? '' : ' among ${found.candidates.map((c) => c.split('/').last).join(', ')}'}: '
              'a reference matches when its name is the screen, the state (the --label, else default or none) and the size, exactly; '
              'name the file, give the state the --label the reference names, or map the names with --compare-map ${shown.toLowerCase()}=<reference name>.',
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
      // What was said, with the capture it led to.
      hear('the steps, before the capture');
      for (final h in heard) {
        report.announcements.add({'image': name, 'screen': label, 'size': sizeName, ...h});
      }
      // Where the keyboard focus is: the node (a control, a text field, a
      // node with a click reaction), and whether its focus ring shows.
      final focusedBox = _focusedBox();
      if (focusedBox != null) {
        final scope = ControlFocusScope.focusedScope!;
        report.focus.add({
          'image': name,
          'screen': label,
          'size': sizeName,
          'id': focusedBox.id,
          if (componentInstanceOf(focusedBox.instance) != null) 'path': focusedBox.tree.pathOf(focusedBox.id, focusedBox.instance),
          'ring': scope.focused!.showsHighlight,
          if (scope.focused!.label?.call() ?? firstTextUnder(focusedBox) case final String text) 'text': text,
          if (scope.layer != null) 'inOverlay': true,
        });
      }
      // A built-in confirm's button has Flutter's focus, not a control's.
      final focusedBuiltIn = focusedBox == null ? _focusedBuiltIn(binding) : null;
      if (focusedBuiltIn != null) {
        report.focus.add({
          'image': name,
          'screen': label,
          'size': sizeName,
          'id': focusedBuiltIn.id,
          'ring': FocusManager.instance.highlightMode == FocusHighlightMode.traditional,
          if (_paragraphText(focusedBuiltIn.box) case final String text) 'text': text,
          'inOverlay': true,
        });
      }
      if (args.dumpLayout) {
        final boxes = [
          for (final b in _boxes(binding))
            {
              'id': b.id,
              if (identical(b, focusedBox)) 'focused': true,
              if (b.instance != null) 'instance': '${b.instance}',
              if (componentInstanceOf(b.instance) != null) 'path': b.tree.pathOf(b.id, b.instance),
              // What a step names with `@` (`quantity@increment`).
              if (_partNames(b) case final parts when parts.isNotEmpty) 'parts': parts,
              'x': _rectOf(b).left.round(),
              'y': _rectOf(b).top.round(),
              'w': double.parse(b.size.width.toStringAsFixed(1)),
              'h': double.parse(b.size.height.toStringAsFixed(1)),
              // What a text shows, as drawn: a check reads values from it.
              if (_shownText(b) case final String text) 'text': text,
            },
          // The built-in confirm's buttons, over the page.
          for (final b in _builtIns(binding))
            {
              'id': b.id,
              if (identical(b.element, focusedBuiltIn?.element)) 'focused': true,
              'x': b.box.localToGlobal(ui.Offset.zero).dx.round(),
              'y': b.box.localToGlobal(ui.Offset.zero).dy.round(),
              'w': double.parse(b.box.size.width.toStringAsFixed(1)),
              'h': double.parse(b.box.size.height.toStringAsFixed(1)),
              if (_paragraphText(b.box) case final String text) 'text': text,
            },
        ];
        File(file.replaceFirst(RegExp(r'\.png$'), '.layout.json'))
            .writeAsStringSync(const JsonEncoder.withIndent(' ').convert(boxes));
      }

      // The mouse a --hover step put on the screen leaves with it: the next
      // size's hover adds it again (Flutter's mouse tracker asserts on a
      // device added twice).
      await _removeMouse();
      await _releaseHeld();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
      collect();
      controller.dispose();
      codelessly.dispose();
    }
  }
}

/// The mouse `--hover` steps move, while a capture is made.
TestGesture? _mouse;

/// A `--drag <id>=<dx>,<dy>,hold` still pressed: the capture shows the drag
/// in progress (a row swiped part of the way, its actions showing). The next
/// step, or the end of the capture, lets go.
TestGesture? _held;

Future<void> _releaseHeld() async {
  final g = _held;
  _held = null;
  if (g != null) await g.up();
}

Future<void> _removeMouse() async {
  final m = _mouse;
  _mouse = null;
  if (m != null) await m.removePointer();
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

/// Pumps (in 100 ms steps, at most 20 s of the screen's time) while a
/// number variable's timeline plays.
Future<void> _countersSettled(WidgetTester tester) async {
  for (var i = 0; i < 200 && VariableAnimator.anyPlaying; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// This run's Google Fonts ([GoogleFontCache]): what the report says of a
/// family it could not fetch.
GoogleFontCache? googleFonts;

/// Waits (bounded, 10 s) until none of this run's font fetches is in flight
/// and what they fetched is registered, pumping so the text that asked for
/// one lays out again in it. Nothing to wait for: returns at once.
Future<void> _fontsSettled(WidgetTester tester, DirectoryFontFetcher fetcher) async {
  if (!fetcher.fetching) return;
  // Real time passes in runAsync (the file read); a pump (no time on the
  // screen's clock) delivers what completed to the app's zone.
  for (var i = 0; i < 200 && fetcher.fetching; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }
  await tester.runAsync(() => CodelesslyFonts.settled.timeout(const Duration(milliseconds: 500), onTimeout: () {}));
  await tester.pump();
  await tester.pump();
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
/// a screen name or a canvas name), else every screen: every layout but the
/// overlays and backdrops, and but those only ever opened as a modal (an
/// `openModal` in a page or in a component, [components] included, names
/// each of its canvases and no `navigate` does).
List<String> _screens(
  ({api.PublishBundle bundle, Map<String, String> layoutOfCanvas, Map<String, List<String>> screens}) published,
  Map<String, api.Json> docs,
  List<String> wanted,
  void Function(RuntimeIssue) issue, {
  List<api.Json> components = const [],
  bool includeModals = false,
}) {
  final all = published.screens.keys.toList();
  if (wanted.isEmpty) {
    final model = published.bundle.model;
    final modals = <String>{}, navigated = <String>{};
    void walk(Object? v) {
      if (v is Map) {
        final to = v['to'];
        if (to is String && v['type'] == api.OpenModalAction.typeName) modals.add(to);
        if (to is String && v['type'] == api.NavigateAction.typeName) navigated.add(to);
        v.values.forEach(walk);
      } else if (v is List) {
        v.forEach(walk);
      }
    }

    docs.values.forEach(walk);
    components.forEach(walk);
    bool onlyModal(String layout) {
      final canvases = published.screens[layout] ?? const <String>[];
      return layout != model.entryLayoutId &&
          canvases.isNotEmpty &&
          canvases.every((c) => modals.contains(c) && !navigated.contains(c)) &&
          !navigated.contains(layout);
    }

    final out = <String>[];
    for (final s in all) {
      if (model.overlayLayoutIds.contains(s) || model.backdropLayoutIds.contains(s)) continue;
      if (onlyModal(s) && !includeModals) {
        // Said, so a run that captures every screen knows what it left out.
        final name = _screenName(published, docs, s);
        issue(RuntimeIssue('modal_screen_not_captured', 'info',
            'Screen "$name" is only ever opened as a modal (an openModal names it, no navigate does): not captured. '
            '--screen $name captures it alone; --modals captures every such screen.',
            screen: name));
        continue;
      }
      out.add(s);
    }
    return out;
  }
  final out = <String>[];
  for (final w in wanted) {
    String? hit = published.screens.containsKey(w) ? w : published.layoutOfCanvas[w];
    // An overlay each of two pages has as its own is named as written on
    // both (`nav` is nav--board and nav--list: tool/notation/site_overlays.dart):
    // not one of them picked.
    final own = <String>{};
    if (hit == null) {
      for (final d in docs.values) {
        for (final e in (api.readMap(d['nodes']) ?? const {}).entries) {
          final n = api.readMap(e.value);
          if (n?['type'] != 'canvas') continue;
          final props = api.readMap(n!['props']) ?? const {};
          if (n['name'] == w && e.key.startsWith('$w--')) own.add(e.key);
          if (n['name'] == w || props['screen'] == w || n['path'] == w) hit ??= published.layoutOfCanvas[e.key];
        }
      }
    }
    if (own.length > 1) {
      issue(RuntimeIssue('unknown_screen_arg', 'error',
          '--screen "$w" is the overlay each of ${own.length} pages has as its own (they draw it differently): ${(own.toList()..sort()).join(', ')}. Name the one meant.'));
    } else if (hit == null) {
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
/// What a flex overflow means and what to change: the node's own size on
/// that axis (fixed, hugging, filling), what its content needs and the
/// children it holds, named with the copy of a list it is (`dish#2`): a
/// fixed size a longer item outgrows is the usual cause, not rounding.
String? _overflowAdvice(WidgetsBinding binding, NodeBox box, double by, String text) {
  final n = box.node;
  final side = RegExp(r'on the (bottom|right|top|left)').firstMatch(text)?[1];
  if (n == null || side == null || !box.hasSize) return null;
  final vertical = side == 'bottom' || side == 'top';
  final axis = vertical ? 'height' : 'width';
  String px(double v) => (v - v.roundToDouble()).abs() < 0.05 ? v.round().toString() : v.toStringAsFixed(1);
  final have = vertical ? box.size.height : box.size.width;
  final need = have + by;
  // Its copy in a list: the n-th box of the same node, as `#n` names it.
  final path = box.tree.pathOf(box.id, box.instance);
  final copies = [for (final b in _boxes(binding)) if (b.id == box.id && identical(b.tree, box.tree) && b.tree.pathOf(b.id, b.instance) == path) b];
  final name = copies.length > 1 ? '$path#${copies.indexOf(box)}' : path;
  final kids = <NodeBox>[];
  void visit(RenderObject o) {
    if (o is NodeBox) {
      if (o.hasSize && o.drawn) kids.add(o);
      return;
    }
    o.visitChildren(visit);
  }

  box.visitChildren(visit);
  final holds = [for (final k in kids.take(8)) '${k.id} ${px(vertical ? k.size.height : k.size.width)}'].join(', ');
  final field = vertical ? n.layout.height : n.layout.width;
  final what = switch (field.fit) {
    api.SizeFit.fixed => 'Its $axis is fixed at ${px(field.value)} and its content needs ${px(need)} ($holds, with its padding and spacing): '
        'a text in it takes more lines here than where that $axis was chosen (a longer item of a list, a narrower column). '
        'Let it grow with its content ({"hug": ${px(field.value)}}), make it at least ${px(need.ceilToDouble())}, '
        'or cap the text (maxLines with an ellipsis).',
    api.SizeFit.hug => 'It hugs its content, which needs ${px(need)} ($holds, with its padding and spacing), but its parent gives it '
        'only ${px(have)}: the parent has a fixed $axis or a max $axis. Let the parent hug too, or let it scroll.',
    _ => 'It fills ${px(have)} of its parent, and its content needs ${px(need)} ($holds, with its padding and spacing). '
        'Give the parent more room on that axis (hug), or let this node hug its content.',
  };
  return 'Node "$name" (${n.type}): its content overflows its $side by ${px(by)} px. $what';
}

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
  // The slices are of the page's route alone: whatever is open over it (a
  // modal, a dialog, a dropdown's menu, a toast: node boxes or not) shows
  // once, in the first window, not again in every slice.
  final covered = route != null;
  final layer = covered ? route : ro;
  final layerAt = covered ? route.localToGlobal(Offset.zero) - ro.localToGlobal(Offset.zero) : Offset.zero;
  Future<ui.Image> shot(RenderRepaintBoundary b) async => (await tester.runAsync(() => b.toImage(pixelRatio: 1)))!;
  final first = await shot(ro);
  final slices = <(ui.Image, double)>[];
  ui.Image? bare;
  const hidden = Offset(0, -1e6);
  for (final b in over) {
    b.capturePaintShift = hidden;
  }
  // What a control shows in its root's overlay layer (a dropdown's menu, a
  // picker, a tooltip) is part of the page's render tree: left out of the
  // slices the same way.
  final roots = _descendants(ro).whereType<RenderControlRoot>().toList();
  for (final r in roots) {
    r.paintsOverlay = false;
  }
  // A page whose content changes height once it scrolls (a header that
  // shrinks on a scroll reaction) is laid out shorter or taller below the
  // first window than in it: each slice is placed by that difference
  // ([shift], what changed above it), so the page below the first window
  // follows on from it with no rows lost or drawn twice at a seam.
  Future<void> scrollTo(double offset) async {
    page.jumpTo(offset.clamp(0.0, page.maxScrollExtent));
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
  }

  // What comes into view as the page passes through the window is not a
  // reader scrolling: a list that loads more at its end loads once, as the
  // page was when captured, not again at every slice.
  viewportTriggersPaused = true;
  try {
    var target = view.height;
    for (var guard = 0; guard < 1000; guard++) {
      await scrollTo(target);
      final shift = max - page.maxScrollExtent;
      final at = page.pixels;
      // The first slice starts where the first window ends.
      if (slices.isEmpty && shift.abs() > 0.5 && (at + shift - view.height).abs() > 0.5 && at < page.maxScrollExtent) {
        final again = view.height - shift;
        if ((again - at).abs() > 0.5 && guard < 3) {
          target = again;
          continue;
        }
      }
      slices.add((await shot(layer), at + shift));
      if (at >= page.maxScrollExtent - 0.5) break;
      target = at + view.height;
    }
    // What stands beside the page view (a sidebar, a rail, the canvas's own
    // margin) is as tall as the window, and the capture is taller: below
    // the first window those columns continue with the pane's own
    // background (its fill and border, without what is in it), so nothing
    // is left unpainted under a sidebar.
    if (view.left > 0.5 || view.right < window.width - 0.5) {
      final beside = pageBox == null ? const <NodeBox>[] : _fixedAround(binding, pageBox);
      final shown = [for (final b in over) if (_rectOf(b).right <= view.left + 0.5 || _rectOf(b).left >= view.right - 0.5) b];
      final inside = <NodeBox>[];
      for (final b in beside) {
        final stack = <RenderObject>[];
        b.visitChildren(stack.add);
        while (stack.isNotEmpty) {
          final o = stack.removeLast();
          if (o is NodeBox) {
            inside.add(o);
          } else {
            o.visitChildren(stack.add);
          }
        }
      }
      for (final b in shown) {
        b.capturePaintShift = Offset.zero;
      }
      final was = [for (final b in inside) b.capturePaintShift];
      for (final b in inside) {
        b.capturePaintShift = hidden;
      }
      await tester.pump();
      bare = await shot(layer);
      for (final (i, b) in inside.indexed) {
        b.capturePaintShift = was[i];
      }
      for (final b in shown) {
        b.capturePaintShift = hidden;
      }
    }
  } finally {
    for (final b in over) {
      b.capturePaintShift = Offset.zero;
    }
    for (final r in roots) {
      r.paintsOverlay = true;
    }
    page.jumpTo(0);
    await _settle(tester);
    viewportTriggersPaused = false;
  }
  final total = (window.height + max).ceilToDouble();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final paint = Paint()..filterQuality = FilterQuality.none;
  // Rows of [img] (a capture of [layer]) in window coordinates.
  // Only the columns the page view covers: what stands beside it (a rail,
  // a sidebar that does not scroll) shows once, in the first window, not
  // again at every seam.
  void rows(ui.Image img, double top, double height, double to) => canvas.drawImageRect(
      img, Rect.fromLTWH(view.left - layerAt.dx, top - layerAt.dy, view.width, height), Rect.fromLTWH(view.left, to, view.width, height), paint);
  for (final (img, at) in slices) {
    // The viewport's rows: the page from offset [at].
    rows(img, view.top, view.height, view.top + at);
  }
  // Below the page view at the page's end (the fixed boxes left out).
  final (last, lastAt) = slices.last;
  rows(last, view.bottom, window.height - view.bottom, view.bottom + lastAt);
  // Beside the page view, under the first window: the panes' backgrounds
  // carried on from the window's last row.
  if (bare != null && max > 0) {
    void carry(double left, double right) {
      if (right - left < 0.5) return;
      canvas.drawImageRect(bare!, Rect.fromLTWH(left - layerAt.dx, window.height - 1 - layerAt.dy, right - left, 1),
          Rect.fromLTWH(left, window.height, right - left, total - window.height), paint);
    }

    carry(0, view.left);
    carry(view.right, window.width);
  }
  // The first window on top, as it shows.
  canvas.drawImage(first, Offset.zero, paint);
  final picture = recorder.endRecording();
  return (await tester.runAsync(() async {
    final image = await picture.toImage(window.width.ceil(), total.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    first.dispose();
    bare?.dispose();
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

/// Whether a route is open over the one [page] is in (a dialog, a drawer, a
/// menu): an onstage entry after it in its navigator's theater.
bool _overlayOver(RenderObject page) {
  for (final (theater, ro) in _theaters()) {
    final onstage = <Element>[];
    theater.debugVisitOnstageChildren(onstage.add);
    final i = onstage.indexWhere((e) {
      final r = e.renderObject;
      if (r == null) return false;
      for (RenderObject? p = page; p != null && !identical(p, ro); p = p.parent) {
        if (identical(p, r)) return true;
      }
      return false;
    });
    if (i >= 0) return i < onstage.length - 1;
  }
  return false;
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
  // A route kept out of sight (a menu while the confirm its line asked is
  // up) is built offstage.
  void visit(RenderObject o) {
    if (o is RenderOffstage && o.offstage) {
      out.add(o);
      return;
    }
    o.visitChildren(visit);
  }

  for (final view in WidgetsBinding.instance.renderViews) {
    visit(view);
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
        if (o is NodeBox && o.attached && o.hasSize && _rooted(o, view)) o,
  ];
}

/// Whether [o]'s parents lead to [root]. A render object that still visits
/// a child it no longer holds (a field hidden by a condition, say) would
/// otherwise be measured from a tree it is not in.
bool _rooted(RenderObject o, RenderObject root) {
  for (RenderObject? p = o; p != null; p = p.parent) {
    if (identical(p, root)) return true;
  }
  if (Platform.environment['RENDER_DEBUG_ORPHANS'] != null) {
    final chain = <String>[];
    for (RenderObject? p = o; p != null; p = p.parent) {
      chain.add(p is NodeBox ? 'NodeBox(${p.id})' : '${p.runtimeType}');
    }
    stderr.writeln('orphan: ${chain.join(' < ')}');
  }
  return false;
}

/// The box of node [id] on screen: the topmost (the last painted), or with
/// `id#n` the n-th (0-based) of the copies a list repeats.
NodeBox? _boxOf(WidgetsBinding binding, String id) => _locate(binding, id).box;

/// Marks a step's problem as "not shown at this size": the step is skipped
/// there, with a note, not failed.
const _notShownHere = 'not shown at this size: ';

/// Whether [b] draws: it and every node box above it shown, with a size.
bool _shown(NodeBox b) {
  if (b.size.isEmpty) return false;
  for (RenderObject? p = b; p != null; p = p.parent) {
    if (p is NodeBox && !p.drawn) return false;
  }
  return true;
}

/// Follows the pages a navigator shows (not its dialogs and sheets): [shown]
/// is the name of the page on top that was navigated to (null: the first).
class _PageObserver extends NavigatorObserver {
  final List<RouteSettings> _pages = [];

  RouteSettings? get shown => _pages.lastOrNull;

  void reset() => _pages.clear();

  // A screen navigated to (`/week`); not the entry, a paywall or a
  // presented layout.
  bool _isPage(Route<dynamic> r) {
    final name = r.settings.name;
    return r is PageRoute && name != null && name != '/' && !name.startsWith('/paywall/') && !name.startsWith('/present/');
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_isPage(route)) _pages.add(route.settings);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_isPage(route) && _pages.isNotEmpty) _pages.removeLast();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => didPop(route, previousRoute);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) didPop(oldRoute, null);
    if (newRoute != null) didPush(newRoute, null);
  }
}

/// The text of each live region on screen (a toast, a text marked `live`, a
/// status a control announces), by its render object: what a screen reader
/// speaks when it changes.
Map<RenderObject, String> _liveRegions(WidgetsBinding binding) {
  final out = <RenderObject, String>{};
  final skip = _offstage();
  for (final view in binding.renderViews) {
    for (final o in _descendants(view, skip: skip)) {
      if (!o.attached || (o is RenderBox && !o.hasSize)) continue;
      final config = SemanticsConfiguration();
      try {
        // ignore: invalid_use_of_protected_member
        o.describeSemanticsConfiguration(config);
      } catch (_) {
        continue;
      }
      if (!config.liveRegion) continue;
      final text = (config.label.trim().isNotEmpty ? config.label : firstTextUnder(o) ?? '').trim();
      if (text.isNotEmpty) out[o] = text;
    }
  }
  return out;
}

/// How a step names [b]: its path (a component's node by its call ids), with
/// `#n` for the n-th copy of a node a list repeats.
String _stepName(WidgetsBinding binding, NodeBox b) {
  final path = b.tree.pathOf(b.id, b.instance);
  final copies = [for (final o in _boxes(binding)) if (o.id == b.id && identical(o.tree, b.tree) && o.tree.pathOf(o.id, o.instance) == path && (_shown(o) || identical(o, b))) o];
  if (copies.length < 2) return path;
  return '$path#${copies.indexWhere((o) => identical(o, b))}';
}

/// Whether node box [b] takes a tap itself: a click reaction of its node,
/// or a control drawn in it that takes input.
bool _takesTap(NodeBox b) {
  final n = b.source.node(b.id);
  if (n != null && n.actions.any((a) => a.trigger.type == api.TriggerType.click)) return true;
  if (n?.behaviors.reorderHandle ?? false) return true;
  // Its own drawing only: not the node boxes of its children.
  var found = false;
  void visit(RenderObject o) {
    if (found || (o is NodeBox && !identical(o, b))) return;
    if ((o is RenderControl && o.enabled && o.takesInput) || o is RenderEditable) {
      found = true;
      return;
    }
    o.visitChildren(visit);
  }

  visit(b);
  return found;
}

/// The nodes inside [box] that take a tap, shown, outermost only (a button
/// inside a tappable card is the card's).
List<NodeBox> _tappableInside(WidgetsBinding binding, NodeBox box) {
  final inside = [
    for (final b in _boxes(binding))
      if (!identical(b, box) && _isInside(b, box) && _shown(b) && _takesTap(b)) b,
  ];
  return [for (final b in inside) if (!inside.any((o) => !identical(o, b) && _isInside(b, o))) b];
}

/// What a step may have meant by [id], which names no node on screen (or one
/// that takes no tap): the nodes that take a tap inside the node its first
/// part names (`dates` for `dates/from`), then those whose name is like its
/// last part (`field` for `textField1`). Empty when none is near.
List<String> _candidates(WidgetsBinding binding, String id) {
  final out = <String>[];
  final segments = id.split('/');
  for (var cut = segments.length; cut >= 1; cut--) {
    final prefix = segments.take(cut).join('/');
    final within = _locate(binding, prefix).box;
    if (within == null) continue;
    for (final b in _tappableInside(binding, within)) {
      final name = _stepName(binding, b);
      if (!out.contains(name)) out.add(name);
    }
    break;
  }
  // What is inside the block named is what was meant; else, by name.
  if (out.isNotEmpty) return out.take(6).toList();
  final want = segments.last.split('#').first.split('@').first.toLowerCase();
  if (want.isNotEmpty) {
    final scored = <(String, int)>[];
    final seen = <String>{};
    for (final b in _boxes(binding)) {
      if (!_shown(b)) continue;
      final name = b.tree.pathOf(b.id, b.instance);
      if (!seen.add(name)) continue;
      // Its id, its name, and (a component's root) the call's id.
      final words = {b.id.toLowerCase(), (b.node?.name ?? '').toLowerCase(), name.split('/').last.toLowerCase()}..remove('');
      // A call named the way the notation numbers one (`Segments1` for the
      // first Segments) is near its component's type.
      final types = {(b.node?.type ?? '').toLowerCase(), if (b.tree.isInstanceRoot(b.id, b.instance)) (componentInstanceOf(b.instance)?.component ?? '').toLowerCase()}
        ..remove('');
      final typed = types.contains(want.replaceFirst(RegExp(r'\d+$'), ''));
      final d = words.map((w) => _distance(want, w)).fold(1 << 20, math.min);
      bool within(String a, String b) => a.length >= 3 && b.length >= 3 && (a.contains(b) || b.contains(a));
      final near = typed || words.any((w) => within(w, want)) || d <= math.max(2, want.length ~/ 3);
      if (near) scored.add((name, d - (_takesTap(b) ? 2 : 0)));
    }
    scored.sort((a, b) => a.$2.compareTo(b.$2));
    for (final (name, _) in scored) {
      if (!out.contains(name)) out.add(name);
    }
  }
  return out.take(6).toList();
}

/// [problem] with the nodes [id] may have meant, when there are any.
String _withCandidates(WidgetsBinding binding, String id, String problem) {
  final c = _candidates(binding, id);
  if (c.isEmpty) return problem;
  final end = problem.endsWith('.') ? problem.substring(0, problem.length - 1) : problem;
  return '$end. Perhaps: ${c.join(', ')}.';
}

/// Levenshtein distance between [a] and [b].
int _distance(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 0; i < a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0)..[0] = i + 1;
    for (var j = 0; j < b.length; j++) {
      cur[j + 1] = math.min(math.min(cur[j] + 1, prev[j + 1] + 1), prev[j] + (a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1));
    }
    prev = cur;
  }
  return prev[b.length];
}

/// The canvas a node box is on (its screen, or a modal shown over it).
String? _canvasOf(NodeBox b) {
  for (RenderObject? p = b; p != null; p = p.parent) {
    if (p is NodeBox && p.node?.type == 'canvas') return p.id;
  }
  return null;
}

/// The id a step names canvas box [b] by: the id written on its page for
/// an overlay site expansion made the page's own (`nav--board` is the
/// board page's `Drawer#nav`, its name `nav`: tool/notation/site_overlays.dart),
/// else its id. One page's overlays are on screen at a time, so the written
/// id names one.
String _canvasWord(NodeBox b) {
  final name = b.node?.name ?? '';
  return name.isNotEmpty && b.id.startsWith('$name--') ? name : b.id;
}

/// [_canvasOf] as a step names it ([_canvasWord]).
String? _canvasNameOf(NodeBox b) {
  for (RenderObject? p = b; p != null; p = p.parent) {
    if (p is NodeBox && p.node?.type == 'canvas') return _canvasWord(p);
  }
  return null;
}

/// Node [id] on screen, or why there is none, or that two nodes answer to
/// it. [id] is a node id or `name` (`saved`), `<id>#<n>` for a list's n-th
/// copy, or a path: a component's node by its call ids (`footer/saved`), a
/// node inside a list's copy (`evCard#0/evReserve`).
///
/// When two different nodes answer to an id and exactly one of them passes
/// [prefer] (`--type`: the one with a text field in it), that one is meant.
({NodeBox? box, String? problem}) _locate(WidgetsBinding binding, String id, {bool Function(NodeBox)? prefer}) {
  final exact = _locateExact(binding, id, prefer: prefer);
  if (exact.box != null || !(exact.problem ?? '').startsWith('no node ') || id.contains('#')) return exact;
  // A node inside a component instance named without the calls above it
  // (`joinSeason/action`, `action` for `FieldSeason1/joinSeason/action`):
  // the node whose full path ends with what was written, when one node on
  // screen has such a path; several are named by their full paths.
  final matches = <String, List<NodeBox>>{};
  for (final b in _boxes(binding)) {
    if (componentInstanceOf(b.instance) == null) continue;
    final path = b.tree.pathOf(b.id, b.instance);
    final plain = path.replaceAll(RegExp(r'#\d+'), '');
    // A component's root is named by its call (`FieldSeason1/joinSeason`),
    // or by its call and its own id (`joinSeason/action`).
    final forms = [plain, if (b.tree.isInstanceRoot(b.id, b.instance)) '$plain/${b.id}'];
    if (forms.any((f) => f == id || f.endsWith('/$id'))) (matches[plain] ??= []).add(b);
  }
  if (matches.isEmpty) return exact;
  if (matches.length > 1) {
    return (
      box: null,
      problem: 'ambiguous: ${matches.length} nodes on screen have a path ending "$id": ${matches.keys.join(', ')}. Name the one meant by its full path',
    );
  }
  final copies = matches.values.single;
  final shown = [for (final b in copies) if (_shown(b)) b];
  if (shown.isEmpty) return (box: null, problem: '$_notShownHere"$id" is hidden here (visible false, or a media rule hides it at this width)');
  final view = Offset.zero & binding.renderViews.first.size;
  return (box: shown.where((b) => _rectOf(b).overlaps(view)).firstOrNull ?? shown.last, problem: null);
}

/// [path] (a component's node by its call ids, `cards#2/cta`) with each
/// `#n` turned from the n-th copy shown into the n-th copy [tree] made: a
/// step counts the copies a list shows, not those a condition hides
/// (`--tap message#9` was the tenth row of the data, hidden or not: test 10,
/// mail). Unchanged when a copy is not found (the lookup says so).
String _rawCopies(RenderTree tree, String path) {
  if (!path.contains('#')) return path;
  final segments = path.split('/');
  for (var d = 0; d < segments.length; d++) {
    final hash = segments[d].lastIndexOf('#');
    final n = hash < 0 ? null : int.tryParse(segments[d].substring(hash + 1));
    if (n == null) continue;
    final name = segments[d].substring(0, hash);
    final before = segments.take(d).join('/');
    var seen = -1;
    for (var k = 0; k < 10000; k++) {
      final copy = tree.boxAtPath('${before.isEmpty ? '' : '$before/'}$name#$k');
      if (copy == null) break;
      if (copy.attached && copy.hasSize && _shown(copy)) seen++;
      if (seen == n) {
        segments[d] = '$name#$k';
        break;
      }
    }
  }
  return segments.join('/');
}

/// [_locate] for a node named as it is: by its id or name, its full path,
/// or segment by segment.
({NodeBox? box, String? problem}) _locateExact(WidgetsBinding binding, String id, {bool Function(NodeBox)? prefer}) {
  final boxes = _boxes(binding);
  (String, int?) split(String segment) {
    final hash = segment.lastIndexOf('#');
    final index = hash < 0 ? null : int.tryParse(segment.substring(hash + 1));
    return (index == null ? segment : segment.substring(0, hash), index);
  }

  // A node inside a component, by path: `plans/card1/cta`; a call by its
  // id (its box is its definition root's): `send`, `sizes#3`.
  final first = id.split('/').first.split('#').first;
  // A path from a canvas (`list/row#1`) is the page's own node, read
  // segment by segment below: as a component's path it reached a component's
  // node of the same id (test 9, kanban 9: a filter chip for a table's row).
  final fromCanvas = id.contains('/') && boxes.any((b) => b.node?.type == 'canvas' && (b.id == first || _canvasWord(b) == first));
  final byPath = !fromCanvas &&
      (id.contains('/') || boxes.any((b) => b.id != first && b.tree.isInstanceRoot(b.id, b.instance) && b.tree.pathOf(b.id, b.instance) == first));
  if (byPath) {
    for (final b in boxes) {
      final found = b.tree.boxAtPath(_rawCopies(b.tree, id));
      if (found != null && found.attached && found.hasSize) {
        // A component's node a media rule or a binding hides here (laid out
        // with no size, or not drawn) is skipped at this size, as a page's.
        if (!_shown(found)) {
          return (box: null, problem: '$_notShownHere"$id" is hidden here (visible false, or a media rule hides it at this width)');
        }
        return (box: found, problem: null);
      }
    }
    if (!id.contains('/')) return (box: null, problem: 'no node "$id" is on screen');
    // A component's root named after its call (`nav/tabs`, where `tabs` is
    // the root of the component `nav` calls): the call's own box.
    final cut = id.lastIndexOf('/');
    final (rootName, _) = split(id.substring(cut + 1));
    for (final b in boxes) {
      final found = b.tree.boxAtPath(id.substring(0, cut));
      if (found != null && found.attached && found.hasSize && found.id == rootName && _shown(found)) return (box: found, problem: null);
    }
  }
  // Segment by segment, each inside the one before: `evCard#0/evReserve`.
  var scope = boxes;
  NodeBox? chosen;
  final segments = id.split('/');
  for (var i = 0; i < segments.length; i++) {
    final (name, index) = split(segments[i]);
    var all = [for (final b in scope) if (b.id == name) b];
    // A node may be named by its `name` too: the same name on a screen's
    // breakpoint canvases reaches whichever is shown.
    if (all.isEmpty) all = [for (final b in scope) if (b.node?.name == name) b];
    final upTo = segments.take(i + 1).join('/');
    if (all.isEmpty) {
      // A node of the page whose box is not built because something around
      // it is hidden at this size (a list under `hide=phone`: its copies are
      // not made) is not shown here, as a node hidden itself is: the step is
      // skipped at this size (support desk, test 11: `--tap queue-row#0` at
      // 390 was an error while `--tap bulkAssign` was skipped).
      if (i == 0 && _hiddenAround(boxes, name)) {
        return (box: null, problem: '$_notShownHere"$name": what holds it is hidden here (visible false, or a media rule hides it at this width)');
      }
      return (box: null, problem: i == 0 ? 'no node "$name" is on screen' : 'no node "$name" is inside "${segments.take(i).join('/')}"');
    }
    if (index != null) {
      // The n-th copy of one node: copies of a page's and a component's
      // nodes of one id (a generated `listView1Item`) are not counted
      // together; under a canvas the page's own, else said.
      final trees = {for (final b in all) '${identityHashCode(b.tree)}|${b.tree.pathOf(b.id, b.instance).replaceAll(RegExp(r'#\d+'), '')}'};
      if (trees.length > 1) {
        final own = [for (final b in all) if (componentInstanceOf(b.instance) == null) b];
        if (i > 0 && chosen?.node?.type == 'canvas' && own.isNotEmpty) {
          all = own;
        } else {
          final names = {for (final b in all) componentInstanceOf(b.instance) == null ? '${_canvasNameOf(b) ?? '<canvas id>'}/$name#$index' : '${b.tree.pathOf(b.id, b.instance).replaceAll(RegExp(r'#\d+$'), '')}#$index'};
          return (box: null, problem: "ambiguous: copies of ${trees.length} different nodes on screen are \"$name\" (a page's and a component's, or two components'). Name the one meant by its path: ${names.take(4).join(' or ')}");
        }
      }
      // The copies shown: a copy a condition hides (`if` in a list, a
      // filter) is not counted, as a reader does not see it.
      final shown = [for (final b in all) if (_shown(b)) b];
      if (shown.isEmpty) return (box: null, problem: '$_notShownHere"$upTo": no copy of "$name" is shown here (visible false, or a media rule hides them at this width)');
      if (index >= shown.length) {
        return (
          box: null,
          problem: '"$upTo": ${shown.length == 1 ? 'there is 1 copy' : 'there are ${shown.length} copies'} of "$name" on screen (#0 to #${shown.length - 1})'
              '${shown.length < all.length ? '; #n counts the copies shown, not the ${all.length - shown.length} hidden' : ''}',
        );
      }
      chosen = shown[index];
    } else {
      // Two different nodes answer to the id (a page's and a component's,
      // a page's and a modal's): say which to write. Copies a list repeats
      // are one node.
      final kinds = <String, NodeBox>{};
      for (final b in all) {
        final path = b.tree.pathOf(b.id, b.instance);
        kinds.putIfAbsent('${identityHashCode(b.tree)}|$path', () => b);
      }
      // Under a canvas (`page/saved`), the page's own node: not one of a
      // component's.
      if (kinds.length > 1 && i > 0 && chosen?.node?.type == 'canvas') {
        final own = [for (final b in kinds.values) if (componentInstanceOf(b.instance) == null) b];
        if (own.length == 1) {
          kinds
            ..clear()
            ..['own'] = own.single;
          all = [for (final b in all) if (componentInstanceOf(b.instance) == null) b];
        }
      }
      if (kinds.length > 1 && prefer != null) {
        final preferred = [for (final b in kinds.values) if (prefer(b)) b];
        if (preferred.length == 1) {
          final keep = preferred.single;
          kinds
            ..clear()
            ..['preferred'] = keep;
          final keepPath = keep.tree.pathOf(keep.id, keep.instance);
          all = [for (final b in all) if (identical(b.tree, keep.tree) && b.tree.pathOf(b.id, b.instance) == keepPath) b];
        }
      }
      if (kinds.length > 1) {
        final paths = {for (final b in kinds.values) b.tree.pathOf(b.id, b.instance)};
        final names = [
          for (final b in kinds.values)
            paths.length == kinds.length
                ? b.tree.pathOf(b.id, b.instance)
                : '${b.tree.pathOf(b.id, b.instance)} (on canvas ${_canvasNameOf(b) ?? '?'})',
        ];
        final write = [
          for (final b in kinds.values)
            componentInstanceOf(b.instance) == null ? '${_canvasNameOf(b) ?? '<canvas id>'}/$name' : b.tree.pathOf(b.id, b.instance),
        ];
        return (
          box: null,
          problem: 'ambiguous: ${kinds.length} different nodes on screen are "$upTo": ${names.join(', ')}. '
              'Ids are per document, so a page, a component and a modal may each have one. Name the one meant: '
              '${write.toSet().length == write.length ? write.join(' or ') : 'they are on one canvas: give them different ids'}',
        );
      }
      // Of the copies a list or a table repeats, the first one in view (a
      // table's five headers: the one a person would see first); the last
      // made when none is.
      final view = Offset.zero & binding.renderViews.first.size;
      chosen = all.where((b) => b.attached && b.hasSize && _rectOf(b).overlaps(view)).firstOrNull ?? all.last;
    }
    if (i < segments.length - 1) {
      final within = chosen;
      scope = [for (final b in boxes) if (!identical(b, within) && _isInside(b, within)) b];
    }
  }
  if (chosen != null && !_shown(chosen)) {
    return (box: null, problem: '$_notShownHere"$id" is hidden here (visible false, or a media rule hides it at this width)');
  }
  return (box: chosen, problem: null);
}

/// Whether node [id] of a tree shown (a page's own node, by its document)
/// has no box because a node around it is hidden here: an ancestor whose box
/// is not shown, or is built with nothing in it.
bool _hiddenAround(List<NodeBox> boxes, String id) {
  for (final tree in {for (final b in boxes) b.tree}) {
    final source = tree.sourceOf(null);
    if (source.node(id) == null) continue;
    for (String? at = source.parentOf(id); at != null; at = source.parentOf(at)) {
      final around = [for (final b in boxes) if (identical(b.tree, tree) && b.id == at && componentInstanceOf(b.instance) == null) b];
      if (around.isEmpty) continue;
      if (around.every((b) => !_shown(b))) return true;
      break;
    }
  }
  return false;
}

/// The page's scroll view: of the vertical ones a user can scroll that have
/// something to scroll, the one with the largest viewport (outermost on a
/// tie).
RenderDesignScroll? _pageScroll(WidgetsBinding binding, {bool fullPage = false}) {
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
  // A pane of a window (a mail list beside its reader, each scrolling on
  // its own) is not the page: the window is captured as it is, not the
  // pane's length with the rest cut or repeated (test 9, mail).
  if (best != null && fullPage) {
    final view = binding.renderViews.first.size;
    if (best.size.width < view.width * 0.6) return null;
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

/// The modifier keys a pointer step holds (`shift+`, `ctrl+`, `alt+`,
/// `meta+`/`cmd+`, `mod+`: Control, Command on a Mac, before its target) and
/// the step without them. A key step names its own (`--key shift+Tab`).
(List<LogicalKeyboardKey>, Step) _heldKeys(Step step) {
  if (!_pointerSteps.contains(step.kind)) return (const [], step);
  final keys = <LogicalKeyboardKey>[];
  var target = step.target;
  while (true) {
    final m = RegExp(r'^(shift|ctrl|control|alt|option|meta|cmd|command|mod)\+(?=.)', caseSensitive: false).firstMatch(target);
    if (m == null) break;
    keys.add(switch (m[1]!.toLowerCase()) {
      'shift' => LogicalKeyboardKey.shiftLeft,
      'alt' || 'option' => LogicalKeyboardKey.altLeft,
      'meta' || 'cmd' || 'command' => LogicalKeyboardKey.metaLeft,
      'mod' => defaultTargetPlatform == TargetPlatform.macOS ? LogicalKeyboardKey.metaLeft : LogicalKeyboardKey.controlLeft,
      _ => LogicalKeyboardKey.controlLeft,
    });
    target = target.substring(m.end);
  }
  return (keys, keys.isEmpty ? step : Step(step.kind, target, step.value));
}

/// A step target's `@` part (`@2`, `@increment`, `@option:Alaska`,
/// `@2026-11-23`).
final _partSuffix = RegExp(r'@(\d+|increment|decrement|thumb|thumb-end|option:.*|\d{4}-\d{2}-\d{2})$');

const _pointerSteps = {'tap', 'double-tap', 'long-press', 'right-click', 'hover', 'drag'};

Future<String?> _apply(WidgetTester tester, Step step, CodelesslyWidgetController controller,
    GlobalKey<NavigatorState> navigator, Codelessly codelessly,
    {required void Function(String code, String message, String? nodeId) warn, List<String> screens = const []}) async {
  final binding = tester.binding;
  await _releaseHeld();
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
    // A point where nothing inside it that takes a press of its own (a link
    // in a table's row: the name that opens a pane) is over it comes first:
    // a step that names the row means the row.
    bool own(ui.Offset p) {
      for (final h in hitAt(p)) {
        if (identical(h, box)) return true;
        if (h is NodeBox && _takesTap(h)) return false;
      }
      return false;
    }

    for (final p in points) {
      if (own(p)) return p;
    }
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

  // Whether anything along [path] reacts to a tap: a node's tap reaction,
  // or a widget inside the node hit (a button, an input) that handles taps.
  bool reactsToTap(List<RenderObject> path) {
    var inWidget = true;
    RenderControl? control;
    for (final o in path) {
      // A control drawn by the SDK (a button, a switch, a field, a tab bar)
      // takes the tap itself: it changes its value, opens its menu or
      // picker, or fires its node's reactions. Only a control that does
      // nothing on its own (a button, an action chip, a list tile) needs a
      // reaction on its node.
      if (o is RenderControl && control == null && o.enabled && o.takesInput) {
        control = o;
        if (o is! RenderButton && o is! RenderListTile) return true;
      }
      if (o is RenderCalendar && o.inline) return true;
      // A table sorts from its headers and selects its rows itself; its cell
      // template is usually a text with no reaction of its own.
      if (o is RenderRunningTable) return true;
      if (o is NodeBox && control != null) {
        if (o.source.node(o.id)?.actions.isNotEmpty ?? false) return true;
        // A reorder handle: a press focuses it, for Alt and the arrows.
        if (o.source.node(o.id)?.behaviors.reorderHandle ?? false) return true;
        control = null;
      }
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

  // Where to put the pointer for [id], or the problem.
  Future<(ui.Offset?, String?)> pointAt(String target, String verb) async {
    // An inline calendar has one node but many dates: name the ISO day.
    final datePart = RegExp(r'^(.*)@(\d{4}-\d{2}-\d{2})$').firstMatch(target);
    if (datePart != null) {
      final id = datePart[1]!, day = DateTime.tryParse(datePart[2]!);
      final found = _locate(binding, id);
      if (found.box == null) {
        return (null, found.problem!.startsWith(_notShownHere) ? '$_notShownHere--$verb $target: ${found.problem!.substring(_notShownHere.length)}.' : _withCandidates(binding, id, '--$verb $target: ${found.problem}.'));
      }
      RenderCalendar? calendar;
      void visit(RenderObject o) {
        if (o is RenderCalendar && o.inline) calendar = o;
        if (calendar == null) o.visitChildren(visit);
      }
      visit(found.box!);
      if (calendar == null || day == null) return (null, '--$verb $target: "$id" is not an inline calendar date.');
      await centerInView(found.box!);
      final cell = calendar!.cellOf(day);
      if (cell == null) return (null, '--$verb $target: ${datePart[2]} is not in the month shown by "$id".');
      return (calendar!.localToGlobal(calendar!.cellRect(cell).center), null);
    }
    // A built-in control's named part: a number field's minus and plus
    // (`@decrement`, `@increment`), a slider's thumb (`@thumb`, a range's
    // upper `@thumb-end`), an option of a dropdown (`@option:Alaska`; the
    // dropdown is opened first when it is closed).
    final named = RegExp(r'^(.*)@(increment|decrement|thumb|thumb-end|option:(.+))$').firstMatch(target);
    if (named != null) {
      final id = named[1]!, what = named[2]!;
      final found = _locate(binding, id);
      if (found.box == null) {
        return (null, found.problem!.startsWith(_notShownHere) ? '$_notShownHere--$verb $target: ${found.problem!.substring(_notShownHere.length)}.' : _withCandidates(binding, id, '--$verb $target: ${found.problem}.'));
      }
      final box = found.box!;
      final parts = _partNames(box);
      String none() => '--$verb $target: "$id" has no part "@$what"${parts.isEmpty ? ' (it has no named parts)' : '; its parts: ${parts.join(', ')}'}.';
      if (what == 'increment' || what == 'decrement') {
        final field = _firstIn<RenderTextField>(box);
        if (field == null || !(field.decoration.prefix?.button ?? false)) return (null, none());
        await centerInView(box);
        return (field.localToGlobal(field.buttonSlot(prefix: what == 'decrement').center), null);
      }
      if (what.startsWith('thumb')) {
        final slider = _firstIn<RenderSlider>(box);
        if (slider == null || (what == 'thumb-end' && !slider.isRange)) return (null, none());
        await centerInView(box);
        final f = what == 'thumb' ? slider.thumbCenter : slider.highThumbCenter;
        final vertical = slider.node.prop(api.SliderProps.orientation) == api.Axis.vertical;
        return (slider.localToGlobal(vertical ? ui.Offset(f.dy, slider.size.height - f.dx) : f), null);
      }
      final label = named[3]!.trim();
      final dropdown = _firstIn<RenderDropdown>(box);
      var rows = _openMenuRows(binding, label);
      if (rows.isEmpty && dropdown != null && !dropdown.isOpen) {
        // Closed: opened as a user does, by a press on it (scrolled into
        // view first).
        if (reachable(box) == null) await centerInView(box);
        final at = reachable(box) ?? _rectOf(box).center;
        await tester.tapAt(at);
        await _settle(tester);
        rows = _openMenuRows(binding, label);
      }
      if (rows.isEmpty) {
        final open = _openMenuRows(binding, null).map((r) => r.item.label).toList();
        return (
          null,
          '--$verb $target: no option "$label" ${open.isEmpty ? 'is shown (no dropdown or menu is open${dropdown == null ? ', and "$id" is no dropdown' : ''})' : 'in the open menu; its options: ${open.take(12).join(', ')}'}.',
        );
      }
      return (rows.last.localToGlobal(rows.last.size.center(ui.Offset.zero)), null);
    }
    // `<id>@<n>`: the n-th part (from 0) of a control with several: a
    // segment, a tab, a navigation destination.
    final part = RegExp(r'^(.*)@(\d+)$').firstMatch(target);
    final id = part == null ? target : part[1]!;
    final found = _locate(binding, id);
    // A number field with a minus and a plus: @0 the minus, @1 the field,
    // @2 the plus, as they are drawn.
    if (part != null && found.box != null && int.parse(part[2]!) <= 2) {
      final field = _firstIn<RenderTextField>(found.box!);
      if (field != null && (field.decoration.prefix?.button ?? false) && _firstIn<RenderItemBar>(found.box!) == null) {
        final n = int.parse(part[2]!);
        if (n == 1) return pointAt(id, verb);
        return pointAt('$id@${n == 0 ? 'decrement' : 'increment'}', verb);
      }
    }
    if (part != null && found.box != null) {
      final n = int.parse(part[2]!);
      RenderBox? control;
      List<ui.Rect> rects = const [];
      void visit(RenderObject o) {
        if (control != null) return;
        if (o is RenderItemBar) {
          control = o;
          rects = o.itemRects;
        } else if (o is RenderSegmentedButton) {
          control = o;
          rects = o.segmentRects;
        } else {
          o.visitChildren(visit);
        }
      }

      visit(found.box!);
      if (control == null) {
        // A component drawn from nodes (a design system's segmented control,
        // its tabs): its parts are the copies of the node it repeats.
        final within = [for (final b in _boxes(binding)) if (!identical(b, found.box) && _isInside(b, found.box!) && b.attached && b.hasSize) b];
        final byId = <String, List<NodeBox>>{};
        for (final b in within) {
          (byId[b.id] ??= []).add(b);
        }
        // Or its parts are numbered nodes that take a tap (a design
        // system's Segments: cell0, cell1, cell2).
        final numbered = <String, List<(int, NodeBox)>>{};
        for (final b in within) {
          final m = RegExp(r'^(.*?)(\d+)$').firstMatch(b.id);
          if (m != null && _takesTap(b)) (numbered[m[1]!] ??= []).add((int.parse(m[2]!), b));
        }
        final cells = numbered.values.where((l) => l.length > 1).firstOrNull;
        final parts = byId.values.where((l) => l.length > 1).firstOrNull ??
            (cells == null ? null : [for (final (_, b) in (cells..sort((a, b) => a.$1.compareTo(b.$1)))) b]);
        if (parts != null) {
          if (n >= parts.length) {
            return (null, '--$verb $target: "$id" has ${parts.length} parts (@0 to @${parts.length - 1}).');
          }
          await centerInView(parts[n]);
          return (reachable(parts[n]) ?? _rectOf(parts[n]).center, null);
        }
      }
      if (control == null) {
        final names = _partNames(found.box!);
        return (
          null,
          names.isNotEmpty
              ? '--$verb $target: "$id" has no part @$n; its parts: ${names.join(', ')}.'
              : '--$verb $target: "$id" has no parts to name with @: @<n> is for a segmented button, a tab bar and a navigation bar; '
                  'a number field has @decrement and @increment, a slider @thumb, a dropdown @option:<label>, an inline calendar @<yyyy-MM-dd> '
                  '(--dump-layout lists each node\'s "parts"). Tap it with --$verb $id.',
        );
      }
      if (n >= rects.length) {
        return (null, '--$verb $target: "$id" has ${rects.length} part${rects.length == 1 ? '' : 's'} (@0 to @${rects.length - 1}).');
      }
      await centerInView(found.box!);
      return (control!.localToGlobal(rects[n].center), null);
    }
    final box = found.box;
    // A bottom sheet's drag handle, which is no node of the document:
    // `<sheet id>/handle` (or `handle` with one sheet open).
    if (box == null && part == null && (id == 'handle' || id.endsWith('/handle'))) {
      final handles = find.byKey(const ValueKey('Codelessly sheet drag area')).evaluate().toList();
      final handle = handles.lastOrNull?.renderObject;
      if (handle is RenderBox && handle.attached && handle.hasSize) return (handle.localToGlobal(handle.size.center(ui.Offset.zero)), null);
    }
    // A list row's swipe action, revealed by a --drag before: by its id or
    // label (`--tap delete`, `--tap Delete`), or under its row
    // (`--tap ListRow1#0/delete`).
    if (box == null && part == null) {
      final cut = id.lastIndexOf('/');
      final name = id.substring(cut + 1);
      final row = cut < 0 ? null : _locate(binding, id.substring(0, cut)).box;
      final actions = [
        for (final e in find.byWidgetPredicate((w) => w.key is ValueKey<(String, String, String)>).evaluate())
          if ((e.widget.key! as ValueKey<(String, String, String)>).value case (final marker, final aid, final label)
              when marker == 'Codelessly swipe action' && (aid == name || label == name))
            if (e.renderObject case final RenderBox r when r.attached && r.hasSize && r.size.width > 0)
              if (row == null || _sharesSwipeRow(r, row)) r,
      ];
      if (actions.length == 1) return (actions.single.localToGlobal(actions.single.size.center(ui.Offset.zero)), null);
      if (actions.length > 1) {
        return (null, '--$verb $id: ${actions.length} rows show the swipe action "$name": name its row (--$verb <row id>#<n>/$name).');
      }
    }
    if (box == null && part == null && !id.contains('/')) {
      // A tab, segment or destination named by its own id (`--tap stay` for
      // the tab {"id": "stay"}): the part of the one control that has it.
      final owners = <String>{};
      for (final b in _boxes(binding)) {
        final props = (b.node?.toJson()['props'] as Map?) ?? const {};
        for (final key in const ['tabs', 'segments', 'destinations']) {
          final list = props[key];
          if (list is! List) continue;
          final n = list.indexWhere((e) => e is Map && (e['id'] == id || e['value'] == id));
          if (n >= 0) owners.add('${b.id}@$n');
        }
      }
      if (owners.length == 1) return pointAt(owners.single, verb);
      // An option of the open dropdown or menu by its label (`--tap Alaska`).
      final rows = _openMenuRows(binding, id);
      if (rows.isNotEmpty) return (rows.last.localToGlobal(rows.last.size.center(ui.Offset.zero)), null);
      // A line of a menu (or a popover, a dialog) open over the page by the
      // text it shows (`--tap "Leo Marsh"` for a `MenuItem "{a}"` under an
      // each: support desk, test 11): the one line there that is pressed.
      final lines = _overlayLinesByLabel(binding, id);
      if (lines.length == 1) return (lines.single.localToGlobal(lines.single.size.center(ui.Offset.zero)), null);
      if (lines.length > 1) {
        return (null, '--$verb $id: ${lines.length} lines of the overlay open show "$id": give the one meant an id (MenuItem#id "…").');
      }
      // A button of the built-in confirm dialog (`confirmOk`, `confirmCancel`).
      for (final b in _builtIns(binding)) {
        if (b.id == id) return (b.box.localToGlobal(b.box.size.center(ui.Offset.zero)), null);
      }
    }
    if (box == null) {
      return (
        null,
        found.problem!.startsWith(_notShownHere)
            ? '$_notShownHere--$verb $id: ${found.problem!.substring(_notShownHere.length)}.'
            : _withCandidates(binding, id, '--$verb $id: ${found.problem}.'),
      );
    }
    var at = reachable(box);
    if (at == null) {
      await centerInView(box);
      at = reachable(box);
    }
    if (at != null) return (at, null);
    final r = _rectOf(box).intersect(viewRect());
    if (r.isEmpty) return (null, '--$verb $id: the node is outside the screen and nothing scrolls it into view; scroll to it first (--scroll).');
    final over = hitAt(r.center).whereType<NodeBox>().firstOrNull;
    // A node drawn for show inside one that takes the press (a Table's
    // checkbox, `ignorePointer`, in a row that selects): the press lands on
    // the node around it there, as a click on it does in a browser.
    if (over != null && _isInside(box, over) && reactsToTap(hitAt(r.center))) return (r.center, null);
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

  // The text field (a [RenderTextField]) inside node [id].
  RenderTextField? fieldOf(RenderObject box) => box is RenderBox ? textFieldIn(box) : null;

  // The text field [id] names: of two nodes sharing the id (a page's field
  // and a component's heading), the one with a field in it.
  RenderTextField? fieldIn(String id) {
    final box = _locate(binding, id, prefer: (b) => fieldOf(b) != null).box;
    return box == null ? null : fieldOf(box);
  }

  switch (step.kind) {
    case 'tap':
      var (at, problem) = await pointAt(step.target, 'tap');
      if (at == null) return problem;
      if (!reactsToTap(hitAt(at))) {
        // A block called by its id (`DateRangePicker#dates`, a design
        // system's component) whose one tappable part is inside it: that
        // part is meant.
        final named = step.target.contains('@') ? null : _boxOf(binding, step.target);
        final inside = named == null ? const <NodeBox>[] : _tappableInside(binding, named);
        final part = inside.length == 1 ? inside.single : null;
        final there = part == null ? null : (reachable(part) ?? (await centerInView(part).then((_) => reachable(part))));
        if (there != null) {
          at = there;
        } else {
          final c = _candidates(binding, step.target);
          warn('tap_no_reaction',
              '--tap ${step.target}: neither the node nor anything around it reacts to a tap (no "click" reaction, button or input), so the tap did nothing. '
                  '${c.isEmpty ? 'Add {"trigger": "click", "actions": [...]} to the node, or tap the node that has it.' : 'Perhaps: ${c.join(', ')}.'}',
              step.target.split('#').first.split('@').first);
        }
      }
      await _unfocusFieldOutside(tester, _boxOf(binding, step.target.replaceFirst(_partSuffix, '')));
      await tester.tapAt(at);
      return null;
    case 'drag':
      // To a point (dx,dy from where it is pressed) or onto another node.
      // `,hold` after the distance: not let go (see [_held]).
      final hold = RegExp(r',\s*hold\s*$').hasMatch(step.value ?? '');
      final by = RegExp(r'^\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*(?:,\s*hold\s*)?$').firstMatch(step.value ?? '');
      ui.Offset? onto;
      if (by == null) {
        if ((step.value ?? '').trim().isEmpty) return '--drag ${step.target}: say where to: --drag ${step.target}=<dx>,<dy> or --drag ${step.target}=<nodeId>.';
        final (t, problem) = await pointAt(step.value!.trim(), 'drag');
        if (t == null) return problem!.replaceFirst('--drag ', '--drag ${step.target}=');
        onto = t;
      }
      final (from, problem) = await pointAt(step.target, 'drag');
      if (from == null) return problem;
      if (onto != null) onto = (await pointAt(step.value!.trim(), 'drag')).$1 ?? onto;
      final to = onto ?? from + ui.Offset(double.parse(by![1]!), double.parse(by[2]!));
      final source = _boxOf(binding, step.target);
      await _unfocusFieldOutside(tester, source);
      // A drag that starts on a long press (a reorder on touch, a long-press
      // draggable) is held first.
      final held = source != null &&
          find
              .byWidgetPredicate((w) => w is LongPressDraggable || w is ReorderableDelayedDragStartListener)
              .evaluate()
              .any((e) => e.renderObject != null && (_isInside(source, e.renderObject!) || _isInside(e.renderObject!, source)));
      // The tree's own draggable (a render object) holds too on touch.
      bool holds(RenderObject o) => o is RenderDragSource && o.startsOnLongPress;
      var ownHeld = false;
      if (source != null) {
        for (RenderObject? p = source; p != null && !ownHeld; p = p.parent) {
          ownHeld = holds(p);
        }
        ownHeld = ownHeld || _descendants(source).any(holds);
      }
      final g = await tester.startGesture(from);
      if (held || ownHeld) await tester.pump(const Duration(milliseconds: 700));
      // Each move is a frame later than the one before, and says so: a
      // pointer that crosses the distance in a fifth of a second and lifts
      // is a swipe (events with no times have no speed, and no swipe fires).
      const moves = 12;
      for (var i = 1; i <= moves; i++) {
        await g.moveTo(ui.Offset.lerp(from, to, i / moves)!, timeStamp: Duration(milliseconds: 16 * i));
        await tester.pump(const Duration(milliseconds: 16));
      }
      if (hold) {
        _held = g;
        await tester.pump(const Duration(milliseconds: 300));
        return null;
      }
      await g.up(timeStamp: const Duration(milliseconds: 16 * moves));
      return null;
    case 'long-press':
      // A finger (or a mouse button) held on the node past the long-press
      // time, then lifted: a `longPress` reaction, a context menu on touch.
      final (point, problem) = await pointAt(step.target, 'long-press');
      if (point == null) return problem;
      var at = point;
      final pressed = _boxOf(binding, step.target);
      // A control inside the node that acts as a finger lands (a slider
      // takes its value there) would act too: hold where none is.
      bool controlUnder(ui.Offset p) {
        for (final o in hitAt(p)) {
          if (identical(o, pressed)) return false;
          if (o is RenderControl && o.enabled && o.takesInput) return true;
        }
        return false;
      }

      if (pressed != null && controlUnder(at)) {
        final r = _rectOf(pressed).intersect(viewRect());
        search:
        for (var j = 0; j < 5; j++) {
          for (var i = 0; i < 5; i++) {
            final p = ui.Offset(r.left + r.width * (i + 0.5) / 5, r.top + r.height * (j + 0.5) / 5);
            if (hitAt(p).contains(pressed) && !controlUnder(p)) {
              at = p;
              break search;
            }
          }
        }
      }
      // Nothing there reacts to a hold: the tap's reactions run instead, as
      // on a device, and a capture cannot tell the two apart.
      final path = hitAt(at);
      final holds = path.any((o) =>
          (o is RenderReactions && o.triggers.intersection(const {api.TriggerType.longPress, api.TriggerType.hold}).isNotEmpty) ||
          (o is RenderSemanticsGestureHandler && o.onLongPress != null) ||
          (o is RenderControl && o.enabled && o.takesInput) ||
          o is RenderEditable);
      if (!holds) {
        warn('long_press_no_reaction',
            '--long-press ${step.target}: nothing at the node reacts to a long press (no "longPress" reaction, onLongPress or menu=), so the hold ends as a tap does: '
                '${reactsToTap(path) ? 'its tap reactions ran' : 'nothing happened'}.',
            step.target.split('#').first);
      }
      await _unfocusFieldOutside(tester, pressed);
      final g = await tester.startGesture(at);
      await tester.pump(const Duration(milliseconds: 700));
      await g.up(timeStamp: const Duration(milliseconds: 700));
      return null;
    case 'right-click':
      // A mouse's secondary button pressed and released on the node: a
      // `secondaryClick` reaction, a context menu on a desktop.
      final (at, problem) = await pointAt(step.target, 'right-click');
      if (at == null) return problem;
      await _unfocusFieldOutside(tester, _boxOf(binding, step.target));
      final mouse = TestPointer(93, PointerDeviceKind.mouse, 93, kSecondaryMouseButton);
      await tester.sendEventToBinding(mouse.hover(at));
      // What the pointer coming over it changed (a hover state that shows a
      // node) is laid out before the press is hit-tested, as a frame comes
      // between the two on a device.
      await tester.pump();
      await tester.sendEventToBinding(mouse.down(at));
      await tester.pump(const Duration(milliseconds: 40));
      await tester.sendEventToBinding(mouse.up());
      await tester.pump();
      await tester.sendEventToBinding(mouse.removePointer(location: at));
      return null;
    case 'double-tap':
      // Two taps in quick succession where the node shows.
      final (at, problem) = await pointAt(step.target, 'double-tap');
      if (at == null) return problem;
      await _unfocusFieldOutside(tester, _boxOf(binding, step.target));
      await tester.tapAt(at);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tapAt(at);
      return null;
    case 'wheel':
      // A mouse wheel turned over the node: dy pixels (negative: away from
      // the user, which zooms in where a wheel zooms), `ctrl+` held with it.
      final m = RegExp(r'^\s*(ctrl\+)?(-?\d+(?:\.\d+)?)\s*$').firstMatch(step.value ?? '');
      if (m == null) return '--wheel ${step.target}=${step.value}: say how far: --wheel ${step.target}=-240 (pixels; negative is away from the user), or =ctrl+-240 with Control held.';
      final (at, problem) = await pointAt(step.target, 'wheel');
      if (at == null) return problem;
      final wheel = TestPointer(90, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(wheel.hover(at));
      if (m[1] != null) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendEventToBinding(wheel.scroll(ui.Offset(0, double.parse(m[2]!))));
      await tester.pump();
      if (m[1] != null) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendEventToBinding(wheel.removePointer(location: at));
      return null;
    case 'pinch':
      // Two fingers 80 px apart about the node's point, spread (or closed) to
      // 80 px times the scale.
      final scale = double.tryParse((step.value ?? '').trim());
      if (scale == null || scale <= 0) return '--pinch ${step.target}=${step.value}: say by how much: --pinch ${step.target}=2 (fingers twice as far apart; 0.5 closes them).';
      final (at, problem) = await pointAt(step.target, 'pinch');
      if (at == null) return problem;
      const half = ui.Offset(40, 0);
      final a = await tester.startGesture(at - half, pointer: 91);
      final b = await tester.startGesture(at + half, pointer: 92);
      await tester.pump();
      const moves = 12;
      for (var i = 1; i <= moves; i++) {
        final by = half * (1 + (scale - 1) * i / moves);
        await a.moveTo(at - by);
        await b.moveTo(at + by);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await a.up();
      await b.up();
      return null;
    case 'hover':
      final (at, problem) = await pointAt(step.target, 'hover');
      if (at == null) return problem;
      // One mouse per capture: a later hover moves it on.
      var g = _mouse;
      if (g == null) {
        g = _mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await g.addPointer(location: ui.Offset.zero);
      }
      await g.moveTo(at);
      return null;
    case 'focus' || 'type':
      final verb = step.kind;
      var target = step.target;
      var field = fieldIn(target);
      // A field named under its block (`quiz/field` for the one field of the
      // TypedAnswer `quiz`): the block's one text field.
      if (field == null && target.contains('/') && _locate(binding, target).box == null) {
        final block = _locate(binding, target.substring(0, target.lastIndexOf('/'))).box;
        final fields = block == null ? const <RenderTextField>[] : _descendants(block).whereType<RenderTextField>().toList();
        if (fields.length == 1) {
          target = target.substring(0, target.lastIndexOf('/'));
          field = fieldIn(target);
        }
      }
      if (field == null) {
        final found = _locate(binding, step.target);
        if (found.box == null) {
          final p = found.problem!;
          return p.startsWith(_notShownHere)
              ? '$_notShownHere--$verb ${step.target}: ${p.substring(_notShownHere.length)}.'
              : _withCandidates(binding, step.target, '--$verb ${step.target}: $p.');
        }
        // Not a text field: the keyboard focus goes to the control or press
        // target in the node (a button, a row with a tap reaction, a reorder
        // handle, a tab), as Tab would put it there.
        if (verb == 'focus') {
          final box = found.box!;
          final problem = _focusIn(box);
          if (problem != null) return '--focus ${step.target}: $problem';
          if (reachable(box) == null) await centerInView(box);
          await tester.pump();
          return null;
        }
        return _withCandidates(binding, step.target,
            '--$verb ${step.target}: the node has no text field in it (only a textField, or a node around one, can be typed into).');
      }
      final box = _locate(binding, target, prefer: (b) => fieldOf(b) != null).box!;
      if (reachable(box) == null) await centerInView(box);
      field.requestFocus();
      await tester.pump();
      if (verb == 'type') {
        field = fieldIn(target);
        if (field == null) return '--type ${step.target}: the text field went away when it was focused.';
        if (!field.focusNode.hasFocus) field.requestFocus();
        tester.testTextInput.enterText(step.value ?? '');
        await tester.pump();
      }
      return null;
    case 'set':
      _writeVariable(binding, controller, step.target, _stepValue(step));
      return null;
    case 'scroll':
      // One offset (along the way the node scrolls), or `x,y` (the
      // horizontal offset and the vertical one: `--scroll reading=0,650`).
      final amount = RegExp(r'^\s*(-?\d+(?:\.\d+)?)\s*(?:,\s*(-?\d+(?:\.\d+)?)\s*)?$').firstMatch(step.value ?? '');
      if (amount == null) {
        return '--scroll ${step.target}=${step.value}: say how far: one offset in pixels (--scroll ${step.target}=650, along the way it scrolls), '
            'or x,y (--scroll ${step.target}=0,650).';
      }
      final one = amount[2] == null ? double.parse(amount[1]!) : null;
      final x = amount[2] == null ? null : double.parse(amount[1]!), y = amount[2] == null ? null : double.parse(amount[2]!);
      // The offset for a scroll view along [axis].
      double? along(Axis axis) => one ?? (axis == Axis.vertical ? y : x);
      if (step.target == 'screen' || step.target.isEmpty) {
        final page = _pageScroll(binding);
        if (page == null) {
          // A page that fits its window: nothing to scroll, nothing wrong.
          warn('scroll_nothing',
              '--scroll ${step.target}=${step.value}: nothing on the screen scrolls (the page fits the window at this size), so the step did nothing.', null);
          return null;
        }
        page.jumpTo(along(page.axis)!);
        return null;
      }
      final found = _locate(binding, step.target);
      final b = found.box;
      if (b == null) {
        return found.problem!.startsWith(_notShownHere)
            ? '$_notShownHere--scroll ${step.target}: ${found.problem!.substring(_notShownHere.length)}.'
            : _withCandidates(binding, step.target, '--scroll ${step.target}: ${found.problem}.');
      }
      final scrolls = _descendants(b).whereType<RenderDesignScroll>().toList();
      if (scrolls.isNotEmpty) {
        // With x,y: the first that scrolls each way; one offset: the first.
        final targets = one != null
            ? [scrolls.first]
            : [
                if (scrolls.where((s) => s.axis == Axis.horizontal).firstOrNull case final h? when x != 0 || !scrolls.any((s) => s.axis == Axis.vertical)) h,
                if (scrolls.where((s) => s.axis == Axis.vertical).firstOrNull case final v?) v,
              ];
        for (final s in targets) {
          s.jumpTo(along(s.axis)!);
        }
        return null;
      }
      // A list or other Flutter scrollable inside the node.
      final positions = [
        for (final e in find.byType(Scrollable).evaluate())
          if ((e.renderObject as RenderBox?) != null && _isInside(e.renderObject!, b)) (e as StatefulElement).state as ScrollableState,
      ];
      if (positions.isEmpty) return '--scroll ${step.target}: the node does not scroll (set props.scrollable: true).';
      final position = positions.first.position;
      position.jumpTo(along(axisDirectionToAxis(position.axisDirection))!);
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
      await _unfocusFieldOutside(tester, null);
      unawaited(navigator.currentState!.push(route));
      return null;
    case 'wait':
      final ms = int.tryParse(step.target) ?? 0;
      await tester.pump(Duration(milliseconds: ms));
      return null;
    case 'unfocus':
      final field = RenderTextField.focused;
      final focused = FocusManager.instance.primaryFocus;
      if (field == null && (focused == null || focused.context == null)) return null;
      field?.focusNode.unfocus();
      if (focused?.context != null) focused!.unfocus();
      tester.testTextInput.hide();
      await tester.pump();
      return null;
    case 'key':
      // `ctrl+k`, `?`, `+` and `ctrl++` (the key `+` after its modifiers).
      final spec = step.target.trim();
      final plus = spec == '+' || spec.endsWith('++');
      final parts = [
        ...(plus ? spec.substring(0, spec.length - 1) : spec).split('+').map((p) => p.trim()).where((p) => p.isNotEmpty),
        if (plus) '+',
      ];
      if (parts.isEmpty) return '--key: name a key (ArrowRight, Enter, Escape, Tab, shift+Tab...).';
      final named = _keyNamed(parts.last);
      if (named == null) {
        return '--key ${step.target}: "${parts.last}" is not a key the command knows. Keys: ${_keyNames.keys.join(', ')}, F1 to F24, '
            'a letter, a digit or a printable character (/, ?, [...); modifiers: shift, ctrl, alt, meta, mod (ctrl, or meta on a Mac).';
      }
      final key = named.key;
      final modifiers = <LogicalKeyboardKey>[];
      for (final m in parts.take(parts.length - 1)) {
        final k = switch (m.toLowerCase()) {
          'shift' => LogicalKeyboardKey.shiftLeft,
          'ctrl' || 'control' => LogicalKeyboardKey.controlLeft,
          'alt' || 'option' => LogicalKeyboardKey.altLeft,
          'meta' || 'cmd' || 'command' => LogicalKeyboardKey.metaLeft,
          // The notation's mod: Command on a Mac, Control elsewhere.
          'mod' => defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.iOS
              ? LogicalKeyboardKey.metaLeft
              : LogicalKeyboardKey.controlLeft,
          _ => null,
        };
        if (k == null) return '--key ${step.target}: "$m" is not a modifier (shift, ctrl, alt, meta, mod).';
        if (!modifiers.contains(k)) modifiers.add(k);
      }
      // A character typed with Shift on a US keyboard (`?` is Shift+/).
      if (named.shifted && !modifiers.contains(LogicalKeyboardKey.shiftLeft)) modifiers.insert(0, LogicalKeyboardKey.shiftLeft);
      final shift = modifiers.contains(LogicalKeyboardKey.shiftLeft);
      final character = named.character == null
          ? null
          : shift && !named.shifted
              ? named.character!.toUpperCase()
              : named.character;
      // Enter in a text field connected to the platform's text input is
      // the input's to act on (a field leaves it alone: an IME may be
      // composing): the platform sends the field its action key (Done, Go,
      // Search: the field's `submitted` reactions) or types the new line.
      // The test's text input does neither by itself, so the step does.
      final typing = RenderTextField.focused;
      if (modifiers.every((m) => m == LogicalKeyboardKey.shiftLeft) &&
          (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) &&
          typing != null &&
          typing.attached &&
          typing.focusNode.hasFocus &&
          typing.editor.hasConnection) {
        final action = typing.editor.inputAction ?? (typing.config.oneLine ? TextInputAction.done : TextInputAction.newline);
        if (!typing.config.oneLine && (action == TextInputAction.newline || modifiers.isNotEmpty)) {
          final v = typing.editor.value;
          final at = v.selection.isValid ? v.selection : TextSelection.collapsed(offset: v.text.length);
          final text = v.text.replaceRange(at.start, at.end, String.fromCharCode(10));
          tester.testTextInput.updateEditingValue(TextEditingValue(text: text, selection: TextSelection.collapsed(offset: at.start + 1)));
        } else {
          await tester.testTextInput.receiveAction(action);
        }
        await tester.pump();
        return null;
      }
      // A character key in a focused text field types it, as the device's
      // keyboard does through the platform's text input (which a key event
      // alone does not reach in a test): `--key o` writes an o.
      if (character != null &&
          modifiers.every((m) => m == LogicalKeyboardKey.shiftLeft) &&
          typing != null &&
          typing.attached &&
          typing.focusNode.hasFocus &&
          typing.editor.hasConnection) {
        final v = typing.editor.value;
        final at = v.selection.isValid ? v.selection : TextSelection.collapsed(offset: v.text.length);
        tester.testTextInput.updateEditingValue(
            TextEditingValue(text: v.text.replaceRange(at.start, at.end, character), selection: TextSelection.collapsed(offset: at.start + character.length)));
        await tester.pump();
        return null;
      }
      for (final m in modifiers) {
        await tester.sendKeyDownEvent(m);
      }
      await tester.sendKeyEvent(key, character: character);
      for (final m in modifiers.reversed) {
        await tester.sendKeyUpEvent(m);
      }
      await tester.pump();
      return null;
  }
  return 'Unknown step ${step.kind}.';
}

/// The first render object of type [T] in [box] (it or under it).
T? _firstIn<T>(RenderObject box) {
  T? found;
  void visit(RenderObject o) {
    if (found != null) return;
    if (o is T) {
      found = o as T;
      return;
    }
    o.visitChildren(visit);
  }

  visit(box);
  return found;
}

/// The rows of the dropdowns and menus open on screen, in paint order;
/// with [label], those whose label is it (letter case aside).
List<RenderMenuRow> _openMenuRows(WidgetsBinding binding, String? label) {
  final want = label?.trim().toLowerCase();
  return [
    for (final view in binding.renderViews)
      for (final o in _descendants(view, skip: _offstage()))
        if (o is RenderMenu && o.attached && o.hasSize)
          for (final r in o.rows)
            if (r.attached && r.hasSize && !r.size.isEmpty && (want == null || r.item.label.trim().toLowerCase() == want)) r,
  ];
}

/// The lines of the overlay that holds the keyboard ([ControlFocusLayer.top]:
/// a menu, a popover, a dialog open over the page) that are pressed (a click
/// reaction) and show [label] first (letter case aside), innermost first:
/// a menu's items by what they say.
List<NodeBox> _overlayLinesByLabel(WidgetsBinding binding, String label) {
  final top = ControlFocusLayer.top;
  if (top == null) return const [];
  final want = label.trim().toLowerCase();
  bool onTop(NodeBox b) {
    for (RenderObject? at = b; at != null; at = at.parent) {
      if (at is RenderControlRoot) return identical(at.focus.layer, top);
    }
    return false;
  }

  final found = [
    for (final b in _boxes(binding))
      if (_shown(b) &&
          (b.node?.actions.any((r) => r.trigger.type == api.TriggerType.click) ?? false) &&
          firstTextUnder(b)?.toLowerCase() == want &&
          onTop(b))
        b,
  ];
  // A pressed line inside another pressed line: the inner one, once.
  return [for (final b in found) if (!found.any((o) => !identical(o, b) && _isInside(o, b))) b];
}

/// The parts a step names with `@` on the control drawn in node box [b]
/// (not those of the nodes inside it): what `--dump-layout` lists as
/// `parts`. Empty when it has none.
List<String> _partNames(NodeBox b) {
  RenderObject? control;
  void visit(RenderObject o) {
    if (control != null || (o is NodeBox && !identical(o, b))) return;
    if (o is RenderItemBar || o is RenderSegmentedButton || o is RenderTextField || o is RenderSlider || o is RenderDropdown || (o is RenderCalendar && o.inline)) {
      control = o;
      return;
    }
    o.visitChildren(visit);
  }

  visit(b);
  return switch (control) {
    final RenderItemBar bar => [for (var i = 0; i < bar.itemRects.length; i++) '@$i'],
    final RenderSegmentedButton s => [for (var i = 0; i < s.segmentRects.length; i++) '@$i'],
    final RenderTextField f when f.decoration.prefix?.button ?? false => const ['@decrement', '@increment'],
    final RenderSlider s => s.isRange ? const ['@thumb', '@thumb-end'] : const ['@thumb'],
    final RenderDropdown d => [for (final l in d.spec.labels) '@option:$l'],
    RenderCalendar() => const ['@<yyyy-MM-dd>'],
    _ => const [],
  };
}

/// Puts the keyboard focus on the first control or press target inside
/// [box] (in Tab's order), with its focus ring, as the keyboard brings it:
/// null, or why it could not (naming the nearest node that can take it).
String? _focusIn(NodeBox box) {
  final scope = RenderControlRoot.of(box)?.focus;
  if (scope == null) return 'the node is in no screen that takes keys.';
  final order = scope.order;
  NodeBox? nodeOf(ControlFocusNode n) {
    for (RenderObject? p = n.owner; p != null; p = p.parent) {
      if (p is NodeBox) return p;
    }
    return null;
  }

  for (final n in order) {
    if (identical(n.owner, box) || _isInside(n.owner, box)) {
      if (n.requestFocus(highlight: true)) return null;
    }
  }
  // Around it (a row whose label was named), else the nearest on screen.
  String name(NodeBox b) => b.tree.pathOf(b.id, b.instance);
  final around = [
    for (final n in order)
      if (nodeOf(n) case final NodeBox b when _isInside(box, b) && !identical(b, box)) b,
  ];
  final at = _rectOf(box).center;
  final near = [
    for (final n in order)
      if (nodeOf(n) case final NodeBox b) (b, (_rectOf(b).center - at).distance),
  ]..sort((a, b) => a.$2.compareTo(b.$2));
  final names = <String>{
    if (around.isNotEmpty) name(around.last),
    for (final (b, _) in near.take(3)) name(b),
  };
  return 'the node cannot take the keyboard focus: it is no control, text field or node with a tap reaction, and has none inside it'
      '${names.isEmpty ? ' (nothing on the screen can).' : '. Nearest that can: ${names.join(', ')}.'}';
}

/// Whether the revealed swipe [action] belongs to the row [row] (or a node
/// in it): the stack that lays the action under the row holds both.
bool _sharesSwipeRow(RenderObject action, RenderObject row) {
  for (RenderObject? p = action.parent; p != null; p = p.parent) {
    if (p is RenderStack) return _isInside(row, p);
  }
  return false;
}

/// Takes the focus from a text field before a step acts elsewhere (a tap,
/// a drag, a navigation), as a click outside a field does in a browser: its
/// blur reactions run first, and nothing is left holding a field the step
/// removes (a form a submit hides). A step on the field itself keeps it.
Future<void> _unfocusFieldOutside(WidgetTester tester, NodeBox? target) async {
  final field = RenderTextField.focused;
  if (field == null) return;
  if (target != null && _isInside(field, target)) return;
  field.focusNode.unfocus();
  tester.testTextInput.hide();
  await tester.pump();
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

/// The printable characters of a US keyboard: the key that types each, and
/// whether Shift is held for it (`?` is Shift+/).
const _characterKeys = <String, (LogicalKeyboardKey, bool)>{
  '/': (LogicalKeyboardKey.slash, false), '?': (LogicalKeyboardKey.slash, true),
  '.': (LogicalKeyboardKey.period, false), '>': (LogicalKeyboardKey.period, true),
  ',': (LogicalKeyboardKey.comma, false), '<': (LogicalKeyboardKey.comma, true),
  ';': (LogicalKeyboardKey.semicolon, false), ':': (LogicalKeyboardKey.semicolon, true),
  "'": (LogicalKeyboardKey.quote, false), '"': (LogicalKeyboardKey.quote, true),
  '[': (LogicalKeyboardKey.bracketLeft, false), '{': (LogicalKeyboardKey.bracketLeft, true),
  ']': (LogicalKeyboardKey.bracketRight, false), '}': (LogicalKeyboardKey.bracketRight, true),
  '\\': (LogicalKeyboardKey.backslash, false), '|': (LogicalKeyboardKey.backslash, true),
  '-': (LogicalKeyboardKey.minus, false), '_': (LogicalKeyboardKey.minus, true),
  '=': (LogicalKeyboardKey.equal, false), '+': (LogicalKeyboardKey.equal, true),
  '`': (LogicalKeyboardKey.backquote, false), '~': (LogicalKeyboardKey.backquote, true),
  '!': (LogicalKeyboardKey.digit1, true), '@': (LogicalKeyboardKey.digit2, true), '#': (LogicalKeyboardKey.digit3, true),
  r'$': (LogicalKeyboardKey.digit4, true), '%': (LogicalKeyboardKey.digit5, true), '^': (LogicalKeyboardKey.digit6, true),
  '&': (LogicalKeyboardKey.digit7, true), '*': (LogicalKeyboardKey.digit8, true), '(': (LogicalKeyboardKey.digit9, true),
  ')': (LogicalKeyboardKey.digit0, true),
};

/// The key named [name] (as the web's `KeyboardEvent.key`: `ArrowRight`,
/// `Enter`, `F2`; any case), a letter, a digit or a printable character:
/// the key, the character it types (null: none) and whether Shift types it.
({LogicalKeyboardKey key, String? character, bool shifted})? _keyNamed(String name) {
  for (final e in _keyNames.entries) {
    if (e.key.toLowerCase() == name.toLowerCase() || (name.toLowerCase() == 'esc' && e.key == 'Escape')) {
      return (key: e.value, character: e.value == LogicalKeyboardKey.space ? ' ' : null, shifted: false);
    }
  }
  if (RegExp(r'^[A-Za-z]$').hasMatch(name)) {
    final c = name.toLowerCase();
    return (key: LogicalKeyboardKey(LogicalKeyboardKey.keyA.keyId + c.codeUnitAt(0) - 0x61), character: c, shifted: false);
  }
  if (RegExp(r'^[0-9]$').hasMatch(name)) {
    return (key: LogicalKeyboardKey(LogicalKeyboardKey.digit0.keyId + name.codeUnitAt(0) - 0x30), character: name, shifted: false);
  }
  final f = RegExp(r'^[Ff]([1-9]|1[0-9]|2[0-4])$').firstMatch(name);
  if (f != null) return (key: LogicalKeyboardKey(LogicalKeyboardKey.f1.keyId + int.parse(f[1]!) - 1), character: null, shifted: false);
  if (_characterKeys[name] case (final key, final shifted)) return (key: key, character: name, shifted: shifted);
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
    var fam = (family == null || family.isEmpty) ? 'Roboto' : family;
    if (monospaceFamilies.contains(fam.toLowerCase()) && DirectoryFontFetcher(faces).match(fam, 400, false) == null) fam = 'Roboto Mono';
    // The file the fetcher serves for the family's regular face.
    final face = DirectoryFontFetcher(faces).match(fam, 400, false);
    final used = face != null && face.family.toLowerCase() == fam.toLowerCase()
        ? face
        : faces.where((f) => f.family == 'Roboto' && !f.italic).firstOrNull;
    if (used == null) return null;
    final own = _coverage.putIfAbsent(used.path, () => fontCoverage(used.path));
    // What the symbol font every style falls back to draws.
    final symbols = FontDemand.symbolFallback.isEmpty ? null : systemSymbolFont();
    if (symbols == null || own == null) return own;
    return _coverage.putIfAbsent('${used.path}+$symbols', () => {...own, ...?fontCoverage(symbols)});
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
    final file = component == null ? fileOfNode[_canvasOf(b) ?? b.id] ?? fileOfNode[b.id] : fileOfComponent(component.component);
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
    // A collapsed accordion or expansion tile clips its content by design.
    final collapses = parent?.type == 'accordion' || parent?.type == 'expansionTile';
    if (parentBox != null && parent != null && parent.type != 'canvas' && parent.type != 'stack' && !collapses && !seen.isEmpty) {
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
    // A control's own label (a button's "←"): its font may lack a glyph too.
    if (node.type != 'text' && b.drawn) {
      final missing = <String>{};
      void visit(RenderObject o) {
        if (o is NodeBox && !identical(o, b)) return;
        if (o is LabeledControl) {
          for (final l in o.labels) {
            final cov = coverage(l.fontFamily);
            if (cov == null) continue;
            for (final r in l.text.runes) {
              if (r > 0x20 && r != 0xA0 && !cov.contains(r)) missing.add(String.fromCharCode(r));
            }
          }
        }
        o.visitChildren(visit);
      }

      visit(b);
      if (missing.isNotEmpty) {
        out.add(RuntimeIssue('missing_glyph', 'warning',
            'The ${node.type} "${nameOf(b)}" shows ${missing.map((c) => '"$c" (U+${c.runes.first.toRadixString(16).toUpperCase().padLeft(4, '0')})').join(', ')} in its label, which its font has no glyph for: drawn as an empty box. '
            'Use a character the font has, or an icon (an IconButton, or the button\'s icon).',
            nodeId: nameOf(b), screen: screen, size: size, file: file));
      }
    }
    if (node.type == 'text') {
      final p = _descendants(b).whereType<RenderParagraph>().firstOrNull;
      if (p == null || !p.hasSize) continue;
      final text = p.text.toPlainText();
      if (text.trim().isEmpty) continue;
      final short = text.length > 30 ? '${text.substring(0, 30)}...' : text;
      // The checks a session runs on what it shows (shared: paragraphIssues).
      for (final i in paragraphIssues(p, nameOf(b))) {
        out.add(RuntimeIssue(i.code, 'warning', i.message, nodeId: nameOf(b), screen: screen, size: size, file: file));
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
      final cut = node.prop(api.TextProps.overflow) != api.TextOverflow.clip;
      if (p.didExceedMaxLines && !cut) {
        out.add(RuntimeIssue('text_truncated', 'warning', 'Text "${nameOf(b)}" ("$short") is cut at maxLines: set "overflow": "ellipsis" if that is meant, or give it more lines.',
            nodeId: nameOf(b), screen: screen, size: size, file: file));
      }
      // A text whose longest word is wider than its box is drawn smaller,
      // then cut at the box's edge (RenderWholeWords): said as what it is.
      final whole = _descendants(b).whereType<RenderWholeWords>().firstOrNull;
      if (whole != null && (whole.scale < 1 || whole.clips)) {
        final word = p.getMinIntrinsicWidth(double.infinity);
        out.add(RuntimeIssue('text_clipped', 'warning',
            'Text "${nameOf(b)}" ("$short") has a word ${word.toStringAsFixed(0)} px wide in a box ${b.size.width.toStringAsFixed(0)} wide: '
            '${whole.clips ? 'it is drawn at ${(whole.scale * 100).round()} % of its size and still cut at the box\'s edge' : 'the text is drawn at ${(whole.scale * 100).round()} % of its size so that the word fits'}. '
            'Give the text more width (a fill or larger width) or a smaller font size.',
            nodeId: nameOf(b), screen: screen, size: size, file: file));
        continue;
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

/// The built-in confirm dialog's buttons are the SDK's widgets, not nodes:
/// steps (`--tap confirmOk`) and the layout name them by these ids.
const _builtInTargets = {
  'confirmOk': ValueKey<String>('codelessly-confirm-ok'),
  'confirmCancel': ValueKey<String>('codelessly-confirm-cancel'),
};

/// Each built-in target on screen: its id, its element and its box.
List<({String id, Element element, RenderBox box})> _builtIns(WidgetsBinding binding) {
  final out = <({String id, Element element, RenderBox box})>[];
  void visit(Element e) {
    final key = e.widget.key;
    for (final t in _builtInTargets.entries) {
      if (key != t.value) continue;
      if (e.renderObject case final RenderBox box when box.attached && box.hasSize) out.add((id: t.key, element: e, box: box));
    }
    e.visitChildren(visit);
  }

  binding.rootElement?.visitChildren(visit);
  return out;
}

/// The text the first paragraph under [box] draws (a button's label).
String? _paragraphText(RenderObject box) {
  String? text;
  void visit(RenderObject o) {
    if (text != null) return;
    if (o is RenderParagraph) {
      text = o.text.toPlainText();
    } else {
      o.visitChildren(visit);
    }
  }

  visit(box);
  return text;
}

/// The built-in target that has the keyboard focus, if one has.
({String id, Element element, RenderBox box})? _focusedBuiltIn(WidgetsBinding binding) {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null) return null;
  for (final b in _builtIns(binding)) {
    if (identical(focused, b.element)) return b;
    var inside = false;
    focused.visitAncestorElements((a) => !(inside = identical(a, b.element)));
    if (inside) return b;
  }
  return null;
}

/// The node box that holds the keyboard focus (the box around the focused
/// control or press target); null: nothing has it.
NodeBox? _focusedBox() {
  final node = ControlFocusScope.focusedScope?.focused;
  if (node == null || !node.owner.attached) return null;
  for (RenderObject? p = node.owner; p != null; p = p.parent) {
    if (p is NodeBox) return p;
  }
  return null;
}

/// Where a run's diagnostics go: `diagnostics.json`, with the screens
/// [screens] names (`--screen`) and the sizes when they are not the default
/// ones, as a PNG names them, then the label: `diagnostics-<label>.json`,
/// `diagnostics-home-<label>.json`, `diagnostics-home@1440x900-<label>.json`,
/// `diagnostics@390x844.json`. Runs of one label on other screens or at other
/// sizes keep each its own.
String diagnosticsFileName(String? label, {List<String> screens = const [], List<ui.Size>? sizes}) {
  final screen = screens.map(_fileSafe).join('+');
  final sized = sizes == null || _sameSizes(sizes, RenderArgs.defaultSizes) ? '' : '@${sizes.map((z) => '${z.width.round()}x${z.height.round()}').join('+')}';
  final where = screen.isEmpty ? sized : '-$screen$sized';
  return 'diagnostics$where${label == null ? '' : '-${_fileSafe(label)}'}.json';
}

bool _sameSizes(List<ui.Size> a, List<ui.Size> b) => a.length == b.length && [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((x) => x);

RenderReport _finish(RenderReport report, RenderArgs args) {
  // Errors first, then warnings; each group in document order.
  report.diagnostics.sort((a, b) => (a['severity'] == 'error' ? 0 : 1).compareTo(b['severity'] == 'error' ? 0 : 1));
  Directory(args.out).createSync(recursive: true);
  File('${args.out}/${diagnosticsFileName(args.label, screens: args.screens, sizes: args.sizes)}').writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
    'errors': report.errors,
    'warnings': report.warnings,
    'images': [for (final i in report.images) i.split('/').last],
    if (report.comparisons.isNotEmpty) 'comparisons': [for (final c in report.comparisons) c.toJson()],
    if (report.downloads.isNotEmpty) 'downloads': report.downloads,
    if (report.clipboard.isNotEmpty) 'clipboard': report.clipboard,
    if (report.focus.isNotEmpty) 'focus': report.focus,
    if (report.announcements.isNotEmpty) 'announcements': report.announcements,
    // A capture named after the screen navigated to: the screen its run
    // started on (what its diagnostics' `screen` says).
    if (report.startedOn.isNotEmpty) 'startedOn': report.startedOn,
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
    b.writeln('        ${d['message']}');
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
  for (final f in report.focus) {
    b.writeln('focus on ${f['path'] ?? f['id']}${f['text'] == null ? '' : ' ${jsonEncode(f['text'])}'}'
        '${f['ring'] == true ? ' (ring shown)' : ' (no ring)'}${f['inOverlay'] == true ? ', in the open overlay' : ''} [screen ${f['screen']} ${f['size']}]');
  }
  for (final a in report.announcements) {
    b.writeln('${a['source'] == 'live' ? 'live region' : 'announced'} ${jsonEncode(a['text'])} (${a['politeness']}) after ${a['after']} [screen ${a['screen']} ${a['size']}]');
  }
  final held = {for (final d in report.diagnostics) if (d['code'] == 'placeholder_word') RegExp(r'^"([^"]+)"').firstMatch('${d['message']}')?[1]};
  b.writeln('${report.errors} error(s), ${report.warnings} warning(s)'
      '${held.isEmpty ? '' : '; ${held.length} placeholder word${held.length == 1 ? '' : 's'} (${held.join(', ')})'}.');
  return b.toString();
}

/// The file node box [b] comes from: its component's for a node inside an
/// instance (ids are local to their document), else its page's.
String? _fileOf(NodeBox b, Map<String, String> fileOfNode, Map<String, api.Json> docs) {
  final c = componentInstanceOf(b.instance);
  if (c == null) return fileOfNode[_canvasOf(b) ?? b.id] ?? fileOfNode[b.id];
  return docs.entries.where((e) => api.readMap(e.value[api.kWidgetKey])?['type'] == c.component).firstOrNull?.key;
}

/// The nodes of [docs] that name each font family (lowercased), as
/// `file:node`: a text style's `fontFamily`, or a named style of [theme]
/// whose family it is.
Map<String, List<String>> _fontUsers(Map<String, api.Json> docs, api.ThemeTokens theme) {
  final out = <String, List<String>>{};
  final styleFamily = {
    for (final k in theme.textStyles.keys)
      if (theme.textStyle(k)?.fontFamily case final String f) k: f,
  };
  for (final d in docs.entries) {
    for (final n in (api.readMap(d.value['nodes']) ?? const {}).entries) {
      final families = <String>{};
      void walk(Object? v) {
        if (v is Map) {
          for (final e in v.entries) {
            if (e.key == 'fontFamily' && e.value is String) families.add(e.value as String);
            if ((e.key == 'style' || e.key == 'from' || e.key.toString().endsWith('Style')) && e.value is String) {
              if (styleFamily[e.value] case final String f) families.add(f);
            }
            walk(e.value);
          }
        } else if (v is List) {
          v.forEach(walk);
        }
      }

      walk(n.value);
      for (final f in families) {
        final list = out.putIfAbsent(f.toLowerCase(), () => []);
        if (!list.contains(n.key)) list.add(n.key);
      }
    }
  }
  return out;
}

/// The text [box] itself draws (not its child nodes'): null for a node that
/// draws none.
String? _shownText(NodeBox box) {
  String? out;
  void visit(RenderObject o) {
    if (out != null || (o is NodeBox && !identical(o, box))) return;
    if (o is RenderParagraph) {
      out = o.text.toPlainText();
      return;
    }
    // A control that draws its own label (a button, a chip) shows it too.
    if (o is LabeledControl) {
      final text = o.labels.map((l) => l.text).where((t) => t.trim().isNotEmpty).join(' ');
      if (text.isNotEmpty) {
        out = text;
        return;
      }
    }
    o.visitChildren(visit);
  }

  visit(box);
  return out;
}

/// The share of [png]'s pixels that are fully transparent, or null when it does not decode.
Future<double?> _transparentShare(List<int> png) async {
  try {
    final codec = await ui.instantiateImageCodec(Uint8List.fromList(png));
    final image = (await codec.getNextFrame()).image;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final total = image.width * image.height;
    image.dispose();
    if (data == null || total == 0) return null;
    final bytes = data.buffer.asUint8List();
    var bare = 0;
    for (var i = 3; i < bytes.length; i += 4) {
      if (bytes[i] == 0) bare++;
    }
    return bare / total;
  } catch (_) {
    return null;
  }
}

/// The words that stood in as placeholders in the site at [siteDir] (a
/// folder with site.json), from the vocabulary record `notation.sh expand`
/// saves beside it (`vocabulary.json` there or in the folder above): each
/// `{word, kind, file, line, node, page, signature, record}`. Empty when
/// there is no record.
List<api.Json> sitePlaceholders(String siteDir) {
  for (final path in ['$siteDir/vocabulary.json', '${Directory(siteDir).absolute.parent.path}/vocabulary.json']) {
    final f = File(path);
    if (!f.existsSync()) continue;
    try {
      final j = jsonDecode(f.readAsStringSync());
      if (j is! Map || j['record'] != 'codelessly notation vocabulary record') continue;
      return [
        for (final p in (j['placeholders'] as List?) ?? const [])
          if (p is Map) {...p.cast<String, Object?>(), 'record': path.replaceAll(r'\', '/')},
      ];
    } on FormatException {
      continue;
    }
  }
  return const [];
}
