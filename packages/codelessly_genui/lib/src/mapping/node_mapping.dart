import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart' show EdgeInsetsModel;

import '../render/genui_theme.dart';

/// Builds Codelessly node JSON (the wire format `NodeJsonConverter` reads,
/// the same JSON a published Codelessly layout holds) from resolved A2UI
/// property values.
///
/// Each function maps one A2UI component to one Codelessly node. The node
/// ids are the A2UI component ids, so a node and the component it renders
/// can always be matched (and an export round-trips to the same ids).
abstract final class CodelesslyNodes {
  static List<Object> _box(double w, double h) => [0, 0, w, h];

  static String hex(int argb) =>
      '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  static Map<String, Object?> _fill(String color) => {
    'id': 'fill',
    'type': 'solid',
    'color': color,
  };

  /// The text style of an A2UI text `variant`.
  static ({double size, String weight, String color}) textStyle(
    String? variant,
    GenUiTheme theme,
  ) => switch (variant) {
    'h1' => (size: 26, weight: 'w700', color: hex(theme.text)),
    'h2' => (size: 21, weight: 'w700', color: hex(theme.text)),
    'h3' => (size: 18, weight: 'w600', color: hex(theme.text)),
    'h4' => (size: 16, weight: 'w600', color: hex(theme.text)),
    'h5' => (size: 14, weight: 'w600', color: hex(theme.text)),
    'caption' => (size: 12, weight: 'w400', color: hex(theme.mutedText)),
    _ => (size: 14, weight: 'w400', color: hex(theme.text)),
  };

  static Map<String, Object?> fontName(String weight, GenUiTheme theme) => {
    'family': theme.fontFamily,
    'style': switch (weight) {
      'w700' => 'Bold',
      'w600' => 'SemiBold',
      'w500' => 'Medium',
      _ => 'Regular',
    },
    'weight': weight,
  };

  /// A2UI `Text` → Codelessly `text`. Wraps to [width] and grows to fit.
  static Map<String, Object?> text({
    required String id,
    required String text,
    required double width,
    required GenUiTheme theme,
    String? variant,
    String? color,
    String align = 'left',
  }) {
    final style = textStyle(variant, theme);
    return {
      'id': id,
      'name': variant == null ? 'Text' : 'Text ($variant)',
      'type': 'text',
      'basicBoxLocal': _box(width, style.size * 1.4),
      'horizontalFit': 'fixed',
      'verticalFit': 'shrinkWrap',
      'data': text,
      'textAlignHorizontal': align,
      'textMixedProps': [
        {
          'start': 0,
          'end': text.length,
          'fontSize': style.size,
          'fontName': fontName(style.weight, theme),
          'lineHeight': {'value': style.size * 1.4, 'unit': 'pixels'},
          'fills': [_fill(color ?? style.color)],
        },
      ],
    };
  }

  /// A2UI `Button` → Codelessly `filledButton`, `outlinedButton` or
  /// `textButton` by variant.
  static Map<String, Object?> button({
    required String id,
    required String label,
    required GenUiTheme theme,
    String? variant,
    bool enabled = true,
    double? width,
  }) {
    final String type = switch (variant) {
      'primary' => 'filledButton',
      'borderless' => 'textButton',
      _ => 'outlinedButton',
    };
    final double w = width ?? math.max(88, label.length * 8.0 + 40);
    final bool filled = type == 'filledButton';
    return {
      'id': id,
      'name': 'Button',
      'type': type,
      'basicBoxLocal': _box(w, 40),
      'enabled': enabled,
      'properties': {
        'label': label,
        'shape': 'roundedRectangle',
        if (filled) 'buttonColor': hex(theme.primary),
        if (type == 'filledButton') 'variant': 'filled',
        'labelStyle': {
          'fontSize': 14,
          'fontName': fontName('w600', theme),
          'fills': [_fill(filled ? '#FFFFFF' : hex(theme.primary))],
        },
      },
    };
  }

  /// A2UI `Slider` → Codelessly `slider`.
  static Map<String, Object?> slider({
    required String id,
    required double value,
    required double min,
    required double max,
    required double width,
    required GenUiTheme theme,
    int? divisions,
  }) => {
    'id': id,
    'name': 'Slider',
    'type': 'slider',
    'basicBoxLocal': _box(width, 36),
    'value': value,
    'properties': {
      'min': min,
      'max': max,
      if (divisions != null) 'divisions': divisions,
      if (divisions != null) 'isDiscrete': true,
      'activeTrackColor': hex(theme.primary),
      'thumbColor': hex(theme.primary),
      'thumbRadius': 9,
      'thumbBorderColor': '#FFFFFF',
      'thumbBorderWidth': 2,
      'thumbStrokeColor': '#FFFFFF',
      'thumbStrokeWidth': 2,
      'inactiveTrackColor': hex(theme.track),
      'trackHeight': 4,
      // Room for the thumb only, so the track lines up with the label.
      'padding': const EdgeInsetsModel.symmetric(horizontal: 11).toJson(),
      'activeTickMarkColor': '#00000000',
      'inactiveTickMarkColor': '#00000000',
      'showLabel': false,
    },
  };

  /// A2UI `CheckBox` → Codelessly `checkbox` (the label is a text node).
  static Map<String, Object?> checkbox({
    required String id,
    required bool value,
    required GenUiTheme theme,
  }) => {
    'id': id,
    'name': 'Checkbox',
    'type': 'checkbox',
    'basicBoxLocal': _box(32, 32),
    'value': value,
    'properties': {'activeColor': hex(theme.primary), 'checkColor': '#FFFFFF'},
  };

  /// `CodelesslySwitch` → Codelessly `switch`.
  static Map<String, Object?> toggle({
    required String id,
    required bool value,
    required GenUiTheme theme,
  }) => {
    'id': id,
    'name': 'Switch',
    'type': 'switch',
    'basicBoxLocal': _box(52, 32),
    'value': value,
    'properties': {
      'useMaterial3': true,
      'activeTrackColor': hex(theme.primary),
      'activeThumbColor': '#FFFFFF',
    },
  };

  /// A2UI `TextField` → Codelessly `textField`.
  static Map<String, Object?> textField({
    required String id,
    required String label,
    required double width,
    required GenUiTheme theme,
    String variant = 'shortText',
    String? errorText,
  }) {
    final bool long = variant == 'longText';
    return {
      'id': id,
      'name': 'TextField',
      'type': 'textField',
      'basicBoxLocal': _box(width, long ? 96 : 52),
      'properties': {
        'keyboardType': switch (variant) {
          'number' => 'number',
          _ => long ? 'multiline' : 'text',
        },
        'obscureText': variant == 'obscured',
        if (long) 'maxLines': 4,
        if (long) 'minLines': 3,
        'cursorColor': hex(theme.primary),
        'inputStyle': {
          'fontSize': 14,
          'fontName': fontName('w400', theme),
          'fills': [_fill(hex(theme.text))],
        },
        'decoration': {
          'labelText': label,
          'errorText': ?errorText,
          'filled': true,
          'fillColor': hex(theme.inputFill),
          'isDense': true,
        },
      },
    };
  }

  /// A2UI `ChoicePicker` (mutually exclusive, few options) → Codelessly
  /// `segmentedButton`.
  static Map<String, Object?> segmented({
    required String id,
    required List<({String value, String label})> options,
    required List<String> selected,
    required double width,
    required GenUiTheme theme,
    bool multi = false,
  }) => {
    'id': id,
    'name': 'ChoicePicker',
    'type': 'segmentedButton',
    'basicBoxLocal': _box(width, 40),
    'properties': {
      'segments': [
        for (final o in options) {'value': o.value, 'label': o.label},
      ],
      'selectedSegments': selected,
      'multiSelectionEnabled': multi,
      'emptySelectionAllowed': multi,
      'showSelectedIcon': false,
      'selectedColor': hex(theme.primarySoft),
      'selectedForegroundColor': hex(theme.primary),
    },
  };

  /// One option of an A2UI `ChoicePicker` → a Codelessly `chip` (action
  /// kind), drawn in the selected or unselected style of the theme. The
  /// picker owns the selection, so the chip's look comes from [selected].
  static Map<String, Object?> optionChip({
    required String id,
    required String label,
    required bool selected,
    required GenUiTheme theme,
  }) {
    final double width = label.length * 7.8 + 30;
    return {
      'id': id,
      'name': 'Option',
      'type': 'chip',
      'basicBoxLocal': _box(width, 36),
      'horizontalFit': 'shrinkWrap',
      'verticalFit': 'shrinkWrap',
      'properties': {
        'chipType': 'action',
        'label': label,
        'backgroundColor': hex(selected ? theme.primarySoft : theme.surface),
        'borderColor': hex(selected ? theme.primary : theme.border),
        'borderWidth': selected ? 1.5 : 1,
        'cornerRadius': 10,
        'elevation': 0,
        'padding': const EdgeInsetsModel.symmetric(
          horizontal: 12,
          vertical: 6,
        ).toJson(),
        'labelPadding': EdgeInsetsModel.zero.toJson(),
        'labelStyle': {
          'fontSize': 13.5,
          'fontName': fontName(selected ? 'w600' : 'w500', theme),
          'fills': [_fill(hex(selected ? theme.primary : theme.text))],
        },
      },
    };
  }

  /// A2UI `Divider` → Codelessly `divider`.
  static Map<String, Object?> divider({
    required String id,
    required double width,
    required GenUiTheme theme,
  }) => {
    'id': id,
    'name': 'Divider',
    'type': 'divider',
    'basicBoxLocal': _box(width, 17),
    'properties': {'color': hex(theme.border), 'thickness': 1},
  };

  /// `CodelesslyChart` → Codelessly `chart` (series kind).
  static Map<String, Object?> chart({
    required String id,
    required String chartType,
    required List<Map<String, Object?>> rows,
    required String xField,
    required List<Map<String, Object?>> series,
    required double width,
    required double height,
    required GenUiTheme theme,
    double? minY,
    double? maxY,
    String yLabelPrefix = '',
    String yLabelSuffix = '',
    int? xLabelEvery,
    int selectedIndex = -1,
  }) {
    final List<int> palette = theme.series;
    // Leave room for each x label: about 6.5 px per character plus a gap.
    final int longest = rows.fold(
      1,
      (n, r) => math.max(n, '${r[xField] ?? ''}'.length),
    );
    final double slot = longest * 6.5 + 14;
    final int every =
        xLabelEvery ??
        math.max(1, (rows.length / math.max(1, (width - 40) / slot)).ceil());
    // A donut colors its slices by a row field; without one, every slice
    // would share the series color, so each row gets a palette color.
    if (chartType == 'donut' &&
        series.isNotEmpty &&
        series.first['colorField'] == null) {
      rows = [
        for (int i = 0; i < rows.length; i++)
          {...rows[i], '_color': hex(palette[i % palette.length])},
      ];
      series = [
        {...series.first, 'colorField': '_color'},
        ...series.skip(1),
      ];
    }
    return {
      'id': id,
      'name': 'Chart',
      'type': 'chart',
      'chartKind': 'series',
      'basicBoxLocal': _box(width, height),
      'selectedIndex': selectedIndex,
      'properties': {
        'chartType': chartType,
        'labelField': xField,
        'sampleData': rows,
        'series': [
          for (int i = 0; i < series.length; i++)
            {
              'field': series[i]['field'],
              'name': series[i]['name'] ?? series[i]['field'],
              'kind':
                  series[i]['kind'] ?? (chartType == 'bar' ? 'bar' : 'line'),
              'color': series[i]['color'] ?? hex(palette[i % palette.length]),
              'stack': ?series[i]['stack'],
              'colorField': ?series[i]['colorField'],
              if (series[i]['dashed'] == true) 'dashed': true,
              if (series[i]['curved'] == true) 'curved': true,
              'strokeWidth': 2.5,
              if (i == 0 && chartType == 'line') 'endDot': true,
            },
        ],
        'minY': ?minY,
        'maxY': ?maxY,
        'fitMinY': minY == null,
        'xLabelEvery': every,
        'gridColor': hex(theme.border),
        'axisLabelColor': hex(theme.mutedText),
        'axisFontSize': 10,
        'axisFontFamily': theme.fontFamily,
        'yLabelPrefix': yLabelPrefix,
        'yLabelSuffix': yLabelSuffix,
        'barRadius': 3,
        'selectionColor': '#14${hex(theme.primary).substring(1)}',
        'dashEmpty': false,
      },
    };
  }

  /// `CodelesslyGauge` → Codelessly radial `gauge`.
  static Map<String, Object?> gauge({
    required String id,
    required double value,
    required double min,
    required double max,
    required double size,
    required GenUiTheme theme,
    List<Map<String, Object?>> zones = const [],
    double? target,
  }) {
    final double span = (max - min).abs() < 1e-9 ? 1 : max - min;
    final List<Map<String, Object?>> stops = [];
    double from = 0;
    for (final Map<String, Object?> zone in zones) {
      final double to =
          (((zone['to'] as num?)?.toDouble() ?? max) - min) / span;
      stops.add({
        'from': from * 100,
        'to': to.clamp(0, 1) * 100,
        'color': zone['color'],
      });
      from = to.clamp(0, 1);
    }
    return {
      'id': id,
      'name': 'Gauge',
      'type': 'gauge',
      'gaugeKind': 'radial',
      'basicBoxLocal': _box(size, size * 0.84),
      'value': value,
      'properties': {
        'min': min,
        'max': max,
        'animate': false,
        'valueColor': hex(theme.primary),
        'trackColor': hex(theme.track),
        'colorByZone': stops.isNotEmpty,
        if (stops.isNotEmpty) 'zones': stops,
        'showTarget': target != null,
        'target': ?target,
        'labels': const <double>[],
        'labelFontFamily': theme.fontFamily,
        'majorTicks': 8,
        'labelColor': hex(theme.mutedText),
        'needleColor': hex(theme.text),
        'tickColor': hex(theme.border),
      },
    };
  }

  /// `CodelesslyProgress` → Codelessly `progressBar`.
  static Map<String, Object?> progress({
    required String id,
    required double value,
    required double width,
    required GenUiTheme theme,
    String? color,
  }) => {
    'id': id,
    'name': 'Progress',
    'type': 'progressBar',
    'basicBoxLocal': _box(width, 8),
    'currentValue': (value.clamp(0, 1) * 100),
    'properties': {
      'maxValue': 100,
      'progressColor': color ?? hex(theme.primary),
      'backgroundColor': hex(theme.track),
      'animate': false,
    },
  };
}
