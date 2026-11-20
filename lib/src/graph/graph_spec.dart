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
    this.grid = true,
    this.scale = 'index',
    this.field = '',
    this.min,
    this.max,
    this.tickValues = const [],
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
    this.maxBarWidth,
    this.ticks = 'step',
    this.morph = 0,
    this.bands = const [],
    this.inset = 0,
  });

  /// Pixels kept clear at each end of a fitted view ([fit]): the first and
  /// the last row stand this far inside the plot, so a dot or a line's end
  /// there is whole.
  final double inset;

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

  /// The widest a bar or a candle is drawn, in the middle of its place;
  /// null: its share of the place, however wide.
  final double? maxBarWidth;

  /// `step`: a label every so many rows. `calendar`: at the rows that start
  /// an hour, a day, a month or a year, whichever stands apart, each
  /// labeled as its unit.
  final String ticks;

  /// Milliseconds a line takes to move to new rows (a range change): each
  /// point travels from where the old line was above it. 0: it jumps.
  final double morph;
  final List<GraphBandSpec> bands;

  /// Whether a line is drawn up each pane at every x tick.
  final bool grid;

  /// `index`: rows evenly spaced, one place each. `linear`: each row where
  /// its [field]'s number is between [min] and [max] (the rows' own least
  /// and most when not given); the view is that stretch, and does not move.
  final String scale;
  final String field;
  final double? min, max;
  bool get linear => scale == 'linear';

  /// The ticks themselves, when the graph does not choose them: on a linear
  /// scale values, on rows their places.
  final List<GraphTick> tickValues;

  factory GraphXSpec.fromJson(Json j) => GraphXSpec(
        grid: _b(j['grid'], true),
        scale: _s(j['scale'], 'index'),
        field: _s(j['field'], ''),
        min: _dn(j['min']),
        max: _dn(j['max']),
        tickValues: GraphTick.list(j['tickValues']),
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
        maxBarWidth: _dn(j['maxBarWidth']),
        ticks: _s(j['ticks'], 'step'),
        morph: _d(j['morph'], 0),
        bands: [for (final b in _l(j['bands'])) GraphBandSpec.fromJson(_m(b))],
        inset: _d(j['inset'], 0),
      );

  Json toJson() => {
        if (!grid) 'grid': grid,
        if (scale != 'index') 'scale': scale,
        if (field.isNotEmpty) 'field': field,
        if (min != null) 'min': min,
        if (max != null) 'max': max,
        if (tickValues.isNotEmpty) 'tickValues': [for (final t in tickValues) t.toJson()],
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
        if (maxBarWidth != null) 'maxBarWidth': maxBarWidth,
        'ticks': ticks,
        'morph': morph,
        if (bands.isNotEmpty) 'bands': [for (final b in bands) b.toJson()],
        if (inset != 0) 'inset': inset,
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
    this.side = 'right',
    this.prefix = '',
    this.suffix = '',
    this.ticks = 5,
    this.tickValues = const [],
    this.nice = false,
  });

  /// A fitted domain is rounded out to the ticks it is given, so the plot
  /// starts and ends on a labeled line (the margins are then not added).
  final bool nice;

  /// `right` or `left`: where the axis gutter is (one side for the graph:
  /// left when any pane says so).
  final String side;

  /// Written before and after each label (`$`, `k`, `%`).
  final String prefix, suffix;

  /// About how many round ticks the axis has.
  final int ticks;

  /// The ticks themselves, when the graph does not choose them.
  final List<GraphTick> tickValues;

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
      side: _s(j['side'], 'right'),
      prefix: _s(j['prefix'], ''),
      suffix: _s(j['suffix'], ''),
      ticks: j['ticks'] is int ? j['ticks']! as int : 5,
      tickValues: GraphTick.list(j['tickValues']),
      nice: _b(j['nice'], false),
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
        if (side != 'right') 'side': side,
        if (prefix.isNotEmpty) 'prefix': prefix,
        if (suffix.isNotEmpty) 'suffix': suffix,
        if (ticks != 5) 'ticks': ticks,
        if (tickValues.isNotEmpty) 'tickValues': [for (final t in tickValues) t.toJson()],
        if (nice) 'nice': nice,
      };
}

/// A tick an axis is told to have: a value, and what is written at it (its
/// own number when no label is given). Written `12` or `{value, label}`.
class GraphTick {
  const GraphTick(this.value, [this.label]);
  final double value;
  final String? label;

  static List<GraphTick> list(Object? v) => [
        for (final t in _l(v))
          if (t is num)
            GraphTick(t.toDouble())
          else if (t is Map && (t['value'] ?? t['x'] ?? t['y']) is num)
            GraphTick(((t['value'] ?? t['x'] ?? t['y'])! as num).toDouble(), t['label']?.toString()),
      ];

  Object toJson() => label == null ? value : {'value': value, 'label': label};
}

/// Something drawn on a pane at a place of its scales, over the marks: a
/// line up the pane ([x] alone), a line across it ([y] alone), a dot ([x]
/// and [y]) or a tinted stretch of the x scale ([from] to [to]). On a linear
/// x scale a place is a value; on rows, a row's key.
class GraphGuideSpec {
  const GraphGuideSpec({
    this.x,
    this.y,
    this.from,
    this.to,
    this.color = const Color(0xFF9CA3AF),
    this.line = 'solid',
    this.width = 1,
    this.label = '',
    this.labelColor,
    this.radius = 3.5,
    this.fill,
    this.below = false,
  });

  final Object? x, from, to;
  final double? y;
  final Color color;

  /// `solid`, `dashed` or `dotted`.
  final String line;
  final double width;
  final String label;
  final Color? labelColor;

  /// A dot's radius, and its inside when it is not the dot's own color.
  final double radius;
  final Color? fill;

  /// A dot's label is under it.
  final bool below;

  factory GraphGuideSpec.fromJson(Json j) => GraphGuideSpec(
        x: j['x'],
        y: _dn(j['y']),
        from: j['from'],
        to: j['to'],
        color: graphColor(j['color'], const Color(0xFF9CA3AF)),
        line: _s(j['line'], 'solid'),
        width: _d(j['width'], 1),
        label: _s(j['label'], ''),
        labelColor: j['labelColor'] == null ? null : graphColor(j['labelColor'], const Color(0xFF6B7280)),
        radius: _d(j['radius'], 3.5),
        fill: j['fill'] == null ? null : graphColor(j['fill'], const Color(0xFFFFFFFF)),
        below: _b(j['below'], false),
      );

  Json toJson() => {
        if (x != null) 'x': x,
        if (y != null) 'y': y,
        if (from != null) 'from': from,
        if (to != null) 'to': to,
        'color': _hex(color),
        'line': line,
        'width': width,
        if (label.isNotEmpty) 'label': label,
        if (labelColor != null) 'labelColor': _hex(labelColor!),
        'radius': radius,
        if (fill != null) 'fill': _hex(fill!),
        if (below) 'below': below,
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
    this.name = '',
    this.stack,
    this.radius = 0,
    this.colorField = '',
    this.colors = const [],
    this.inner = 0,
    this.gap = 0,
    this.startAngle = 0,
    this.labels = false,
    this.fillTo,
    this.colored = true,
    this.dots = 0,
    this.center = '',
    this.centerLabel = '',
  });

  /// Whether the mark's color was written; one that writes none takes the
  /// next of the style's palette (GraphStyleSpec.palette).
  final bool colored;

  /// A line: a dot of this radius on every row (0: none).
  final double dots;

  /// An arc with a hole: what is written in it. `total`: the sum of its
  /// values, and while a slice is selected that slice's value. Empty:
  /// nothing. [centerLabel] is written small under the figure (while a
  /// slice is selected, its label).
  final String center, centerLabel;

  /// A bar's value is written over it.
  final bool labels;

  /// An area's color at the bottom of the pane, when it is not its own
  /// (its fill runs from one to the other).
  final Color? fillTo;

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

  /// What a tooltip and a legend call the mark; empty for its field.
  final String name;

  /// Bars with the same stack stand on one another; bars with none (or
  /// another) stand side by side in the row's place.
  final String? stack;

  /// A bar's corner radius (the top of a stack's last bar).
  final double radius;

  /// A row field holding the row's own color (a slice's, a bar's).
  final String colorField;

  /// An arc's colors, row by row, where [colorField] gives none.
  final List<Color> colors;

  /// An arc: the hole's share of the radius (0: a pie), the room between
  /// slices and where the first starts (degrees, clockwise from the top).
  final double inner, gap, startAngle;

  String get label => name.isEmpty ? valueField : name;

  /// A candle, or a bar with open and close, is colored by its direction.
  bool get byDirection => open.isNotEmpty && close.isNotEmpty;

  /// The row fields the mark reads on the y scale.
  List<String> get fields => type == 'candle' ? [open, high, low, close] : [y];

  /// The fields that bound the mark for autoscale.
  List<String> get extentFields => type == 'candle' ? [high, low] : [y];

  /// The field of the mark's value (a candle's close).
  String get valueField => type == 'candle' ? close : y;

  /// [colorOf] gives the color of a mark that writes none (by the mark's
  /// field, so an area and the line along its top share one), and
  /// [palette] an arc's colors row by row when it writes none.
  factory GraphMarkSpec.fromJson(Json j, {Color? Function(String field)? colorOf, List<Color> palette = const []}) {
    final type = _s(j['type'], 'line');
    final written = j['color'] != null;
    final own = written || type == 'candle' || type == 'arc' ? null : colorOf?.call(_s(j['y'], ''));
    return GraphMarkSpec(
        type: type,
        y: _s(j['y'], ''),
        open: _s(j['open'], ''),
        high: _s(j['high'], ''),
        low: _s(j['low'], ''),
        close: _s(j['close'], ''),
        color: graphColor(j['color'], own ?? const Color(0xFF2962FF)),
        colored: written,
        dots: _d(j['dots'], 0),
        center: _s(j['center'], ''),
        centerLabel: _s(j['centerLabel'], ''),
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
        name: _s(j['name'], ''),
        stack: j['stack'] is String ? j['stack']! as String : null,
        radius: _d(j['radius'], 0),
        colorField: _s(j['colorField'], ''),
        colors: type == 'arc' && _l(j['colors']).isEmpty && !written
            ? palette
            : [for (final c in _l(j['colors'])) graphColor(c, const Color(0xFF2962FF))],
        inner: _d(j['inner'], 0),
        gap: _d(j['gap'], 0),
        startAngle: _d(j['startAngle'], 0),
        labels: _b(j['labels'], false),
        fillTo: j['fillTo'] == null ? null : graphColor(j['fillTo'], const Color(0x00000000)),
      );
  }

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
        if (name.isNotEmpty) 'name': name,
        if (stack != null) 'stack': stack,
        if (radius != 0) 'radius': radius,
        if (colorField.isNotEmpty) 'colorField': colorField,
        if (colors.isNotEmpty) 'colors': [for (final c in colors) _hex(c)],
        if (inner != 0) 'inner': inner,
        if (gap != 0) 'gap': gap,
        if (startAngle != 0) 'startAngle': startAngle,
        if (labels) 'labels': labels,
        if (fillTo != null) 'fillTo': _hex(fillTo!),
        if (dots != 0) 'dots': dots,
        if (center.isNotEmpty) 'center': center,
        if (centerLabel.isNotEmpty) 'centerLabel': centerLabel,
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
    this.coord = 'rect',
    this.guides = const [],
  });

  final List<GraphGuideSpec> guides;

  /// `rect` (marks over the x scale) or `polar` (the rows round a center:
  /// `arc` marks; no axes, and the x viewport does not move it).
  final String coord;
  bool get polar => coord == 'polar';

  /// Its share of the graph's height.
  final double grow;
  final GraphYSpec y;
  final List<GraphMarkSpec> marks;
  final List<GraphPriceLineSpec> priceLines;
  final List<GraphMarkerSpec> markers;

  factory GraphPaneSpec.fromJson(Json j, {Color? Function(String field)? colorOf, List<Color> palette = const []}) =>
      GraphPaneSpec(
        grow: _d(j['grow'], 1),
        y: GraphYSpec.fromJson(_m(j['y'])),
        marks: [for (final m in _l(j['marks'])) GraphMarkSpec.fromJson(_m(m), colorOf: colorOf, palette: palette)],
        priceLines: [for (final m in _l(j['priceLines'])) GraphPriceLineSpec.fromJson(_m(m))],
        markers: [for (final m in _l(j['markers'])) GraphMarkerSpec.fromJson(_m(m))],
        coord: _s(j['coord'], 'rect'),
        guides: [for (final g in _l(j['guides'])) GraphGuideSpec.fromJson(_m(g))],
      );

  Json toJson() => {
        'grow': grow,
        'y': y.toJson(),
        'marks': [for (final m in marks) m.toJson()],
        if (priceLines.isNotEmpty) 'priceLines': [for (final l in priceLines) l.toJson()],
        if (markers.isNotEmpty) 'markers': [for (final m in markers) m.toJson()],
        if (coord != 'rect') 'coord': coord,
        if (guides.isNotEmpty) 'guides': [for (final g in guides) g.toJson()],
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
    this.ink = const Color(0xFF111827),
    this.palette = graphPalette,
    this.tooltip = const Color(0xFFFFFFFF),
    this.tooltipText = const Color(0xFF111827),
    this.tooltipBorder = const Color(0x1F000000),
  });

  /// A tooltip: its ground (a surface over the graph), its text and the
  /// line round it.
  final Color tooltip, tooltipText, tooltipBorder;

  /// A figure written large (the one in a donut's hole).
  final Color ink;

  /// The colors of the marks that write none, in turn (and of an arc's
  /// slices and a legend's keys).
  final List<Color> palette;

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
        ink: graphColor(j['ink'], const Color(0xFF111827)),
        tooltip: graphColor(j['tooltip'], const Color(0xFFFFFFFF)),
        tooltipText: graphColor(j['tooltipText'], const Color(0xFF111827)),
        tooltipBorder: graphColor(j['tooltipBorder'], const Color(0x1F000000)),
        palette: _l(j['palette']).isEmpty
            ? graphPalette
            : [for (final c in _l(j['palette'])) graphColor(c, const Color(0xFF2962FF))],
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
        'ink': _hex(ink),
        'tooltip': _hex(tooltip),
        'tooltipText': _hex(tooltipText),
        'tooltipBorder': _hex(tooltipBorder),
        if (!identical(palette, graphPalette)) 'palette': [for (final c in palette) _hex(c)],
      };
}

/// The colors marks take in turn when neither they nor the style say: a
/// blue, then hues that stand apart from it and from one another.
const graphPalette = [
  Color(0xFF2962FF),
  Color(0xFF0C8275),
  Color(0xFFCD8700),
  Color(0xFFC9435D),
  Color(0xFF8551C0),
  Color(0xFF3DA23A),
  Color(0xFFDE6227),
  Color(0xFF087D9B),
];

/// The legend: a key for each named mark (its color and its name), or in a
/// polar pane for each slice (its color, its label and its share).
class GraphLegendSpec {
  const GraphLegendSpec({this.show = 'none', this.position = 'auto', this.values = true});

  /// `none` (a graph has no legend unless it asks). `auto`: drawn when
  /// there is more than one thing to tell apart and there is room: under a
  /// plot with two or more named marks; beside labeled slices in a graph
  /// wide enough that the ring keeps at least three quarters of its height
  /// (slices in a narrower graph have none). `always`: whenever there is a
  /// key to draw (slices in a narrower graph: under them).
  final String show;

  /// `bottom`, `top` (a line of keys, wrapped, in the middle) or `right` (a
  /// list). `auto`: under a plot; beside slices where the list fits there,
  /// else under them.
  final String position;

  /// Each slice's share is written after its label.
  final bool values;

  factory GraphLegendSpec.fromJson(Object? v) {
    if (v is bool) return GraphLegendSpec(show: v ? 'always' : 'none');
    final j = _m(v);
    final show = j['show'];
    return GraphLegendSpec(
      show: show is bool ? (show ? 'always' : 'none') : _s(show, 'none'),
      position: _s(j['position'], 'auto'),
      values: _b(j['values'], true),
    );
  }

  Json toJson() => {'show': show, 'position': position, 'values': values};
}

/// The selection: the row (or the one bar or slice) under the pointer, or
/// pinned by a tap. The graph draws it apart from the rest and says what it
/// holds in a tooltip; a page reads it as state (`selection`).
class GraphSelectionSpec {
  const GraphSelectionSpec({
    this.on = 'none',
    this.by = 'row',
    this.dim = 0.35,
    this.band,
    this.grow = 4,
    this.dot = 4,
    this.tooltip = true,
    this.title = '',
    this.tooltipFill,
    this.tooltipText,
    this.total = false,
  });

  /// `none`, `hover` (the pointer selects, and leaving clears), `tap` (a
  /// tap selects and stays; a tap on it again or on nothing clears) or
  /// `both` (hover, and a tap pins what is under it).
  final String on;

  /// `row`: everything the row has (a tooltip row per mark). `mark`: the
  /// one bar of a group or stack under the pointer.
  final String by;

  /// The opacity of what is not selected while something is (1: as it is).
  final double dim;

  /// A fill behind the selected row, the height of the pane; null for none.
  final Color? band;

  /// How much thicker a selected slice is drawn.
  final double grow;

  /// A dot of this radius on each line at the selected row (0: none).
  final double dot;

  /// Whether a tooltip is drawn, its first line ([title]: a row field,
  /// empty for the x label) and its colors (null: the style's tooltip and
  /// its text).
  final bool tooltip;
  final String title;
  final Color? tooltipFill, tooltipText;

  /// A last tooltip row with the sum of the row's marks.
  final bool total;

  bool get hover => on == 'hover' || on == 'both';
  bool get tap => on == 'tap' || on == 'both';

  factory GraphSelectionSpec.fromJson(Json j) => GraphSelectionSpec(
        on: _s(j['on'], 'none'),
        by: _s(j['by'], 'row'),
        dim: _d(j['dim'], 0.35),
        band: j['band'] == null ? null : graphColor(j['band'], const Color(0x14000000)),
        grow: _d(j['grow'], 4),
        dot: _d(j['dot'], 4),
        tooltip: _b(j['tooltip'], true),
        title: _s(j['title'], ''),
        tooltipFill: j['tooltipFill'] == null ? null : graphColor(j['tooltipFill'], const Color(0xFF111827)),
        tooltipText: j['tooltipText'] == null ? null : graphColor(j['tooltipText'], const Color(0xFFFFFFFF)),
        total: _b(j['total'], false),
      );

  Json toJson() => {
        'on': on,
        'by': by,
        'dim': dim,
        if (band != null) 'band': _hex(band!),
        'grow': grow,
        'dot': dot,
        'tooltip': tooltip,
        if (title.isNotEmpty) 'title': title,
        if (tooltipFill != null) 'tooltipFill': _hex(tooltipFill!),
        if (tooltipText != null) 'tooltipText': _hex(tooltipText!),
        'total': total,
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
    this.selection = const GraphSelectionSpec(),
    this.animate = 0,
    this.animateIn = false,
    this.legend = const GraphLegendSpec(),
  });

  final GraphLegendSpec legend;

  /// How long (ms) the marks take to move to new values when the rows
  /// change (0: at once), and whether they grow from zero when the graph
  /// first shows.
  final double animate;
  final bool animateIn;

  /// The row field that names a row across updates (its time): how an
  /// update is told from an append and from older rows put before.
  final String key;
  final GraphXSpec x;
  final List<GraphPaneSpec> panes;
  final List<GraphTransformSpec> transforms;
  final GraphCrosshairSpec crosshair;
  final GraphInteractionsSpec interactions;
  final GraphStyleSpec style;
  final GraphSelectionSpec selection;

  factory GraphSpec.fromJson(Json j) {
    final style = GraphStyleSpec.fromJson(_m(j['style']));
    // A mark that writes no color takes the palette's next: the first
    // such field the first color, and every mark of that field the same.
    final byField = <String, Color>{};
    Color? colorOf(String field) =>
        style.palette.isEmpty ? null : byField[field] ??= style.palette[byField.length % style.palette.length];
    return GraphSpec(
      key: _s(j['key'], 't'),
      x: GraphXSpec.fromJson(_m(j['x'])),
      panes: [for (final p in _l(j['panes'])) GraphPaneSpec.fromJson(_m(p), colorOf: colorOf, palette: style.palette)],
      transforms: [for (final t in _l(j['transforms'])) GraphTransformSpec.fromJson(_m(t))],
      crosshair: GraphCrosshairSpec.fromJson(_m(j['crosshair'])),
      interactions: GraphInteractionsSpec.fromJson(_m(j['interactions'])),
      style: style,
      selection: GraphSelectionSpec.fromJson(_m(j['selection'])),
      animate: _d(j['animate'], 0),
      animateIn: _b(j['animateIn'], false),
      legend: GraphLegendSpec.fromJson(j['legend']),
    );
  }

  Json toJson() => {
        'type': 'graph',
        'key': key,
        'x': x.toJson(),
        'panes': [for (final p in panes) p.toJson()],
        if (transforms.isNotEmpty) 'transforms': [for (final t in transforms) t.toJson()],
        'crosshair': crosshair.toJson(),
        'interactions': interactions.toJson(),
        'style': style.toJson(),
        if (selection.on != 'none') 'selection': selection.toJson(),
        if (animate > 0) 'animate': animate,
        if (animateIn) 'animateIn': animateIn,
        'legend': legend.toJson(),
      };
}
