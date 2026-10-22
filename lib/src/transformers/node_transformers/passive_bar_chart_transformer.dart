import 'dart:convert';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';

class PassiveBarChartTransformer extends NodeWidgetTransformer<BarChartNode> {
  PassiveBarChartTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    BarChartNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) {
    return PassiveBarChartWidget(node: node, settings: settings);
  }
}

/// Renders a [BarChartNode], reading its bindable `values`, `labels`,
/// `highlight` and `color` from conditions and variables.
class PassiveBarChartWidget extends StatelessWidget {
  final BarChartNode node;
  final WidgetBuildSettings settings;
  final List<VariableData> variablesOverrides;

  /// Overrides [BarChartProperties.animate], e.g. to hold still in the editor.
  final bool? animate;

  const PassiveBarChartWidget({
    super.key,
    required this.node,
    required this.settings,
    this.variablesOverrides = const [],
    this.animate,
  });

  /// Reads a bound list: a list, or JSON text of one.
  static List? _list(Object? value) {
    if (value is List) return value;
    if (value is String && value.trim().startsWith('[')) {
      try {
        final Object? decoded = jsonDecode(value);
        if (decoded is List) return decoded;
      } catch (_) {}
    }
    return null;
  }

  static double? _number(Object? value) => switch (value) {
    num() => value.toDouble(),
    String() => double.tryParse(value.trim()),
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final ScopedValues scopedValues = ScopedValues.of(
      context,
      variablesOverrides: variablesOverrides,
    );
    final BarChartProperties props = node.properties;
    Object? bound(String property) =>
        PropertyValueDelegate.getPropertyValue<Object>(
          node,
          property,
          scopedValues: scopedValues,
        );

    final List<double?> values =
        _list(bound('values'))?.map(_number).toList() ?? node.values;
    final List<String> labels =
        _list(
          bound('labels'),
        )?.map((e) => e == null ? '' : '$e').toList() ??
        node.labels;
    final Object? boundHighlight = bound('highlight');
    final int? highlight = boundHighlight != null
        ? _number(boundHighlight)?.toInt()
        : (node.variables['highlight'] == null ? node.highlight : null);
    final Color color =
        PropertyValueDelegate.getPropertyValue<ColorRGBA>(
          node,
          'color',
          scopedValues: scopedValues,
        )?.toFlutterColor() ??
        props.color.toFlutterColor();

    double max = props.max;
    if (max <= 0) {
      max = values.whereType<double>().fold(0, (a, b) => b > a ? b : a);
    }
    final bool animated = animate ?? props.animate;
    final bool hasLabels = labels.any((l) => l.isNotEmpty);
    final bool gutter = props.gridLabels.isNotEmpty;
    final double right = gutter ? props.gridLabelWidth : 0;
    final TextStyle styled = TextUtils.retrieveTextStyle(
      fontName: FontName(
        family: props.labelFontFamily,
        weight: FontWeightNumeric.w400,
      ),
      fontSize: props.labelFontSize,
      color: props.labelColor.toFlutterColor(),
    ).copyWith(height: 1.2);

    return AdaptiveNodeBox(
      node: node,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double labelHeight = hasLabels
              ? props.labelFontSize * 1.2 + props.labelGap
              : 0;
          final double height = (constraints.maxHeight - labelHeight - 1)
              .clamp(0, double.infinity);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: height,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (int g = 1; g <= props.gridLines; g++) ...[
                      Positioned(
                        left: 0,
                        right: right,
                        bottom: height * g / props.gridLines - 0.5,
                        height: 1,
                        child: ColoredBox(
                          color: props.gridColor.toFlutterColor(),
                        ),
                      ),
                      if (gutter && g - 1 < props.gridLabels.length)
                        Positioned(
                          right: 0,
                          width: props.gridLabelWidth - 6,
                          bottom: height * g / props.gridLines -
                              props.labelFontSize / 2,
                          child: Text(
                            props.gridLabels[g - 1],
                            style: styled.copyWith(height: 1),
                            maxLines: 1,
                            softWrap: false,
                          ),
                        ),
                    ],
                    Positioned.fill(
                      right: right,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (int i = 0; i < values.length; i++) ...[
                            if (i > 0) SizedBox(width: props.barGap),
                            Expanded(
                              child: _bar(
                                values[i],
                                i,
                                max,
                                height,
                                highlight,
                                color,
                                animated,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 1,
                margin: EdgeInsets.only(right: right),
                color: props.baselineColor.toFlutterColor(),
              ),
              if (hasLabels) ...[
                SizedBox(height: props.labelGap),
                Padding(
                  padding: EdgeInsets.only(right: right),
                  child: Row(
                    children: [
                      for (int i = 0; i < values.length; i++) ...[
                        if (i > 0) SizedBox(width: props.barGap),
                        Expanded(
                          child: Text(
                            i < labels.length ? labels[i] : '',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.visible,
                            style: i == highlight
                                ? styled.copyWith(
                                    color: props.highlightLabelColor
                                        .toFlutterColor(),
                                  )
                                : styled,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _bar(
    double? value,
    int index,
    double max,
    double height,
    int? highlight,
    Color color,
    bool animated,
  ) {
    final BarChartProperties props = node.properties;
    if (value == null) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: props.emptyHeight,
          color: props.emptyColor.toFlutterColor(),
        ),
      );
    }
    final double h = max <= 0
        ? 0
        : (height * (value / max).clamp(0.0, 1.0)).clamp(
            props.emptyHeight,
            height,
          );
    final Color barColor = highlight == null || highlight < 0 || index == highlight
        ? color
        : color.withValues(alpha: color.a * props.dimmedOpacity);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: h),
      duration: animated
          ? Duration(milliseconds: props.animationDurationInMillis)
          : Duration.zero,
      curve: Curves.easeOutCubic,
      builder: (context, hh, _) => Container(
        height: hh,
        decoration: BoxDecoration(
          color: barColor,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(props.barRadius),
          ),
        ),
      ),
    );
  }
}
