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
  group('chart', () {
    test('a legend for its named series, unless legend says not', () {
      final e = engineOf(node('chart', series('line', 4)), const Size(600, 300));
      expect(e.spec.legend.show, 'auto');
      expect([for (final k in e.legend!.keys) k.label], ['New', 'Back']);
      expect(e.legend!.position, 'bottom');
      expect(engineOf(node('chart', series('line', 4, {'legend': false})), const Size(600, 300)).legend, isNull);
    });

    test('its scale is rounded out to its grid lines', () {
      final e = engineOf(node('chart', series('line', 4, {'fitMinY': true})));
      final (lo, hi) = e.yDomain(0);
      expect(e.spec.panes.single.y.nice, isTrue);
      expect(e.yTicks(0).first, lo);
      expect(e.yTicks(0).last, hi);
      // With no grid lines there is nothing to round out to.
      expect(engineOf(node('chart', series('line', 4, {'gridLines': 0}))).spec.panes.single.y.nice, isFalse);
    });

    test('a line has a dot on each of a few points, and none on many or with its end dot', () {
      List<double> dots(Map<String, Object?> props) =>
          [for (final m in engineOf(node('chart', props)).spec.panes.single.marks) m.dots];
      expect(dots(series('line', 12)), [3.0, 3.0]);
      expect(dots(series('line', 13)), [0.0, 0.0]);
      final ended = series('line', 4);
      (ended['series']! as List)[0] = {'field': 'a', 'name': 'New', 'kind': 'line', 'endDot': true, 'strokeWidth': 4};
      expect(dots(ended), [0.0, 3.0]);
    });

    test('an area fades to the foot of the plot under its line', () {
      final marks = engineOf(node('chart', series('line', 4, const {}, 'area'))).spec.panes.single.marks;
      expect([for (final m in marks) m.type], ['area', 'area', 'line', 'line']);
      expect(marks[0].fade, isTrue);
      expect(marks[0].fillOpacity, 0.25);
    });

    test('the row under the pointer has a line up the plot on a line chart, and none on bars', () {
      final line = engineOf(node('chart', series('line', 4))).spec.crosshair;
      expect((line.enabled, line.vertical, line.horizontal, line.priceTag, line.timeLabel), (true, true, false, false, 'none'));
      expect(engineOf(node('chart', series('bar', 4, const {}, 'bar'))).spec.crosshair.enabled, isFalse);
      expect(engineOf(node('chart', series('line', 4, {'selectOnHover': false}))).spec.crosshair.enabled, isFalse);
    });

    test('bars are rounded and no wider than the chart\'s widest, each of a group', () {
      final e = engineOf(node('chart', series('bar', 2, const {}, 'bar')), const Size(800, 200));
      expect(e.spec.panes.single.marks.first.radius, 4);
      expect(e.spec.x.maxBarWidth, 36);
      final rects = e.barRects(0, 0);
      expect(rects[0].$2.width, closeTo(36, 0.001));
      expect(rects[1].$2.width, closeTo(36, 0.001));
      final own = engineOf(node('chart', series('bar', 2, {'barRadius': 0, 'maxBarWidth': 12}, 'bar')), const Size(800, 200));
      expect(own.spec.panes.single.marks.first.radius, 0);
      expect(own.barRects(0, 0)[0].$2.width, closeTo(12, 0.001));
    });

    test('a donut: its legend beside it, and its total in its hole when it names it', () {
      final e = engineOf(node('chart', donut()), const Size(500, 200));
      expect([for (final k in e.legend!.keys) (k.label, k.value)], [('Rent', '60%'), ('Food', '40%')]);
      expect(e.legend!.position, 'right');
      final mark = e.spec.panes.single.marks.single;
      expect(mark.center, '');
      // Rows that give no color: the palette's, slice by slice.
      expect([for (final s in e.slices(mark)) s.color], graphPalette.sublist(0, 2));
      final named = engineOf(node('chart', donut({'centerLabel': 'Total'}))).spec.panes.single.marks.single;
      expect((named.center, named.centerLabel), ('total', 'Total'));
      expect(engineOf(node('chart', donut({'legend': false})), const Size(500, 200)).legend, isNull);
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

    test('round lines with their figures where it keeps room left of the plot; its own ticks win', () {
      final e = engineOf(node('lineChart', line()));
      final y = e.spec.panes.single.y;
      expect((y.labels, y.nice, y.ticks, y.decimals), (true, true, 4, 0));
      expect(e.yDomain(0), (10.0, 40.0));
      expect([for (final t in e.yTicks(0)) e.yLabel(0, t)], ['10', '20', '30', '40']);
      // No room (a sparkline's padding): no lines and no figures.
      final bare = engineOf(node('lineChart', line({'plotPadding': [2, 4, 2, 4]}))).spec.panes.single.y;
      expect((bare.labels, bare.ticks, bare.nice), (false, 0, false));
      final own = engineOf(node('lineChart', line({
        'yTicks': [
          {'y': 15, 'label': 'low'},
        ],
      })));
      expect(own.spec.panes.single.y.nice, isFalse);
      expect(own.yTicks(0), [15]);
    });

    test('the point under the pointer is selected, with a line up the plot, unless scrubEnabled says not', () {
      final e = engineOf(node('lineChart', line()));
      expect(e.spec.selection.on, 'hover');
      expect(e.spec.selection.tooltip, isTrue);
      expect((e.spec.crosshair.enabled, e.spec.crosshair.horizontal), (true, false));
      final off = engineOf(node('lineChart', line({'scrubEnabled': false})));
      expect((off.spec.selection.on, off.spec.crosshair.enabled), ('none', false));
    });
  });

  group('barChart', () {
    test('gridValues: round lines over its largest value, each with its own figure', () {
      final e = engineOf(node('barChart', {
        'values': [12, 18, 27],
        'gridValues': true,
        'gridLabelsLeft': true,
      }));
      expect(e.yDomain(0), (0.0, 30.0));
      expect([for (final t in e.yTicks(0)) e.yLabel(0, t)], ['0', '10', '20', '30']);
      expect(e.plotLeft, 40);
      // Without it the chart is as high as its largest value and has no figures.
      final plain = engineOf(node('barChart', {
        'values': [12, 18, 27],
      }));
      expect(plain.yDomain(0), (0.0, 27.0));
      expect(plain.plotLeft, 0);
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
      expect([for (final c in chartColors(named, roles(named))) c.value], [0xFF111111, 0xFF222222]);
      final plain = ThemeTokens.fromJson({'primary': '#FF2563EB'});
      final derived = [for (final c in chartColors(plain, roles(plain))) c.value];
      expect(derived, chartPaletteOf(0xFF2563EB));
      expect(derived.first, 0xFF2563EB);
      expect(derived.toSet().length, derived.length);
      // No primary: the graph's own.
      expect([for (final c in chartColors(ThemeTokens.none, roles(ThemeTokens.none))) c.value],
          [for (final c in graphPalette) c.toARGB32()]);
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
      // A tooltip is an inverted surface, the grid a hairline of the ink, and
      // the first mark the theme's primary; what the style says is its own.
      expect(spec.style.tag, r.onSurface);
      expect(spec.style.tagText, r.surface);
      expect(spec.style.grid.toARGB32(), r.hairline.toARGB32());
      expect(spec.style.ink, r.onSurface);
      expect(spec.style.text, const Color(0xFF00FF00));
      expect(spec.panes.single.marks.single.color, const Color(0xFF2563EB));
      expect(spec.selection.tooltipFill, isNull);
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
