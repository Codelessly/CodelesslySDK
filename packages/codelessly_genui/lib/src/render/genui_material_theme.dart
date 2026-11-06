import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'genui_theme.dart';

/// [style] in the GenUI font. A Google font (the default, Inter) is loaded
/// through google_fonts, as the Codelessly SDK loads it for its nodes; any
/// other family is used by name.
TextStyle genUiTextStyle(GenUiTheme theme, TextStyle style) =>
    GoogleFonts.asMap().containsKey(theme.fontFamily)
    ? GoogleFonts.getFont(theme.fontFamily, textStyle: style)
    : style.copyWith(fontFamily: theme.fontFamily);

/// The Material theme GenUI components draw under, made from the
/// [GenUiTheme], so that the few components drawn with Material widgets
/// (Tabs, Modal, DateTimeInput and its pickers, Icon, the filterable
/// ChoicePicker's search field) match the Codelessly-drawn ones instead of
/// showing Material defaults.
ThemeData genUiMaterialTheme(ThemeData base, GenUiTheme t) {
  final Color primary = Color(t.primary);
  final Color text = Color(t.text);
  final Color muted = Color(t.mutedText);
  final Color border = Color(t.border);
  final Color surface = Color(t.surface);
  final ColorScheme scheme =
      ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
      ).copyWith(
        primary: primary,
        onPrimary: Colors.white,
        primaryContainer: Color(t.primarySoft),
        onPrimaryContainer: primary,
        secondaryContainer: Color(t.primarySoft),
        onSecondaryContainer: primary,
        surface: surface,
        onSurface: text,
        onSurfaceVariant: muted,
        surfaceContainerLowest: surface,
        surfaceContainerLow: surface,
        surfaceContainer: surface,
        surfaceContainerHigh: surface,
        surfaceContainerHighest: Color(t.surfaceAlt),
        outline: border,
        outlineVariant: border,
        error: Color(t.negative),
      );
  TextStyle font(double size, FontWeight weight, Color color) => genUiTextStyle(
    t,
    TextStyle(fontSize: size, fontWeight: weight, color: color, height: 1.35),
  );
  final TextTheme textTheme = TextTheme(
    displaySmall: font(30, FontWeight.w700, text),
    headlineMedium: font(26, FontWeight.w700, text),
    headlineSmall: font(22, FontWeight.w700, text),
    titleLarge: font(18, FontWeight.w600, text),
    titleMedium: font(15, FontWeight.w600, text),
    titleSmall: font(13, FontWeight.w600, text),
    bodyLarge: font(14, FontWeight.w400, text),
    bodyMedium: font(14, FontWeight.w400, text),
    bodySmall: font(12, FontWeight.w400, muted),
    labelLarge: font(14, FontWeight.w600, text),
    labelMedium: font(12, FontWeight.w500, muted),
    labelSmall: font(11, FontWeight.w500, muted),
  );
  final BorderRadius radius = BorderRadius.circular(10);
  OutlineInputBorder outline(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: color, width: width),
      );
  final RoundedRectangleBorder card = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
  );
  return base.copyWith(
    colorScheme: scheme,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    iconTheme: IconThemeData(color: muted, size: 20),
    dividerTheme: DividerThemeData(color: border, thickness: 1, space: 17),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Color(t.inputFill),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      labelStyle: font(14, FontWeight.w400, muted),
      floatingLabelStyle: font(13, FontWeight.w500, primary),
      hintStyle: font(14, FontWeight.w400, muted),
      helperStyle: font(12, FontWeight.w400, muted),
      errorStyle: font(12, FontWeight.w400, Color(t.negative)),
      prefixIconColor: muted,
      suffixIconColor: muted,
      border: outline(border),
      enabledBorder: outline(border),
      focusedBorder: outline(primary, 1.5),
      errorBorder: outline(Color(t.negative)),
      focusedErrorBorder: outline(Color(t.negative), 1.5),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: primary,
      unselectedLabelColor: muted,
      labelStyle: font(14, FontWeight.w600, primary),
      unselectedLabelStyle: font(14, FontWeight.w500, muted),
      indicatorColor: primary,
      indicatorSize: TabBarIndicatorSize.label,
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(color: primary, width: 2.5),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
      ),
      dividerColor: border,
      dividerHeight: 1,
      overlayColor: WidgetStatePropertyAll(primary.withValues(alpha: 0.06)),
      labelPadding: const EdgeInsets.symmetric(horizontal: 12),
      tabAlignment: TabAlignment.start,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: Colors.black26,
      shape: card,
      titleTextStyle: font(18, FontWeight.w700, text),
      contentTextStyle: font(14, FontWeight.w400, text),
      barrierColor: Colors.black38,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: surface,
      modalBarrierColor: Colors.black38,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      showDragHandle: true,
      dragHandleColor: border,
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: card,
      headerBackgroundColor: surface,
      headerForegroundColor: text,
      headerHeadlineStyle: font(24, FontWeight.w700, text),
      headerHelpStyle: font(12, FontWeight.w600, muted),
      weekdayStyle: font(12, FontWeight.w600, muted),
      dayStyle: font(14, FontWeight.w500, text),
      yearStyle: font(14, FontWeight.w500, text),
      todayBorder: BorderSide(color: primary),
      todayForegroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.white : primary,
      ),
      dayBackgroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? primary : null,
      ),
      dividerColor: border,
      cancelButtonStyle: TextButton.styleFrom(foregroundColor: muted),
      confirmButtonStyle: TextButton.styleFrom(foregroundColor: primary),
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: surface,
      shape: card,
      hourMinuteColor: WidgetStateColor.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? Color(t.primarySoft)
            : Color(t.surfaceAlt),
      ),
      hourMinuteTextColor: WidgetStateColor.resolveWith(
        (s) => s.contains(WidgetState.selected) ? primary : text,
      ),
      dialHandColor: primary,
      dialBackgroundColor: Color(t.surfaceAlt),
      dayPeriodColor: Color(t.primarySoft),
      dayPeriodTextColor: text,
      dayPeriodBorderSide: BorderSide(color: border),
      helpTextStyle: font(12, FontWeight.w600, muted),
      cancelButtonStyle: TextButton.styleFrom(foregroundColor: muted),
      confirmButtonStyle: TextButton.styleFrom(foregroundColor: primary),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        textStyle: font(14, FontWeight.w600, primary),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        textStyle: font(14, FontWeight.w600, Colors.white),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        side: BorderSide(color: border),
        textStyle: font(14, FontWeight.w600, primary),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: muted),
    ),
    listTileTheme: ListTileThemeData(
      dense: true,
      contentPadding: EdgeInsets.zero,
      titleTextStyle: font(14, FontWeight.w400, text),
      iconColor: muted,
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? primary : muted,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? primary : null,
      ),
      side: BorderSide(color: muted, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surface,
      selectedColor: Color(t.primarySoft),
      side: BorderSide(color: border),
      shape: RoundedRectangleBorder(borderRadius: radius),
      labelStyle: font(13.5, FontWeight.w500, text),
      showCheckmark: false,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: primary,
      linearTrackColor: Color(t.track),
    ),
  );
}
