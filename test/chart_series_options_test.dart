import 'dart:ui';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('y-axis labels take a prefix and suffix', () {
    expect(yAxisLabel(12000, r'$', ''), r'$12k');
    expect(yAxisLabel(8000, '', ' €'), '8.0k €');
    expect(yAxisLabel(-5000, r'$', ''), r'−$5.0k');
    expect(yAxisLabel(250, '', ''), '250');
  });

  test('a fitted y domain hugs the data on round steps', () {
    final (double lo, double hi, double step) = fittedYDomain(38200, 42061, 4);
    expect(lo, lessThanOrEqualTo(38200));
    expect(lo, greaterThan(30000));
    expect(hi, greaterThanOrEqualTo(42061));
    expect((lo / step) % 1, 0);
  });

  test('a curved series passes through every point', () {
    const List<Offset> pts = [Offset(0, 10), Offset(10, 0), Offset(20, 8)];
    final Path straight = seriesPath(pts);
    final Path curved = seriesPath(pts, curved: true);
    double length(Path p) =>
        p.computeMetrics().fold(0.0, (sum, m) => sum + m.length);
    expect(length(curved), greaterThan(length(straight)));
    // Control points stay at the neighbours' heights: no overshoot.
    final Rect b = curved.getBounds();
    expect(b.top, closeTo(0, 0.01));
    expect(b.bottom, closeTo(10, 0.01));
  });

  test('the new series and chart options survive JSON', () {
    const ChartSeries series = ChartSeries(
      field: 'v',
      kind: ChartSeriesKind.area,
      curved: true,
      endDot: true,
      endDotHaloColor: ColorRGBA.white,
    );
    final ChartSeries back = ChartSeries.fromJson(series.toJson());
    expect(back.curved, isTrue);
    expect(back.endDotHaloColor, ColorRGBA.white);

    final ChartProperties props = ChartProperties(
      chartType: ChartType.line,
      plotInset: 0,
      fitMinY: true,
      yLabelPrefix: r'$',
      yLabelSuffix: 'k',
      yAxisFontFamily: 'IBM Plex Mono',
    );
    final ChartProperties copy = ChartProperties.fromJson(props.toJson());
    expect(copy.plotInset, 0);
    expect(copy.fitMinY, isTrue);
    expect(copy.yLabelPrefix, r'$');
    expect(copy.yLabelSuffix, 'k');
    expect(copy.yAxisFontFamily, 'IBM Plex Mono');
  });
}
