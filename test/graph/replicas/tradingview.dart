// TradingView's main chart, as a graph spec and the page around it. As seen
// on the live chart (tradingview.com/chart, NASDAQ:AAPL daily, 2026-11-19):
// candles (#089981 up, #F23645 down) with volume bars on a scale of their
// own in the bottom of the same pane, a price axis on the right, a dotted
// last-price line with its tag, a legend at the top left that reads the bar
// under the pointer (the last one at rest), and a dashed crosshair through
// the pointer with dark tags on both axes. The view is the user's: a drag
// pans, the wheel zooms about the pointer, the price axis fits the bars in
// view until it is dragged.
import 'dart:math' as math;

import 'package:codelessly_sdk/graph.dart';
import 'package:flutter/widgets.dart';

const tradingViewUp = Color(0xFF089981);
const tradingViewDown = Color(0xFFF23645);
const tradingViewInk = Color(0xFF131722);

String _hex(Color c) => '#${c.toARGB32().toRadixString(16).padLeft(8, '0')}';

/// [days] daily bars ending now.
List<Json> tradingViewBars(int days, {int seed = 21}) {
  final random = math.Random(seed);
  final end = DateTime.utc(2026, 11, 19).millisecondsSinceEpoch;
  var price = 240.0;
  return [
    for (var i = 0; i < days; i++)
      () {
        final open = price + (random.nextDouble() - 0.5) * 2;
        final close = open + (random.nextDouble() - 0.44) * 7;
        price = close;
        return <String, Object?>{
          't': end - (days - 1 - i) * 86400000,
          'o': open,
          'h': math.max(open, close) + random.nextDouble() * 3,
          'l': math.min(open, close) - random.nextDouble() * 3,
          'c': close,
          'v': 30000000 + random.nextInt(60000000),
        };
      }(),
  ];
}

Json tradingViewSpec({required List<Json> rows, String? fontFamily, String countdown = '', bool moreHistory = true}) {
  final last = rows.last;
  final up = (last['c']! as double) >= (last['o']! as double);
  return {
    'type': 'graph',
    'key': 't',
    'x': {
      'label': 't',
      'format': 'MMM d',
      'ticks': 'calendar',
      'barSpacing': 6,
      'rightOffset': 5,
      'axisHeight': 28,
      // Older bars are asked for a screen and more before the first one is
      // reached, so a drag back never runs out of bars.
      'historyThreshold': 200,
      'moreHistory': moreHistory,
    },
    'panes': [
      {
        'y': {
          'width': 56,
          'margins': [0.1, 0.1],
        },
        'marks': [
          {'type': 'bar', 'y': 'v', 'open': 'o', 'close': 'c', 'upColor': '#FF92D2CC', 'downColor': '#FFF7A9A7', 'overlay': 0.2},
          {
            'type': 'candle',
            'open': 'o',
            'high': 'h',
            'low': 'l',
            'close': 'c',
            'upColor': _hex(tradingViewUp),
            'downColor': _hex(tradingViewDown),
          },
        ],
        'priceLines': [
          {'field': 'c', 'color': _hex(up ? tradingViewUp : tradingViewDown), 'line': 'dotted', 'note': countdown},
        ],
        // Earnings and dividends, on their days.
        'markers': [
          // By the day itself, so a badge stays on its day as older bars load.
          for (final r in rows)
            if (((r['t']! as int) ~/ 86400000) % 63 == 5)
              {'at': r['t'], 'text': 'E', 'color': _hex(tradingViewDown)}
            else if (((r['t']! as int) ~/ 86400000) % 63 == 40)
              {'at': r['t'], 'text': 'D', 'color': '#FF2962FF'},
        ],
      },
    ],
    'crosshair': {'on': 'both', 'line': 'dashed', 'timeFormat': "EEE dd MMM ''yy"},
    'style': {
      'background': '#FFFFFF',
      'grid': '#FFF0F3FA',
      'text': _hex(tradingViewInk),
      'crosshair': '#FF9598A1',
      'tag': _hex(tradingViewInk),
      'tagText': '#FFFFFF',
      'fontSize': 12,
      if (fontFamily != null) 'fontFamily': fontFamily,
    },
  };
}

String tradingViewVolume(num v) => '${(v / 1e6).toStringAsFixed(2)} M';

class TradingViewPage extends StatefulWidget {
  const TradingViewPage({super.key, this.fontFamily, this.history = 2800, this.loadDelay = const Duration(milliseconds: 350)});
  final String? fontFamily;

  /// The bars there are in all (the page shows the last 400 and loads the
  /// rest as the view goes back), and how long a load takes.
  final int history;
  final Duration loadDelay;

  @override
  State<TradingViewPage> createState() => TradingViewPageState();
}

class TradingViewPageState extends State<TradingViewPage> {
  /// Every bar the "server" has; [rows] is the part loaded so far.
  late final List<Json> all = tradingViewBars(widget.history);
  late List<Json> rows = all.sublist(all.length - 400);
  int loads = 0;

  /// How many of [all], from its end, are loaded.
  int loaded = 400;

  bool get moreHistory => loaded < all.length;
  bool get loading => (graph['view'] as Json?)?['loadingHistory'] == true;

  /// The graph asks for older bars: 300 more come after a moment, put
  /// before the ones there are.
  Future<void> loadOlder() async {
    loads++;
    await Future<void>.delayed(widget.loadDelay);
    if (!mounted) return;
    final from = (all.length - loaded - 300).clamp(0, all.length);
    setState(() {
      rows = [...all.sublist(from, all.length - loaded), ...rows];
      loaded = all.length - from;
    });
  }
  Json graph = const {};

  /// The time to the bar's close, as the page's clock would write it.
  String countdown = '03:17:11';

  Json get spec => tradingViewSpec(rows: rows, fontFamily: widget.fontFamily, countdown: countdown, moreHistory: moreHistory);

  void setCountdown(String next) => setState(() => countdown = next);
  Json get view => graph['view']! as Json;

  /// The bar the legend reads: under the pointer, else the last.
  Json get bar => ((graph['cursor'] as Json?)?['row'] as Json?) ?? rows.last;

  String get legend {
    final b = bar, i = rows.indexWhere((r) => r['t'] == b['t']);
    final before = i > 0 ? rows[i - 1]['c']! as double : b['o']! as double;
    final change = (b['c']! as double) - before;
    String n(Object? v) => (v! as double).toStringAsFixed(2);
    final sign = change < 0 ? '−' : '+';
    return 'O${n(b['o'])} H${n(b['h'])} L${n(b['l'])} C${n(b['c'])} '
        '$sign${change.abs().toStringAsFixed(2)} ($sign${(change.abs() / before * 100).toStringAsFixed(2)}%)';
  }

  bool get barUp => (bar['c']! as double) >= (bar['o']! as double);

  void setRows(List<Json> next) => setState(() => rows = next);

  @override
  Widget build(BuildContext context) {
    TextStyle text(double size, Color color, [FontWeight weight = FontWeight.w400]) =>
        TextStyle(fontSize: size, color: color, fontWeight: weight, fontFamily: widget.fontFamily, height: 1.3);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        width: 760,
        height: 520,
        color: const Color(0xFFFFFFFF),
        child: Stack(
          children: [
            Positioned.fill(
              child: CodelesslyGraph(
                spec: spec,
                data: rows,
                onState: (s) => setState(() => graph = s),
                onNeedHistory: (_) => loadOlder(),
              ),
            ),
            Positioned(
              left: 10,
              top: 8,
              child: IgnorePointer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Apple Inc · 1D · NASDAQ  ', style: text(14, tradingViewInk)),
                        Text(legend, key: const Key('legend'), style: text(12, barUp ? tradingViewUp : tradingViewDown)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (loading) Text('Loading older bars\u2026  ', key: const Key('loading'), style: text(12, const Color(0xFF787B86))),
                        Text('Vol ', style: text(12, tradingViewInk)),
                        Text(tradingViewVolume(bar['v']! as num),
                            key: const Key('volume'), style: text(12, barUp ? tradingViewUp : tradingViewDown)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
