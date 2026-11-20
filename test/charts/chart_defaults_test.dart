import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/graph.dart' show GraphEngine, GraphSpec, graphPalette;
import 'package:codelessly_sdk/src/render/surface_roles.dart';
import 'package:codelessly_sdk/src/widgets/chart_words.dart';
import 'package:codelessly_sdk/src/widgets/indicator_theme.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// What a chart type looks like when its node says nothing more than its
// data: each default here is one the chart's own key turns off or changes.

Node node(String type, Map<String, Object?> props) => Node.fromJson({'type': type, 'props': props}, id: 'c')!;

GraphEngine engineOf(Node n, [Size size = const Size(400, 200)]) {
  final chart = chartGraphOf(n)!;
  return GraphEngine(GraphSpec.fromJson(chart.spec), data: chart.data)
    ..resize(size)
    ..select(chart.selected);
}

Map<String, Object?> series(String type, int rows, [Map<String, Object?> extra = const {}, String kind = 'line']) => {
      'chartType': type,
      'data': [
        for (var i = 0; i < rows; i++) {'label': 'r$i', 'a': 12 + i * 3, 'b': 4 + i},
      ],
      'series': <Map<String, Object?>>[
        {'field': 'a', 'name': 'New', 'kind': kind},
        {'field': 'b', 'name': 'Back', 'kind': kind},
      ],
      ...extra,
    };

Map<String, Object?> donut([Map<String, Object?> extra = const {}]) => {
      'chartType': 'donut',
      'donutThickness': 0.2,
      'series': [
        {'field': 'value', 'colorField': 'color'},
      ],
      'data': [
        {'label': 'Rent', 'value': 60},
        {'label': 'Food', 'value': 40},
      ],
      ...extra,
    };

void main() {
  group('a node that leaves its keys out draws as its type always has', () {
    test('a chart: no legend, no tooltip, no dots, square bars, a scale with the margins of its values', () {
      final e = engineOf(node('chart', series('line', 4)), const Size(600, 300));
      expect(e.spec.legend.show, 'none');
      expect(e.legend, isNull);
      expect((e.spec.selection.on, e.spec.selection.tooltip), ('none', false));
      expect(e.spec.crosshair.enabled, isFalse);
      expect([for (final m in e.spec.panes.single.marks) m.dots], [0.0, 0.0]);
      expect(e.spec.panes.single.y.nice, isFalse);
      expect((e.spec.x.inset, e.spec.style.topInset, e.spec.style.fontSize), (0.0, 0.0, 10.0));
      expect(e.xOfRow(0), closeTo(e.plotLeft, 0.001));
      final bars = engineOf(node('chart', series('bar', 2, const {}, 'bar')), const Size(800, 200));
      expect(bars.spec.panes.single.marks.first.radius, 0);
      expect(bars.spec.x.maxBarWidth, isNull);
      final area = engineOf(node('chart', series('line', 4, const {}, 'area'))).spec.panes.single.marks.first;
      expect((area.type, area.fade), ('area', false));
      final ring = engineOf(node('chart', donut()), const Size(500, 200));
      expect(ring.legend, isNull);
      expect(ring.spec.panes.single.marks.single.center, '');
      expect(ring.arcGeometry(0, ring.spec.panes.single.marks.single).$1, const Offset(250, 100));
    });

    test('a lineChart: no lines or figures of its own, nothing under the pointer', () {
      final e = engineOf(node('lineChart', {
        'data': [
          for (final (i, v) in [12, 18, 14, 22].indexed) {'x': i, 'y': v},
        ],
      }));
      final y = e.spec.panes.single.y;
      expect((y.labels, y.ticks, y.nice), (false, 0, false));
      expect((e.spec.selection.on, e.spec.crosshair.enabled), ('none', false));
    });

    test('a barChart: drawn, not offered, as high as its largest value', () {
      final e = engineOf(node('barChart', {
        'values': [12, 18, 27],
      }));
      expect((e.spec.selection.on, e.spec.selection.tooltip), ('none', false));
      expect(e.yDomain(0), (0.0, 27.0));
      expect(e.plotLeft, 0);
      expect(e.spec.style.topInset, 0);
    });
  });

  group('chart', () {
    test('legend: a key for each of two or more named series', () {
      final e = engineOf(node('chart', series('line', 4, {'legend': true})), const Size(600, 300));
      expect(e.spec.legend.show, 'auto');
      expect([for (final k in e.legend!.keys) k.label], ['New', 'Back']);
      expect(e.legend!.position, 'bottom');
      final one = series('line', 4, {'legend': true});
      one['series'] = [(one['series']! as List).first];
      expect(engineOf(node('chart', one), const Size(600, 300)).legend, isNull);
    });

    test('roundScale: its scale is rounded out to its grid lines', () {
      final e = engineOf(node('chart', series('line', 4, {'fitMinY': true, 'roundScale': true})));
      final (lo, hi) = e.yDomain(0);
      expect(e.spec.panes.single.y.nice, isTrue);
      expect(e.yTicks(0).first, lo);
      expect(e.yTicks(0).last, hi);
      // With no grid lines there is nothing to round out to.
      expect(engineOf(node('chart', series('line', 4, {'roundScale': true, 'gridLines': 0}))).spec.panes.single.y.nice, isFalse);
    });

    test('dots: a dot on each point of a line while the rows are that few, and none with its end dot', () {
      List<double> dots(Map<String, Object?> props) =>
          [for (final m in engineOf(node('chart', props)).spec.panes.single.marks) m.dots];
      expect(dots(series('line', 12, {'dots': 12})), [3.0, 3.0]);
      expect(dots(series('line', 13, {'dots': 12})), [0.0, 0.0]);
      expect(dots(series('line', 13, {'dots': 20})), [3.0, 3.0]);
      final ended = series('line', 4, {'dots': 12});
      (ended['series']! as List)[0] = {'field': 'a', 'name': 'New', 'kind': 'line', 'endDot': true, 'strokeWidth': 4};
      expect(dots(ended), [0.0, 3.0]);
    });

    test('a series\' fade: its area fades to the foot of the plot under its line', () {
      final props = series('line', 4, const {}, 'area');
      (props['series']! as List)[0] = {'field': 'a', 'name': 'New', 'kind': 'area', 'fade': true};
      final marks = engineOf(node('chart', props)).spec.panes.single.marks;
      expect([for (final m in marks) m.type], ['area', 'area', 'line', 'line']);
      expect([marks[0].fade, marks[1].fade], [true, false]);
      expect(marks[0].fillOpacity, 0.25);
    });

    test('cursorLine: a line up the plot through the row under the pointer, on a line chart that selects', () {
      final line = engineOf(node('chart', series('line', 4, {'selectOnHover': true, 'cursorLine': true}))).spec.crosshair;
      expect((line.enabled, line.vertical, line.horizontal, line.priceTag, line.timeLabel), (true, true, false, false, 'none'));
      expect(engineOf(node('chart', series('line', 4, {'cursorLine': true}))).spec.crosshair.enabled, isFalse);
      expect(engineOf(node('chart', series('line', 4, {'selectOnHover': true}))).spec.crosshair.enabled, isFalse);
      expect(engineOf(node('chart', series('bar', 4, {'selectOnHover': true, 'cursorLine': true}, 'bar'))).spec.crosshair.enabled, isFalse);
    });

    test('plotInset: room over the top line, and at each end of a line', () {
      final e = engineOf(node('chart', series('line', 4, {'plotInset': 6})));
      expect((e.spec.x.inset, e.spec.style.topInset), (6.0, 6.0));
      expect(e.xOfRow(0), closeTo(e.plotLeft + 6, 0.001));
      expect(e.xOfRow(3), closeTo(e.plotRight - 6, 0.001));
      final bars = engineOf(node('chart', series('bar', 4, {'plotInset': 6}, 'bar')));
      expect((bars.spec.x.inset, bars.spec.style.topInset), (0.0, 6.0));
    });

    test('maxBarWidth and barRadius: each bar of a group is at most that wide', () {
      final e = engineOf(node('chart', series('bar', 2, {'barRadius': 4, 'maxBarWidth': 36}, 'bar')), const Size(800, 200));
      expect(e.spec.panes.single.marks.first.radius, 4);
      final rects = e.barRects(0, 0);
      expect(rects[0].$2.width, closeTo(36, 0.001));
      expect(rects[1].$2.width, closeTo(36, 0.001));
    });

    test('a donut: legend puts its labels beside it, centerLabel its total in its hole', () {
      final e = engineOf(node('chart', donut({'legend': true})), const Size(500, 200));
      expect([for (final k in e.legend!.keys) (k.label, k.value)], [('Rent', '60%'), ('Food', '40%')]);
      expect(e.legend!.position, 'right');
      // In a box with no room beside the ring: under it.
      final under = engineOf(node('chart', donut({'legend': true})), const Size(200, 200));
      expect(under.legend!.position, 'bottom');
      final mark = e.spec.panes.single.marks.single;
      // Rows that give no color: the palette's, slice by slice.
      expect([for (final s in e.slices(mark)) s.color], graphPalette.sublist(0, 2));
      final named = engineOf(node('chart', donut({'centerLabel': 'Total'}))).spec.panes.single.marks.single;
      expect((named.center, named.centerLabel), ('total', 'Total'));
      // A series' own color is every slice's.
      final one = donut();
      one['series'] = [
        {'field': 'value', 'color': '#FF010203'},
      ];
      final single = engineOf(node('chart', one));
      expect({for (final s in single.slices(single.spec.panes.single.marks.single)) s.color}, {const Color(0xFF010203)});
    });
  });

  group('lineChart', () {
    Map<String, Object?> line([Map<String, Object?> extra = const {}]) => {
          'data': [
            for (final (i, v) in [12, 18, 14, 22, 19, 27, 24, 31].indexed) {'x': i, 'y': v},
          ],
          ...extra,
        };

    test('gridValues: round lines with their figures where it keeps room left of the plot; its own ticks win', () {
      final e = engineOf(node('lineChart', line({'gridValues': true})));
      final y = e.spec.panes.single.y;
      expect((y.labels, y.nice, y.ticks, y.decimals), (true, true, 4, 0));
      expect(e.yDomain(0), (10.0, 35.0));
      expect([for (final t in e.yTicks(0)) e.yLabel(0, t)], ['10', '15', '20', '25', '30', '35']);
      // No room (a sparkline's padding): no lines and no figures.
      final bare = engineOf(node('lineChart', line({'gridValues': true, 'plotPadding': [2, 4, 2, 4]}))).spec.panes.single.y;
      expect((bare.labels, bare.ticks, bare.nice), (false, 0, false));
      final own = engineOf(node('lineChart', line({
        'gridValues': true,
        'yTicks': [
          {'y': 15, 'label': 'low'},
        ],
      })));
      expect(own.spec.panes.single.y.nice, isFalse);
      expect(own.yTicks(0), [15]);
    });

    test('scrubEnabled selects the point under the pointer with a tooltip; cursorLine draws a line up the plot through it', () {
      final e = engineOf(node('lineChart', line({'scrubEnabled': true, 'cursorLine': true})));
      expect(e.spec.selection.on, 'hover');
      expect(e.spec.selection.tooltip, isTrue);
      expect((e.spec.crosshair.enabled, e.spec.crosshair.horizontal), (true, false));
      expect(engineOf(node('lineChart', line({'scrubEnabled': true}))).spec.crosshair.enabled, isFalse);
      expect(engineOf(node('lineChart', line({'cursorLine': true}))).spec.crosshair.enabled, isFalse);
    });
  });

  group('barChart', () {
    test('tooltip: the bar under the pointer is set apart and says its value', () {
      final e = engineOf(node('barChart', {
        'values': [12, 18, 27],
        'labels': ['a', 'b', 'c'],
        'tooltip': true,
      }));
      expect((e.spec.selection.on, e.spec.selection.tooltip), ('hover', true));
      e.hover(Offset(e.xOfRow(1), 100));
      expect(e.selection?.index, 1);
      // Its value alone: one mark with no name has no word to read beside it.
      expect(e.selectionRows().map((r) => (r.$2, r.$3)), [('', 18.0)]);
    });

    test('gridValues: round lines over its largest value, each with its own figure', () {
      final e = engineOf(node('barChart', {
        'values': [12, 18, 27],
        'gridValues': true,
        'gridLabelsLeft': true,
      }));
      expect(e.yDomain(0), (0.0, 30.0));
      expect([for (final t in e.yTicks(0)) e.yLabel(0, t)], ['0', '10', '20', '30']);
      expect(e.plotLeft, 40);
      // Room over the top line, and the labels in no family of the chart's
      // own when it names none.
      final own0 = chartGraphOf(node('barChart', {'values': [1], 'gridValues': true, 'labelFontFamily': ''}))!.spec['style'] as Map;
      expect((own0['topInset'], own0.containsKey('fontFamily')), (6.0, false));
      final named = chartGraphOf(node('barChart', {'values': [1]}))!.spec['style'] as Map;
      expect((named.containsKey('topInset'), named['fontFamily']), (false, 'JetBrains Mono'));
      // Its own top or labels are the chart's.
      final own = engineOf(node('barChart', {
        'values': [12, 18, 27],
        'gridValues': true,
        'max': 50,
      }));
      expect(own.yDomain(0), (0.0, 50.0));
    });
  });

  group('the theme', () {
    SurfaceRoles roles(ThemeTokens theme) => surfaceRoles(theme);

    test('series colors: the ones the theme names, else its primary and hues apart from it', () {
      final named = ThemeTokens.fromJson({
        'primary': '#FF2563EB',
        'colors': {'chart1': '#FF111111', 'chart2': '#FF222222'},
      });
      final colors = [for (final c in chartColors(named, roles(named))) c.value];
      // The ones it names first, then hues its first gives that are not
      // near one of them: more slices than names are still told apart.
      expect(colors.take(2), [0xFF111111, 0xFF222222]);
      expect(colors.length, greaterThan(2));
      expect(colors.toSet().length, colors.length);
      final desk = ThemeTokens.fromJson({
        'colors': {'chart1': '#FF4F46E5', 'chart2': '#FF14B8A6', 'chart3': '#FFF59E0B', 'chart4': '#FFEC4899', 'chart5': '#FF0EA5E9'},
      });
      final five = [for (final c in chartColors(desk, roles(desk))) c.value];
      expect(five.take(5), [0xFF4F46E5, 0xFF14B8A6, 0xFFF59E0B, 0xFFEC4899, 0xFF0EA5E9]);
      expect(five.length, greaterThan(5));
      for (final extra in five.skip(5)) {
        for (final name in five.take(5)) {
          final d = ((extra >> 16 & 0xFF) - (name >> 16 & 0xFF)).abs() + ((extra >> 8 & 0xFF) - (name >> 8 & 0xFF)).abs() + ((extra & 0xFF) - (name & 0xFF)).abs();
          expect(d, greaterThan(80));
        }
      }
      final plain = ThemeTokens.fromJson({'primary': '#FF2563EB'});
      final derived = [for (final c in chartColors(plain, roles(plain))) c.value];
      expect(derived, chartPaletteOf(0xFF2563EB));
      expect(derived.first, 0xFF2563EB);
      expect(derived.toSet().length, derived.length);
      // No primary: from the blue a page with no theme has.
      expect([for (final c in chartColors(ThemeTokens.none, roles(ThemeTokens.none))) c.value], chartPaletteOf(0xFF2563EB));
    });

    test('a series that says no color takes the next; one that does keeps it', () {
      final theme = ThemeTokens.fromJson({'primary': '#FF2563EB'});
      final n = node('chart', {
        'series': [
          {'field': 'a'},
          {'field': 'b', 'color': '#FF010203'},
          {'field': 'c'},
        ],
      });
      final colors = [for (final s in withChartPalette(n, theme, roles(theme)).prop(ChartProps.series)) s.color.value];
      final palette = chartPaletteOf(0xFF2563EB);
      expect(colors, [palette[0], 0xFF010203, palette[1]]);
      // A donut's series is not one color: its slices take the theme's, row by row.
      final ring = withChartPalette(node('chart', donut()), theme, roles(theme));
      final e = GraphEngine(
          GraphSpec.fromJson({
            ...chartGraphOf(ring)!.spec,
            'style': graphThemeStyle(theme, roles(theme)),
          }),
          data: chartGraphOf(ring)!.data)
        ..resize(const Size(200, 200));
      expect([for (final s in e.slices(e.spec.panes.single.marks.single)) s.color.toARGB32()], [palette[0], palette[1]]);
    });

    test('a graph\'s style takes the theme\'s colors for what it leaves out', () {
      final theme = ThemeTokens.fromJson({'primary': '#FF2563EB', 'surface': '#FF101014', 'onSurface': '#FFF5F5F5'});
      final r = roles(theme);
      final style = graphThemeStyle(theme, r);
      final spec = GraphSpec.fromJson({
        'style': {...style, 'text': '#FF00FF00'},
        'panes': [
          {
            'marks': [
              {'type': 'line', 'y': 'a'},
            ],
          },
        ],
      });
      // A tag is an inverted surface, the grid a hairline of the ink, and
      // the first mark the theme's primary; what the style says is its own.
      expect(spec.style.tag, r.onSurface);
      expect(spec.style.tagText, r.surface);
      // A tooltip is the surface itself, in its ink, a hairline round it.
      expect(spec.style.tooltip, r.surface);
      expect(spec.style.tooltipText, r.onSurface);
      expect(spec.style.tooltipBorder.toARGB32(), r.hairline.toARGB32());
      expect(spec.style.grid.toARGB32(), r.hairline.toARGB32());
      expect(spec.style.ink, r.onSurface);
      expect(spec.style.text, const Color(0xFF00FF00));
      expect(spec.panes.single.marks.single.color, const Color(0xFF2563EB));
      expect(spec.selection.tooltipFill, isNull);
    });
  });

  group('a tooltip', () {
    test('a chart that names no tooltip colors leaves them to the graph\'s style; its own are kept', () {
      final theme = ThemeTokens.fromJson({'primary': '#FF2563EB'});
      final roles = surfaceRoles(theme);
      for (final (type, props) in [
        ('chart', series('bar', 2, const {}, 'bar')),
        ('lineChart', <String, Object?>{'data': [{'x': 0, 'y': 1}]}),
        ('barChart', <String, Object?>{'values': [1, 2]}),
      ]) {
        final themed = withThemeColors(node(type, props), roles);
        final selection = chartGraphOf(themed)!.spec['selection'] as Map;
        expect(selection.containsKey('tooltipFill'), isFalse, reason: type);
        expect(selection.containsKey('tooltipText'), isFalse, reason: type);
      }
      final own = chartGraphOf(node('chart', series('bar', 2, {'tooltipColor': '#FF010203', 'tooltipTextColor': '#FF040506'}, 'bar')))!
          .spec['selection'] as Map;
      expect((own['tooltipFill'], own['tooltipText']), ('#FF010203', '#FF040506'));
    });
  });

  group('the palette of an accent', () {
    test('starts with it, and no two of its colors are near one another', () {
      for (final accent in [0xFF2563EB, 0xFF16A34A, 0xFFDC2626, 0xFF111827, 0xFF7C3AED]) {
        final palette = chartPaletteOf(accent);
        expect(palette, hasLength(8));
        expect(palette.first, accent);
        for (var i = 0; i < palette.length; i++) {
          for (var j = i + 1; j < palette.length; j++) {
            final a = Color(palette[i]), b = Color(palette[j]);
            final d = (a.r - b.r).abs() + (a.g - b.g).abs() + (a.b - b.b).abs();
            expect(d, greaterThan(0.12), reason: '${palette[i].toRadixString(16)} and ${palette[j].toRadixString(16)}');
          }
        }
      }
    });
  });
}
