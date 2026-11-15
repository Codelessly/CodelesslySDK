/// Storyboard configuration for the generated Skip app.
library;

import 'package:material_ui/material_ui.dart';
import 'package:soft_saas_ui/soft_saas_ui.dart';

import '../models/storyboard_item.dart';

/// Configuration class for the storyboard app
class StoryboardConfig {
  /// App title displayed in the sidebar header
  static const String appTitle = 'Skip, generated';

  /// App subtitle displayed below the title
  static const String appSubtitle = 'Screens written per person';

  /// The storyboard's own frame is Soft SaaS UI, light and dark.
  static ThemeData get lightTheme => SoftSaaSTheme.light();
  static ThemeData get darkTheme => SoftSaaSTheme.dark();

  /// Optional: Custom font family for headers
  static const String? headerFontFamily = null;

  /// Every item here is a full screen or a flow: none is wrapped.
  static bool shouldWrapComponent(StoryboardItem item) => item.category == 'Components';

  /// Builds the wrapper for component views
  static Widget buildComponentWrapper(Widget child) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Container(constraints: const BoxConstraints(maxWidth: 600), child: child),
    );
  }
}
