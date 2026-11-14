// A stroke path's draw-on (30.0.0's `strokePath.drawMs`, `drawDelayMs`,
// `drawCurve`) as codelessly_api's migration writes it: an animation on the
// node whose track draws the line op's `trimEnd` from 0 up to its own value
// (and the fill's color from transparent), and a transition of that
// `trimEnd` with the same timing.
//
// Each frame is checked against 30.0.0's painter: its RenderStrokePath (git
// history before b225dc3c) drew `from + (to - from) * drawCurve(t)` of the
// line, t = (ms since its first tick - drawDelayMs) / drawMs clamped to 0–1,
// from 0 to the progress when the node first showed, and from where it was
// to the new progress when the progress changed. That share drawn as a
// static progress is pinned to 30.0.0's pixels by migrated_paint_test.dart's
// goldens, so a frame matching the static drawing at the formula's share is
// the old frame.
import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// [node] (30.0.0's spellings, in a schema-2 document) as `migrate2to3`
/// makes it.
Json _migrated(Json node) => readMap(readMap(migrate2to3({
  'schema': 2,
  'nodes': {'n': node},
})['nodes'])!['n'])!;

const _size = Size(160, 90);

/// A running (or, not [interactive], design-canvas) view of [json] as
/// node `n`, its expressions read from [scope].
class _View {
  _View(this.tree, this.key);
  final NodeTree tree;
  final GlobalKey key;

  Future<List<int>> pixels(WidgetTester tester) async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final data = (await tester.runAsync(() async {
      final image = await boundary.toImage();
      final d = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return d;
    }))!;
    return data.buffer.asUint8List().toList();
  }
}

Future<_View> _show(WidgetTester tester, Json json, {VariableScope? scope, bool interactive = true}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = _size;
  addTearDown(tester.view.reset);
  final node = Node.fromJson(json, id: 'n')!;
  final doc = LayoutDocument(roots: const ['n'], nodes: {'n': node});
  final tree = NodeTree(DocumentSource(doc), binder: NodeBinder(scope: scope ?? VariableScope(const [])));
  addTearDown(tree.dispose);
  final key = GlobalKey();
  await tester.pumpWidget(MaterialApp(
    home: Align(
      alignment: Alignment.topLeft,
      child: RepaintBoundary(
        key: key,
        child: SizedBox.fromSize(
          size: _size,
          child: ColoredBox(color: Colors.white, child: NodeView(tree: tree, rootId: 'n', interactive: interactive)),
        ),
      ),
    ),
  ));
  return _View(tree, key);
}

/// The pixels of [strokePath] drawn at a static [progress] (no draw-on),
/// on a box with [more].
Future<List<int>> _still(WidgetTester tester, Json strokePath, double progress, {Json more = const {}}) async {
  final still = {...strokePath, 'progress': progress}..remove('drawMs');
  final view = await _show(tester, _migrated(_box(still, more: more)));
  await tester.pump();
  final out = await view.pixels(tester);
  await tester.pumpWidget(const SizedBox());
  return out;
}

Json _box(Json strokePath, {Json more = const {}}) => {
  'type': 'box',
  'layout': {'width': _size.width, 'height': _size.height},
  'strokePath': strokePath,
  ...more,
};

/// The largest channel difference between two RGBA images.
int _difference(List<int> a, List<int> b) {
  var most = 0;
  for (var i = 0; i < a.length; i++) {
    final d = (a[i] - b[i]).abs();
    if (d > most) most = d;
  }
  return most;
}

int _ink(List<int> rgba) {
  var ink = 0;
  for (var i = 0; i < rgba.length; i += 4) {
    if (rgba[i] != 255 || rgba[i + 1] != 255 || rgba[i + 2] != 255) ink++;
  }
  return ink;
}

/// 30.0.0's share drawn [ms] after its first tick, running [from] → [to].
double _old(Json strokePath, double ms, {double from = 0, required double to}) {
  final drawMs = (strokePath['drawMs'] as num).toDouble();
  final delay = ((strokePath['drawDelayMs'] ?? 0) as num).toDouble();
  final curve = api.AnimationCurve.parse(strokePath['drawCurve']) ?? api.AnimationCurve.easeInOut;
  final t = ((ms - delay) / drawMs).clamp(0.0, 1.0);
  return from + (to - from) * curve.transform(t);
}

/// The line op's `trimEnd` as the tree shows node `n` now.
double? _trimEnd(_View view, [String list = 'painter']) {
  final cp = view.tree.resolve('n')!.toJson()['customPaint'] as Map;
  final ops = (cp[list] as List).cast<Map<Object?, Object?>>();
  // Omitted when it is its default, 1.
  return api.readDouble(ops.firstWhere((o) => o['id'] == 'strokePath')['trimEnd'] ?? 1);
}

/// Pumps to [times] (ms since the first tick, ascending) and checks each
/// frame against the static drawing at [expected]'s share, within
/// [tolerance] (largest channel difference).
Future<void> _matchFrames(WidgetTester tester, _View view, List<int> times, double Function(int ms) expected,
    Map<double, List<int>> stills, {String list = 'painter', int tolerance = 0, int at = 0}) async {
  var now = at;
  for (final ms in times) {
    await tester.pump(Duration(milliseconds: ms - now));
    now = ms;
    final share = expected(ms);
    expect(_trimEnd(view, list), closeTo(share, 1e-4), reason: 'trimEnd (encoded to 4 places) at $ms ms');
    final drawn = await view.pixels(tester);
    final still = stills[share]!;
    expect(_difference(drawn, still), lessThanOrEqualTo(tolerance), reason: 'pixels at $ms ms (share $share)');
  }
}

void main() {
  group('a migrated draw-on draws each frame as 30.0.0 drew it', () {
    testWidgets('a line drawn on after a delay, on an easing curve, up to its progress', (tester) async {
      final strokePath = <String, Object?>{
        'points': [[0, 70], [0.15, 20], [0.35, 65], [0.6, 15], [1, 60]], 'color': '#FF1D2B2F', 'width': 4,
        'progress': 0.8, 'drawMs': 600, 'drawDelayMs': 100, 'drawCurve': 'easeOutCubic',
      };
      const times = [0, 50, 100, 160, 250, 400, 550, 700, 900];
      double share(int ms) => _old(strokePath, ms.toDouble(), to: 0.8);
      final stills = {for (final t in times) share(t): await _still(tester, strokePath, share(t))};
      expect(_ink(stills[share(0)]!), 0, reason: 'nothing is drawn before the delay');

      final view = await _show(tester, _migrated(_box(strokePath)));
      await tester.pump(); // the first tick
      await _matchFrames(tester, view, times, share, stills);
      expect(tester.binding.transientCallbackCount, 0, reason: 'it stops when drawn');
    });

    testWidgets('the default curve (easeInOut), the whole line, a dashed line in front', (tester) async {
      final strokePath = <String, Object?>{
        'points': [[0.05, 10], [0.9, 20], [0.4, 80]], 'dashPattern': [8, 4], 'cap': 'butt', 'inFront': true,
        'color': '#FF0057B8', 'width': 3, 'drawMs': 500,
      };
      const times = [0, 40, 125, 250, 375, 480, 600];
      const more = {
        'decoration': {'fills': [{'color': '#FFEFE6D2'}]},
      };
      double share(int ms) => _old(strokePath, ms.toDouble(), to: 1);
      final stills = {for (final t in times) share(t): await _still(tester, strokePath, share(t), more: more)};
      final view = await _show(tester, _migrated(_box(strokePath, more: more)));
      await tester.pump();
      await _matchFrames(tester, view, times, share, stills, list: 'foregroundPainter');
    });

    testWidgets('a fill fading in with the drawn share is within one level of the fade', (tester) async {
      final strokePath = <String, Object?>{
        'points': [[0.1, 10], [0.9, 15], [0.8, 80], [0.15, 70]], 'fillColor': '#C0FF8800', 'progress': 0.9,
        'color': '#FF222222', 'width': 2, 'drawMs': 400, 'drawCurve': 'linear',
      };
      const times = [0, 100, 200, 300, 400, 500];
      double share(int ms) => _old(strokePath, ms.toDouble(), to: 0.9);
      final stills = {for (final t in times) share(t): await _still(tester, strokePath, share(t))};
      final view = await _show(tester, _migrated(_box(strokePath)));
      await tester.pump();
      await _matchFrames(tester, view, times, share, stills, tolerance: 1);
    });

    testWidgets('a progress that changes draws from where it is to the new share, after the delay again', (tester) async {
      final strokePath = <String, Object?>{
        'points': [[0, 20], [0.5, 80], [1, 20]], 'color': '#FF0A7D50', 'width': 5, 'drawMs': 300, 'drawDelayMs': 50,
      };
      final scope = VariableScope(const [Variable(name: 'p', type: VariableType.decimal, value: 0.4)]);
      const entrance = [0, 100, 200, 350, 400];
      const change = [0, 30, 60, 120, 200, 300, 360, 420];
      double first(int ms) => _old(strokePath, ms.toDouble(), to: 0.4);
      double second(int ms) => _old(strokePath, ms.toDouble(), from: 0.4, to: 0.95);
      final stills = {
        for (final t in entrance) first(t): await _still(tester, strokePath, first(t)),
        for (final t in change) second(t): await _still(tester, strokePath, second(t)),
      };
      final view = await _show(tester, _migrated(_box(strokePath, more: {'bind': {'strokePath.progress': r'${p}'}})), scope: scope);
      await tester.pump();
      await _matchFrames(tester, view, entrance, first, stills);
      // Drawn: the progress changes. 30.0.0 ran from the share shown to the
      // new one, its delay and duration counted from its next tick.
      scope.set('p', 0.95);
      await tester.pump(); // its first tick
      await _matchFrames(tester, view, change, second, stills);
    });

    testWidgets('the design canvas draws the line at its progress at once, and nothing ticks', (tester) async {
      final strokePath = <String, Object?>{
        'points': [[0, 70], [0.5, 10], [1, 60]], 'color': '#FF1D2B2F', 'progress': 0.6, 'drawMs': 600,
      };
      final still = await _still(tester, strokePath, 0.6);
      final view = await _show(tester, _migrated(_box(strokePath)), interactive: false);
      await tester.pump();
      expect(_difference(await view.pixels(tester), still), 0);
      expect(tester.binding.transientCallbackCount, 0);
    });
  });
}
