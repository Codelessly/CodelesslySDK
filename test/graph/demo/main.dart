// The graph prototype to try by hand: the three replicas of the tests
// (test/graph/replicas) and the first stock chart, one at a time.
//
//   cd example && flutter run -d chrome -t ../test/graph/demo/main.dart
import 'package:codelessly_sdk/graph.dart';
import 'package:flutter/widgets.dart';

import '../replicas/robinhood.dart';
import '../replicas/tradingview.dart';
import '../replicas/webull.dart';
import '../stock.dart';

void main() => runApp(const GraphDemo());

class GraphDemo extends StatefulWidget {
  const GraphDemo({super.key});

  @override
  State<GraphDemo> createState() => _GraphDemoState();
}

class _GraphDemoState extends State<GraphDemo> {
  static const tabs = ['Robinhood', 'Webull', 'TradingView', 'Prototype'];
  static const hints = [
    'Hover or touch the line: it snaps to the nearest point and the header follows. The ranges below swap the data.',
    'Hover: lines through the pointer, tags on both axes, a card up and left of it. The ranges above swap the data.',
    'Drag to pan, wheel to zoom about the pointer, drag the price axis to scale it (double click it to fit again), '
        'drag the time axis to zoom, hover for the crosshair and legend.',
    'The first prototype: candles, a 20-row average and a volume pane. "Add a bar" appends a row: it is followed '
        'while the last bar is in view, and left off screen once you have panned back.',
  ];
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF111827);
    return WidgetsApp(
      color: ink,
      debugShowCheckedModeBanner: false,
      builder: (context, _) => DefaultTextStyle(
        style: const TextStyle(fontFamily: 'Roboto', fontSize: 13, color: ink),
        child: ColoredBox(
          color: const Color(0xFFF3F4F6),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    for (var i = 0; i < tabs.length; i++)
                      GestureDetector(
                        onTap: () => setState(() => tab = i),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: i == tab ? ink : const Color(0xFFFFFFFF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(tabs[i],
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, color: i == tab ? const Color(0xFFFFFFFF) : ink)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(hints[tab], style: const TextStyle(color: Color(0xFF4B5563))),
                const SizedBox(height: 14),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    // One at a time, each with its own state.
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: switch (tab) {
                        0 => const RobinhoodPage(key: Key('robinhood'), fontFamily: 'Roboto'),
                        1 => const WebullPage(key: Key('webull'), fontFamily: 'Roboto'),
                        2 => const TradingViewPage(key: Key('tradingview'), fontFamily: 'Roboto'),
                        _ => const _Prototype(key: Key('prototype')),
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Prototype extends StatefulWidget {
  const _Prototype({super.key});

  @override
  State<_Prototype> createState() => _PrototypeState();
}

class _PrototypeState extends State<_Prototype> {
  int count = 500;
  late List<Json> rows = stockRows(count);
  final Json spec = stockSpec()..['style'] = {'fontFamily': 'Roboto'};
  Json state = const {};

  @override
  Widget build(BuildContext context) {
    final view = state['view'] as Json?;
    final cursor = (state['cursor'] as Json?)?['row'] as Json?;
    String n(Object? v) => v is num ? v.toStringAsFixed(2) : '-';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => setState(() => rows = stockRows(++count)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFF2962FF), borderRadius: BorderRadius.circular(6)),
                child: const Text('Add a bar', style: TextStyle(color: Color(0xFFFFFFFF), fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 16),
            // The graph's published state, as a page's texts would read it.
            Text(view == null
                ? ''
                : 'rows ${view['first']} to ${view['last']} of $count   '
                    'at end: ${view['atEnd']}   price axis fitted: ${(view['auto']! as List).first}'),
            const SizedBox(width: 16),
            Text(cursor == null
                ? ''
                : 'O ${n(cursor['o'])}  H ${n(cursor['h'])}  L ${n(cursor['l'])}  C ${n(cursor['c'])}  '
                    'MA20 ${n(cursor['ma20'])}'),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: 900,
          height: 460,
          child: CodelesslyGraph(spec: spec, data: rows, onState: (s) => setState(() => state = s)),
        ),
      ],
    );
  }
}
