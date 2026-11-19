// A stock chart as data, and rows for it: what the graph tests draw.
import 'dart:math' as math;

import 'package:codelessly_sdk/graph.dart' show Json;

/// Price candles with a 20-row average and a last-price line over a volume
/// pane: the chart of a trading app, with nothing but JSON.
Json stockSpec({String mode = 'linear', String follow = 'end'}) => {
      'type': 'graph',
      'key': 't',
      'x': {'label': 't', 'format': 'MMM d', 'barSpacing': 8, 'rightOffset': 3, 'follow': follow, 'historyThreshold': 10},
      'transforms': [
        {'type': 'sma', 'field': 'c', 'period': 20, 'as': 'ma20'},
      ],
      'panes': [
        {
          'grow': 3,
          'y': {
            'domain': 'visible',
            'margins': [0.1, 0.1],
            'mode': mode,
          },
          'marks': [
            {'type': 'candle', 'open': 'o', 'high': 'h', 'low': 'l', 'close': 'c'},
            {'type': 'line', 'y': 'ma20', 'color': '#F59E0B'},
          ],
          'priceLines': [
            {'field': 'c', 'color': '#2962FF'},
          ],
        },
        {
          'grow': 1,
          'y': {'decimals': 0},
          'marks': [
            {'type': 'bar', 'y': 'v', 'open': 'o', 'close': 'c', 'upColor': '#8026A69A', 'downColor': '#80EF5350'},
          ],
        },
      ],
      'crosshair': {'magnet': 'c'},
    };

/// [n] daily rows of a seeded walk, the first at day [start]. The same
/// seed gives the same rows, so a longer history shares its later rows.
List<Json> stockRows(int n, {int start = 0, int seed = 7}) {
  final all = <Json>[];
  final random = math.Random(seed);
  var price = 100.0;
  final day0 = DateTime.utc(2024, 1, 1).millisecondsSinceEpoch;
  // The walk is generated from day -1000 so rows before `start` exist.
  for (var d = -1000; d < start + n; d++) {
    final open = price;
    // A slow wave under the noise, so a window's extent differs from the
    // whole's.
    final close = open + (random.nextDouble() - 0.5) * 3 + math.sin(d / 40) * 0.8;
    final high = math.max(open, close) + random.nextDouble() * 1.5;
    final low = math.min(open, close) - random.nextDouble() * 1.5;
    price = close;
    final volume = 1000000 + random.nextInt(4000000);
    if (d < start) continue;
    all.add({
      't': day0 + d * 86400000,
      'o': open,
      'h': high,
      'l': low,
      'c': close,
      'v': volume,
    });
  }
  return all;
}
