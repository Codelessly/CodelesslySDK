// Procedural noise for a `noise` paint (film grain, paper texture): SVG's
// `feTurbulence` (Filter Effects §15.21), computed with the reference
// implementation the specification gives (its seeded random generator,
// lattice and gradients), so a seed draws the same grain as a browser's
// <feTurbulence seed="n">. A paint draws one stitched tile, repeated: the
// tile's edges meet without a seam (`stitchTiles="stitch"`).
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:codelessly_api/core.dart' as api;

/// The side of a noise paint's tile, in pixels.
const noiseTileSize = 256;

/// Each noise paint's tile, kept with the paint itself (weakly: it goes
/// with the paint).
final Expando<String> _tileOf = Expando('noise tile');

/// The tile a noise paint repeats, as a PNG data URL (made once per noise
/// and color): feTurbulence's four channels, or with a color, that color
/// with the noise's first channel as its alpha.
String noiseTileUrl(api.Paint p) {
  final n = p.noise ?? const api.NoisePaint();
  final color = p.color;
  return _tileOf[p] ??= (() {
    final t = Turbulence(
      seed: n.seed,
      baseFrequencyX: n.baseFrequency,
      baseFrequencyY: n.baseFrequency,
      numOctaves: n.numOctaves,
      fractalNoise: n.type == api.NoiseType.fractalNoise,
    );
    const size = noiseTileSize;
    final Uint8List rgba;
    if (color == null) {
      rgba = t.tile(size, size);
    } else {
      rgba = Uint8List(size * size * 4);
      final c = color.value;
      final a = (c >> 24) & 0xff, r = (c >> 16) & 0xff, g = (c >> 8) & 0xff, b = c & 0xff;
      for (var y = 0; y < size; y++) {
        for (var x = 0; x < size; x++) {
          final i = (y * size + x) * 4;
          rgba[i] = r;
          rgba[i + 1] = g;
          rgba[i + 2] = b;
          rgba[i + 3] = (t.channelAt(0, x, y, size, size) * a / 255).round();
        }
      }
    }
    return 'data:image/png;base64,${base64.encode(encodePng(rgba, size, size))}';
  })();
}

/// feTurbulence over one tile: its RGBA bytes (straight alpha), row by row.
class Turbulence {
  Turbulence({
    required this.seed,
    required this.baseFrequencyX,
    required this.baseFrequencyY,
    required this.numOctaves,
    required this.fractalNoise,
  }) {
    _init(seed);
  }

  final int seed;
  final double baseFrequencyX, baseFrequencyY;
  final int numOctaves;

  /// `type="fractalNoise"` (else `turbulence`).
  final bool fractalNoise;

  static const _bSize = 0x100, _bm = 0xff, _perlinN = 0x1000;
  static const _randM = 2147483647, _randA = 16807, _randQ = 127773, _randR = 2836;

  final _lattice = Int32List(_bSize + _bSize + 2);
  final _gradient = List.generate(4, (_) => Float64List((_bSize + _bSize + 2) * 2));

  static int _setupSeed(int s) {
    if (s <= 0) s = -(s % (_randM - 1)) + 1;
    if (s > _randM - 1) s = _randM - 1;
    return s;
  }

  static int _random(int s) {
    var r = _randA * (s % _randQ) - _randR * (s ~/ _randQ);
    if (r <= 0) r += _randM;
    return r;
  }

  void _init(int seed) {
    var s = _setupSeed(seed);
    var i = 0;
    for (var k = 0; k < 4; k++) {
      final g = _gradient[k];
      for (i = 0; i < _bSize; i++) {
        _lattice[i] = i;
        for (var j = 0; j < 2; j++) {
          s = _random(s);
          g[i * 2 + j] = ((s % (_bSize + _bSize)) - _bSize) / _bSize;
        }
        final len = math.sqrt(g[i * 2] * g[i * 2] + g[i * 2 + 1] * g[i * 2 + 1]);
        if (len != 0) {
          g[i * 2] /= len;
          g[i * 2 + 1] /= len;
        }
      }
    }
    while (--i > 0) {
      final k = _lattice[i];
      s = _random(s);
      final j = s % _bSize;
      _lattice[i] = _lattice[j];
      _lattice[j] = k;
    }
    for (i = 0; i < _bSize + 2; i++) {
      _lattice[_bSize + i] = _lattice[i];
      for (var k = 0; k < 4; k++) {
        final g = _gradient[k];
        g[(_bSize + i) * 2] = g[i * 2];
        g[(_bSize + i) * 2 + 1] = g[i * 2 + 1];
      }
    }
  }

  static double _sCurve(double t) => t * t * (3 - 2 * t);
  static double _lerp(double t, double a, double b) => a + t * (b - a);

  double _noise2(int channel, double vx, double vy, _Stitch? st) {
    var t = vx + _perlinN;
    var bx0 = t.toInt(), bx1 = bx0 + 1;
    final rx0 = t - t.toInt(), rx1 = rx0 - 1;
    t = vy + _perlinN;
    var by0 = t.toInt(), by1 = by0 + 1;
    final ry0 = t - t.toInt(), ry1 = ry0 - 1;
    if (st != null) {
      if (bx0 >= st.wrapX) bx0 -= st.width;
      if (bx1 >= st.wrapX) bx1 -= st.width;
      if (by0 >= st.wrapY) by0 -= st.height;
      if (by1 >= st.wrapY) by1 -= st.height;
    }
    bx0 &= _bm;
    bx1 &= _bm;
    by0 &= _bm;
    by1 &= _bm;
    final i = _lattice[bx0], j = _lattice[bx1];
    final b00 = _lattice[i + by0], b10 = _lattice[j + by0], b01 = _lattice[i + by1], b11 = _lattice[j + by1];
    final sx = _sCurve(rx0), sy = _sCurve(ry0);
    final g = _gradient[channel];
    var u = rx0 * g[b00 * 2] + ry0 * g[b00 * 2 + 1];
    var v = rx1 * g[b10 * 2] + ry0 * g[b10 * 2 + 1];
    final a = _lerp(sx, u, v);
    u = rx0 * g[b01 * 2] + ry1 * g[b01 * 2 + 1];
    v = rx1 * g[b11 * 2] + ry1 * g[b11 * 2 + 1];
    final b = _lerp(sx, u, v);
    return _lerp(sy, a, b);
  }

  /// The turbulence of [channel] at ([x], [y]) over a stitched tile
  /// [tileW] × [tileH] at the origin.
  double turbulence(int channel, double x, double y, double tileW, double tileH) {
    var fx = baseFrequencyX, fy = baseFrequencyY;
    // Frequencies adjusted so a whole number of lattice cells fits the tile.
    if (fx != 0) {
      final lo = (tileW * fx).floor() / tileW, hi = (tileW * fx).ceil() / tileW;
      fx = lo > 0 && fx / lo < hi / fx ? lo : hi;
    }
    if (fy != 0) {
      final lo = (tileH * fy).floor() / tileH, hi = (tileH * fy).ceil() / tileH;
      fy = lo > 0 && fy / lo < hi / fy ? lo : hi;
    }
    final w = (tileW * fx + 0.5).toInt(), h = (tileH * fy + 0.5).toInt();
    final st = _Stitch(w, h, _perlinN + w, _perlinN + h);
    var sum = 0.0, vx = x * fx, vy = y * fy, ratio = 1.0;
    for (var o = 0; o < numOctaves; o++) {
      final n = _noise2(channel, vx, vy, st);
      sum += fractalNoise ? n / ratio : n.abs() / ratio;
      vx *= 2;
      vy *= 2;
      ratio *= 2;
      st
        ..width *= 2
        ..wrapX = 2 * st.wrapX - _perlinN
        ..height *= 2
        ..wrapY = 2 * st.wrapY - _perlinN;
    }
    return sum;
  }

  /// A channel's value 0..255 at a pixel, as feTurbulence writes it.
  int channelAt(int channel, int px, int py, int tileW, int tileH) {
    final t = turbulence(channel, px.toDouble(), py.toDouble(), tileW.toDouble(), tileH.toDouble());
    final v = fractalNoise ? (t * 255 + 255) / 2 : t * 255;
    return v.round().clamp(0, 255);
  }

  /// The tile's RGBA bytes (straight alpha).
  Uint8List tile(int w, int h) {
    final out = Uint8List(w * h * 4);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        for (var c = 0; c < 4; c++) {
          out[(y * w + x) * 4 + c] = channelAt(c, x, y, w, h);
        }
      }
    }
    return out;
  }
}

class _Stitch {
  _Stitch(this.width, this.height, this.wrapX, this.wrapY);
  int width, height, wrapX, wrapY;
}

/// [rgba] (straight alpha, [w] × [h]) as a PNG file: stored (uncompressed)
/// deflate blocks, so it needs no zlib.
Uint8List encodePng(Uint8List rgba, int w, int h) {
  final raw = BytesBuilder(copy: false);
  for (var y = 0; y < h; y++) {
    raw.addByte(0); // filter: none
    raw.add(Uint8List.sublistView(rgba, y * w * 4, (y + 1) * w * 4));
  }
  final data = raw.takeBytes();
  final z = BytesBuilder(copy: false)..add([0x78, 0x01]);
  for (var i = 0; i < data.length; i += 65535) {
    final n = math.min(65535, data.length - i);
    final last = i + n >= data.length;
    z
      ..addByte(last ? 1 : 0)
      ..add([n & 0xff, n >> 8, (~n) & 0xff, ((~n) >> 8) & 0xff])
      ..add(Uint8List.sublistView(data, i, i + n));
  }
  var a = 1, b = 0;
  for (final v in data) {
    a = (a + v) % 65521;
    b = (b + a) % 65521;
  }
  final adler = (b << 16) | a;
  z.add([(adler >> 24) & 0xff, (adler >> 16) & 0xff, (adler >> 8) & 0xff, adler & 0xff]);
  final out = BytesBuilder(copy: false)..add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  void chunk(String type, List<int> body) {
    final t = ascii.encode(type);
    out
      ..add(_u32(body.length))
      ..add(t)
      ..add(body)
      ..add(_u32(_crc32([...t, ...body])));
  }

  chunk('IHDR', [..._u32(w), ..._u32(h), 8, 6, 0, 0, 0]);
  chunk('IDAT', z.takeBytes());
  chunk('IEND', const []);
  return out.takeBytes();
}

List<int> _u32(int v) => [(v >> 24) & 0xff, (v >> 16) & 0xff, (v >> 8) & 0xff, v & 0xff];

final Uint32List _crcTable = () {
  final t = Uint32List(256);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
    t[n] = c;
  }
  return t;
}();

int _crc32(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xff] ^ (c >> 8);
  }
  return (c ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}
