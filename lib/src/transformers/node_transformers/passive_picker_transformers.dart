import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../codelessly_sdk.dart';
import '../utils/node_state_provider.dart';

DateTime _date(String value) =>
    DateTime.parse('${validateIsoDate(value)}T00:00:00');

String _isoDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String _clock(TimeOfDay value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

class PassiveDateTimeInputTransformer
    extends NodeWidgetTransformer<DateTimeInputNode> {
  PassiveDateTimeInputTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    DateTimeInputNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) => PassiveDateTimeInputWidget(node: node, isPreview: settings.isPreview);
}

class PassiveDateTimeInputWidget extends StatefulWidget {
  const PassiveDateTimeInputWidget({
    super.key,
    required this.node,
    this.isPreview = false,
  });
  final DateTimeInputNode node;
  final bool isPreview;

  @override
  State<PassiveDateTimeInputWidget> createState() =>
      _PassiveDateTimeInputWidgetState();
}

class _PassiveDateTimeInputWidgetState
    extends State<PassiveDateTimeInputWidget> {
  String? selected;
  String? error;

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final scoped = ScopedValues.of(context);
    final bound = PropertyValueDelegate.getPropertyValue<String>(
      node,
      'value',
      scopedValues: scoped,
    );
    final raw = bound ?? selected ?? node.value;
    String? value;
    try {
      if (raw.isNotEmpty) value = validateDateTimeInputValue(node.mode, raw);
    } on FormatException {
      value = null;
    }
    final min =
        PropertyValueDelegate.getPropertyValue<String>(
          node,
          'min',
          scopedValues: scoped,
        ) ??
        node.properties.min;
    final max =
        PropertyValueDelegate.getPropertyValue<String>(
          node,
          'max',
          scopedValues: scoped,
        ) ??
        node.properties.max;
    DateTime first = _date(node.properties.firstDate ?? '0001-01-01');
    DateTime last = _date(node.properties.lastDate ?? '9999-12-31');
    if (node.mode != 'time') {
      if (min != null && min.isNotEmpty) {
        final lower = _date(min.substring(0, 10));
        if (lower.isAfter(first)) first = lower;
      }
      if (max != null && max.isNotEmpty) {
        final upper = _date(max.substring(0, 10));
        if (upper.isBefore(last)) last = upper;
      }
    }
    final date = value == null || node.mode == 'time'
        ? DateTime.now()
        : _date(value.substring(0, 10));
    final initial = date.isBefore(first)
        ? first
        : date.isAfter(last)
        ? last
        : date;
    final localizations = MaterialLocalizations.of(context);
    final display = value == null
        ? ''
        : node.mode == 'date'
        ? localizations.formatMediumDate(date)
        : node.mode == 'time'
        ? TimeOfDay(
            hour: int.parse(value.substring(0, 2)),
            minute: int.parse(value.substring(3, 5)),
          ).format(context)
        : '${localizations.formatMediumDate(date)} · '
              '${TimeOfDay.fromDateTime(DateTime.parse(value)).format(context)}';
    final enabled = node.enabled && !widget.isPreview;
    return InkWell(
      onTap: !enabled || first.isAfter(last)
          ? null
          : () async {
              DateTime chosen = initial;
              if (node.mode != 'time') {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: initial,
                  firstDate: first,
                  lastDate: last,
                );
                if (picked == null || !context.mounted) return;
                chosen = picked;
              }
              TimeOfDay? time;
              if (node.mode != 'date') {
                time = await showTimePicker(
                  context: context,
                  initialTime: value == null
                      ? TimeOfDay.now()
                      : node.mode == 'time'
                      ? TimeOfDay(
                          hour: int.parse(value.substring(0, 2)),
                          minute: int.parse(value.substring(3, 5)),
                        )
                      : TimeOfDay.fromDateTime(DateTime.parse(value)),
                );
                if (time == null || !context.mounted) return;
              }
              final result = node.mode == 'date'
                  ? _isoDate(chosen)
                  : node.mode == 'time'
                  ? _clock(time!)
                  : DateTime.utc(
                      chosen.year,
                      chosen.month,
                      chosen.day,
                      time!.hour,
                      time.minute,
                    ).toIso8601String();
              final tooEarly =
                  min != null &&
                  min.isNotEmpty &&
                  compareDateTimeBounds(node.mode, result, min) < 0;
              final tooLate =
                  max != null &&
                  max.isNotEmpty &&
                  compareDateTimeBounds(node.mode, result, max) > 0;
              if (tooEarly || tooLate) {
                setState(
                  () => error =
                      'Choose a time between ${min ?? "—"} and ${max ?? "—"}',
                );
                return;
              }
              setState(() {
                selected = result;
                error = null;
              });
              if (context.read<CodelesslyContext?>() == null) return;
              NodeStateProvider.setState(context, result);
              FunctionsRepository.setPropertyValue(
                context,
                node: node,
                property: 'value',
                value: result,
              );
              FunctionsRepository.triggerAction(
                context,
                TriggerType.changed,
                node: node,
                value: result,
              );
            },
      child: InputDecorator(
        isEmpty: display.isEmpty,
        decoration: InputDecoration(
          labelText: node.properties.label,
          hintText:
              node.properties.label == null || node.properties.label!.isEmpty
              ? 'Select ${node.mode == 'dateTime' ? 'date and time' : node.mode}'
              : null,
          suffixIcon: Icon(
            node.mode == 'time' ? Icons.access_time : Icons.calendar_today,
          ),
          enabled: node.enabled,
          errorText: error,
          border: const OutlineInputBorder(),
        ),
        child: Text(display.isEmpty ? ' ' : display),
      ),
    );
  }
}

class PassiveDatePickerTransformer
    extends NodeWidgetTransformer<DatePickerNode> {
  PassiveDatePickerTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    DatePickerNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) => PassiveDatePickerWidget(node: node, isPreview: settings.isPreview);
}

class PassiveTimePickerTransformer
    extends NodeWidgetTransformer<TimePickerNode> {
  PassiveTimePickerTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    TimePickerNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) => PassiveTimePickerWidget(node: node, isPreview: settings.isPreview);
}

class PassiveDatePickerWidget extends StatefulWidget {
  const PassiveDatePickerWidget({
    super.key,
    required this.node,
    this.isPreview = false,
  });
  final DatePickerNode node;
  final bool isPreview;

  @override
  State<PassiveDatePickerWidget> createState() =>
      _PassiveDatePickerWidgetState();
}

class _PassiveDatePickerWidgetState extends State<PassiveDatePickerWidget> {
  String? selected;

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final scoped = ScopedValues.of(context);
    final bound = PropertyValueDelegate.getPropertyValue<String>(
      node,
      'value',
      scopedValues: scoped,
    );
    final first = _date(node.properties.firstDate ?? '0001-01-01');
    final last = _date(node.properties.lastDate ?? '9999-12-31');
    final raw = bound ?? selected ?? node.value;
    DateTime initial;
    try {
      initial = _date(raw);
    } on FormatException {
      initial = _date(node.value);
    }
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    final label = _isoDate(initial);
    return OutlinedButton(
      onPressed: !node.enabled || widget.isPreview
          ? null
          : () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: initial,
                firstDate: first,
                lastDate: last,
              );
              if (picked == null || !context.mounted) return;
              final value = _isoDate(picked);
              setState(() => selected = value);
              if (context.read<CodelesslyContext?>() == null) return;
              NodeStateProvider.setState(context, value);
              FunctionsRepository.setPropertyValue(
                context,
                node: node,
                property: 'value',
                value: value,
              );
              FunctionsRepository.triggerAction(
                context,
                TriggerType.changed,
                node: node,
                value: value,
              );
            },
      child: Text(label),
    );
  }
}

class PassiveTimePickerWidget extends StatefulWidget {
  const PassiveTimePickerWidget({
    super.key,
    required this.node,
    this.isPreview = false,
  });
  final TimePickerNode node;
  final bool isPreview;

  @override
  State<PassiveTimePickerWidget> createState() =>
      _PassiveTimePickerWidgetState();
}

class _PassiveTimePickerWidgetState extends State<PassiveTimePickerWidget> {
  String? selected;

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final scoped = ScopedValues.of(context);
    final bound = PropertyValueDelegate.getPropertyValue<String>(
      node,
      'value',
      scopedValues: scoped,
    );
    final raw = bound ?? selected ?? node.value;
    String value;
    try {
      value = validateClockTime(raw);
    } on FormatException {
      value = node.value;
    }
    return OutlinedButton(
      onPressed: !node.enabled || widget.isPreview
          ? null
          : () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(
                  hour: int.parse(value.substring(0, 2)),
                  minute: int.parse(value.substring(3, 5)),
                ),
              );
              if (picked == null || !context.mounted) return;
              final time = _clock(picked);
              setState(() => selected = time);
              if (context.read<CodelesslyContext?>() == null) return;
              NodeStateProvider.setState(context, time);
              FunctionsRepository.setPropertyValue(
                context,
                node: node,
                property: 'value',
                value: time,
              );
              FunctionsRepository.triggerAction(
                context,
                TriggerType.changed,
                node: node,
                value: time,
              );
            },
      child: Text(value),
    );
  }
}
