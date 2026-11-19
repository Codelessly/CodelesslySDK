// The stock chart of Robinhood's web page, as a graph spec and the page
// around it. Sizes, colors and behavior are as measured on the live page
// (robinhood.com/us/en/stocks/AAPL, 2026-11-19): a 272 x 196 plot with no
// axes, a 2 px line in sessions (the one in use opaque, the others at half),
// a dotted previous-close line band by band over the whole day, and a hover
// that snaps to the nearest point with a 1 px rule, a ringed dot, the time
// above the plot, and the header's price and change following it.
//
// The page's texts read the graph's published state, as a Codelessly page's
// Text nodes would read its variables.
import 'dart:math' as math;

import 'package:codelessly_sdk/graph.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'rolling_text.dart';

const robinhoodUp = Color(0xFF00C805);
const robinhoodDown = Color(0xFFFF5000);
const robinhoodGrey = Color(0xFF6A7278);
const robinhoodRanges = ['1D', '1W', '1M', '3M', 'YTD', '1Y', '5Y', 'ALL'];

String _hex(Color c) => '#${c.toARGB32().toRadixString(16).padLeft(8, '0')}';

/// The session of a 5-minute slot of the day (slot 0 is midnight).
String robinhoodSession(int slot) => slot < 48
    ? 'overnight'
    : slot < 114
        ? 'pre'
        : slot < 192
            ? 'regular'
            : 'after';

const robinhoodSessionLabels = {
  'overnight': 'Overnight',
  'pre': 'Pre-market',
  'regular': 'Today',
  'after': 'After-hours',
};

/// A day so far: a point every five minutes from midnight to 12:05 PM.
List<Json> robinhoodDay({double previousClose = 352.45, int points = 146, int seed = 3}) {
  final random = math.Random(seed);
  final day = DateTime.utc(2026, 11, 19).millisecondsSinceEpoch;
  var price = previousClose + 1.4;
  return [
    for (var i = 0; i < points; i++)
      {
        't': day + i * 300000,
        // Flat-ish overnight, then a fall after the open (as the day read).
        'c': price += (random.nextDouble() - 0.5) * 0.9 + (i > 112 && i < 124 ? -0.75 : 0),
        'session': robinhoodSession(i),
      },
  ];
}

/// A longer range: [points] closes ending now.
List<Json> robinhoodRange(int points, {int seed = 5, Duration step = const Duration(days: 1)}) {
  final random = math.Random(seed);
  final end = DateTime.utc(2026, 11, 19).millisecondsSinceEpoch;
  var price = 300.0;
  return [
    for (var i = 0; i < points; i++)
      {
        't': end - (points - 1 - i) * step.inMilliseconds,
        'c': price += (random.nextDouble() - 0.42) * 4,
      },
  ];
}

/// The chart. [baseline] is the price the change is measured from: the
/// previous close on a day, the first point on a longer range.
Json robinhoodSpec({required List<Json> rows, required double baseline, bool day = true, String? fontFamily}) {
  final up = (rows.last['c']! as double) >= baseline;
  return {
    'type': 'graph',
    'key': 't',
    'x': {
      'label': 't',
      'format': day ? 'h:mm a' : 'MMM d, yyyy',
      'fit': 'points',
      // A range change moves the line to its new shape.
      'morph': 300,
      if (day) 'slots': 288,
      'labels': false,
      'axisHeight': 0,
      if (day)
        'bands': [
          {'id': 'overnight', 'from': 0, 'to': 48, 'group': 'pre'},
          {'id': 'pre', 'from': 48, 'to': 114, 'group': 'pre'},
          {'id': 'regular', 'from': 114, 'to': 192},
          {'id': 'after', 'from': 192, 'to': 287},
        ],
    },
    'panes': [
      {
        'y': {
          'width': 0,
          'labels': false,
          'margins': [0, 0],
          if (day) 'include': [baseline],
        },
        'marks': [
          {
            'type': 'line',
            'y': 'c',
            'color': _hex(up ? robinhoodUp : robinhoodDown),
            'width': 2,
            if (day) 'segmentBy': 'session',
            if (day) 'dimInactive': 0.5,
          },
        ],
        if (day)
          'priceLines': [
            {
              'value': baseline,
              'color': _hex(robinhoodGrey),
              'activeColor': '#000000',
              'line': 'dotted',
              'tag': false,
              'byBand': true,
            },
          ],
      },
    ],
    'crosshair': {
      'magnet': 'c',
      'on': 'touch',
      'horizontal': false,
      'line': 'solid',
      'dot': 5,
      'dotStroke': 2,
      'timeLabel': 'top',
      'priceTag': false,
    },
    'interactions': {
      'dragPan': false,
      'wheelZoom': false,
      'pinchZoom': false,
      'axisScale': false,
      'doubleTapReset': false,
      'fling': false,
    },
    'style': {
      'background': '#FFFFFF',
      'grid': '#00000000',
      'text': _hex(robinhoodGrey),
      'crosshair': _hex(robinhoodGrey),
      'fontSize': 13,
      'topInset': 24,
      if (fontFamily != null) 'fontFamily': fontFamily,
    },
  };
}

class RobinhoodPage extends StatefulWidget {
  const RobinhoodPage({super.key, this.previousClose = 352.45, this.fontFamily});
  final double previousClose;
  final String? fontFamily;

  @override
  State<RobinhoodPage> createState() => RobinhoodPageState();
}

class RobinhoodPageState extends State<RobinhoodPage> {
  String range = '1D';
  late List<Json> rows = robinhoodDay(previousClose: widget.previousClose);
  Json graph = const {};

  bool get day => range == '1D';
  double get baseline => day ? widget.previousClose : rows.first['c']! as double;
  Json get spec => robinhoodSpec(rows: rows, baseline: baseline, day: day, fontFamily: widget.fontFamily);

  /// The row the header reads: under the cursor, else the last.
  Json get row => ((graph['cursor'] as Json?)?['row'] as Json?) ?? rows.last;
  double get price => row['c']! as double;
  double get change => price - baseline;
  String get priceText => '\$${price.toStringAsFixed(2)}';
  String get changeText {
    final sign = change < 0 ? '-' : '+';
    return '$sign\$${change.abs().toStringAsFixed(2)} ($sign${(change.abs() / baseline * 100).toStringAsFixed(2)}%)';
  }

  String get sessionText => day
      ? robinhoodSessionLabels[row['session']]!
      : const {'1W': 'Past week', '1M': 'Past month', '3M': 'Past 3 months', 'YTD': 'Year to date', '1Y': 'Past year', '5Y': 'Past 5 years', 'ALL': 'All time'}[range]!;

  void select(String next) => setState(() {
        range = next;
        rows = switch (next) {
          '1D' => robinhoodDay(previousClose: widget.previousClose),
          '1W' => robinhoodRange(390, step: const Duration(minutes: 5)),
          '1M' => robinhoodRange(22),
          '3M' => robinhoodRange(64),
          'YTD' => robinhoodRange(222),
          '1Y' => robinhoodRange(252),
          '5Y' => robinhoodRange(260, step: const Duration(days: 7)),
          _ => robinhoodRange(400, step: const Duration(days: 30)),
        };
      });

  @override
  Widget build(BuildContext context) {
    TextStyle text(double size, FontWeight weight, [Color color = const Color(0xFF000000), double spacing = 0]) =>
        TextStyle(fontSize: size, fontWeight: weight, color: color, letterSpacing: spacing, fontFamily: widget.fontFamily, height: 1.25);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        width: 400,
        height: 480,
        color: const Color(0xFFFFFFFF),
        child: Stack(
          children: [
            Positioned(left: 24, top: 20, child: Text('Apple', style: text(32, FontWeight.w500, const Color(0xFF000000), -0.33))),
            Positioned(
              left: 24,
              top: 60,
              child: RollingText(priceText, key: const Key('price'), style: text(32, FontWeight.w500, const Color(0xFF000000), -0.33)),
            ),
            Positioned(
              left: 24,
              top: 105,
              child: Row(
                children: [
                  Text(changeText, key: const Key('change'), style: text(13, FontWeight.w700, change < 0 ? robinhoodDown : robinhoodUp)),
                  Text(' $sessionText', key: const Key('session'), style: text(13, FontWeight.w400)),
                ],
              ),
            ),
            if (day) Positioned(left: 24, top: 132, child: Text('24 Hour Market', style: text(13, FontWeight.w700))),
            Positioned(
              // Keyed: the line above comes and goes with the range, and the
              // graph must stay the same one to move between them.
              key: const Key('graph'),
              left: 24,
              top: 167,
              width: 272,
              height: 220,
              child: CodelesslyGraph(
                spec: spec,
                data: rows,
                onState: (s) => setState(() => graph = s),
              ),
            ),
            Positioned(
              left: 24,
              top: 431,
              child: Row(
                children: [
                  for (final r in robinhoodRanges)
                    Padding(
                      padding: const EdgeInsets.only(right: 18),
                      child: GestureDetector(
                        key: Key('range-$r'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => select(r),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r, style: text(13, FontWeight.w700, const Color(0xFF000000), 2)),
                            const SizedBox(height: 10),
                            Container(width: 14, height: 2, color: r == range ? const Color(0xFF000000) : const Color(0x00000000)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A time as the page writes it over the rule.
String robinhoodTime(int ms) => DateFormat('h:mm a').format(DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true));
