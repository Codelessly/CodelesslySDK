// The graph's data model: everything a graph is, as JSON. No closures: a
// field is named, a format is a string, a gesture is a flag, and what the
// user does (the viewport, the cursor) is state the graph publishes.
//
// A prototype: the records are plain classes here, PropRecords of
// codelessly_api once the shape is settled.
import 'dart:ui' show Color;

typedef Json = Map<String, Object?>;

double _d(Object? v, double or) => v is num ? v.toDouble() : or;
double? _dn(Object? v) => v is num ? v.toDouble() : null;
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

/// A stretch of the x scale with a name: a trading session. A line mark
/// can break at its edges and dim outside the one in use, and a price line
/// can be drawn band by band.
class GraphBandSpec {
  const GraphBandSpec({required this.id, required this.from, required this.to, String? group}) : group = group ?? id;

  final String id;

  /// Bands a price line treats as one (overnight and pre-market).
  final String group;

  /// The first and last positions of the band.
  final double from, to;

  factory GraphBandSpec.fromJson(Json j) => GraphBandSpec(
      id: _s(j['id'], ''), from: _d(j['from'], 0), to: _d(j['to'], 0), group: j['group'] is String ? j['group']! as String : null);

  Json toJson() => {'id': id, 'from': from, 'to': to, if (group != id) 'group': group};
}

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
    this.overscroll = false,
    this.axisHeight = 24,
    this.labels = true,
    this.historyThreshold = 10,
    this.moreHistory = true,
    this.fit = 'none',
    this.slots,
    this.tickEvery,
    this.ticks = 'step',
    this.morph = 0,
    this.bands = const [],
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

  /// false: the view stays on the rows there are. Zooming out stops when
  /// they fill the plot, and panning stops at the first row and at the last
  /// (with [rightOffset] of room). true: it may be dragged and zoomed past
  /// them, over empty plot (as [clamp] allows).
  final bool overscroll;
  final double axisHeight;

  /// Whether the time axis writes its labels.
  final bool labels;

  /// Rows from the first one at which the graph asks for older rows.
  final double historyThreshold;

  /// Whether there are rows older than the first: the page sets it false
  /// once it has loaded them all, and the graph stops asking.
  final bool moreHistory;

  /// `none`: the viewport is the user's. `points`: every position fits
  /// across the plot, the first on its left edge and the last on its right
  /// (a line with no room at its ends). `bars`: the same with half a bar's
  /// room at each end.
  final String fit;

  /// The positions a fitted view spans when it is more than the rows there
  /// are (a trading day not over yet: the line ends partway across).
  final int? slots;

  /// A time label every this many positions (30: each half hour of minute
  /// rows); null for the smallest round step whose labels stand apart.
  final int? tickEvery;

  /// `step`: a label every so many rows. `calendar`: at the rows that start
  /// an hour, a day, a month or a year, whichever stands apart, each
  /// labeled as its unit.
  final String ticks;

  /// Milliseconds a line takes to move to new rows (a range change): each
  /// point travels from where the old line was above it. 0: it jumps.
  final double morph;
  final List<GraphBandSpec> bands;

  factory GraphXSpec.fromJson(Json j) => GraphXSpec(
        label: _s(j['label'], 't'),
        format: _s(j['format'], 'MMM d'),
        barSpacing: _d(j['barSpacing'], 8),
        minBarSpacing: _d(j['minBarSpacing'], 0.5),
        maxBarSpacing: _d(j['maxBarSpacing'], 80),
        rightOffset: _d(j['rightOffset'], 3),
        follow: _s(j['follow'], 'end'),
        clamp: _b(j['clamp'], true),
        overscroll: _b(j['overscroll'], false),
        axisHeight: _d(j['axisHeight'], 24),
        labels: _b(j['labels'], true),
        historyThreshold: _d(j['historyThreshold'], 10),
        moreHistory: _b(j['moreHistory'], true),
        fit: _s(j['fit'], 'none'),
        slots: j['slots'] is int ? j['slots']! as int : null,
        tickEvery: j['tickEvery'] is int ? j['tickEvery']! as int : null,
        ticks: _s(j['ticks'], 'step'),
        morph: _d(j['morph'], 0),
        bands: [for (final b in _l(j['bands'])) GraphBandSpec.fromJson(_m(b))],
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
        'overscroll': overscroll,
        'axisHeight': axisHeight,
        'labels': labels,
        'historyThreshold': historyThreshold,
        'moreHistory': moreHistory,
        'fit': fit,
        if (slots != null) 'slots': slots,
        if (tickEvery != null) 'tickEvery': tickEvery,
        'ticks': ticks,
        'morph': morph,
        if (bands.isNotEmpty) 'bands': [for (final b in bands) b.toJson()],
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
    this.labels = true,
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

  /// Whether the price axis writes its labels.
  final bool labels;
  final int decimals;

  factory GraphYSpec.fromJson(Json j) {
    final margins = _l(j['margins']);
    return GraphYSpec(
      domain: _s(j['domain'], 'visible'),
      min: _dn(j['min']),
      max: _dn(j['max']),
      marginTop: margins.isNotEmpty ? _d(margins[0], 0.1) : 0.1,
      marginBottom: margins.length > 1 ? _d(margins[1], 0.1) : 0.1,
      include: [for (final v in _l(j['include'])) if (v is num) v.toDouble()],
      mode: _s(j['mode'], 'linear'),
      width: _d(j['width'], 56),
      labels: _b(j['labels'], true),
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
        'labels': labels,
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
    this.fade = false,
    this.curved = false,
    this.overlay,
    this.segmentBy = '',
    this.dimInactive = 1,
    this.endDot = 0,
    this.endDotColor,
    this.pulse = false,
  });

  final String type;
  final String y, open, high, low, close;
  final Color color, upColor, downColor;
  final double width, fillOpacity;

  /// An area's fill fades to nothing at the bottom of the pane.
  final bool fade;
  final bool curved;

  /// The mark is on a scale of its own, fitted so it stands in this share
  /// of the pane from its bottom (volume bars under a price line). It takes
  /// no part in the pane's own scale.
  final double? overlay;

  /// A line breaks where this row field changes (a session), and the parts
  /// outside the band in use are drawn at [dimInactive] of their opacity.
  final String segmentBy;
  final double dimInactive;

  /// A dot of this radius on the last row (0: none), in [endDotColor] or
  /// the mark's color, with a ring that swells and fades when [pulse].
  final double endDot;
  final Color? endDotColor;
  final bool pulse;

  /// A candle, or a bar with open and close, is colored by its direction.
  bool get byDirection => open.isNotEmpty && close.isNotEmpty;

  /// The row fields the mark reads on the y scale.
  List<String> get fields => type == 'candle' ? [open, high, low, close] : [y];

  /// The fields that bound the mark for autoscale.
  List<String> get extentFields => type == 'candle' ? [high, low] : [y];

  /// The field of the mark's value (a candle's close).
  String get valueField => type == 'candle' ? close : y;

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
        fade: _b(j['fade'], false),
        curved: _b(j['curved'], false),
        overlay: _dn(j['overlay']),
        segmentBy: _s(j['segmentBy'], ''),
        dimInactive: _d(j['dimInactive'], 1),
        endDot: _d(j['endDot'], 0),
        endDotColor: j['endDotColor'] == null ? null : graphColor(j['endDotColor'], const Color(0xFF2962FF)),
        pulse: _b(j['pulse'], false),
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
        'fade': fade,
        'curved': curved,
        if (overlay != null) 'overlay': overlay,
        if (segmentBy.isNotEmpty) 'segmentBy': segmentBy,
        'dimInactive': dimInactive,
        'endDot': endDot,
        if (endDotColor != null) 'endDotColor': _hex(endDotColor!),
        'pulse': pulse,
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
    this.line = 'dashed',
    this.tag = true,
    this.byBand = false,
    this.activeColor,
    this.note = '',
  });

  final double? value;
  final String field;
  final String label;
  final Color color;

  /// `dashed`, `dotted` or `solid`.
  final String line;
  final bool tag;

  /// Drawn band by band across the whole x scale (not only where rows
  /// are), the band in use in [activeColor].
  final bool byBand;
  final Color? activeColor;

  /// A second line in the tag, under the value (the time to a bar's close).
  final String note;

  factory GraphPriceLineSpec.fromJson(Json j) => GraphPriceLineSpec(
        value: _dn(j['value']),
        field: _s(j['field'], ''),
        label: _s(j['label'], ''),
        color: graphColor(j['color'], const Color(0xFF2962FF)),
        line: _s(j['line'], 'dashed'),
        tag: _b(j['tag'], true),
        byBand: _b(j['byBand'], false),
        activeColor: j['activeColor'] == null ? null : graphColor(j['activeColor'], const Color(0xFF000000)),
        note: _s(j['note'], ''),
      );

  Json toJson() => {
        if (value != null) 'value': value,
        if (field.isNotEmpty) 'field': field,
        if (label.isNotEmpty) 'label': label,
        'color': _hex(color),
        'line': line,
        'tag': tag,
        'byBand': byBand,
        if (activeColor != null) 'activeColor': _hex(activeColor!),
        if (note.isNotEmpty) 'note': note,
      };
}

/// A lettered badge at the foot of a pane, on the row with key [at] (an
/// earnings date, a dividend).
class GraphMarkerSpec {
  const GraphMarkerSpec({required this.at, this.text = '', this.color = const Color(0xFF2962FF)});

  final Object? at;
  final String text;
  final Color color;

  factory GraphMarkerSpec.fromJson(Json j) =>
      GraphMarkerSpec(at: j['at'], text: _s(j['text'], ''), color: graphColor(j['color'], const Color(0xFF2962FF)));

  Json toJson() => {'at': at, 'text': text, 'color': _hex(color)};
}

/// One pane: marks over the shared x scale, on a y scale of its own.
class GraphPaneSpec {
  const GraphPaneSpec({
    this.grow = 1,
    this.y = const GraphYSpec(),
    this.marks = const [],
    this.priceLines = const [],
    this.markers = const [],
  });

  /// Its share of the graph's height.
  final double grow;
  final GraphYSpec y;
  final List<GraphMarkSpec> marks;
  final List<GraphPriceLineSpec> priceLines;
  final List<GraphMarkerSpec> markers;

  factory GraphPaneSpec.fromJson(Json j) => GraphPaneSpec(
        grow: _d(j['grow'], 1),
        y: GraphYSpec.fromJson(_m(j['y'])),
        marks: [for (final m in _l(j['marks'])) GraphMarkSpec.fromJson(_m(m))],
        priceLines: [for (final m in _l(j['priceLines'])) GraphPriceLineSpec.fromJson(_m(m))],
        markers: [for (final m in _l(j['markers'])) GraphMarkerSpec.fromJson(_m(m))],
      );

  Json toJson() => {
        'grow': grow,
        'y': y.toJson(),
        'marks': [for (final m in marks) m.toJson()],
        if (priceLines.isNotEmpty) 'priceLines': [for (final l in priceLines) l.toJson()],
        if (markers.isNotEmpty) 'markers': [for (final m in markers) m.toJson()],
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
  const GraphCrosshairSpec({
    this.enabled = true,
    this.magnet = '',
    this.on = 'both',
    this.vertical = true,
    this.horizontal = true,
    this.line = 'dashed',
    this.dot = 0,
    this.dotStroke = 0,
    this.timeLabel = 'axis',
    this.timeFormat = '',
    this.priceTag = true,
  });

  final bool enabled;

  /// The row field its price snaps to (`c`: the close); empty for the
  /// pointer's own price.
  final String magnet;

  /// `hover`, `longPress`, `both`, or `touch`: a hover, and a finger from
  /// the moment it is down (a scrub: no pan).
  final String on;
  final bool vertical, horizontal;

  /// `dashed` or `solid`.
  final String line;

  /// A dot of this radius where the lines cross, in the magnet mark's
  /// color, ringed [dotStroke] wide in the background color.
  final double dot, dotStroke;

  /// Where the row's time is written: `axis` (a tag on the time axis),
  /// `top` (plain text above the plot, over the line) or `none`.
  final String timeLabel;

  /// The time's pattern; empty for the axis's.
  final String timeFormat;
  final bool priceTag;

  factory GraphCrosshairSpec.fromJson(Json j) => GraphCrosshairSpec(
        enabled: _b(j['enabled'], true),
        magnet: _s(j['magnet'], ''),
        on: _s(j['on'], 'both'),
        vertical: _b(j['vertical'], true),
        horizontal: _b(j['horizontal'], true),
        line: _s(j['line'], 'dashed'),
        dot: _d(j['dot'], 0),
        dotStroke: _d(j['dotStroke'], 0),
        timeLabel: _s(j['timeLabel'], 'axis'),
        timeFormat: _s(j['timeFormat'], ''),
        priceTag: _b(j['priceTag'], true),
      );

  Json toJson() => {
        'enabled': enabled,
        'magnet': magnet,
        'on': on,
        'vertical': vertical,
        'horizontal': horizontal,
        'line': line,
        'dot': dot,
        'dotStroke': dotStroke,
        'timeLabel': timeLabel,
        'timeFormat': timeFormat,
        'priceTag': priceTag,
      };
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
    this.topInset = 0,
  });

  final Color background, grid, text, crosshair, tag, tagText, separator;
  final double fontSize;
  final String? fontFamily;

  /// Room above the panes (for a crosshair's time written on top).
  final double topInset;

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
        topInset: _d(j['topInset'], 0),
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
        'topInset': topInset,
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
