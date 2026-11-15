import 'package:material_ui/material_ui.dart';
import 'package:soft_saas_ui/soft_saas/design_tokens.dart';
import 'package:soft_saas_ui/soft_saas/typography.dart';
import 'package:skip_shell/storyboard/models/text_style_entry.dart';
import 'package:skip_shell/storyboard/models/providers/text_theme_provider.dart';

typedef ReboundTextThemeProvider = SoftSaaSTextThemeProvider;

/// Soft SaaS UI text theme provider
///
/// Provides all Soft SaaS UI text styles organized by category for the
/// Text Themes Showcase in the storyboard.
class SoftSaaSTextThemeProvider extends TextThemeProvider {
  @override
  List<TextStyleCategory> getCategories() {
    const brightness = Brightness.light;

    return [
      // Heading Styles
      TextStyleCategory(
        name: 'Heading Styles',
        key: 'Page & Section Headers',
        description: 'Main titles, page headers, and section headers',
        entries: [
          TextStyleEntry(
            name: 'heading1',
            extension: '.heading1',
            size: '30px',
            sizeValue: SoftSaaSTokens.fontSize3XL,
            weight: 'Bold (700)',
            weightValue: 700,
            style: SoftSaaSTypography.heading1(brightness),
            usages: [],
          ),
          TextStyleEntry(
            name: 'heading2',
            extension: '.heading2',
            size: '24px',
            sizeValue: SoftSaaSTokens.fontSize2XL,
            weight: 'Bold (700)',
            weightValue: 700,
            style: SoftSaaSTypography.heading2(brightness),
            usages: [],
          ),
          TextStyleEntry(
            name: 'heading3',
            extension: '.heading3',
            size: '18px',
            sizeValue: SoftSaaSTokens.fontSizeLG,
            weight: 'Semibold (600)',
            weightValue: 600,
            style: SoftSaaSTypography.heading3(brightness),
            usages: [],
          ),
          TextStyleEntry(
            name: 'heading4',
            extension: '.heading4',
            size: '16px',
            sizeValue: SoftSaaSTokens.fontSizeMD,
            weight: 'Semibold (600)',
            weightValue: 600,
            style: SoftSaaSTypography.heading4(brightness),
            usages: [],
          ),
          TextStyleEntry(
            name: 'heading5',
            extension: '.heading5',
            size: '14px',
            sizeValue: SoftSaaSTokens.fontSizeSM,
            weight: 'Semibold (600)',
            weightValue: 600,
            style: SoftSaaSTypography.heading5(brightness),
            usages: [],
          ),
          TextStyleEntry(
            name: 'heading6',
            extension: '.heading6',
            size: '12px',
            sizeValue: SoftSaaSTokens.fontSizeXS,
            weight: 'Medium (500)',
            weightValue: 500,
            style: SoftSaaSTypography.heading6(brightness),
            usages: [],
          ),
        ],
      ),

      // Body Text Styles
      TextStyleCategory(
        name: 'Body Text Styles',
        key: 'Main Content',
        description: 'Primary body text and content',
        entries: [
          TextStyleEntry(
            name: 'bodyLarge',
            extension: '.bodyLarge',
            size: '16px',
            sizeValue: SoftSaaSTokens.fontSizeMD,
            weight: 'Normal (400)',
            weightValue: 400,
            style: SoftSaaSTypography.bodyLarge(brightness),
            usages: [],
          ),
          TextStyleEntry(
            name: 'bodyMedium',
            extension: '.bodyMedium',
            size: '14px',
            sizeValue: SoftSaaSTokens.fontSizeSM,
            weight: 'Normal (400)',
            weightValue: 400,
            style: SoftSaaSTypography.bodyMedium(brightness),
            usages: [],
          ),
          TextStyleEntry(
            name: 'bodySmall',
            extension: '.bodySmall',
            size: '12px',
            sizeValue: SoftSaaSTokens.fontSizeXS,
            weight: 'Normal (400)',
            weightValue: 400,
            style: SoftSaaSTypography.bodySmall(brightness),
            usages: [],
          ),
        ],
      ),

      // Secondary Text Styles
      TextStyleCategory(
        name: 'Secondary Text Styles',
        key: 'Supporting Content',
        description: 'Secondary text and supporting information',
        entries: [
          TextStyleEntry(
            name: 'bodyLargeSecondary',
            extension: '.bodyLargeSecondary',
            size: '16px',
            sizeValue: SoftSaaSTokens.fontSizeMD,
            weight: 'Normal (400)',
            weightValue: 400,
            style: SoftSaaSTypography.bodyLargeSecondary(brightness),
            usages: [],
          ),
          TextStyleEntry(
            name: 'bodyMediumSecondary',
            extension: '.bodyMediumSecondary',
            size: '14px',
            sizeValue: SoftSaaSTokens.fontSizeSM,
            weight: 'Normal (400)',
            weightValue: 400,
            style: SoftSaaSTypography.bodyMediumSecondary(brightness),
            usages: [],
          ),
          TextStyleEntry(
            name: 'bodySmallSecondary',
            extension: '.bodySmallSecondary',
            size: '12px',
            sizeValue: SoftSaaSTokens.fontSizeXS,
            weight: 'Normal (400)',
            weightValue: 400,
            style: SoftSaaSTypography.bodySmallSecondary(brightness),
            usages: [],
          ),
        ],
      ),

      // Tertiary Text Styles
      TextStyleCategory(
        name: 'Tertiary Text Styles',
        key: 'Placeholders & Disabled',
        description: 'Placeholder text and disabled states',
        entries: [
          TextStyleEntry(
            name: 'bodyMediumTertiary',
            extension: '.bodyMediumTertiary',
            size: '14px',
            sizeValue: SoftSaaSTokens.fontSizeSM,
            weight: 'Normal (400)',
            weightValue: 400,
            style: SoftSaaSTypography.bodyMediumTertiary(brightness),
            usages: [],
          ),
          TextStyleEntry(
            name: 'bodySmallTertiary',
            extension: '.bodySmallTertiary',
            size: '12px',
            sizeValue: SoftSaaSTokens.fontSizeXS,
            weight: 'Normal (400)',
            weightValue: 400,
            style: SoftSaaSTypography.bodySmallTertiary(brightness),
            usages: [],
          ),
        ],
      ),

      // Button Text Styles
      TextStyleCategory(
        name: 'Button Text Styles',
        key: 'Interactive Elements',
        description: 'Button and interactive element text',
        entries: [
          TextStyleEntry(
            name: 'buttonSmall',
            extension: '.buttonSmall',
            size: '12px',
            sizeValue: SoftSaaSTokens.fontSizeXS,
            weight: 'Medium (500)',
            weightValue: 500,
            style: SoftSaaSTypography.buttonSmall(Colors.black),
            usages: [],
          ),
          TextStyleEntry(
            name: 'buttonMedium',
            extension: '.buttonMedium',
            size: '12px',
            sizeValue: SoftSaaSTokens.fontSizeXS,
            weight: 'Medium (500)',
            weightValue: 500,
            style: SoftSaaSTypography.buttonMedium(Colors.black),
            usages: [],
          ),
          TextStyleEntry(
            name: 'buttonLarge',
            extension: '.buttonLarge',
            size: '14px',
            sizeValue: SoftSaaSTokens.fontSizeSM,
            weight: 'Medium (500)',
            weightValue: 500,
            style: SoftSaaSTypography.buttonLarge(Colors.black),
            usages: [],
          ),
        ],
      ),

      // Label Text Styles
      TextStyleCategory(
        name: 'Label Text Styles',
        key: 'Form Labels',
        description: 'Form labels and input field labels',
        entries: [
          TextStyleEntry(
            name: 'label',
            extension: '.label',
            size: '14px',
            sizeValue: SoftSaaSTokens.fontSizeSM,
            weight: 'Medium (500)',
            weightValue: 500,
            style: SoftSaaSTypography.label(brightness),
            usages: [],
          ),
          TextStyleEntry(
            name: 'labelSmall',
            extension: '.labelSmall',
            size: '12px',
            sizeValue: SoftSaaSTokens.fontSizeXS,
            weight: 'Medium (500)',
            weightValue: 500,
            style: SoftSaaSTypography.labelSmall(brightness),
            usages: [],
          ),
        ],
      ),

      // Badge Text Styles
      TextStyleCategory(
        name: 'Badge Text Styles',
        key: 'Badges & Tags',
        description: 'Badge, tag, and status text',
        entries: [
          TextStyleEntry(
            name: 'badgeSmall',
            extension: '.badgeSmall',
            size: '12px',
            sizeValue: SoftSaaSTokens.fontSizeXS,
            weight: 'Medium (500)',
            weightValue: 500,
            style: SoftSaaSTypography.badgeSmall(Colors.black),
            usages: [],
          ),
          TextStyleEntry(
            name: 'badgeMedium',
            extension: '.badgeMedium',
            size: '12px',
            sizeValue: SoftSaaSTokens.fontSizeXS,
            weight: 'Medium (500)',
            weightValue: 500,
            style: SoftSaaSTypography.badgeMedium(Colors.black),
            usages: [],
          ),
          TextStyleEntry(
            name: 'badgeLarge',
            extension: '.badgeLarge',
            size: '14px',
            sizeValue: SoftSaaSTokens.fontSizeSM,
            weight: 'Medium (500)',
            weightValue: 500,
            style: SoftSaaSTypography.badgeLarge(Colors.black),
            usages: [],
          ),
        ],
      ),
    ];
  }
}
