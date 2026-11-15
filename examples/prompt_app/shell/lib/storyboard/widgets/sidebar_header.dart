import 'package:material_ui/material_ui.dart';
import 'package:skip_shell/storyboard/data/storyboard_config.dart';
import 'package:skip_shell/storyboard/models/item_status.dart';

/// Header section of the storyboard sidebar
class SidebarHeader extends StatelessWidget {
  final bool isDarkMode;
  final bool showStatusIndicators;
  final ValueChanged<bool> onStatusToggle;
  final VoidCallback onThemeToggle;
  final VoidCallback? onSettingsPressed;

  const SidebarHeader({
    super.key,
    required this.isDarkMode,
    required this.showStatusIndicators,
    required this.onStatusToggle,
    required this.onThemeToggle,
    this.onSettingsPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  StoryboardConfig.appTitle,
                  style: TextStyle(
                    fontFamily: StoryboardConfig.headerFontFamily,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  StoryboardConfig.appSubtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.6)
                        : Colors.black.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          StatusLegend(
            isDarkMode: isDarkMode,
            showStatusIndicators: showStatusIndicators,
            onToggle: onStatusToggle,
          ),
          const SizedBox(width: 4),
          if (onSettingsPressed != null)
            IconButton(
              icon: Icon(
                Icons.settings,
                color: isDarkMode ? Colors.white : Colors.black,
                size: 20,
              ),
              onPressed: onSettingsPressed,
              tooltip: 'Settings',
            ),
          IconButton(
            icon: Icon(
              isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
            onPressed: onThemeToggle,
            tooltip: 'Toggle theme',
          ),
        ],
      ),
    );
  }
}
