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
