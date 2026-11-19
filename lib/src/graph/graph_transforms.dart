// Fields worked out over the rows before a row (window transforms): the
// moving averages and oscillators a price chart overlays. Each is a record
// of the spec; a row with too few rows before it has no value (a gap).
import 'dart:math' as math;

import 'graph_spec.dart';

double? _num(Object? v) => v is num && v.isFinite ? v.toDouble() : null;

/// [rows] with each of [transforms]' fields written into them, and `_i`,
/// each row's position.
List<Json> applyGraphTransforms(List<Json> rows, List<GraphTransformSpec> transforms) {
  final out = [
    for (var i = 0; i < rows.length; i++) {...rows[i], '_i': i},
  ];
  for (final t in transforms) {
    final src = [for (final r in out) _num(r[t.field])];
    switch (t.type) {
      case 'sma':
        _write(out, t.as, sma(src, t.period));
      case 'ema':
        _write(out, t.as, ema(src, t.period));
      case 'rsi':
        _write(out, t.as, rsi(src, t.period));
      case 'bollinger':
        final mid = sma(src, t.period), dev = stddev(src, t.period);
        _write(out, '${t.as}Mid', mid);
        _write(out, '${t.as}Upper', [
          for (var i = 0; i < mid.length; i++) mid[i] == null || dev[i] == null ? null : mid[i]! + t.k * dev[i]!,
        ]);
        _write(out, '${t.as}Lower', [
          for (var i = 0; i < mid.length; i++) mid[i] == null || dev[i] == null ? null : mid[i]! - t.k * dev[i]!,
        ]);
    }
  }
  return out;
}

void _write(List<Json> rows, String field, List<double?> values) {
  for (var i = 0; i < rows.length; i++) {
    rows[i][field] = values[i];
  }
}

/// The mean of the last [period] values.
List<double?> sma(List<double?> v, int period) {
  final out = List<double?>.filled(v.length, null);
  var sum = 0.0, n = 0;
  for (var i = 0; i < v.length; i++) {
    final x = v[i];
    if (x == null) {
      sum = 0;
      n = 0;
      continue;
    }
    sum += x;
    n++;
    if (n > period) {
      sum -= v[i - period]!;
      n--;
    }
    if (n == period) out[i] = sum / period;
  }
  return out;
}

/// The exponential mean, seeded with the first [period] values' mean.
List<double?> ema(List<double?> v, int period) {
  final out = List<double?>.filled(v.length, null);
  final seed = sma(v, period);
  final a = 2 / (period + 1);
  double? last;
  for (var i = 0; i < v.length; i++) {
    final x = v[i];
    if (x == null) {
      last = null;
    } else if (last == null) {
      last = seed[i];
    } else {
      last = x * a + last * (1 - a);
    }
    out[i] = last;
  }
  return out;
}

/// The standard deviation of the last [period] values.
List<double?> stddev(List<double?> v, int period) {
  final mean = sma(v, period);
  return [
    for (var i = 0; i < v.length; i++)
      if (mean[i] == null)
        null
      else
        math.sqrt([
              for (var k = i - period + 1; k <= i; k++) (v[k]! - mean[i]!) * (v[k]! - mean[i]!),
            ].reduce((a, b) => a + b) /
            period),
  ];
}

/// Wilder's relative strength index, 0 to 100.
List<double?> rsi(List<double?> v, int period) {
  final out = List<double?>.filled(v.length, null);
  var gain = 0.0, loss = 0.0, n = 0;
  for (var i = 1; i < v.length; i++) {
    final a = v[i - 1], b = v[i];
    if (a == null || b == null) {
      gain = loss = 0;
      n = 0;
      continue;
    }
    final up = math.max(0.0, b - a), down = math.max(0.0, a - b);
    if (n < period) {
      gain += up;
      loss += down;
      n++;
      if (n < period) continue;
      gain /= period;
      loss /= period;
    } else {
      gain = (gain * (period - 1) + up) / period;
      loss = (loss * (period - 1) + down) / period;
    }
    out[i] = loss == 0 ? 100 : 100 - 100 / (1 + gain / loss);
  }
  return out;
}
