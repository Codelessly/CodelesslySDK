import 'package:a2ui_core/a2ui_core.dart';

import '../catalog/catalog_spec.dart';

/// What kind of interaction an action came from, by its source component.
enum GenUiInteraction {
  /// A Button whose action is named like a submit (`submit`, `send`, ...).
  formSubmit,

  /// Any other Button.
  buttonTap,

  /// A Slider released at a new value.
  sliderCommit,

  /// A CheckBox, CodelesslySwitch or a CodelesslyTable row toggled.
  toggle,

  /// A ChoicePicker option picked.
  selection,

  /// A TextField submitted.
  textSubmit,

  /// Another component.
  other,
}

/// An interaction or change on a GenUI surface, with the surface's data
/// model as it is at that moment.
sealed class GenUiEvent {
  const GenUiEvent({
    required this.surfaceId,
    required this.timestamp,
    required this.dataModel,
  });

  final String surfaceId;
  final DateTime timestamp;

  /// A copy of the surface's whole data model when the event happened.
  final Map<String, Object?> dataModel;
}

/// A user action (A2UI `action` event): a button tap, a form submit, or a
/// committed input value. This is what goes back to the agent.
final class GenUiActionEvent extends GenUiEvent {
  const GenUiActionEvent({
    required super.surfaceId,
    required super.timestamp,
    required super.dataModel,
    required this.name,
    required this.sourceComponentId,
    required this.sourceComponentType,
    required this.interaction,
    required this.context,
    required this.action,
  });

  /// The action name the agent gave the event.
  final String name;
  final String sourceComponentId;
  final String? sourceComponentType;
  final GenUiInteraction interaction;

  /// The action's context with every binding resolved.
  final Map<String, Object?> context;

  /// The A2UI action as the protocol sends it.
  final A2uiRendererAction action;

  /// The A2UI v0.9.1 client-to-server message, with the data model the
  /// surface sends (`sendDataModel`).
  Map<String, Object?> toA2uiMessage() => {
    'version': kGenUiProtocolVersion.jsonValue,
    'action': action.toJson(),
  };
}

/// A value the user changed in the data model (an input moved). It is
/// reported to the host for local display; it is not sent to the agent
/// unless the input has an action.
final class GenUiValueChanged extends GenUiEvent {
  const GenUiValueChanged({
    required super.surfaceId,
    required super.timestamp,
    required super.dataModel,
    required this.path,
    required this.value,
  });

  /// The JSON pointer that changed, e.g. `/weightKg`.
  final String path;
  final Object? value;
}

/// An error on a surface (invalid component, failed data write), as A2UI
/// reports it to the agent.
final class GenUiErrorEvent extends GenUiEvent {
  const GenUiErrorEvent({
    required super.surfaceId,
    required super.timestamp,
    required super.dataModel,
    required this.error,
  });

  final A2uiRendererError error;

  Map<String, Object?> toA2uiMessage() => {
    'version': kGenUiProtocolVersion.jsonValue,
    'error': error.toJson(),
  };
}

/// Classifies an action by the component that sent it.
GenUiInteraction classifyInteraction(String? componentType, String name) {
  final String n = name.toLowerCase();
  return switch (componentType) {
    'Button' =>
      RegExp(r'submit|send|save|confirm|done|apply|book|order|calculate')
              .hasMatch(n)
          ? GenUiInteraction.formSubmit
          : GenUiInteraction.buttonTap,
    'Slider' => GenUiInteraction.sliderCommit,
    'CheckBox' ||
    'CodelesslySwitch' ||
    'CodelesslyTable' => GenUiInteraction.toggle,
    'ChoicePicker' => GenUiInteraction.selection,
    'TextField' => GenUiInteraction.textSubmit,
    _ => GenUiInteraction.other,
  };
}
