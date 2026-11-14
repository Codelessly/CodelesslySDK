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

/// The reference screenshot for capture [png] (`<screen>@<WxH>[-<label>].png`):
/// [reference] itself when it is a file; in a directory, the PNG of the
/// same size whose name is the screen and the state exactly, the state
/// being the capture's label (else `default`, or none): `home--default--390x844.png`,
/// `home@390x844.png`, `section--saved--390x844.png` for `--label saved`
/// (and not `section--saved-empty--390x844.png`). Separators between the
/// parts are any of `--`, `-`, `_`, `@`, `.`. [map] renames a screen (or a
/// `<screen>-<label>` pair) to the reference's name for it: `home` →
/// `index`, `section-saved` → `section--saved-list`.
({String? file, List<String> candidates}) referenceFor(String png, String reference, {Map<String, String> map = const {}}) {
  final type = FileSystemEntity.typeSync(reference);
  if (type == FileSystemEntityType.file) return (file: reference, candidates: const []);
  if (type != FileSystemEntityType.directory) return (file: null, candidates: const []);
  final name = png.split('/').last;
  final m = RegExp(r'^(.*)@(\d+x\d+)(?:-(.*))?\.png$').firstMatch(name);
  if (m == null) return (file: null, candidates: const []);
  var screen = m[1]!.toLowerCase();
  final size = m[2]!;
  String? label = m[3]?.toLowerCase();
  final lower = {for (final e in map.entries) e.key.toLowerCase(): e.value.toLowerCase()};
  String? stem; // the reference's whole name for this capture, sans size
  if (label != null && lower['$screen-$label'] != null) {
    stem = lower['$screen-$label'];
  } else if (lower[screen] != null) {
    screen = lower[screen]!;
  }
  final files = [
    for (final f in Directory(reference).listSync())
      if (f is File && f.path.toLowerCase().endsWith('.png') && !f.path.endsWith('.compare.png') && !f.path.endsWith('.diff.png') &&
          RegExp('(^|[^0-9])${RegExp.escape(size)}([^0-9]|\$)').hasMatch(f.path.split('/').last))
        f.path,
  ]..sort();
  const sep = r'(?:--|[-_@.])';
  String norm(String s) => s.replaceAll(RegExp(r'[-_@.]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  // The name with the size taken out, its parts joined by single dashes.
  String rest(String f) {
    final base = f.split('/').last.toLowerCase().replaceFirst(RegExp(r'\.png$'), '');
    return norm(base.replaceFirst(RegExp('$sep?${RegExp.escape(size)}$sep?'), '-'));
  }
  final ofScreen = [
    for (final f in files)
      if (rest(f) == norm(screen) || rest(f).startsWith('${norm(screen)}-')) f,
  ];
  if (stem != null) {
    final pick = [for (final f in files) if (rest(f) == norm(stem)) f];
    return (file: pick.length == 1 ? pick.single : null, candidates: files);
  }
  String stateOf(String f) {
    final r = rest(f);
    return r == norm(screen) ? '' : r.substring(norm(screen).length + 1);
  }
  final want = label == null ? const {'', 'default'} : {norm(label)};
  final pick = [for (final f in ofScreen) if (want.contains(stateOf(f))) f];
  if (pick.length == 1) return (file: pick.single, candidates: ofScreen);
  // Both `home--390x844.png` and `home--default--390x844.png`: the default.
  if (pick.length > 1 && label == null) {
    final d = [for (final f in pick) if (stateOf(f) == 'default') f];
    if (d.length == 1) return (file: d.single, candidates: ofScreen);
  }
  return (file: null, candidates: ofScreen.isEmpty ? files : ofScreen);
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
