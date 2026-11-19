// The chart of Webull's quote page, as a graph spec and the page around it.
// As measured on the live page (webull.com/quote/nasdaq-aapl, 2026-11-19):
// an 844 x 480 canvas, a 1.5 px line (#00B28E up, #F24F5B down) over a fill
// that fades out, volume bars on a scale of their own in the bottom of the
// same pane, a price axis on the right and a time axis below, a day laid
// out over its whole session (the line ends partway), a blue dot pulsing on
// the last point, and a hover with dashed blue lines through the pointer,
// blue tags on both axes and a card up and left of the pointer.
import 'dart:math' as math;

import 'package:codelessly_sdk/graph.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

const webullUp = Color(0xFF00B28E);
const webullDown = Color(0xFFF24F5B);
const webullBlue = Color(0xFF0057FF);
const webullTab = Color(0xFF007CFF);
const webullRanges = ['1D', '5D', '1M', '3M', '1Y', '5Y'];

String _hex(Color c) => '#${c.toARGB32().toRadixString(16).padLeft(8, '0')}';

/// A session so far: a row a minute from 9:30 to [minutes] later.
List<Json> webullDay({double previousClose = 352.45, int minutes = 157, int seed = 11}) {
  final random = math.Random(seed);
  final open = DateTime.utc(2026, 11, 19, 9, 30).millisecondsSinceEpoch;
  var price = previousClose + 2.5;
  return [
    for (var i = 0; i < minutes; i++)
      () {
        final before = price;
        price += (random.nextDouble() - 0.5) * 0.5 + (i < 10 ? -0.55 : 0) + (i > 145 ? -0.3 : 0);
        return <String, Object?>{
          't': open + i * 60000,
          'o': before,
          'c': price,
          'v': (20000 + random.nextInt(60000)) * (i < 5 ? 6 : 1),
        };
      }(),
  ];
}

/// [days] daily rows ending now.
List<Json> webullDaily(int days, {int seed = 13}) {
  final random = math.Random(seed);
  final end = DateTime.utc(2026, 11, 18).millisecondsSinceEpoch;
  var price = 342.0;
  return [
    for (var i = 0; i < days; i++)
      () {
        final before = price;
        price += (random.nextDouble() - 0.46) * 6;
        return <String, Object?>{
          't': end - (days - 1 - i) * 86400000,
          'o': before,
          'c': price,
          'v': 40000000 + random.nextInt(50000000),
        };
      }(),
  ];
}

Json webullSpec({required List<Json> rows, required double baseline, bool day = true, String? fontFamily}) {
  final color = (rows.last['c']! as double) >= baseline ? webullUp : webullDown;
  return {
    'type': 'graph',
    'key': 't',
    'x': {
      'label': 't',
      'format': day ? 'HH:mm' : 'MM/dd',
      'fit': 'bars',
      if (day) 'slots': 390,
      if (day) 'tickEvery': 30,
      'axisHeight': 28,
    },
    'panes': [
      {
        'y': {
          'width': 60,
          // Room under the line for the volume bars.
          'margins': [0.08, 0.3],
        },
        'marks': [
          {'type': 'area', 'y': 'c', 'color': _hex(color), 'fillOpacity': 0.2, 'fade': true},
          {'type': 'bar', 'y': 'v', 'open': 'o', 'close': 'c', 'upColor': '#8000B28E', 'downColor': '#80F24F5B', 'overlay': 0.2},
          {'type': 'line', 'y': 'c', 'color': _hex(color), 'width': 1.5, 'endDot': 3, 'endDotColor': _hex(webullBlue), 'pulse': day},
        ],
      },
    ],
    'crosshair': {'on': 'hover', 'line': 'dashed', 'timeFormat': day ? 'MM/dd HH:mm' : 'MM/dd/yyyy'},
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
      'grid': '#FFF2F3F5',
      'text': '#FF979BA1',
      'crosshair': _hex(webullBlue),
      'tag': _hex(webullBlue),
      'tagText': '#FFFFFF',
      'fontSize': 12,
      if (fontFamily != null) 'fontFamily': fontFamily,
    },
  };
}

class WebullPage extends StatefulWidget {
  const WebullPage({super.key, this.previousClose = 352.45, this.fontFamily});
  final double previousClose;
  final String? fontFamily;

  @override
  State<WebullPage> createState() => WebullPageState();
}

class WebullPageState extends State<WebullPage> {
  static const cardSize = Size(132, 84);

  String range = '1D';
  late List<Json> rows = webullDay(previousClose: widget.previousClose);
  Json graph = const {};

  bool get day => range == '1D';
  double get baseline => day ? widget.previousClose : rows.first['o']! as double;
  Json get spec => webullSpec(rows: rows, baseline: baseline, day: day, fontFamily: widget.fontFamily);
  Json? get cursor => graph['cursor'] as Json?;

  /// What a row's change is measured from: the previous close on a day, the
  /// row before on a longer range.
  double reference(Json row) {
    final i = row['_i']! as int;
    return day || i == 0 ? baseline : rows[i - 1]['c']! as double;
  }

  String changeText(Json row) {
    final pct = ((row['c']! as double) / reference(row) - 1) * 100;
    return '${pct < 0 ? '' : '+'}${pct.toStringAsFixed(2)}%';
  }

  /// Where the card sits: its bottom right corner up and left of the
  /// pointer, turned to the other side where it would leave the plot.
  Offset cardOrigin(Json cursor) {
    final x = cursor['x']! as double, y = cursor['y']! as double;
    final left = x - 6 - cardSize.width, top = y - 6 - cardSize.height;
    return Offset(left < 0 ? x + 6 : left, top < 0 ? y + 6 : top);
  }

  void select(String next) => setState(() {
        range = next;
        rows = switch (next) {
          '1D' => webullDay(previousClose: widget.previousClose),
          '5D' => webullDaily(5),
          '1M' => webullDaily(22),
          '3M' => webullDaily(64),
          '1Y' => webullDaily(252),
          _ => webullDaily(1260),
        };
      });

  @override
  Widget build(BuildContext context) {
    TextStyle text(double size, FontWeight weight, Color color) =>
        TextStyle(fontSize: size, fontWeight: weight, color: color, fontFamily: widget.fontFamily, height: 1.2);
    final cursor = this.cursor;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        width: 864,
        height: 540,
        color: const Color(0xFFFFFFFF),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                for (final r in webullRanges)
                  GestureDetector(
                    key: Key('range-$r'),
                    onTap: () => select(r),
                    child: Container(
                      width: 45,
                      height: 34,
                      margin: const EdgeInsets.only(right: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: r == range ? webullTab : const Color(0x00000000),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(r, style: text(16, FontWeight.w700, r == range ? const Color(0xFFFFFFFF) : const Color(0xFF000000))),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 844,
              height: 480,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CodelesslyGraph(spec: spec, data: rows, onState: (s) => setState(() => graph = s)),
                  ),
                  if (cursor != null)
                    Positioned(
                      left: cardOrigin(cursor).dx,
                      top: cardOrigin(cursor).dy,
                      child: IgnorePointer(
                        child: Container(
                          key: const Key('card'),
                          width: cardSize.width,
                          height: cardSize.height,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFFFF),
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: const [BoxShadow(color: Color(0x29000000), blurRadius: 12, offset: Offset(0, 2))],
                          ),
                          child: () {
                            final row = cursor['row']! as Json;
                            final up = (row['c']! as double) >= reference(row);
                            final value = text(11, FontWeight.w400, up ? webullUp : webullDown);
                            final label = text(11, FontWeight.w400, const Color(0xFF636872));
                            final time = DateTime.fromMillisecondsSinceEpoch(row['t']! as int, isUtc: true);
                            Widget line(String name, String v, Key key) => Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(name, style: label),
                                    Expanded(
                                      child: Text(v,
                                          key: key, style: value, textAlign: TextAlign.right, maxLines: 1, softWrap: false, overflow: TextOverflow.clip),
                                    ),
                                  ],
                                );
                            return Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(DateFormat(day ? 'MM/dd HH:mm' : 'MM/dd/yyyy').format(time),
                                    key: const Key('card-time'),
                                    maxLines: 1,
                                    softWrap: false,
                                    overflow: TextOverflow.clip,
                                    style: text(11, FontWeight.w400, const Color(0xFF1A1A1A))),
                                line('Price', (row['c']! as double).toStringAsFixed(2), const Key('card-price')),
                                line('Chg%', changeText(row), const Key('card-change')),
                                line('Volume', NumberFormat('#,##0.00').format(row['v']), const Key('card-volume')),
                              ],
                            );
                          }(),
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
