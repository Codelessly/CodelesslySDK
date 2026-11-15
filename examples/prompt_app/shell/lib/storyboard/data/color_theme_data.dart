import 'package:material_ui/material_ui.dart';
import 'package:soft_saas_ui/soft_saas/design_tokens.dart';
import 'package:skip_shell/storyboard/models/providers/color_theme_provider.dart';
import 'package:skip_shell/storyboard/models/color_entry.dart';

typedef ReboundColorProvider = SoftSaaSColorThemeProvider;

/// Color theme provider for Soft SaaS UI design system
class SoftSaaSColorThemeProvider extends ColorThemeProvider {
  @override
  List<ColorCategory> getCategories() {
    return [
      ColorCategory(
        name: 'Semantic Colors',
        key: 'Semantic',
        description: 'Colors with semantic meaning for states and actions',
        entries: [
          const ColorEntry(
            name: 'Primary',
            accessor: 'SoftSaaSTokens.primary',
            description: 'Primary brand color for CTAs and emphasis',
            color: SoftSaaSTokens.primary,
            semanticRole: 'primary',
          ),
          const ColorEntry(
            name: 'Primary Dark',
            accessor: 'SoftSaaSTokens.primaryDark',
            description: 'Primary color variant for dark mode',
            color: SoftSaaSTokens.primaryDark,
            semanticRole: 'primary',
          ),
          const ColorEntry(
            name: 'Success',
            accessor: 'SoftSaaSTokens.success',
            description: 'Positive actions and success states',
            color: SoftSaaSTokens.success,
            semanticRole: 'success',
          ),
          const ColorEntry(
            name: 'Success Dark',
            accessor: 'SoftSaaSTokens.successDark',
            description: 'Success color variant for dark mode',
            color: SoftSaaSTokens.successDark,
            semanticRole: 'success',
          ),
          const ColorEntry(
            name: 'Warning',
            accessor: 'SoftSaaSTokens.warning',
            description: 'Warning states and cautionary actions',
            color: SoftSaaSTokens.warning,
            semanticRole: 'warning',
          ),
          const ColorEntry(
            name: 'Warning Dark',
            accessor: 'SoftSaaSTokens.warningDark',
            description: 'Warning color variant for dark mode',
            color: SoftSaaSTokens.warningDark,
            semanticRole: 'warning',
          ),
          const ColorEntry(
            name: 'Error',
            accessor: 'SoftSaaSTokens.error',
            description: 'Error states and destructive actions',
            color: SoftSaaSTokens.error,
            semanticRole: 'error',
          ),
          const ColorEntry(
            name: 'Error Dark',
            accessor: 'SoftSaaSTokens.errorDark',
            description: 'Error color variant for dark mode',
            color: SoftSaaSTokens.errorDark,
            semanticRole: 'error',
          ),
          const ColorEntry(
            name: 'Info',
            accessor: 'SoftSaaSTokens.info',
            description: 'Informational messages and states',
            color: SoftSaaSTokens.info,
            semanticRole: 'info',
          ),
          const ColorEntry(
            name: 'Info Dark',
            accessor: 'SoftSaaSTokens.infoDark',
            description: 'Info color variant for dark mode',
            color: SoftSaaSTokens.infoDark,
            semanticRole: 'info',
          ),
          const ColorEntry(
            name: 'Purple',
            accessor: 'SoftSaaSTokens.purple',
            description: 'Purple accent for special features',
            color: SoftSaaSTokens.purple,
            semanticRole: 'accent',
          ),
          const ColorEntry(
            name: 'Purple Dark',
            accessor: 'SoftSaaSTokens.purpleDark',
            description: 'Purple color variant for dark mode',
            color: SoftSaaSTokens.purpleDark,
            semanticRole: 'accent',
          ),
        ],
      ),
      ColorCategory(
        name: 'Gray Scale',
        key: 'GrayScale',
        description: 'Neutral gray colors from lightest to darkest',
        entries: [
          const ColorEntry(
            name: 'Gray 50',
            accessor: 'SoftSaaSTokens.gray50',
            description: 'Lightest gray - secondary backgrounds',
            color: SoftSaaSTokens.gray50,
            semanticRole: 'neutral',
          ),
          const ColorEntry(
            name: 'Gray 100',
            accessor: 'SoftSaaSTokens.gray100',
            description: 'Very light gray - tertiary backgrounds',
            color: SoftSaaSTokens.gray100,
            semanticRole: 'neutral',
          ),
          const ColorEntry(
            name: 'Gray 200',
            accessor: 'SoftSaaSTokens.gray200',
            description: 'Light gray - primary borders',
            color: SoftSaaSTokens.gray200,
            semanticRole: 'neutral',
          ),
          const ColorEntry(
            name: 'Gray 300',
            accessor: 'SoftSaaSTokens.gray300',
            description: 'Medium-light gray - secondary borders',
            color: SoftSaaSTokens.gray300,
            semanticRole: 'neutral',
          ),
          const ColorEntry(
            name: 'Gray 400',
            accessor: 'SoftSaaSTokens.gray400',
            description: 'Medium gray - tertiary text',
            color: SoftSaaSTokens.gray400,
            semanticRole: 'neutral',
          ),
          const ColorEntry(
            name: 'Gray 500',
            accessor: 'SoftSaaSTokens.gray500',
            description: 'Neutral gray - secondary elements',
            color: SoftSaaSTokens.gray500,
            semanticRole: 'neutral',
          ),
          const ColorEntry(
            name: 'Gray 600',
            accessor: 'SoftSaaSTokens.gray600',
            description: 'Dark gray - secondary text',
            color: SoftSaaSTokens.gray600,
            semanticRole: 'neutral',
          ),
          const ColorEntry(
            name: 'Gray 700',
            accessor: 'SoftSaaSTokens.gray700',
            description: 'Darker gray - tertiary backgrounds (dark mode)',
            color: SoftSaaSTokens.gray700,
            semanticRole: 'neutral',
          ),
          const ColorEntry(
            name: 'Gray 800',
            accessor: 'SoftSaaSTokens.gray800',
            description: 'Very dark gray - secondary backgrounds (dark mode)',
            color: SoftSaaSTokens.gray800,
            semanticRole: 'neutral',
          ),
          const ColorEntry(
            name: 'Gray 900',
            accessor: 'SoftSaaSTokens.gray900',
            description: 'Darkest gray - primary text and backgrounds (dark mode)',
            color: SoftSaaSTokens.gray900,
            semanticRole: 'neutral',
          ),
        ],
      ),
      ColorCategory(
        name: 'Light Mode',
        key: 'LightMode',
        description: 'Color tokens for light theme',
        entries: [
          const ColorEntry(
            name: 'Primary Background',
            accessor: 'SoftSaaSTokens.lightPrimaryBackground',
            description: 'Main background color for light mode',
            color: SoftSaaSTokens.lightPrimaryBackground,
            semanticRole: 'background',
          ),
          const ColorEntry(
            name: 'Secondary Background',
            accessor: 'SoftSaaSTokens.lightSecondaryBackground',
            description: 'Secondary background for cards and panels',
            color: SoftSaaSTokens.lightSecondaryBackground,
            semanticRole: 'background',
          ),
          const ColorEntry(
            name: 'Tertiary Background',
            accessor: 'SoftSaaSTokens.lightTertiaryBackground',
            description: 'Tertiary background for subtle areas',
            color: SoftSaaSTokens.lightTertiaryBackground,
            semanticRole: 'background',
          ),
          const ColorEntry(
            name: 'Primary Text',
            accessor: 'SoftSaaSTokens.lightPrimaryText',
            description: 'Main text color for light mode',
            color: SoftSaaSTokens.lightPrimaryText,
            semanticRole: 'text',
          ),
          const ColorEntry(
            name: 'Secondary Text',
            accessor: 'SoftSaaSTokens.lightSecondaryText',
            description: 'Secondary text for less emphasis',
            color: SoftSaaSTokens.lightSecondaryText,
            semanticRole: 'text',
          ),
          const ColorEntry(
            name: 'Tertiary Text',
            accessor: 'SoftSaaSTokens.lightTertiaryText',
            description: 'Tertiary text for subtle information',
            color: SoftSaaSTokens.lightTertiaryText,
            semanticRole: 'text',
          ),
          const ColorEntry(
            name: 'Primary Border',
            accessor: 'SoftSaaSTokens.lightPrimaryBorder',
            description: 'Main border color for light mode',
            color: SoftSaaSTokens.lightPrimaryBorder,
            semanticRole: 'border',
          ),
          const ColorEntry(
            name: 'Secondary Border',
            accessor: 'SoftSaaSTokens.lightSecondaryBorder',
            description: 'Secondary border for emphasis',
            color: SoftSaaSTokens.lightSecondaryBorder,
            semanticRole: 'border',
          ),
        ],
      ),
      ColorCategory(
        name: 'Dark Mode',
        key: 'DarkMode',
        description: 'Color tokens for dark theme',
        entries: [
          const ColorEntry(
            name: 'Primary Background',
            accessor: 'SoftSaaSTokens.darkPrimaryBackground',
            description: 'Main background color for dark mode',
            color: SoftSaaSTokens.darkPrimaryBackground,
            semanticRole: 'background',
          ),
          const ColorEntry(
            name: 'Secondary Background',
            accessor: 'SoftSaaSTokens.darkSecondaryBackground',
            description: 'Secondary background for cards and panels',
            color: SoftSaaSTokens.darkSecondaryBackground,
            semanticRole: 'background',
          ),
          const ColorEntry(
            name: 'Tertiary Background',
            accessor: 'SoftSaaSTokens.darkTertiaryBackground',
            description: 'Tertiary background for subtle areas',
            color: SoftSaaSTokens.darkTertiaryBackground,
            semanticRole: 'background',
          ),
          const ColorEntry(
            name: 'Primary Text',
            accessor: 'SoftSaaSTokens.darkPrimaryText',
            description: 'Main text color for dark mode',
            color: SoftSaaSTokens.darkPrimaryText,
            semanticRole: 'text',
          ),
          const ColorEntry(
            name: 'Secondary Text',
            accessor: 'SoftSaaSTokens.darkSecondaryText',
            description: 'Secondary text for less emphasis',
            color: SoftSaaSTokens.darkSecondaryText,
            semanticRole: 'text',
          ),
          const ColorEntry(
            name: 'Tertiary Text',
            accessor: 'SoftSaaSTokens.darkTertiaryText',
            description: 'Tertiary text for subtle information',
            color: SoftSaaSTokens.darkTertiaryText,
            semanticRole: 'text',
          ),
          const ColorEntry(
            name: 'Primary Border',
            accessor: 'SoftSaaSTokens.darkPrimaryBorder',
            description: 'Main border color for dark mode',
            color: SoftSaaSTokens.darkPrimaryBorder,
            semanticRole: 'border',
          ),
          const ColorEntry(
            name: 'Secondary Border',
            accessor: 'SoftSaaSTokens.darkSecondaryBorder',
            description: 'Secondary border for emphasis',
            color: SoftSaaSTokens.darkSecondaryBorder,
            semanticRole: 'border',
          ),
        ],
      ),
    ];
  }

  @override
  List<GradientEntry> getGradients() {
    return [
      GradientEntry(
        name: 'Primary Gradient',
        accessor: 'SoftSaaSTokens.primaryGradient',
        description: 'Primary brand gradient for hero sections',
        gradient: const LinearGradient(
          colors: [SoftSaaSTokens.primary, SoftSaaSTokens.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        colors: const [SoftSaaSTokens.primary, SoftSaaSTokens.primaryDark],
        direction: 'Top Left → Bottom Right',
      ),
      GradientEntry(
        name: 'Success Gradient',
        accessor: 'SoftSaaSTokens.successGradient',
        description: 'Success gradient for positive actions',
        gradient: const LinearGradient(
          colors: [SoftSaaSTokens.success, SoftSaaSTokens.successDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        colors: const [SoftSaaSTokens.success, SoftSaaSTokens.successDark],
        direction: 'Top Left → Bottom Right',
      ),
      GradientEntry(
        name: 'Error Gradient',
        accessor: 'SoftSaaSTokens.errorGradient',
        description: 'Error gradient for warning states',
        gradient: const LinearGradient(
          colors: [SoftSaaSTokens.error, SoftSaaSTokens.errorDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        colors: const [SoftSaaSTokens.error, SoftSaaSTokens.errorDark],
        direction: 'Top Left → Bottom Right',
      ),
      GradientEntry(
        name: 'Purple Gradient',
        accessor: 'SoftSaaSTokens.purpleGradient',
        description: 'Purple gradient for premium features',
        gradient: const LinearGradient(
          colors: [SoftSaaSTokens.purple, SoftSaaSTokens.purpleDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        colors: const [SoftSaaSTokens.purple, SoftSaaSTokens.purpleDark],
        direction: 'Top Left → Bottom Right',
      ),
    ];
  }
}
