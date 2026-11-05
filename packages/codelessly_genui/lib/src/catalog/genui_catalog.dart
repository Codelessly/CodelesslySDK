import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_flutter/v0_9/basic_catalog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../functions/calc_function.dart';
import '../render/components.dart' as c;
import '../render/genui_theme.dart';
import '../render/visualization.dart';
import 'catalog_spec.dart';

/// The catalog document as a [CatalogApi] (schemas only), e.g. for an agent
/// or a validator.
CatalogApi genUiCatalogApi() => Catalog.fromJson(
  buildGenUiCatalogJson(),
  protocolVersion: A2uiProtocolVersion.v0_9,
);

/// The Codelessly GenUI catalog with its renderers: a2ui_flutter
/// [CatalogImplementation] whose components render with the Codelessly SDK.
///
/// Layout containers (Row, Column, List), media and dialogs (Image, Icon,
/// Tabs, Modal, DateTimeInput) and the many-option ChoicePicker reuse the
/// a2ui_flutter basic implementations; everything else draws Codelessly
/// nodes.
CatalogImplementation genUiCatalog({
  GenUiTheme theme = const GenUiTheme(),
  String locale = 'en-US',
  OpenUrlCallback? openUrl,
  @visibleForTesting void Function(String componentId)? debugOnBuild,
}) {
  final CatalogApi api = genUiCatalogApi();
  final Map<String, ComponentWidgetBuilder> builders = {
    'Text': c.buildText,
    'Button': c.buildButton,
    'Divider': c.buildDivider,
    'Slider': c.buildSlider,
    'CheckBox': c.buildCheckBox,
    'TextField': c.buildTextField,
    'Card': c.buildCard,
    'ChoicePicker': (context, node, props, buildChild) => c.buildChoicePicker(
      context,
      node,
      props,
      buildChild,
      fallback: BasicComponents.choicePicker.builder,
    ),
    'Row': BasicComponents.row.builder,
    'Column': BasicComponents.column.builder,
    'List': BasicComponents.list.builder,
    'Image': BasicComponents.image.builder,
    'Icon': BasicComponents.icon.builder,
    'Tabs': BasicComponents.tabs.builder,
    'Modal': BasicComponents.modal.builder,
    'DateTimeInput': BasicComponents.dateTimeInput.builder,
    'CodelesslyChart': c.buildChart,
    'CodelesslyGauge': c.buildGauge,
    'CodelesslyProgress': c.buildProgress,
    'CodelesslyMetric': c.buildMetric,
    'CodelesslySwitch': c.buildSwitch,
    'CodelesslyTable': c.buildTable,
    'CodelesslyVisualization': buildVisualization,
  };
  final missing = api.components.keys.toSet().difference(builders.keys.toSet());
  assert(missing.isEmpty, 'No renderer for $missing');

  Widget themed(BuildContext context, Widget Function(BuildContext) build) {
    final SurfaceModel<ComponentImplementation>? surface = A2uiSurface.maybeOf(
      context,
    );
    final Object? primary = surface?.theme['primaryColor'];
    final GenUiTheme resolved = primary is String
        ? theme.withPrimaryHex(primary)
        : theme;
    return GenUiThemeScope(
      theme: resolved,
      child: Builder(builder: build),
    );
  }

  return CatalogImplementation(
    id: kGenUiCatalogId,
    components: [
      for (final MapEntry<String, ComponentApi> entry in api.components.entries)
        ComponentImplementation(
          name: entry.key,
          schema: entry.value.schema,
          allowedParents: entry.value.allowedParents,
          allowedChildren: entry.value.allowedChildren,
          builder: (context, node, props, buildChild) {
            debugOnBuild?.call(node.componentId);
            return themed(
              context,
              (context) =>
                  builders[entry.key]!(context, node, props, buildChild),
            );
          },
        ),
    ],
    functions: [
      ...BasicCatalog.v0_9(locale: locale, openUrl: openUrl).functions.values,
      CalcFunction(),
    ],
    themeSchema: api.themeSchema,
    schemaId: api.schemaId,
    title: api.title,
    description: api.description,
    protocolVersion: A2uiProtocolVersion.v0_9,
    instructions: kGenUiCatalogInstructions,
    definitions: api.definitions,
  );
}
