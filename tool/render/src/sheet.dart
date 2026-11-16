// Many captures as one labelled contact sheet, drawn with dart:ui in the render harness (no image library):
// `tool/codelessly sheet` and `render --sheet` hand it a job (render_harness.dart), through the render server when
// it is up.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'fonts.dart' show defaultFonts;

/// The PNGs of [inputs] (files, or folders searched recursively), without compare and diff images, earlier sheets
/// and hidden folders.
List<String> sheetInputs(List<String> inputs) {
  final out = <String>[];
  for (final p in inputs) {
    if (FileSystemEntity.isDirectorySync(p)) {
      final root = Directory(p).absolute.path;
      final found = Directory(p).listSync(recursive: true).whereType<File>().where((f) {
        final n = f.uri.pathSegments.last;
        final rel = f.absolute.path.substring(root.length + 1);
        return n.endsWith('.png') && !n.endsWith('.diff.png') && !n.endsWith('.compare.png') && !n.startsWith('sheet') &&
            !rel.split('/').any((s) => s.startsWith('.'));
      }).map((f) => f.path).toList()
        ..sort();
      out.addAll(found);
    } else if (File(p).existsSync()) {
      out.add(p);
    }
  }
  return out;
}

int _widthOf(String path) {
  final size = path.split('/').last.split('@').skip(1).firstOrNull ?? '';
  return int.tryParse(size.split('x').first) ?? 0;
}

/// Rows of the sheet: [columns] a row, else one row per state (the part of a capture's name around its size),
/// narrowest size first.
List<List<String>> sheetRows(List<String> images, {int? columns}) {
  if (columns != null && columns > 0) {
    return [for (var i = 0; i < images.length; i += columns) images.sublist(i, (i + columns).clamp(0, images.length))];
  }
  final rows = <String, List<String>>{};
  for (final f in images) {
    final dir = File(f).parent.path;
    final stem = f.split('/').last.replaceFirst(RegExp(r'\.png$'), '');
    final at = stem.indexOf('@');
    final screen = at < 0 ? stem : stem.substring(0, at);
    final size = at < 0 ? '' : stem.substring(at + 1);
    final dash = size.indexOf('-');
    final state = dash < 0 ? '' : size.substring(dash + 1);
    (rows['$dir/$screen|$state'] ??= []).add(f);
  }
  return [for (final r in rows.values) r..sort((a, b) => _widthOf(a).compareTo(_widthOf(b)))];
}

bool _fontLoaded = false;

Future<void> _loadLabelFont(String flutterRoot) async {
  if (_fontLoaded) return;
  final face = defaultFonts(flutterRoot).where((f) => f.family == 'Roboto' && f.weight == 400 && !f.italic).firstOrNull;
  if (face != null) await ui.loadFontFromList(File(face.path).readAsBytesSync(), fontFamily: 'Roboto');
  _fontLoaded = true;
}

ui.Paragraph _label(String text, double size, ui.Color color, double width) {
  final b = ui.ParagraphBuilder(ui.ParagraphStyle(fontFamily: 'Roboto', fontSize: size, maxLines: 1, ellipsis: '…'))
    ..pushStyle(ui.TextStyle(color: color, fontFamily: 'Roboto', fontSize: size))
    ..addText(text);
  return b.build()..layout(ui.ParagraphConstraints(width: width));
}

/// Draws the sheet of [images] into [out]: each scaled to at most [height] tall under its name, rows as
/// [sheetRows] makes them. Returns the file, or null when there is nothing to draw. [base] makes labels relative.
Future<String?> makeSheet(List<String> images, String out,
    {int height = 480, int? columns, String? title, String? base, required String flutterRoot}) async {
  if (images.isEmpty) return null;
  await _loadLabelFont(flutterRoot);
  const pad = 12.0, labelH = 22.0;
  final titleH = title == null ? 0.0 : 34.0;
  final rows = <List<(String, ui.Image)>>[];
  for (final row in sheetRows(images, columns: columns)) {
    final cells = <(String, ui.Image)>[];
    for (final f in row) {
      final bytes = File(f).readAsBytesSync();
      final probe = await (await ui.instantiateImageCodec(bytes)).getNextFrame();
      final tall = probe.image.height > height;
      probe.image.dispose();
      final codec = await ui.instantiateImageCodec(bytes, targetHeight: tall ? height : null);
      cells.add((f, (await codec.getNextFrame()).image));
    }
    rows.add(cells);
  }
  double rowWidth(List<(String, ui.Image)> r) => r.fold<double>(pad, (a, c) => a + c.$2.width + pad);
  double rowHeight(List<(String, ui.Image)> r) => r.fold<double>(0, (a, c) => a > c.$2.height ? a : c.$2.height.toDouble());
  final width = rows.map(rowWidth).reduce((a, b) => a > b ? a : b);
  final total = titleH + rows.fold<double>(0, (a, r) => a + rowHeight(r) + labelH + pad) + pad;

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(ui.Rect.fromLTWH(0, 0, width, total), ui.Paint()..color = const ui.Color(0xFFECEEF1));
  if (title != null) canvas.drawParagraph(_label(title, 16, const ui.Color(0xFF111827), width - 2 * pad), const ui.Offset(pad, 9));
  final border = ui.Paint()
    ..color = const ui.Color(0xFFCBD0D7)
    ..style = ui.PaintingStyle.stroke;
  var y = titleH + pad;
  for (final r in rows) {
    var x = pad;
    for (final (f, im) in r) {
      final name = base != null && f.startsWith('$base/') ? f.substring(base.length + 1) : f.split('/').last;
      canvas.drawParagraph(_label(name, 14, const ui.Color(0xFF374151), im.width.toDouble()), ui.Offset(x, y + 3));
      canvas.drawImage(im, ui.Offset(x, y + labelH), ui.Paint()..filterQuality = ui.FilterQuality.medium);
      canvas.drawRect(ui.Rect.fromLTWH(x - 0.5, y + labelH - 0.5, im.width + 1, im.height + 1), border);
      x += im.width + pad;
    }
    y += rowHeight(r) + labelH + pad;
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(width.ceil(), total.ceil());
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  for (final r in rows) {
    for (final (_, im) in r) {
      im.dispose();
    }
  }
  File(out).parent.createSync(recursive: true);
  File(out).writeAsBytesSync(Uint8List.sublistView(png!));
  return out;
}
