// Inline month and range selection, using the same RenderCalendar as the
// date picker's popup. The node carries start/end values and per-day data.
import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_api/core.dart'
    show CalendarProps, Node, PickerFieldProps;
import 'package:flutter/rendering.dart';

import '../node_tree.dart' show fireTrigger;
import '../recipe.dart';
import 'calendar.dart';
import 'kit_pickers.dart';
import 'tokens.dart';

Map<String, String> _dayMap(Object? raw) => switch (raw) {
  final Map m => {for (final e in m.entries) '${e.key}': '${e.value}'},
  // Marks worked out from a list: days (a dot under each), or records with
  // a day (`date`, `day`) and a text (`label`, `title`, `text`, `mark`).
  final List l => {
    for (final e in l)
      if (e is Map && (e['date'] ?? e['day']) != null)
        '${e['date'] ?? e['day']}': '${e['label'] ?? e['title'] ?? e['text'] ?? e['mark'] ?? '•'}'
      else if (e is String && e.isNotEmpty)
        e: '•',
  },
  _ => const {},
};

void inlineCalendarRecipe(NodeBuilder b, Node n, List<RenderBox> chain, {PickerLocale locale = PickerLocale.english}) {
  final l = n.layout;
  chain.add(
    b.fitBox(
      'fit',
      l.width.fit,
      l.height.fit,
      Size(l.width.value, l.height.value),
    ),
  );
  final box = b.obtain<RenderCalendar>(
    'calendar',
    () => RenderCalendar(
      colors: PickerColors.of(
        ControlTokens.of(b),
        n.prop(PickerFieldProps.pickerTheme),
      ),
      symbols: locale,
      today: locale.now(),
      value: parseDay(n.prop(CalendarProps.start)),
      rangeEnd: parseDay(n.prop(CalendarProps.end)),
      inline: true,
    ),
  );
  box
    ..colors = PickerColors.of(
      ControlTokens.of(b),
      n.prop(PickerFieldProps.pickerTheme),
    )
    ..symbols = locale
    ..label = n.prop(CalendarProps.label)
    ..range = n.prop(CalendarProps.range)
    ..direction = n.behaviors.textDirection == api.TextDirection.rtl
        ? TextDirection.rtl
        : TextDirection.ltr
    ..updateRange(
      start: parseDay(n.prop(CalendarProps.start)),
      end: n.prop(CalendarProps.range) ? parseDay(n.prop(CalendarProps.end)) : null,
      first: parseDay(n.prop(CalendarProps.firstDate)),
      last: parseDay(n.prop(CalendarProps.lastDate)),
      disabledDates: n.prop(CalendarProps.disabledDates).toSet(),
      dayPrices: _dayMap(n.prop(CalendarProps.dayPrices)),
      marks: _dayMap(n.prop(CalendarProps.marks)),
    )
    // A range gives {start, end}; one day gives the day (yyyy-MM-dd).
    ..onRangeChanged = b.tree.animates
        ? (start, end) => fireTrigger(
            b,
            'changed',
            event: {
              'value': n.prop(CalendarProps.range)
                  ? {
                      'start': start == null ? '' : isoDay(start),
                      'end': end == null ? '' : isoDay(end),
                    }
                  : start == null
                  ? ''
                  : isoDay(start),
            },
          )
        : null;
  chain.add(box);
}
