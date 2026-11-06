import 'dart:convert';
import 'dart:math' as math;

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../functions/calc_function.dart';
import '../mapping/node_mapping.dart';
import 'codelessly_node_view.dart';
import 'genui_material_theme.dart';
import 'genui_theme.dart';
import 'visualization.dart';

/// Width for a leaf: the width it is given, or [fallback] when unbounded
/// (in a Row without weights).
Widget _sized(double fallback, Widget Function(double width) build) =>
    LayoutBuilder(
      builder: (context, constraints) => build(
        constraints.hasBoundedWidth
            ? math.max(1, constraints.maxWidth)
            : fallback,
      ),
    );

/// Runs a component's `action`, if it has one.
VoidCallback? _actionOf(ComponentProps props) {
  final NodeAction? action = props.action('action');
  if (action == null) return null;
  return () => action();
}

/// A write-back for [key] that reports failures as A2UI errors.
void Function(Object?)? _writer(
  BuildContext context,
  ComponentProps props,
  String key,
) {
  final WritableBinding<Object?>? binding = props.writable(key);
  if (binding == null) return null;
  final SurfaceModel<ComponentImplementation> surface = A2uiSurface.of(context);
  return (value) {
    try {
      binding.set(value);
    } on A2uiDataError catch (error) {
      surface.dispatchError(
        A2uiRendererError(
          code: error.code,
          surfaceId: surface.id,
          message: error.message,
          path: error.path,
        ),
      );
    }
  };
}

String _label(ComponentProps props, String key) => props.string(key) ?? '';

TextStyle _style(BuildContext context, String? variant) {
  final GenUiTheme theme = GenUiThemeScope.of(context);
  final s = CodelesslyNodes.textStyle(variant, theme);
  return genUiTextStyle(
    theme,
    TextStyle(
      fontSize: s.size,
      height: 1.35,
      fontWeight: switch (s.weight) {
        'w700' => FontWeight.w700,
        'w600' => FontWeight.w600,
        'w500' => FontWeight.w500,
        _ => FontWeight.w400,
      },
      color: Color(variant == 'caption' ? theme.mutedText : theme.text),
    ),
  );
}

/// A small label over an input, in the catalog's type.
Widget _fieldLabel(BuildContext context, String label, [String? trailing]) {
  final GenUiTheme theme = GenUiThemeScope.of(context);
  return Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: _style(context, 'h5').copyWith(fontSize: 13),
          ),
        ),
        if (trailing != null)
          Text(
            trailing,
            style: _style(context, null).copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(theme.primary),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Basic components rendered by Codelessly nodes
// ---------------------------------------------------------------------------

Widget buildText(
  BuildContext context,
  ComponentNode<ComponentImplementation> node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final GenUiTheme theme = GenUiThemeScope.of(context);
  final String text = _label(props, 'text');
  final String? variant = props.string('variant');
  return _sized(
    320,
    (width) => CodelesslyNodeView(
      nodeJson: CodelesslyNodes.text(
        id: node.componentId,
        text: text,
        width: width,
        theme: theme,
        variant: variant,
      ),
    ),
  );
}

Widget buildButton(
  BuildContext context,
  ComponentNode<ComponentImplementation> node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final GenUiTheme theme = GenUiThemeScope.of(context);
  final ComponentNode<ComponentImplementation>? child = props.child('child');
  final String? label = child == null
      ? null
      : ComponentProps(child.props.value).string('text');
  final VoidCallback? onTap = props.isValid ? _actionOf(props) : null;
  if (label == null && child != null) {
    // An icon or composite child: a plain Material button around it.
    return OutlinedButton(onPressed: onTap, child: buildChild(child));
  }
  // A button whose checks fail is drawn dimmed rather than in the SDK's
  // disabled style, which loses the label on a filled button.
  return Opacity(
    opacity: onTap == null ? 0.45 : 1,
    child: IgnorePointer(
      ignoring: onTap == null,
      child: CodelesslyNodeView(
        nodeJson: CodelesslyNodes.button(
          id: node.componentId,
          label: label ?? '',
          theme: theme,
          variant: props.string('variant'),
        ),
        onTap: onTap,
      ),
    ),
  );
}

Widget buildDivider(
  BuildContext context,
  ComponentNode<ComponentImplementation> node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final GenUiTheme theme = GenUiThemeScope.of(context);
  if (props.string('axis') == 'vertical') {
    return VerticalDivider(width: 17, color: Color(theme.border));
  }
  return _sized(
    320,
    (width) => CodelesslyNodeView(
      nodeJson: CodelesslyNodes.divider(
        id: node.componentId,
        width: width,
        theme: theme,
      ),
    ),
  );
}

Widget buildSlider(
  BuildContext context,
  ComponentNode<ComponentImplementation> node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final GenUiTheme theme = GenUiThemeScope.of(context);
  final double min = props.number('min') ?? 0;
  final double max = math.max(min + 1e-9, props.number('max') ?? 100);
  final double? step = props.number('step');
  final double raw = props.number('value') ?? min;
  final double value = raw.isFinite ? raw.clamp(min, max) : min;
  final int? divisions = step != null && step > 0
      ? math.max(1, ((max - min) / step).round())
      : null;
  final void Function(Object?)? write = _writer(context, props, 'value');
  final String unit = props.string('unit') ?? '';
  final String shown =
      '${NumberFormat.decimalPattern().format(_snap(value, step))}$unit';
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _fieldLabel(context, _label(props, 'label'), shown),
      _sized(
        280,
        (width) => CodelesslyNodeView(
          nodeJson: CodelesslyNodes.slider(
            id: node.componentId,
            value: value,
            min: min,
            max: max,
            width: width,
            theme: theme,
            divisions: divisions,
          ),
          bindings: {
            if (write != null)
              'value': NodePropertyBinding(
                value: value,
                type: VariableType.decimal,
                write: (v) => write(
                  v is num ? _snap(v.toDouble().clamp(min, max), step) : v,
                ),
              ),
          },
          onCommit: _actionOf(props),
          commitTrigger: TriggerType.changeEnd,
        ),
      ),
    ],
  );
}

num _snap(double v, double? step) {
  final double s = step != null && step > 0 ? (v / step).round() * step : v;
  final double r = double.parse(s.toStringAsFixed(6));
  return r == r.roundToDouble() ? r.toInt() : r;
}

Widget buildCheckBox(
  BuildContext context,
  ComponentNode<ComponentImplementation> node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final GenUiTheme theme = GenUiThemeScope.of(context);
  final bool value = props.boolean('value') ?? false;
  final void Function(Object?)? write = _writer(context, props, 'value');
  return _toggleRow(
    context,
    label: _label(props, 'label'),
    error: props.validationErrors.firstOrNull,
    onLabelTap: write == null ? null : () => write(!value),
    control: CodelesslyNodeView(
      nodeJson: CodelesslyNodes.checkbox(
        id: node.componentId,
        value: value,
        theme: theme,
      ),
      bindings: {
        if (write != null)
          'value': NodePropertyBinding(
            value: value,
            type: VariableType.boolean,
            write: write,
          ),
      },
      onCommit: _actionOf(props),
    ),
  );
}

Widget _toggleRow(
  BuildContext context, {
  required String label,
  required Widget control,
  VoidCallback? onLabelTap,
  String? error,
  bool trailing = false,
}) {
  final Widget text = Expanded(
    child: GestureDetector(
      onTap: onLabelTap,
      behavior: HitTestBehavior.opaque,
      child: Text(label, style: _style(context, null)),
    ),
  );
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: trailing
            ? [text, const SizedBox(width: 8), control]
            : [control, const SizedBox(width: 8), text],
      ),
      if (error != null)
        Text(
          error,
          style: _style(
            context,
            'caption',
          ).copyWith(color: Color(GenUiThemeScope.of(context).negative)),
        ),
    ],
  );
}

Widget buildSwitch(
  BuildContext context,
  ComponentNode<ComponentImplementation> node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final GenUiTheme theme = GenUiThemeScope.of(context);
  final bool value = props.boolean('value') ?? false;
  final void Function(Object?)? write = _writer(context, props, 'value');
  return _toggleRow(
    context,
    label: _label(props, 'label'),
    trailing: true,
    onLabelTap: write == null ? null : () => write(!value),
    control: CodelesslyNodeView(
      nodeJson: CodelesslyNodes.toggle(
        id: node.componentId,
        value: value,
        theme: theme,
      ),
      bindings: {
        if (write != null)
          'value': NodePropertyBinding(
            value: value,
            type: VariableType.boolean,
            write: write,
          ),
      },
      onCommit: _actionOf(props),
    ),
  );
}

Widget buildTextField(
  BuildContext context,
  ComponentNode<ComponentImplementation> node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final GenUiTheme theme = GenUiThemeScope.of(context);
  final String value = props.string('value') ?? '';
  final void Function(Object?)? write = _writer(context, props, 'value');
  final String variant = props.string('variant') ?? 'shortText';
  return _sized(
    280,
    (width) => CodelesslyNodeView(
      nodeJson: CodelesslyNodes.textField(
        id: node.componentId,
        label: _label(props, 'label'),
        width: width,
        theme: theme,
        variant: variant,
        // A check's message shows once there is something to check, not
        // on an empty form the user has not touched.
        errorText: value.isEmpty ? null : props.validationErrors.firstOrNull,
      ),
      bindings: {
        if (write != null)
          'inputValue': NodePropertyBinding(
            value: value,
            type: VariableType.text,
            write: (v) => write(
              variant == 'number' ? (num.tryParse('$v') ?? v) : '${v ?? ''}',
            ),
          ),
      },
      onCommit: _actionOf(props),
      commitTrigger: TriggerType.submitted,
    ),
  );
}

Widget buildChoicePicker(
  BuildContext context,
  ComponentNode<ComponentImplementation> node,
  ComponentProps props,
  ChildWidgetBuilder buildChild, {
  ComponentWidgetBuilder? fallback,
}) {
  final GenUiTheme theme = GenUiThemeScope.of(context);
  final List<({String value, String label})> options = [
    for (final Object? o in props.list('options'))
      if (o is Map && o['value'] is String)
        (
          value: o['value'] as String,
          label: ComponentProps.asString(o['label']) ?? o['value'] as String,
        ),
  ];
  final bool multi = props.string('variant') == 'multipleSelection';
  final List<String> selected = [
    for (final Object? v in props.list('value')) '$v',
  ];
  final void Function(Object?)? write = _writer(context, props, 'value');
  final VoidCallback? commit = _actionOf(props);
  final String label = _label(props, 'label');
  final String? error = props.validationErrors.firstOrNull;

  void pick(String value) {
    if (write == null) return;
    final List<String> next = multi
        ? (selected.contains(value)
              ? [
                  for (final v in selected)
                    if (v != value) v,
                ]
              : [...selected, value])
        : [value];
    if (!multi && selected.length == 1 && selected.first == value) return;
    write(next);
    commit?.call();
  }

  Widget chips(List<({String value, String label})> shown) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final o in options)
        Semantics(
          button: true,
          selected: selected.contains(o.value),
          label: o.label,
          child: CodelesslyNodeView(
            key: ValueKey('${node.instanceId}_${o.value}'),
            nodeJson: CodelesslyNodes.optionChip(
              id: '${node.componentId}_${o.value}',
              label: o.label,
              selected: selected.contains(o.value),
              theme: theme,
            ),
            onTap: write == null ? null : () => pick(o.value),
          ),
        ),
    ],
  );

  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (label.isNotEmpty) _fieldLabel(context, label),
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: props.boolean('filterable') == true
            ? _FilterableOptions(
                options: options,
                selected: selected,
                build: chips,
              )
            : chips(options),
      ),
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            error,
            style: _style(
              context,
              'caption',
            ).copyWith(color: Color(theme.negative)),
          ),
        ),
    ],
  );
}

/// A search field over a ChoicePicker's options (`filterable`). Selected
/// options stay listed while they are filtered out, so the choice stays
/// visible.
class _FilterableOptions extends StatefulWidget {
  const _FilterableOptions({
    required this.options,
    required this.selected,
    required this.build,
  });

  final List<({String value, String label})> options;
  final List<String> selected;
  final Widget Function(List<({String value, String label})>) build;

  @override
  State<_FilterableOptions> createState() => _FilterableOptionsState();
}

class _FilterableOptionsState extends State<_FilterableOptions> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final String q = _query.trim().toLowerCase();
    final shown = [
      for (final o in widget.options)
        if (q.isEmpty ||
            o.label.toLowerCase().contains(q) ||
            widget.selected.contains(o.value))
          o,
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        TextField(
          onChanged: (v) => setState(() => _query = v),
          style: Theme.of(context).textTheme.bodyMedium,
          decoration: const InputDecoration(
            hintText: 'Search',
            prefixIcon: Icon(Icons.search, size: 18),
          ),
        ),
        if (shown.isEmpty)
          Text('No matches', style: Theme.of(context).textTheme.bodySmall)
        else
          widget.build(shown),
      ],
    );
  }
}

/// A2UI `Image`, rounded, with a themed placeholder while it loads and when
/// it fails. Sizes follow the basic catalog's variants.
Widget buildImage(
  BuildContext context,
  ComponentNode<ComponentImplementation> node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final GenUiTheme theme = GenUiThemeScope.of(context);
  final String url = props.string('url') ?? '';
  final String description = props.string('description') ?? '';
  final String? variant = props.string('variant');
  final BoxFit fit =
      BoxFit.values.asNameMap()[props.string('fit')] ??
      (variant == 'avatar' || variant == 'icon' ? BoxFit.cover : BoxFit.cover);
  final double radius = switch (variant) {
    'avatar' => 999,
    'icon' => 6,
    _ => 12,
  };
  final double? height = switch (variant) {
    'icon' => 24,
    'avatar' => 40,
    'smallFeature' => 72,
    'mediumFeature' => 160,
    'largeFeature' => 240,
    'header' => 200,
    _ => null,
  };
  final double? width = switch (variant) {
    'icon' => 24,
    'avatar' => 40,
    'smallFeature' => 96,
    _ => null,
  };
  Widget placeholder(IconData? icon) => Container(
    color: Color(theme.surfaceAlt),
    alignment: Alignment.center,
    child: icon == null || (height != null && height < 40)
        ? null
        : Icon(icon, color: Color(theme.mutedText), size: 22),
  );
  final bool network = url.startsWith('https://') || url.startsWith('http://');
  final Widget image = !network
      ? placeholder(Icons.image_not_supported_outlined)
      : Image.network(
          url,
          fit: fit,
          semanticLabel: description.isEmpty ? null : description,
          excludeFromSemantics: description.isEmpty,
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : placeholder(null),
          errorBuilder: (context, error, stack) =>
              placeholder(Icons.broken_image_outlined),
        );
  final Widget clipped = ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: SizedBox(
      width: width,
      height: height ?? (network ? null : 160),
      child: image,
    ),
  );
  return width != null
      ? Align(
          alignment: AlignmentDirectional.centerStart,
          widthFactor: 1,
          child: clipped,
        )
      : clipped;
}

/// Runs [onCommit] when [value] changes soon after the user touched
/// [child]. It gives the commit `action` extension to inputs drawn by the
/// a2ui_flutter basic widgets (the chip picker, the date and time input),
/// which only write the data model. A change the agent makes, with no touch
/// before it, sends nothing.
class CommitOnUserChange extends StatefulWidget {
  const CommitOnUserChange({
    super.key,
    required this.value,
    required this.onCommit,
    required this.child,
  });

  final Object? value;
  final VoidCallback? onCommit;
  final Widget child;

  @override
  State<CommitOnUserChange> createState() => _CommitOnUserChangeState();
}

class _CommitOnUserChangeState extends State<CommitOnUserChange> {
  DateTime? _touched;

  @override
  void didUpdateWidget(CommitOnUserChange oldWidget) {
    super.didUpdateWidget(oldWidget);
    final DateTime? touched = _touched;
    if (touched != null &&
        DateTime.now().difference(touched) < const Duration(minutes: 2) &&
        jsonEncode(oldWidget.value) != jsonEncode(widget.value)) {
      _touched = null;
      final VoidCallback? commit = widget.onCommit;
      if (commit != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => commit());
      }
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => _touched = DateTime.now(),
    child: widget.child,
  );
}

Widget buildDateTimeInput(
  BuildContext context,
  ComponentNode<ComponentImplementation> node,
  ComponentProps props,
  ChildWidgetBuilder buildChild, {
  required ComponentWidgetBuilder basic,
}) => CommitOnUserChange(
  value: props.value('value'),
  onCommit: _actionOf(props),
  child: basic(context, node, props, buildChild),
);

Widget buildCard(
  BuildContext context,
  ComponentNode<ComponentImplementation> node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final GenUiTheme theme = GenUiThemeScope.of(context);
  final ComponentNode<ComponentImplementation>? child = props.child('child');
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Color(theme.surface),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Color(theme.border)),
    ),
    // List tiles (the basic radio and chip pickers) need a Material between
    // them and the card's decoration.
    child: child == null
        ? null
        : Material(type: MaterialType.transparency, child: buildChild(child)),
  );
}

// ---------------------------------------------------------------------------
// Codelessly extensions
// ---------------------------------------------------------------------------

List<Map<String, Object?>> _rows(Object? value) => [
  if (value is List)
    for (final Object? row in value)
      if (row is Map) {for (final e in row.entries) '${e.key}': e.value},
];

Widget buildChart(
  BuildContext context,
  ComponentNode<ComponentImplementation> node,
  ComponentProps props,
  ChildWidgetBuilder buildChild, {
  double? heightOverride,
}) {
  final GenUiTheme theme = GenUiThemeScope.of(context);
  final List<Map<String, Object?>> rows = _rows(props.value('data'));
  final List<Map<String, Object?>> series = [
    for (final Object? s in props.list('series'))
      if (s is Map && s['field'] is String)
        {for (final e in s.entries) '${e.key}': e.value},
  ];
  final String xField =
      props.string('xField') ??
      (rows.isEmpty
          ? 'label'
          : rows.first.keys.firstWhere(
              (k) => !series.any((s) => s['field'] == k),
              orElse: () => 'label',
            ));
  final String title = props.string('title') ?? '';
  final double inlineHeight = props.number('height') ?? 200;
  final double height =
      heightOverride ??
      (GenUiDisplayMode.isFullscreen(context)
          ? math.max(380, inlineHeight * 1.8)
          : inlineHeight);
  final String chartType = props.string('chartType') ?? 'line';
  final WritableBinding<Object?>? selection = props.writable('selectedIndex');
  final int selected = props.number('selectedIndex')?.round() ?? -1;
  final bool legend = props.boolean('showLegend') ?? series.length > 1;
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (title.isNotEmpty) Text(title, style: _style(context, 'h5')),
      if (chartType == 'donut' && rows.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 6),
          child: Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              for (int i = 0; i < rows.length; i++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Color(
                          GenUiTheme.parseHexColor(
                                rows[i][series.firstOrNull?['colorField']]
                                    as String?,
                              ) ??
                              theme.series[i % theme.series.length],
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${rows[i][xField] ?? ''}',
                      style: _style(context, 'caption'),
                    ),
                  ],
                ),
            ],
          ),
        )
      else if (legend && series.length > 1)
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              for (int i = 0; i < series.length; i++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Color(
                          GenUiTheme.parseHexColor(
                                series[i]['color'] as String?,
                              ) ??
                              theme.series[i % theme.series.length],
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${series[i]['name'] ?? series[i]['field']}',
                      style: _style(context, 'caption'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      _sized(320, (width) {
        final Widget chart = CodelesslyNodeView(
          nodeJson: CodelesslyNodes.chart(
            id: node.componentId,
            chartType: chartType,
            rows: rows,
            xField: xField,
            series: series,
            width: width,
            height: height,
            theme: theme,
            minY: props.number('minY') ?? _niceMin(rows, series, chartType),
            maxY: props.number('maxY'),
            yLabelPrefix: props.string('yLabelPrefix') ?? '',
            yLabelSuffix: props.string('yLabelSuffix') ?? '',
            xLabelEvery: props.number('xLabelEvery')?.round(),
            selectedIndex: selected,
          ),
        );
        if (selection == null || rows.isEmpty) return chart;
        // Scrubbing: dragging over the chart writes the row under the
        // finger to the bound path.
        void scrub(Offset local) {
          const double yAxis = 36;
          final double plot = math.max(1, width - yAxis);
          final double t = ((local.dx - yAxis) / plot).clamp(0, 1);
          final int index = (t * (rows.length - 1)).round();
          if (index != selected) selection.set(index);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => scrub(d.localPosition),
          onHorizontalDragStart: (d) => scrub(d.localPosition),
          onHorizontalDragUpdate: (d) => scrub(d.localPosition),
          child: chart,
        );
      }),
    ],
  );
}

/// A y-axis start for line charts that fits the data instead of starting
/// at zero, rounded to a step of the data's range.
double? _niceMin(
  List<Map<String, Object?>> rows,
  List<Map<String, Object?>> series,
  String chartType,
) {
  if (chartType != 'line' || rows.isEmpty) return null;
  double lo = double.infinity, hi = -double.infinity;
  for (final row in rows) {
    for (final s in series) {
      if (s['kind'] == 'area' || s['kind'] == 'bar') return null;
      final Object? v = row[s['field']];
      if (v is num) {
        lo = math.min(lo, v.toDouble());
        hi = math.max(hi, v.toDouble());
      }
    }
  }
  if (!lo.isFinite || lo <= 0) return null;
  final double span = math.max(hi - lo, hi.abs() * 0.05);
  final double step = math
      .pow(10, (math.log(span) / math.ln10).floor())
      .toDouble();
  final double min = ((lo - span * 0.15) / step).floor() * step;
  return min <= 0 ? null : min;
}

Widget buildGauge(
  BuildContext context,
  ComponentNode<ComponentImplementation> node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final GenUiTheme theme = GenUiThemeScope.of(context);
  final double min = props.number('min') ?? 0;
  final double max = props.number('max') ?? 100;
  final double value = (props.number('value') ?? min).clamp(min, max);
  final double size = props.number('size') ?? 180;
  final String unit = props.string('unit') ?? '';
  final String label = props.string('label') ?? '';
  final List<Map<String, Object?>> zones = _rows(props.value('zones'));
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: size,
        height: size * 0.84,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CodelesslyNodeView(
              nodeJson: CodelesslyNodes.gauge(
                id: node.componentId,
                value: value,
                min: min,
                max: max,
                size: size,
                theme: theme,
                zones: zones,
                target: props.number('target'),
              ),
            ),
            Positioned(
              bottom: size * 0.1,
              child: Text(
                '${NumberFormat('0.#').format(value)}$unit',
                style: _style(
                  context,
                  'h2',
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ),
          ],
        ),
      ),
      if (label.isNotEmpty)
        Text(
          label,
          style: _style(context, 'caption'),
          textAlign: TextAlign.center,
        ),
    ],
  );
}

Widget buildProgress(
  BuildContext context,
  ComponentNode<ComponentImplementation> node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final GenUiTheme theme = GenUiThemeScope.of(context);
  final double value = props.number('value') ?? 0;
  final String label = props.string('label') ?? '';
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (label.isNotEmpty)
        _fieldLabel(context, label, '${(value.clamp(0, 1) * 100).round()}%'),
      _sized(
        280,
        (width) => CodelesslyNodeView(
          nodeJson: CodelesslyNodes.progress(
            id: node.componentId,
            value: value,
            width: width,
            theme: theme,
            color: props.string('color'),
          ),
        ),
      ),
    ],
  );
}

Widget buildMetric(
  BuildContext context,
  ComponentNode<ComponentImplementation> node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final GenUiTheme theme = GenUiThemeScope.of(context);
  final String tone = props.string('tone') ?? 'neutral';
  final String caption = props.string('caption') ?? '';
  final String valueText = switch (props.value('value')) {
    final num n => NumberFormat.decimalPattern().format(
      _snap(n.toDouble(), null),
    ),
    _ => props.string('value') ?? '—',
  };
  final int color = switch (tone) {
    'positive' => theme.positive,
    'negative' => theme.negative,
    'accent' => theme.primary,
    _ => theme.text,
  };
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: Color(theme.surfaceAlt),
      borderRadius: BorderRadius.circular(12),
    ),
    child: _sized(
      140,
      (width) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CodelesslyNodeView(
            nodeJson: CodelesslyNodes.text(
              id: '${node.componentId}_label',
              text: _label(props, 'label'),
              width: width,
              theme: theme,
              variant: 'caption',
            ),
          ),
          // A long figure shrinks to fit the tile rather than wrapping.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: CodelesslyNodeView(
              nodeJson: CodelesslyNodes.text(
                id: node.componentId,
                text: valueText,
                width: math.max(width, valueText.length * 11.0 + 4),
                theme: theme,
                variant: 'h3',
                color: CodelesslyNodes.hex(color),
              ),
            ),
          ),
          if (caption.isNotEmpty)
            CodelesslyNodeView(
              nodeJson: CodelesslyNodes.text(
                id: '${node.componentId}_caption',
                text: caption,
                width: width,
                theme: theme,
                variant: 'caption',
              ),
            ),
        ],
      ),
    ),
  );
}

Widget buildTable(
  BuildContext context,
  ComponentNode<ComponentImplementation> node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final GenUiTheme theme = GenUiThemeScope.of(context);
  final List<Map<String, Object?>> rows = _rows(props.value('rows'));
  final List<Map<String, Object?>> columns = _rows(props.value('columns'));
  final String? checkField = props.string('checkField');
  final WritableBinding<Object?>? rowsBinding = props.writable('rows');
  final NodeAction? action = props.action('action');
  final String currency = props.string('currency') ?? 'USD';
  final NumberFormat money = NumberFormat.simpleCurrency(name: currency);

  Object? cell(Map<String, Object?> row, Map<String, Object?> column) {
    final Object? expr = column['expr'];
    if (expr is String && expr.isNotEmpty) return evaluateCalc(expr, row);
    return row[column['field']];
  }

  String format(Object? value, Map<String, Object?> column) {
    final String fmt = (column['format'] as String?) ?? 'text';
    final int? decimals = (column['decimals'] as num?)?.toInt();
    if (value is! num) {
      final num? parsed = num.tryParse('${value ?? ''}');
      if (fmt == 'text' || parsed == null) return value == null ? '' : '$value';
      value = parsed;
    }
    return switch (fmt) {
      'currency' => money.format(value),
      'percent' => '${(value * 100).toStringAsFixed(decimals ?? 0)}%',
      'number' =>
        decimals == null
            ? NumberFormat.decimalPattern().format(value)
            : value.toStringAsFixed(decimals),
      _ => '$value',
    };
  }

  bool numeric(Map<String, Object?> column) =>
      const {'number', 'currency', 'percent'}.contains(column['format']);

  final bool hasTotals = columns.any((c) => c['total'] == true);
  final TextStyle head = _style(
    context,
    'caption',
  ).copyWith(fontWeight: FontWeight.w600);
  final TextStyle body = _style(
    context,
    null,
  ).copyWith(fontSize: 13, fontFeatures: const [FontFeature.tabularFigures()]);

  Widget textCell(String s, TextStyle style, bool right) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
    child: Text(s, style: style, textAlign: right ? TextAlign.right : null),
  );

  void toggle(int index, bool checked) {
    if (rowsBinding == null || checkField == null) return;
    final List<Object?> next = [
      for (int i = 0; i < rows.length; i++)
        i == index ? {...rows[i], checkField: checked} : rows[i],
    ];
    rowsBinding.set(next);
    if (action != null) {
      action();
    }
  }

  // Text columns share the width and wrap; number columns keep their
  // natural width. Very narrow layouts scroll sideways.
  final int offset = checkField != null ? 1 : 0;
  final Map<int, TableColumnWidth> widths = {
    if (checkField != null) 0: const FixedColumnWidth(40),
    // The first text column (usually the item name) takes the spare width
    // and wraps; the other columns keep their natural width.
    for (int i = 0; i < columns.length; i++)
      i + offset:
          !numeric(columns[i]) && i == columns.indexWhere((c) => !numeric(c))
          ? const FlexColumnWidth()
          : const IntrinsicColumnWidth(),
  };
  // The width the columns need without squeezing: the longest text in each
  // (at about 7.5 px a character), and at least 150 px for the item column.
  final int flexColumn = columns.indexWhere((c) => !numeric(c));
  double natural = checkField != null ? 40 : 0;
  for (int i = 0; i < columns.length; i++) {
    int longest = '${columns[i]['header'] ?? ''}'.length;
    for (final row in rows) {
      longest = math.max(
        longest,
        format(cell(row, columns[i]), columns[i]).length,
      );
    }
    final double w = longest * 7.5 + 14;
    natural += i == flexColumn ? math.max(150, math.min(w, 240)) : w;
  }
  return LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints.tightFor(
          width: math.max(
            math.max(300, natural),
            constraints.hasBoundedWidth ? constraints.maxWidth : 360,
          ),
        ),
        child: Table(
          columnWidths: widths,
          defaultColumnWidth: const IntrinsicColumnWidth(),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          border: TableBorder(
            horizontalInside: BorderSide(color: Color(theme.border)),
            bottom: BorderSide(color: Color(theme.border)),
          ),
          children: [
            TableRow(
              decoration: BoxDecoration(color: Color(theme.surfaceAlt)),
              children: [
                if (checkField != null) const SizedBox(width: 40),
                for (final c in columns)
                  textCell('${c['header'] ?? ''}', head, numeric(c)),
              ],
            ),
            for (int i = 0; i < rows.length; i++)
              TableRow(
                children: [
                  if (checkField != null)
                    CodelesslyNodeView(
                      key: ValueKey('${node.componentId}_check_$i'),
                      nodeJson: CodelesslyNodes.checkbox(
                        id: '${node.componentId}_check_$i',
                        value: rows[i][checkField] == true,
                        theme: theme,
                      ),
                      bindings: {
                        'value': NodePropertyBinding(
                          value: rows[i][checkField] == true,
                          type: VariableType.boolean,
                          write: (v) => toggle(i, v == true),
                        ),
                      },
                    ),
                  for (final c in columns)
                    textCell(
                      format(cell(rows[i], c), c),
                      checkField != null && rows[i][checkField] == true
                          ? body.copyWith(color: Color(theme.mutedText))
                          : body,
                      numeric(c),
                    ),
                ],
              ),
            if (hasTotals)
              TableRow(
                children: [
                  if (checkField != null) const SizedBox(),
                  for (int ci = 0; ci < columns.length; ci++)
                    columns[ci]['total'] == true
                        ? textCell(
                            format(
                              rows.fold<num>(
                                0,
                                (sum, r) =>
                                    sum +
                                    (num.tryParse('${cell(r, columns[ci])}') ??
                                        0),
                              ),
                              columns[ci],
                            ),
                            body.copyWith(fontWeight: FontWeight.w700),
                            true,
                          )
                        : textCell(
                            ci == 0 ? 'Total' : '',
                            body.copyWith(fontWeight: FontWeight.w700),
                            false,
                          ),
                ],
              ),
          ],
        ),
      ),
    ),
  );
}
