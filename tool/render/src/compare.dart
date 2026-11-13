// `--compare <reference.png | dir>`: a capture against a reference
// screenshot (a hand-coded site's, a design's). Writes a side-by-side image
// and a diff image next to the capture and summarizes where the two differ:
// the page heights, how much of the page matches, and the vertical bands
// where they diverge (so a reader looks there, not at the whole page). The
// two images may differ in height (and in width: the reference is scaled
// to the capture's width).
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// An image's RGBA pixels.
typedef Pixels = ({int width, int height, Uint8List rgba});

/// What a comparison found.
final class ImageComparison {
  ImageComparison({
    required this.capture,
    required this.reference,
    required this.captureHeight,
    required this.referenceHeight,
    required this.width,
    required this.matching,
    required this.bands,
    this.firstDifference,
  });

  final String capture, reference;
  final int captureHeight, referenceHeight, width;

  /// The share of compared pixels that match (within a small tolerance).
  final double matching;

  /// Rows where the images differ, top to bottom: start and end (exclusive)
  /// row, the share of the band's pixels that differ, and the mean
  /// difference (0–255) of those pixels.
  final List<({int top, int bottom, double share, double mean, int? shift})> bands;

  /// The first row that differs, if any.
  final int? firstDifference;

  Map<String, Object?> toJson() => {
        'capture': capture.split('/').last,
        'reference': reference,
        'width': width,
        'captureHeight': captureHeight,
        'referenceHeight': referenceHeight,
        'matching': double.parse(matching.toStringAsFixed(4)),
        if (firstDifference != null) 'firstDifference': firstDifference,
        'bands': [
          for (final b in bands)
            {'top': b.top, 'bottom': b.bottom, 'share': double.parse(b.share.toStringAsFixed(3)), 'mean': b.mean.round(), 'shift': ?b.shift},
        ],
      };

  /// A few lines for a person or an agent.
  String summary({int maxBands = 8}) {
    final b = StringBuffer();
    final dh = captureHeight - referenceHeight;
    b.writeln('compare ${capture.split('/').last} with $reference: ${(matching * 100).toStringAsFixed(1)}% of pixels match '
        '(${width}px wide; height ${_n(captureHeight)} vs ${_n(referenceHeight)}: '
        '${dh == 0 ? 'the same' : '${_n(dh.abs())} px ${dh > 0 ? 'taller' : 'shorter'} than the reference'}).');
    if (firstDifference != null) b.writeln('  first difference at y=$firstDifference.');
    final big = [...bands]..sort((x, y) => ((y.bottom - y.top) * y.share).compareTo((x.bottom - x.top) * x.share));
    for (final x in big.take(maxBands).toList()..sort((p, q) => p.top.compareTo(q.top))) {
      b.writeln('  y ${x.top}–${x.bottom} (${x.bottom - x.top} px): ${(x.share * 100).toStringAsFixed(0)}% of pixels differ, '
          'mean difference ${x.mean.round()}${x.top >= math.min(captureHeight, referenceHeight) ? ' (only one image is this tall)' : ''}'
          '${x.shift == null ? '' : '; it matches the reference ${x.shift!.abs()} px ${x.shift! > 0 ? 'lower' : 'higher'} (what is above it is ${x.shift! > 0 ? 'taller' : 'shorter'} in the reference)'}.');
    }
    if (bands.length > maxBands) b.writeln('  ... ${bands.length - maxBands} smaller band(s): see "comparisons" in the diagnostics file.');
    return b.toString().trimRight();
  }
}

String _n(int v) => v.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

Future<Pixels> decodePng(List<int> bytes, {int? width}) async {
  final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes), targetWidth: width);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final out = (width: image.width, height: image.height, rgba: data!.buffer.asUint8List());
  image.dispose();
  codec.dispose();
  return out;
}

Future<ui.Image> _imageOf(Pixels p) {
  final c = Completer<ui.Image>();
  ui.decodeImageFromPixels(p.rgba, p.width, p.height, ui.PixelFormat.rgba8888, c.complete);
  return c.future;
}

/// The vertical offset (within 80 px) at which rows [top]..[bottom] of
/// [a] match [b] best, when that at least halves the pixels that differ;
/// null when none does.
int? _shift(Pixels a, Pixels b, int top, int bottom, int tolerance) {
  if (bottom > a.height) return null;
  double share(int s) {
    var differ = 0, n = 0;
    for (var y = top; y < bottom; y += 2) {
      final yb = y + s;
      if (yb < 0 || yb >= b.height) {
        differ += a.width ~/ 3;
        n += a.width ~/ 3;
        continue;
      }
      for (var x = 0; x < a.width; x += 3) {
        final i = (y * a.width + x) * 4, j = (yb * b.width + x) * 4;
        final d = math.max((a.rgba[i] - b.rgba[j]).abs(), math.max((a.rgba[i + 1] - b.rgba[j + 1]).abs(), (a.rgba[i + 2] - b.rgba[j + 2]).abs()));
        if (d > tolerance) differ++;
        n++;
      }
    }
    return n == 0 ? 1 : differ / n;
  }

  int? best;
  // A shift counts when it at least halves what differs.
  var bestShare = math.min(0.1, share(0) / 2);
  for (var s = -80; s <= 80; s++) {
    if (s == 0) continue;
    final v = share(s);
    if (v < bestShare) {
      bestShare = v;
      best = s;
    }
  }
  return best;
}

Future<List<int>> _png(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

/// The reference for capture [png] (`<screen>@<w>x<h>[-<label>].png`) in
/// [reference]: the file itself, or in a directory the file naming the
/// same size and the screen, preferring one that names the label (else
/// `default`). Null, with the candidates, when none fits.
({String? file, List<String> candidates}) referenceFor(String png, String reference) {
  final type = FileSystemEntity.typeSync(reference);
  if (type == FileSystemEntityType.file) return (file: reference, candidates: const []);
  if (type != FileSystemEntityType.directory) return (file: null, candidates: const []);
  final name = png.split('/').last;
  final m = RegExp(r'^(.*)@(\d+x\d+)(?:-(.*))?\.png$').firstMatch(name);
  if (m == null) return (file: null, candidates: const []);
  final screen = m[1]!.toLowerCase(), size = m[2]!, label = m[3]?.toLowerCase();
  final files = [
    for (final f in Directory(reference).listSync())
      if (f is File && f.path.toLowerCase().endsWith('.png') && f.path.split('/').last.contains(size)) f.path,
  ]..sort();
  final ofScreen = [for (final f in files) if (f.split('/').last.toLowerCase().startsWith(screen)) f];
  bool names(String f, String word) => RegExp('(^|[^a-z0-9])${RegExp.escape(word)}([^a-z0-9]|\$)').hasMatch(f.split('/').last.toLowerCase());
  final pool = ofScreen.isEmpty ? files : ofScreen;
  final pick = pool.where((f) => names(f, label ?? 'default')).toList();
  if (pick.length == 1) return (file: pick.single, candidates: pool);
  if (pool.length == 1) return (file: pool.single, candidates: pool);
  return (file: null, candidates: pool);
}

/// Compares capture [capturePath] with [referencePath]; writes
/// `<capture>.compare.png` (capture left, reference right) and
/// `<capture>.diff.png` (the capture dimmed, differing pixels in red).
Future<ImageComparison> compareImages(String capturePath, String referencePath) async {
  final a = await decodePng(File(capturePath).readAsBytesSync());
  final b = await decodePng(File(referencePath).readAsBytesSync(), width: null);
  final ref = b.width == a.width ? b : await decodePng(File(referencePath).readAsBytesSync(), width: a.width);
  final w = a.width, h = math.min(a.height, ref.height), hMax = math.max(a.height, ref.height);
  const tolerance = 24; // per channel: anti-aliasing and font hinting
  final rowShare = Float64List(hMax), rowMean = Float64List(hMax);
  final diff = Uint8List(w * a.height * 4);
  var matching = 0;
  for (var y = 0; y < a.height; y++) {
    var differ = 0, sum = 0;
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      final r = a.rgba[i], g = a.rgba[i + 1], bl = a.rgba[i + 2];
      var d = 255;
      if (y < h) {
        d = math.max((r - ref.rgba[i]).abs(), math.max((g - ref.rgba[i + 1]).abs(), (bl - ref.rgba[i + 2]).abs()));
      }
      final over = d > tolerance;
      if (over) {
        differ++;
        sum += d;
        diff[i] = 255;
        diff[i + 1] = (g * 0.3).round();
        diff[i + 2] = (bl * 0.3).round();
      } else {
        if (y < h) matching++;
        final grey = ((r + g + bl) / 3 * 0.35 + 165).round();
        diff[i] = diff[i + 1] = diff[i + 2] = grey;
      }
      diff[i + 3] = 255;
    }
    rowShare[y] = differ / w;
    rowMean[y] = differ == 0 ? 0 : sum / differ;
  }
  for (var y = a.height; y < hMax; y++) {
    rowShare[y] = 1;
    rowMean[y] = 255;
  }
  // Bands: rows where at least 1% of pixels differ, merged across gaps of
  // up to 12 rows; bands under 3 rows dropped.
  final bands = <({int top, int bottom, double share, double mean, int? shift})>[];
  int? start;
  var gap = 0;
  void close(int end) {
    if (start == null) return;
    if (end - start! >= 3) {
      var s = 0.0, m = 0.0, n = 0;
      for (var y = start!; y < end; y++) {
        s += rowShare[y];
        if (rowShare[y] > 0) {
          m += rowMean[y];
          n++;
        }
      }
      bands.add((top: start!, bottom: end, share: s / (end - start!), mean: n == 0 ? 0 : m / n, shift: _shift(a, ref, start!, end, tolerance)));
    }
    start = null;
  }

  for (var y = 0; y < hMax; y++) {
    if (rowShare[y] >= 0.01) {
      start ??= y;
      gap = 0;
    } else if (start != null) {
      if (++gap > 12) close(y - gap + 1);
    }
  }
  close(hMax - gap);
  int? first;
  for (var y = 0; y < hMax; y++) {
    if (rowShare[y] >= 0.01) {
      first = y;
      break;
    }
  }
  // Images.
  final base = capturePath.replaceFirst(RegExp(r'\.png$'), '');
  final ia = await _imageOf(a), ib = await _imageOf(ref), id = await _imageOf((width: w, height: a.height, rgba: diff));
  const gutter = 16.0;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(ui.Rect.fromLTWH(0, 0, w * 2 + gutter, hMax.toDouble()), ui.Paint()..color = const ui.Color(0xFF808080));
  canvas.drawImage(ia, ui.Offset.zero, ui.Paint());
  canvas.drawImage(ib, ui.Offset(w + gutter, 0), ui.Paint());
  final side = await recorder.endRecording().toImage((w * 2 + gutter).toInt(), hMax);
  File('$base.compare.png').writeAsBytesSync(await _png(side));
  File('$base.diff.png').writeAsBytesSync(await _png(id));
  for (final i in [ia, ib, id, side]) {
    i.dispose();
  }
  return ImageComparison(
    capture: capturePath,
    reference: referencePath,
    captureHeight: a.height,
    referenceHeight: ref.height,
    width: w,
    matching: h == 0 ? 0 : matching / (w * h),
    bands: bands,
    firstDifference: first,
  );
}
