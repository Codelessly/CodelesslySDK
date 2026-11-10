import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Gives [child] Flutter's default Material and Cupertino localizations when
/// the host app has none.
///
/// The SDK builds layouts with `package:flutter/material.dart` widgets, and a
/// text field, a date picker or a dialog's barrier label read
/// `MaterialLocalizations.of(context)`. A host built on `WidgetsApp`, or on
/// the decoupled `package:material_ui` (whose `MaterialApp` registers
/// `material_ui`'s localizations, a different type), has none: in a release
/// build the null check throws and every text field renders as Flutter's
/// grey error box. Localizations the host does give are kept.
class MaterialLocalizationsScope extends StatelessWidget {
  /// Creates a [MaterialLocalizationsScope].
  const MaterialLocalizationsScope({super.key, required this.child});

  /// The widget below this widget in the tree.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool hasMaterial =
        Localizations.of<MaterialLocalizations>(
          context,
          MaterialLocalizations,
        ) !=
        null;
    final bool hasCupertino =
        Localizations.of<CupertinoLocalizations>(
          context,
          CupertinoLocalizations,
        ) !=
        null;
    if (hasMaterial && hasCupertino) return child;
    final List<LocalizationsDelegate<dynamic>> delegates = [
      if (!hasMaterial) DefaultMaterialLocalizations.delegate,
      if (!hasCupertino) DefaultCupertinoLocalizations.delegate,
    ];
    if (Localizations.maybeLocaleOf(context) == null) {
      return Localizations(
        locale: const Locale('en', 'US'),
        delegates: [DefaultWidgetsLocalizations.delegate, ...delegates],
        child: child,
      );
    }
    return Localizations.override(
      context: context,
      delegates: delegates,
      child: child,
    );
  }
}
