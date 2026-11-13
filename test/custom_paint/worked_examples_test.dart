// The proposal's worked examples as fixtures (test/fixtures/custom_paint):
// a function plot (a polyline from a bound list of points, axes, a grid and
// labels), a dial (ticks and numbers by repeat and rotate, a bound needle)
// and a cell board from a bound list. Each renders as one node; its
// variables drive it. With CUSTOM_PAINT_PNG_DIR set, each is written there
// as a PNG to look at.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/custom_paint.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

LayoutDocument _fixture(String name) =>
    LayoutDocument.fromJson(jsonDecode(File('test/fixtures/custom_paint/$name.json').readAsStringSync()) as Json);

Future<(Uint8List rgba, int w, int h)> _render(WidgetTester tester, String name, {VariableScope? scope}) async {
  final doc = _fixture(name);
  final root = doc.roots.single;
  final s = scope ?? VariableScope(doc.logic.variables[root] ?? const []);
  final tree = NodeTree(DocumentSource(doc), binder: NodeBinder(scope: s));
  addTearDown(tree.dispose);
  final key = GlobalKey();
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: ColoredBox(
      color: const Color(0xFFF5F5F5),
      child: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(key: key, child: Padding(padding: const EdgeInsets.all(8), child: NodeView(tree: tree, rootId: root))),
      ),
    ),
  ));
  await tester.pump();
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Platform.environment['CUSTOM_PAINT_PNG_DIR'];
    if (dir != null) File('$dir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
    final out = (rgba!.buffer.asUint8List(), image.width, image.height);
    image.dispose();
    return out;
  }))!;
}

/// The color at logical (x, y) of the node (2× pixels, 8 px padding).
Color _at((Uint8List, int, int) shot, double x, double y) {
  final (px, w, _) = shot;
  final i = (((y + 8) * 2).round() * w + ((x + 8) * 2).round()) * 4;
  return Color.fromARGB(px[i + 3], px[i], px[i + 1], px[i + 2]);
}

bool _near(Color a, Color b, [int tolerance = 40]) =>
    ((a.r - b.r).abs() * 255) <= tolerance && ((a.g - b.g).abs() * 255) <= tolerance && ((a.b - b.b).abs() * 255) <= tolerance;

void main() {
  setUpAll(() async {
    final roboto = File('/opt/flutter/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf');
    final medium = File('/opt/flutter/bin/cache/artifacts/material_fonts/Roboto-Medium.ttf');
    if (!roboto.existsSync()) return;
    final loader = FontLoader('Roboto')
      ..addFont(Future.value(ByteData.sublistView(roboto.readAsBytesSync())))
      ..addFont(Future.value(ByteData.sublistView(medium.readAsBytesSync())));
    await loader.load();
  });

  testWidgets('a function plot: the bound curve over its grid and axes', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final shot = await _render(tester, 'function_plot');
    // The curve at x = π/2 (its top, 1.2): 20 + 40·1.5708, 100 − 60·1.2.
    expect(_near(_at(shot, 20 + 40 * 1.5708, 100 - 60 * 1.2), const Color(0xFF1E88E5)), isTrue, reason: 'the curve\'s top');
    expect(_near(_at(shot, 20 + 40 * 3.1416, 100), const Color(0xFF1E88E5)), isTrue, reason: 'it crosses the axis at π');
    expect(_near(_at(shot, 260, 100), const Color(0xFF263238)), isTrue, reason: 'the x axis');
    expect(_near(_at(shot, 140, 40), const Color(0xFFE3E7EA), 6), isTrue, reason: 'a grid line (x = 3)');
  });

  testWidgets('a dial: ticks and numbers by repeat and rotate, the needle at its bound value', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final doc = _fixture('dial');
    final scope = VariableScope(doc.logic.variables['dial']!);
    final shot = await _render(tester, 'dial', scope: scope);
    // 220 px box, view box 200: 1.1 px per unit. The 12 o'clock tick (long).
    expect(_near(_at(shot, 110, 110 - 85 * 1.1), const Color(0xFFE8ECEE)), isTrue, reason: 'the 12 o\'clock tick');
    // The needle at 17.5 of 60: 105° clockwise from 12.
    expect(_near(_at(shot, 110 + 60 * 1.1 * 0.9659, 110 + 60 * 1.1 * 0.2588), const Color(0xFFE74C3C)), isTrue, reason: 'the needle');

    // The value moves: the needle points straight down, and only it redraws.
    RenderCustomPaintLayer? layer;
    void visit(RenderObject o) {
      if (o is RenderCustomPaintLayer) layer ??= o;
      o.visitChildren(visit);
    }

    visit(tester.renderObject(find.byType(NodeView)));
    final before = layer!.debugRecordCount;
    scope.set('value', 30);
    await tester.pump();
    expect(layer!.debugRecordCount, before + 1, reason: 'the needle group only');
  });

  testWidgets('a cell board from a bound list', (tester) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final shot = await _render(tester, 'cell_grid');
    // 384 × 256 for 24 × 16: 16 px a cell. A glider cell (3, 1), a blinker cell (11, 6), the bottom row.
    expect(_near(_at(shot, 3 * 16 + 8, 1 * 16 + 8), const Color(0xFF2E7D32)), isTrue);
    expect(_near(_at(shot, 11 * 16 + 8, 6 * 16 + 8), const Color(0xFF6A1B9A)), isTrue);
    expect(_near(_at(shot, 5 * 16 + 8, 15 * 16 + 8), const Color(0xFF8D6E63)), isTrue);
    expect(_near(_at(shot, 20 * 16 + 8, 3 * 16 + 8), const Color(0xFFE8D69B), 30), isTrue, reason: 'an empty cell: the agar');
  });
}
