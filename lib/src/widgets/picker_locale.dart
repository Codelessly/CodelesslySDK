// The date and time pickers' locale (render/controls/kit_pickers.dart's
// [PickerLocale]) from intl's data and the runtime's clock: the render layer
// imports neither. Month and day names and the first weekday are the
// platform locale's (no Material localizations); `now()` is the formulas'
// clock, which the render tool's `--now` pins; patterns are intl's
// `DateFormat`, as the pickers always read them.
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:intl/date_symbol_data_local.dart' show dateTimeSymbolMap;
import 'package:intl/date_symbols.dart' show DateSymbols;
import 'package:intl/intl.dart' show DateFormat;

import '../render/controls/kit_pickers.dart';
import '../runtime/expressions/formula_clock.dart';

final Map<String, DateSymbols> _symbols = dateTimeSymbolMap().cast<String, DateSymbols>();
final Map<String, PickerLocale> _made = {};

/// The pickers' locale for [locale] (the platform's when null): an unknown
/// one falls back to its language, then to US English.
PickerLocale pickerLocale([ui.Locale? locale]) {
  final l = locale ?? SchedulerBinding.instance.platformDispatcher.locale;
  final country = l.countryCode;
  final key = country == null || country.isEmpty ? l.languageCode : '${l.languageCode}_$country';
  return _made.putIfAbsent(key, () {
    final s = (country == null || country.isEmpty ? null : _symbols[key]) ?? _symbols[l.languageCode] ?? _symbols['en_US']!;
    return _IntlPickerLocale(s);
  });
}

class _IntlPickerLocale implements PickerLocale {
  _IntlPickerLocale(this.s);
  final DateSymbols s;

  @override
  List<String> get months => s.STANDALONEMONTHS;
  @override
  List<String> get shortMonths => s.SHORTMONTHS;
  @override
  List<String> get weekdays => s.WEEKDAYS;
  @override
  List<String> get shortWeekdays => s.SHORTWEEKDAYS;
  @override
  List<String> get narrowWeekdays => s.STANDALONENARROWWEEKDAYS;
  @override
  List<String> get ampm => s.AMPMS;

  /// intl counts from Monday = 0.
  @override
  int get firstWeekday => s.FIRSTDAYOFWEEK % 7 + 1;

  @override
  DateTime now() => FormulaClock.now();

  @override
  String? format(String pattern, DateTime at) {
    try {
      return DateFormat(pattern).format(at);
    } catch (_) {
      return null;
    }
  }
}
