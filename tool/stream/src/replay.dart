// Replays a recorded ui_apply stream through UiSession.applyStream on a
// virtual clock, headless (the render command's harness: real fonts from
// files, PNG captures of a RepaintBoundary), and writes the frames, a
// frames.json for the overlay and video, and metrics.json.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_api/validate.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/paint/icon_glyph.dart' show IconSources;
import 'package:codelessly_sdk/src/scripting/sandbox/quickjs_sandbox.dart' show QuickJsLibrary;
import 'package:flutter/material.dart' hide Page, Step; // ignore: deprecated_member_use
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';

import '../../render/src/fonts.dart';
import '../../render/src/prepare.dart';
import 'interact.dart';

/// One recorded stream: its meta line and its timed deltas.
class RecordedStream {
  RecordedStream(this.meta, this.deltas);
  final Map<String, Object?> meta;
  final List<({int tMs, String delta})> deltas;

  static RecordedStream read(String path) {
    final lines = File(path).readAsLinesSync().where((l) => l.trim().isNotEmpty).toList();
    final meta = (jsonDecode(lines.first) as Map)['meta'] as Map<String, Object?>;
    return RecordedStream(meta, [
      for (final l in lines.skip(1))
        if (jsonDecode(l) case final Map m when m['delta'] is String) (tMs: (m['tMs'] as num).round(), delta: m['delta'] as String),
    ]);
  }

  String get text => deltas.map((d) => d.delta).join();
}

class ReplayArgs {
  ReplayArgs(
      {required this.stream,
      required this.out,
      required this.sizes,
      this.fontDirs = const [],
      this.frameMs,
      this.frames,
      this.designSystem,
      this.dark = false,
      this.dumpDocument = false});
  final String stream;
  final String out;
  final List<ui.Size> sizes;
  final List<String> fontDirs;

  /// The design system to replay with: an id (a folder of the SDK's
  /// `design_systems/`) or a design system folder. Null: the one the
  /// recording's meta names (`designSystem.id`), else none.
  final String? designSystem;

  /// Whether the UI is shown in its theme's dark mode (light by default).
  final bool dark;

  /// Whether to write the document the session held when the stream ended
  /// (`document.json`, before any scripted interaction) and the state its
  /// views showed (`state.json`: `UiSession.values`), next to the
  /// metrics. Off by default.
  final bool dumpDocument;

  /// Virtual ms between captures (null: the stream's length / [frames]).
  final int? frameMs;
  final int? frames;
}

/// The design system [idOrPath] names: a design system folder, or an id
/// looked up in the SDK's `design_systems/` (the working directory is the
/// SDK's root under `flutter test`).
Future<api.DesignSystem> loadDesignSystem(String idOrPath) async {
  final dir = [idOrPath, 'design_systems/$idOrPath']
      .where((d) => File('$d/${api.DesignSystemManifest.fileName}').existsSync())
      .firstOrNull;
  if (dir == null) throw StateError('No design system "$idOrPath" (a folder with ${api.DesignSystemManifest.fileName}, or an id in design_systems/).');
  final problems = <String>[];
  final ds = await api.DesignSystem.load((ref) async {
    final f = File('$dir/$ref');
    return f.existsSync() ? f.readAsStringSync() : null;
  }, problems: problems);
  if (problems.isNotEmpty) throw StateError('The design system at $dir does not load cleanly: ${problems.join('; ')}');
  return ds;
}

/// The design system a replay of [stream] uses: [arg] when given, else the
/// one its meta names.
String? designSystemOf(RecordedStream stream, String? arg) =>
    arg ?? switch (stream.meta['designSystem']) { final Map m => m['id'] as String?, final String s => s, _ => null };

/// Replays [args.stream] at each size; returns the metrics by size.
Future<Map<String, Object?>> runReplay(WidgetTester tester, ReplayArgs args) async {
  final stream = RecordedStream.read(args.stream);
  final dsName = designSystemOf(stream, args.designSystem);
  final ds = dsName == null ? null : (await tester.runAsync(() => loadDesignSystem(dsName)))!;
  final dir = File(args.stream).parent.path;
  final root = Platform.environment['FLUTTER_ROOT'] ?? '';
  final codepoints = materialCodepoints(root);
  final faces = [...defaultFonts(root), ...scanFonts(args.fontDirs)];
  // The UI a follow-up (or retry) edits: the streams before it, in order.
  final bases = [
    for (final b in switch (stream.meta['base']) { final String s => [s], final List l => l, _ => const [] })
      RecordedStream.read('$dir/$b'),
  ];

  final families = <String>{'Roboto', 'Material Icons'};
  // The families the UI names, and those of the design system's tokens and
  // components.
  final dsText = ds == null ? '' : jsonEncode(ds.toJson());
  for (final m in RegExp(r'"fontFamily":\s*"([^"]+)"').allMatches('${bases.map((b) => b.text).join()}${stream.text}$dsText')) {
    families.add(m[1]!);
  }
  await tester.runAsync(() async {
    for (final family in families) {
      var files = [for (final f in faces) if (f.family == family) f.path];
      // A family no file provides is drawn with Roboto, as the render
      // command substitutes it (not the test font's boxes).
      if (files.isEmpty) files = [for (final f in faces) if (f.family == 'Roboto') f.path];
      if (files.isEmpty) continue;
      final loader = FontLoader(family == 'Material Icons' ? 'MaterialIcons' : family);
      for (final p in files) {
        loader.addFont(Future.value(File(p).readAsBytesSync().buffer.asByteData()));
      }
      await loader.load();
    }
  });
  IconSources.codepointOf = (name, style) => codepoints[style == 'filled' ? '${name}_baseline' : '${name}_$style'] ?? codepoints[name];
  debugDisableShadows = false;
  final assets = stream.meta['assets'] is String ? '${Directory.current.path}/${stream.meta['assets']}' : dir;
  final assetDir = Directory(assets).existsSync() ? Directory(assets).parent.path : dir;
  // What a host does before applying an op: the render command's offline
  // preparation (default font family, icon codepoints, local images as
  // data URLs). The op is otherwise as the model wrote it.
  api.EditOp prepareOp(api.EditOp op) {
    if (op is! api.SetOp) return op;
    final p = prepare({
      'nodes': {op.id: op.node},
    }, dir: assetDir, defaultFamily: 'Roboto', codepoints: codepoints);
    final node = api.readMap(api.readMap(p.json['nodes'])?[op.id]);
    return node == null ? op : api.SetOp(op.id, node, parent: op.parent, index: op.index, slot: op.slot, placeholders: op.placeholders);
  }

  // What the loaded fonts can draw (a family no file has is drawn with
  // Roboto): the session reports text they cannot (missing_glyph).
  final coverage = <String, Set<int>>{};
  Set<int> covered(String family) => coverage[family] ??= () {
        var files = [for (final f in faces) if (f.family == family) f.path];
        if (files.isEmpty) files = [for (final f in faces) if (f.family == 'Roboto') f.path];
        return {for (final p in files.take(2)) ...api.fontCodepoints(File(p).readAsBytesSync())};
      }();
  bool glyphs(String? family, int cp) => covered(family ?? 'Roboto').contains(cp);
  final results = <String, Object?>{};
  try {
    for (final size in args.sizes) {
      results['${size.width.round()}x${size.height.round()}'] = await _replayAt(tester, stream, bases, size, args, prepareOp, glyphs, ds);
    }
  } finally {
    debugDisableShadows = true;
    IconSources.codepointOf = null;
    NodeBox.debugCountApplies = false;
    NodeBox.debugApplyCounts.clear();
  }
  tester.view.reset();
  return results;
}

Future<Map<String, Object?>> _replayAt(WidgetTester tester, RecordedStream stream, List<RecordedStream> bases, ui.Size size, ReplayArgs args,
    api.EditOp Function(api.EditOp) prepareOp, api.GlyphCoverage glyphs, api.DesignSystem? ds) async {
  final sizeName = '${size.width.round()}x${size.height.round()}';
  final out = Directory('${args.out}/$sizeName')..createSync(recursive: true);
  final framesDir = Directory('${out.path}/frames')..createSync(recursive: true);
  for (final f in framesDir.listSync()) {
    f.deleteSync();
  }
  final apps = stream.meta['profile'] == 'agentApps';
  if (apps) ReplayServices.useLocalQuickJs();
  // As the render command does (prepareTheme): the default family is the
  // theme's, so the controls' text is in the family the prepared text nodes
  // name, not the test font's boxes. With a design system, its tokens
  // (their text styles given the family the same way) are the theme, and
  // its components are node types.
  final theme = api.ThemeTokens.fromJson(prepareTheme({
    ...?ds?.tokens.toJson(),
    if (args.dark) 'mode': 'dark',
  }, defaultFamily: 'Roboto'));
  final session = UiSession(
    catalog: api.Catalog.core,
    designSystem: ds,
    profile: apps ? api.TrustProfile.agentApps : api.TrustProfile.agent,
    check: strictEditCheck(ValidateOptions(
      formulas: FormulaEvaluator.report,
      components: ds?.components,
      theme: ds == null ? null : theme,
    )),
    glyphCoverage: glyphs,
    theme: theme,
  );
  final baseRetries = <Map<String, Object?>>[];
  for (final b in bases) {
    // The UI the follow-up edits, as it was when its streams ended.
    final r = await session.applyStream(Stream.value(b.text), map: prepareOp);
    baseRetries.add({'stream': b.meta['turn'], 'applied': r.applied.length, 'rejected': r.rejected.length});
  }
  final kind = stream.meta['kind'] ?? 'page';
  // An app fills the window like a page.
  final card = kind == 'card';
  final boundary = GlobalKey();
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  final prompt = (stream.meta['followup'] ?? stream.meta['prompt'] ?? stream.meta['brief'] ?? '') as String;
  Widget frame(Widget view) => card
      ? ColoredBox(
          color: const Color(0xFFF1F5F9),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 300),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(16)),
                      child: Text(prompt, style: const TextStyle(fontFamily: 'Roboto', fontSize: 14, color: Colors.white, height: 1.35)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  view,
                ]),
              ),
            ),
          ),
        )
      : view;
  await tester.pumpWidget(RepaintBoundary(
    key: boundary,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Roboto'),
      home: Material(
          color: card ? const Color(0xFFF1F5F9) : Colors.white,
          child: frame(CodelesslyView(session: session, services: apps ? const ReplayServices() : null))),
    ),
  ));

  // The clock.
  final deltas = stream.deltas;
  final lastT = deltas.isEmpty ? 0 : deltas.last.tMs;
  final total = lastT + 800;
  final frameMs = args.frameMs ?? math.max(66, (total / (args.frames ?? 180)).ceil());
  final controller = StreamController<String>();
  final times = <({int index, int tMs, int reapplied, int ops, String kind, String? id, bool ok})>[];
  var pendingOps = <StreamProgress>[];
  var chars = 0;
  final totalChars = stream.text.length;
  final outputTokens = (stream.meta['outputTokens'] as num?)?.toDouble() ?? totalChars / 4;
  var now = 0;
  final frames = <Map<String, Object?>>[];
  final pumpMs = <double>[];
  NodeBox.debugCountApplies = true;
  NodeBox.debugApplyCounts.clear();
  final done = session.applyStream(controller.stream, map: prepareOp, onOp: (p) => pendingOps.add(p));
  int? firstPaint, firstText, firstSection, complete;
  String? newest;
  final watch = Stopwatch();
  final errors = <Object>[];

  Future<void> pump(Duration d) async {
    watch
      ..reset()
      ..start();
    await tester.pump(d);
    watch.stop();
    pumpMs.add(watch.elapsedMicroseconds / 1000);
    Object? e;
    while ((e = tester.takeException()) != null) {
      final line = '$e'.split('\n').where((l) => l.trim().isNotEmpty).take(2).join(' ');
      // A flex "overflowed by 1e-7 pixels" is rounding.
      final by = RegExp(r'overflowed by ([0-9.eE+-]+) pixels').firstMatch(line);
      if (by != null && (double.tryParse(by[1]!) ?? 1) < 0.01) continue;
      errors.add({'tMs': now, 'error': line.length > 300 ? line.substring(0, 300) : line});
    }
  }

  void recordOps(int tMs) {
    if (pendingOps.isEmpty) return;
    final reapplied = NodeBox.debugApplyCounts.values.fold<int>(0, (a, b) => a + b);
    NodeBox.debugApplyCounts.clear();
    for (final p in pendingOps) {
      final op = p.op.op;
      final ok = p.result.applied.isNotEmpty;
      times.add((
        index: p.op.index,
        tMs: tMs,
        reapplied: (reapplied / pendingOps.length).round(),
        ops: pendingOps.length,
        kind: op.op,
        id: op is api.SetOp ? op.id : op is api.PatchOp ? op.id : null,
        ok: ok,
      ));
      if (ok && op is api.SetOp) newest = op.id;
    }
    pendingOps = [];
    final doc = session.document;
    final rootId = doc.roots.isEmpty ? null : doc.roots.first;
    // First paint: the canvas shows (it has content: a canvas whose
    // children have not arrived waits for them, but its card surface shows
    // at once).
    if (firstPaint == null && rootId != null && session.node(rootId)?.type == 'canvas') {
      firstPaint = tMs;
    }
    // First text: a node a person can read.
    if (firstText == null && rootId != null) {
      bool shown(String id) {
        for (String? x = id; x != null; x = doc.parentOf(x)) {
          if (!identical(session.node(x), doc[x])) return false;
        }
        return true;
      }
      for (final n in doc.subtree(rootId)) {
        if (n.type == 'text' && shown(n.id)) {
          firstText = tMs;
          break;
        }
      }
    }
    if (firstSection == null && rootId != null) {
      final container = _sectionContainer(doc, rootId);
      if (container != null) {
        for (final s in doc[container]!.children) {
          if (_complete(doc, s) && doc.subtree(s).length >= 3) {
            firstSection = tMs;
            break;
          }
        }
      }
    }
  }

  var di = 0;
  var frameIndex = 0;
  // Until every delta is in and the tail has been shown.
  while (now <= total || di < deltas.length || !controller.isClosed) {
    // Every delta due by now, each followed by a frame when it completed
    // ops (so each op's re-applied boxes are counted on their own).
    while (di < deltas.length && deltas[di].tMs <= now) {
      chars += deltas[di].delta.length;
      controller.add(deltas[di].delta);
      final t = deltas[di].tMs;
      di++;
      await pump(Duration.zero);
      recordOps(t);
    }
    if (di == deltas.length && !controller.isClosed) {
      await controller.close();
      await pump(Duration.zero);
      recordOps(lastT);
      complete = lastT;
    }
    // Pages follow the newest content, as a reader's eye would.
    if (!card) _follow(tester, session, newest);
    await tester.runAsync(() => PaintImages.settled(timeout: const Duration(milliseconds: 400)));
    await pump(Duration(milliseconds: frameMs));
    // Capture.
    final file = '${framesDir.path}/f${frameIndex.toString().padLeft(4, '0')}.png';
    await tester.runAsync(() async {
      final ro = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await ro.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      File(file).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    frames.add({
      'file': file,
      'tMs': now,
      'tokens': (outputTokens * chars / math.max(1, totalChars)).round(),
      'nodes': session.document.nodes.length,
      'pending': session.pending.length,
    });
    frameIndex++;
    now += frameMs;
  }
  final result = await done;
  if (args.dumpDocument) {
    const enc = JsonEncoder.withIndent(' ');
    File('${out.path}/document.json').writeAsStringSync(enc.convert(session.document.toJson()));
    File('${out.path}/state.json').writeAsStringSync(enc.convert(jsonDecode(jsonEncode(session.values, toEncodable: (o) => '$o'))));
  }
  final usage = ds == null ? null : _designSystemUsage(tester, session.document, ds);
  // What only layout can tell, after the last frame: sizes, and whether the
  // UI shows anything (what a host adds to the tool result).
  final layout = session.shownDiagnostics();
  final end = session.lastStreamEnd;
  // Works when used: the brief's scripted interaction, on the final UI.
  final script = stream.meta['followup'] == null || stream.meta['turn'] == 'retry' ? interactionsFor('${stream.meta['ui']}') : null;
  final used = script == null ? null : await runInteractions(tester, session, boundary, script);
  final applied = times.where((t) => t.ok).toList();
  final re = [for (final t in applied) t.reapplied]..sort();
  int pct(List<int> l, double p) => l.isEmpty ? 0 : l[math.min(l.length - 1, (p * l.length).floor())];
  final metrics = <String, Object?>{
    'stream': File(args.stream).uri.pathSegments.last,
    'size': sizeName,
    'source': stream.meta['source'],
    'model': ?stream.meta['model'],
    'rateTokensPerSecond': ?stream.meta['rateTokensPerSecond'],
    'ttftMs': stream.meta['ttftMs'] ?? (deltas.isEmpty ? null : deltas.first.tMs),
    'timeToFirstPaintMs': firstPaint,
    'timeToFirstTextMs': firstText,
    'timeToFirstSectionMs': firstSection,
    'timeToCompleteMs': complete,
    'outputTokens': outputTokens.round(),
    'tokensEstimated': stream.meta['tokensEstimated'] ?? false,
    'chars': totalChars,
    'deltas': deltas.length,
    'opsApplied': result.applied.length,
    'opsRejected': result.rejected.length,
    'opsRecoveredFromMalformed': end?.recovered ?? 0,
    'jsonRepairs': end?.repairs ?? 0,
    'pending': result.pending.length,
    'renderDiagnostics': [
      for (final d in [...result.warnings.where((d) => const {'empty_button', 'low_contrast', 'missing_glyph'}.contains(d.code)), ...layout])
        '${d.code} ${d.nodeId ?? d.path}',
    ],
    // What the final frame shows wrong (UiSession.shownDiagnostics), in full.
    'shownDiagnostics': [for (final d in layout) d.toJson()],
    'finalDiagnostics': [for (final d in [...result.errors, ...layout, ...result.warnings.where((d) => const {'empty_button', 'low_contrast', 'missing_glyph'}.contains(d.code))]) '${d.code} ${d.path}'],
    'scripts': (session.document.extra['scripts'] as List?)?.length ?? 0,
    'designSystem': ?usage,
    'themeMode': args.dark ? 'dark' : 'light',
    'worksWhenUsed': ?used,
    if (baseRetries.isNotEmpty) 'bases': baseRetries,
    'streamedOps': times.length,
    'rejections': [for (final d in result.errors) d.toJson()],
    'nodes': session.document.nodes.length,
    'reappliedBoxesPerOp': {'min': re.isEmpty ? 0 : re.first, 'median': pct(re, 0.5), 'p90': pct(re, 0.9), 'max': re.isEmpty ? 0 : re.last},
    'frames': frames.length,
    'frameMs': frameMs,
    'pumpsOverBudget16ms': pumpMs.where((m) => m > 16.7).length,
    'pumps': pumpMs.length,
    'pumpMsMedian': (pumpMs.toList()..sort()).elementAtOrNull(pumpMs.length ~/ 2),
    'renderExceptions': errors,
    'warnings': result.warnings.length,
  };
  File('${out.path}/metrics.json').writeAsStringSync(const JsonEncoder.withIndent(' ').convert(metrics));
  File('${out.path}/frames.json').writeAsStringSync(jsonEncode({'meta': stream.meta, 'size': sizeName, 'frames': frames, 'metrics': metrics}));
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
  session.dispose();
  return metrics;
}

/// How much of the final UI is the design system's, and whether its
/// components rendered: nodes whose type is one of its components (each
/// rendered as its definition, a [ComponentInstance] in the render tree,
/// unless hidden), and nodes of a base control type it `replaces`.
Map<String, Object?> _designSystemUsage(WidgetTester tester, api.LayoutDocument doc, api.DesignSystem ds) {
  final replaces = ds.manifest.replaces.toSet();
  final calls = [for (final n in doc.nodes.values) if (ds.components[n.type] != null) n.id];
  final rendered = <String>{};
  void visit(RenderObject o) {
    final ci = o is NodeBox ? componentInstanceOf(o.instance) : null;
    if (ci != null) {
      // The outermost instance: the call in the UI's own document.
      var top = ci;
      for (var outer = componentInstanceOf(top.outer); outer != null; outer = componentInstanceOf(top.outer)) {
        top = outer;
      }
      rendered.add(top.call);
    }
    o.visitChildren(visit);
  }

  for (final v in tester.binding.renderViews) {
    visit(v);
  }
  return {
    'id': ds.id,
    'version': ds.manifest.version,
    'componentNodes': calls.length,
    'componentsRendered': calls.where(rendered.contains).length,
    'componentsNotRendered': [for (final id in calls) if (!rendered.contains(id)) '$id (${doc[id]!.type})'],
    'replacedControls': [for (final n in doc.nodes.values) if (replaces.contains(n.type)) '${n.id} (${n.type})'],
  };
}

bool _complete(api.LayoutDocument doc, String id) {
  final n = doc[id];
  if (n == null) return false;
  return n.childIds.every((c) => _complete(doc, c));
}

/// The node whose children are the sections: the first one below the root
/// with two or more children.
String? _sectionContainer(api.LayoutDocument doc, String root) {
  String? x = root;
  for (var depth = 0; depth < 6 && x != null; depth++) {
    final n = doc[x];
    if (n == null) return null;
    final kids = n.childIds.toList();
    if (kids.length >= 2 && depth > 0) {
      // A stack holding the page and a floating bar: the page.
      final page = kids.where((k) => doc[k]?.childIds.length != null && (doc[k]!.childIds.length) >= 2).firstOrNull;
      return n.type == 'stack' && page != null ? page : x;
    }
    x = kids.isEmpty ? null : kids.first;
  }
  return null;
}

/// Scrolls the page so the newest node is in view.
void _follow(WidgetTester tester, UiSession session, String? newest) {
  if (newest == null) return;
  RenderDesignScroll? page;
  NodeBox? box;
  void visit(RenderObject o) {
    // The page: the outermost vertical scroll view (a horizontal table
    // inside it, or a list, is not the page).
    if (o is RenderDesignScroll && page == null && o.axis == Axis.vertical && o.hasSize) page = o;
    if (o is NodeBox && o.id == newest && o.attached) box = o;
    o.visitChildren(visit);
  }

  for (final v in tester.binding.renderViews) {
    visit(v);
  }
  final p = page, b = box;
  if (p == null || b == null || !b.hasSize || !p.hasSize || p.maxScrollExtent <= 0) return;
  final top = b.localToGlobal(Offset.zero, ancestor: p).dy;
  final bottom = top + b.size.height;
  final view = p.size.height;
  if (bottom <= view * 0.92 && top >= 0) return;
  final target = (p.offset + bottom - view * 0.85).clamp(0.0, p.maxScrollExtent);
  // Ease toward it: no jump cuts in the video.
  final next = p.offset + (target - p.offset) * 0.5;
  if ((next - p.offset).abs() > 0.5) p.jumpTo(next);
}

/// The replay's services: scripts run in the sandbox the platform has
/// (QuickJS through dart:ffi on the VM, built by tool/build_quickjs.sh).
class ReplayServices implements CodelesslyServices, ServiceLocator {
  const ReplayServices();

  /// Points the sandbox at the QuickJS build for this machine
  /// (`tool/build_quickjs.sh`), when there is one; false when not.
  static bool useLocalQuickJs() {
    for (final ext in const ['so', 'dylib']) {
      final path = '${Directory.current.path}/.dart_tool/codelessly_quickjs/libcodelessly_quickjs.$ext';
      if (File(path).existsSync()) {
        QuickJsLibrary.libraryPath = path;
        return true;
      }
    }
    return false;
  }

  static const _runner = SandboxScriptRunner();

  @override
  T? service<T extends Object>() => T == ScriptRunner ? _runner as T : null;

  @override
  Future<Object?> callApi(String apiId, {Json params = const {}}) async => null;

  @override
  Future<bool> openUrl(String url) async => false;
}
