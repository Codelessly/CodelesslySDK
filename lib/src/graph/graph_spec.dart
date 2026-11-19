// The graph's data model: everything a graph is, as JSON. No closures: a
// field is named, a format is a string, a gesture is a flag, and what the
// user does (the viewport, the cursor) is state the graph publishes.
//
// A prototype: the records are plain classes here, PropRecords of
// codelessly_api once the shape is settled.
import 'dart:ui' show Color;

typedef Json = Map<String, Object?>;

double _d(Object? v, double or) => v is num ? v.toDouble() : or;
bool _b(Object? v, bool or) => v is bool ? v : or;
String _s(Object? v, String or) => v is String ? v : or;
Json _m(Object? v) => v is Map ? v.cast<String, Object?>() : const {};
List<Object?> _l(Object? v) => v is List ? v : const [];

/// `#RRGGBB` or `#AARRGGBB`.
Color graphColor(Object? v, Color or) {
  if (v is! String) return or;
  final hex = v.replaceFirst('#', '');
  final n = int.tryParse(hex, radix: 16);
  if (n == null) return or;
  return hex.length <= 6 ? Color(0xFF000000 | n) : Color(n);
}

String _hex(Color c) => '#${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

/// The x scale: rows evenly spaced by position (an index scale, so closed
/// sessions take no room), labeled from [label], under a viewport.
class GraphXSpec {
  const GraphXSpec({
    this.label = 't',
    this.format = 'MMM d',
    this.barSpacing = 8,
    this.minBarSpacing = 0.5,
    this.maxBarSpacing = 80,
    this.rightOffset = 3,
    this.follow = 'end',
    this.clamp = true,
    this.axisHeight = 24,
    this.historyThreshold = 10,
  });

  /// The row field of the label (an ISO time, epoch milliseconds or a text).
  final String label;

  /// An intl date pattern for a time label.
  final String format;

  /// Pixels from one row to the next when the graph first shows.
  final double barSpacing, minBarSpacing, maxBarSpacing;

  /// Rows of empty room right of the last row when the graph first shows.
  final double rightOffset;

  /// `end`: new rows scroll into view while the last row is in view.
  /// `none`: the view stays on the rows it shows.
  final String follow;

  /// The view keeps some rows in it however far it is dragged.
  final bool clamp;
  final double axisHeight;

  /// Rows from the first one at which the graph asks for older rows.
  final double historyThreshold;

  factory GraphXSpec.fromJson(Json j) => GraphXSpec(
        label: _s(j['label'], 't'),
        format: _s(j['format'], 'MMM d'),
        barSpacing: _d(j['barSpacing'], 8),
        minBarSpacing: _d(j['minBarSpacing'], 0.5),
        maxBarSpacing: _d(j['maxBarSpacing'], 80),
        rightOffset: _d(j['rightOffset'], 3),
        follow: _s(j['follow'], 'end'),
        clamp: _b(j['clamp'], true),
        axisHeight: _d(j['axisHeight'], 24),
        historyThreshold: _d(j['historyThreshold'], 10),
      );

  Json toJson() => {
        'label': label,
        'format': format,
        'barSpacing': barSpacing,
        'minBarSpacing': minBarSpacing,
        'maxBarSpacing': maxBarSpacing,
        'rightOffset': rightOffset,
        'follow': follow,
        'clamp': clamp,
        'axisHeight': axisHeight,
        'historyThreshold': historyThreshold,
      };
}

/// A pane's y scale.
class GraphYSpec {
  const GraphYSpec({
    this.domain = 'visible',
    this.min,
    this.max,
    this.marginTop = 0.1,
    this.marginBottom = 0.1,
    this.include = const [],
    this.mode = 'linear',
    this.width = 56,
    this.decimals = 2,
  });

  /// `visible`: fitted to the rows in view (autoscale). `data`: to all rows.
  /// `fixed`: [min] to [max].
  final String domain;
  final double? min, max;

  /// Room above and below the fitted values, as shares of their span.
  final double marginTop, marginBottom;

  /// Values the fitted domain always holds (a previous close, zero).
  final List<double> include;

  /// `linear`, or `percent`: labels are the change from the first row in
  /// view.
  final String mode;

  /// The axis gutter's width.
  final double width;
  final int decimals;

  factory GraphYSpec.fromJson(Json j) {
    final margins = _l(j['margins']);
    return GraphYSpec(
      domain: _s(j['domain'], 'visible'),
      min: j['min'] is num ? (j['min']! as num).toDouble() : null,
      max: j['max'] is num ? (j['max']! as num).toDouble() : null,
      marginTop: margins.isNotEmpty ? _d(margins[0], 0.1) : 0.1,
      marginBottom: margins.length > 1 ? _d(margins[1], 0.1) : 0.1,
      include: [for (final v in _l(j['include'])) if (v is num) v.toDouble()],
      mode: _s(j['mode'], 'linear'),
      width: _d(j['width'], 56),
      decimals: j['decimals'] is int ? j['decimals']! as int : 2,
    );
  }

  Json toJson() => {
        'domain': domain,
        if (min != null) 'min': min,
        if (max != null) 'max': max,
        'margins': [marginTop, marginBottom],
        if (include.isNotEmpty) 'include': include,
        'mode': mode,
        'width': width,
        'decimals': decimals,
      };
}

/// What a mark draws: `candle` (open, high, low, close), `line` and `area`
/// (y), `bar` (y, from zero).
class GraphMarkSpec {
  const GraphMarkSpec({
    required this.type,
    this.y = '',
    this.open = '',
    this.high = '',
    this.low = '',
    this.close = '',
    this.color = const Color(0xFF2962FF),
    this.upColor = const Color(0xFF26A69A),
    this.downColor = const Color(0xFFEF5350),
    this.width = 1.5,
    this.fillOpacity = 0.18,
    this.curved = false,
  });

  final String type;
  final String y, open, high, low, close;
  final Color color, upColor, downColor;
  final double width, fillOpacity;
  final bool curved;

  /// A candle, or a bar with open and close, is colored by its direction.
  bool get byDirection => open.isNotEmpty && close.isNotEmpty;

  /// The row fields the mark reads on the y scale.
  List<String> get fields => type == 'candle' ? [open, high, low, close] : [y];

  /// The fields that bound the mark for autoscale.
  List<String> get extentFields => type == 'candle' ? [high, low] : [y];

  factory GraphMarkSpec.fromJson(Json j) => GraphMarkSpec(
        type: _s(j['type'], 'line'),
        y: _s(j['y'], ''),
        open: _s(j['open'], ''),
        high: _s(j['high'], ''),
        low: _s(j['low'], ''),
        close: _s(j['close'], ''),
        color: graphColor(j['color'], const Color(0xFF2962FF)),
        upColor: graphColor(j['upColor'], const Color(0xFF26A69A)),
        downColor: graphColor(j['downColor'], const Color(0xFFEF5350)),
        width: _d(j['width'], 1.5),
        fillOpacity: _d(j['fillOpacity'], 0.18),
        curved: _b(j['curved'], false),
      );

  Json toJson() => {
        'type': type,
        if (y.isNotEmpty) 'y': y,
        if (open.isNotEmpty) 'open': open,
        if (high.isNotEmpty) 'high': high,
        if (low.isNotEmpty) 'low': low,
        if (close.isNotEmpty) 'close': close,
        'color': _hex(color),
        'upColor': _hex(upColor),
        'downColor': _hex(downColor),
        'width': width,
        'fillOpacity': fillOpacity,
        'curved': curved,
      };
}

/// A horizontal line at a price, tagged on the axis: a fixed [value], or
/// the last row's [field] (the last price).
class GraphPriceLineSpec {
  const GraphPriceLineSpec({
    this.value,
    this.field = '',
    this.label = '',
    this.color = const Color(0xFF2962FF),
    this.dashed = true,
    this.tag = true,
  });

  final double? value;
  final String field;
  final String label;
  final Color color;
  final bool dashed, tag;

  factory GraphPriceLineSpec.fromJson(Json j) => GraphPriceLineSpec(
        value: j['value'] is num ? (j['value']! as num).toDouble() : null,
        field: _s(j['field'], ''),
        label: _s(j['label'], ''),
        color: graphColor(j['color'], const Color(0xFF2962FF)),
        dashed: _b(j['dashed'], true),
        tag: _b(j['tag'], true),
      );

  Json toJson() => {
        if (value != null) 'value': value,
        if (field.isNotEmpty) 'field': field,
        if (label.isNotEmpty) 'label': label,
        'color': _hex(color),
        'dashed': dashed,
        'tag': tag,
      };
}

/// One pane: marks over the shared x scale, on a y scale of its own.
class GraphPaneSpec {
  const GraphPaneSpec({this.grow = 1, this.y = const GraphYSpec(), this.marks = const [], this.priceLines = const []});

  /// Its share of the graph's height.
  final double grow;
  final GraphYSpec y;
  final List<GraphMarkSpec> marks;
  final List<GraphPriceLineSpec> priceLines;

  factory GraphPaneSpec.fromJson(Json j) => GraphPaneSpec(
        grow: _d(j['grow'], 1),
        y: GraphYSpec.fromJson(_m(j['y'])),
        marks: [for (final m in _l(j['marks'])) GraphMarkSpec.fromJson(_m(m))],
        priceLines: [for (final m in _l(j['priceLines'])) GraphPriceLineSpec.fromJson(_m(m))],
      );

  Json toJson() => {
        'grow': grow,
        'y': y.toJson(),
        'marks': [for (final m in marks) m.toJson()],
        if (priceLines.isNotEmpty) 'priceLines': [for (final l in priceLines) l.toJson()],
      };
}

/// A field worked out from the rows before them: `sma`, `ema`, `rsi`
/// (written to [as]) and `bollinger` (to `[as]Mid`, `[as]Upper`,
/// `[as]Lower`).
class GraphTransformSpec {
  const GraphTransformSpec({required this.type, required this.field, required this.as, this.period = 20, this.k = 2});

  final String type, field, as;
  final int period;
  final double k;

  factory GraphTransformSpec.fromJson(Json j) => GraphTransformSpec(
        type: _s(j['type'], 'sma'),
        field: _s(j['field'], ''),
        as: _s(j['as'], ''),
        period: j['period'] is int ? j['period']! as int : 20,
        k: _d(j['k'], 2),
      );

  Json toJson() => {'type': type, 'field': field, 'as': as, 'period': period, 'k': k};
}

/// The crosshair: a line through the row under the pointer and one at its
/// price, tagged on both axes.
class GraphCrosshairSpec {
  const GraphCrosshairSpec({this.enabled = true, this.magnet = '', this.on = 'both'});

  final bool enabled;

  /// The row field its price snaps to (`c`: the close); empty for the
  /// pointer's own price.
  final String magnet;

  /// `hover`, `longPress` or `both`.
  final String on;

  factory GraphCrosshairSpec.fromJson(Json j) =>
      GraphCrosshairSpec(enabled: _b(j['enabled'], true), magnet: _s(j['magnet'], ''), on: _s(j['on'], 'both'));

  Json toJson() => {'enabled': enabled, 'magnet': magnet, 'on': on};
}

/// What each gesture does: a table of flags, never a callback.
class GraphInteractionsSpec {
  const GraphInteractionsSpec({
    this.dragPan = true,
    this.wheelZoom = true,
    this.pinchZoom = true,
    this.axisScale = true,
    this.doubleTapReset = true,
    this.fling = true,
  });

  /// A drag on the plot pans the x viewport (and y, once y is manual).
  final bool dragPan;

  /// The wheel zooms x about the pointer.
  final bool wheelZoom;

  /// Two fingers zoom x about their middle.
  final bool pinchZoom;

  /// A drag on the price axis scales y (autoscale goes off); on the time
  /// axis, x.
  final bool axisScale;

  /// A double tap on an axis fits it again.
  final bool doubleTapReset;

  /// A flick keeps panning and slows down.
  final bool fling;

  factory GraphInteractionsSpec.fromJson(Json j) => GraphInteractionsSpec(
        dragPan: _b(j['dragPan'], true),
        wheelZoom: _b(j['wheelZoom'], true),
        pinchZoom: _b(j['pinchZoom'], true),
        axisScale: _b(j['axisScale'], true),
        doubleTapReset: _b(j['doubleTapReset'], true),
        fling: _b(j['fling'], true),
      );

  Json toJson() => {
        'dragPan': dragPan,
        'wheelZoom': wheelZoom,
        'pinchZoom': pinchZoom,
        'axisScale': axisScale,
        'doubleTapReset': doubleTapReset,
        'fling': fling,
      };
}

class GraphStyleSpec {
  const GraphStyleSpec({
    this.background = const Color(0xFFFFFFFF),
    this.grid = const Color(0x14000000),
    this.text = const Color(0xFF6B7280),
    this.crosshair = const Color(0xFF9CA3AF),
    this.tag = const Color(0xFF111827),
    this.tagText = const Color(0xFFFFFFFF),
    this.separator = const Color(0x1F000000),
    this.fontSize = 11,
    this.fontFamily,
  });

  final Color background, grid, text, crosshair, tag, tagText, separator;
  final double fontSize;
  final String? fontFamily;

  factory GraphStyleSpec.fromJson(Json j) => GraphStyleSpec(
        background: graphColor(j['background'], const Color(0xFFFFFFFF)),
        grid: graphColor(j['grid'], const Color(0x14000000)),
        text: graphColor(j['text'], const Color(0xFF6B7280)),
        crosshair: graphColor(j['crosshair'], const Color(0xFF9CA3AF)),
        tag: graphColor(j['tag'], const Color(0xFF111827)),
        tagText: graphColor(j['tagText'], const Color(0xFFFFFFFF)),
        separator: graphColor(j['separator'], const Color(0x1F000000)),
        fontSize: _d(j['fontSize'], 11),
        fontFamily: j['fontFamily'] is String ? j['fontFamily']! as String : null,
      );

  Json toJson() => {
        'background': _hex(background),
        'grid': _hex(grid),
        'text': _hex(text),
        'crosshair': _hex(crosshair),
        'tag': _hex(tag),
        'tagText': _hex(tagText),
        'separator': _hex(separator),
        'fontSize': fontSize,
        if (fontFamily != null) 'fontFamily': fontFamily,
      };
}

/// A graph.
class GraphSpec {
  const GraphSpec({
    this.key = 't',
    this.x = const GraphXSpec(),
    this.panes = const [],
    this.transforms = const [],
    this.crosshair = const GraphCrosshairSpec(),
    this.interactions = const GraphInteractionsSpec(),
    this.style = const GraphStyleSpec(),
  });

  /// The row field that names a row across updates (its time): how an
  /// update is told from an append and from older rows put before.
  final String key;
  final GraphXSpec x;
  final List<GraphPaneSpec> panes;
  final List<GraphTransformSpec> transforms;
  final GraphCrosshairSpec crosshair;
  final GraphInteractionsSpec interactions;
  final GraphStyleSpec style;

  factory GraphSpec.fromJson(Json j) => GraphSpec(
        key: _s(j['key'], 't'),
        x: GraphXSpec.fromJson(_m(j['x'])),
        panes: [for (final p in _l(j['panes'])) GraphPaneSpec.fromJson(_m(p))],
        transforms: [for (final t in _l(j['transforms'])) GraphTransformSpec.fromJson(_m(t))],
        crosshair: GraphCrosshairSpec.fromJson(_m(j['crosshair'])),
        interactions: GraphInteractionsSpec.fromJson(_m(j['interactions'])),
        style: GraphStyleSpec.fromJson(_m(j['style'])),
      );

  Json toJson() => {
        'type': 'graph',
        'key': key,
        'x': x.toJson(),
        'panes': [for (final p in panes) p.toJson()],
        if (transforms.isNotEmpty) 'transforms': [for (final t in transforms) t.toJson()],
        'crosshair': crosshair.toJson(),
        'interactions': interactions.toJson(),
        'style': style.toJson(),
      };
}
