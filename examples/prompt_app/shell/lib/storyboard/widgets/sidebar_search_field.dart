import 'package:material_ui/material_ui.dart';

/// Search text field for the storyboard sidebar
class SidebarSearchField extends StatelessWidget {
  final String searchQuery;
  final bool isSearchFocused;
  final bool isDarkMode;
  final ValueChanged<String> onChanged;
  final VoidCallback onTap;
  final VoidCallback onTapOutside;
  final VoidCallback onClear;

  const SidebarSearchField({
    super.key,
    required this.searchQuery,
    required this.isSearchFocused,
    required this.isDarkMode,
    required this.onChanged,
    required this.onTap,
    required this.onTapOutside,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: TextField(
        onChanged: onChanged,
        onTap: onTap,
        onTapOutside: (_) => onTapOutside(),
        decoration: InputDecoration(
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          hintText: 'Search components...',
          hintStyle: TextStyle(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.4),
            fontSize: 13,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.4),
            size: 18,
          ),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.6)
                        : Colors.black.withValues(alpha: 0.6),
                    size: 16,
                  ),
                  onPressed: onClear,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                )
              : null,
          filled: true,
          fillColor: isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: isDarkMode ? Colors.white12 : Colors.black12,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: isDarkMode ? Colors.white12 : Colors.black12,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: isDarkMode ? Colors.white12 : Colors.black12,
              width: 1,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          isDense: true,
        ),
        style: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black,
          fontSize: 13,
        ),
      ),
    );
  }
}
