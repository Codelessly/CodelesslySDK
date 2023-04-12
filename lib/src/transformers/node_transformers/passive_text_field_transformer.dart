import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../codelessly_sdk.dart';
import '../../functions/functions_repository.dart';

class PassiveTextFieldTransformer extends NodeWidgetTransformer<TextFieldNode> {
  PassiveTextFieldTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    TextFieldNode node,
    BuildContext context, [
    WidgetBuildSettings settings = const WidgetBuildSettings(),
  ]) {
    return PassiveTextFieldWidget(
      node: node,
      settings: settings,
      onTap: () => onTap(context, node.reactions),
      onChanged: (value) => onChanged(context, node, value),
      onSubmitted: () => onSubmitted(context, node.reactions),
    );
  }

  Widget buildTextFieldWidgetFromProps({
    required TextFieldProperties props,
    required double height,
    required double width,
  }) {
    final node = TextFieldNode(
      id: '',
      name: 'TextField',
      basicBoxLocal: NodeBox(0, 0, width, height),
      properties: props,
      edgePins: EdgePinsModel.standard,
    );
    return PassiveTextFieldWidget(node: node);
  }

  static TextStyle getTextStyle(TextProp? style) {
    return PassiveTextTransformer.retrieveTextStyleData(
      fontSize: style?.fontSize ?? 18,
      lineHeight: style?.lineHeight ?? LineHeight.auto,
      letterSpacing: style?.letterSpacing ?? LetterSpacing.zero,
      color: style?.fills[0].toFlutterColor() ?? Colors.black,
      fontName: style?.fontName ?? FontName.robotoRegular,
      textDecoration: style?.textDecoration ?? TextDecorationEnum.none,
      effects: [],
    );
  }

  static InputBorder? getInputBorder(InputBorderModel? inputBorder) {
    if (inputBorder == null) return null;
    switch (inputBorder.borderType) {
      case BorderTypeEnum.none:
        return InputBorder.none;
      case BorderTypeEnum.outline:
        return OutlineInputBorder(
          borderRadius: inputBorder.cornerRadius.borderRadius,
          borderSide: inputBorder.borderSide.toFlutter(),
          gapPadding: inputBorder.gapPadding,
        );
      case BorderTypeEnum.underline:
        return UnderlineInputBorder(
          borderRadius: inputBorder.cornerRadius.borderRadius,
          borderSide: inputBorder.borderSide.toFlutter(),
        );
      default:
        return null;
    }
  }

  static InputDecoration getDecoration(
    BuildContext context,
    BaseNode node,
    InputDecorationModel decoration,
    bool useIconFonts, [
    WidgetBuildSettings settings = const WidgetBuildSettings(),
  ]) {
    final bool isCollapsed =
        context.getNodeValue(node.id, 'isCollapsed') ?? decoration.isCollapsed;
    final bool isDense =
        context.getNodeValue(node.id, 'isDense') ?? decoration.isDense;
    final String? labelText =
        context.getNodeValue(node.id, 'labelText') ?? decoration.labelText;
    final String? hintText =
        context.getNodeValue(node.id, 'hintText') ?? decoration.hintText;

    return InputDecoration(
      icon: !decoration.icon.show || decoration.icon.isEmpty
          ? null
          : retrieveIconWidget(decoration.icon, null, useIconFonts),
      labelText: labelText?.isNotEmpty == true ? labelText : null,
      labelStyle: getTextStyle(decoration.labelStyle),
      floatingLabelStyle: getTextStyle(decoration.floatingLabelStyle),
      helperText: decoration.helperText,
      helperStyle: getTextStyle(decoration.helperStyle),
      helperMaxLines: decoration.helperMaxLines,
      hintText: hintText,
      hintStyle: getTextStyle(decoration.hintStyle),
      hintMaxLines: decoration.hintMaxLines,
      errorText: decoration.errorText,
      errorStyle: getTextStyle(decoration.errorStyle),
      errorMaxLines: decoration.errorMaxLines,
      floatingLabelBehavior: decoration.floatingLabelBehavior.toFlutter(),
      isCollapsed: isCollapsed,
      isDense: isDense,
      contentPadding: node.padding.edgeInsets,
      prefixIcon: !decoration.prefixIcon.show || decoration.prefixIcon.isEmpty
          ? null
          : retrieveIconWidget(decoration.prefixIcon, null, useIconFonts),
      // prefixIconConstraints:
      //     decoration.prefixIconConstraints.flutterConstraints,
      prefixText: decoration.prefixText,
      prefixStyle: getTextStyle(decoration.prefixStyle),
      suffixIcon: !decoration.suffixIcon.show || decoration.suffixIcon.isEmpty
          ? null
          : retrieveIconWidget(decoration.suffixIcon, null, useIconFonts),
      suffixText: decoration.suffixText,
      suffixStyle: getTextStyle(decoration.suffixStyle),
      // suffixIconConstraints:
      //     decoration.suffixIconConstraints.flutterConstraints,
      counterText: decoration.counterText,
      counterStyle: getTextStyle(decoration.counterStyle),
      filled: decoration.filled,
      fillColor: decoration.fillColor.toFlutterColor(),
      focusColor: decoration.focusColor.toFlutterColor(),
      hoverColor: decoration.hoverColor.toFlutterColor(),
      errorBorder: getInputBorder(decoration.errorBorder),
      focusedBorder: getInputBorder(decoration.focusedBorder),
      focusedErrorBorder: getInputBorder(decoration.focusedErrorBorder),
      disabledBorder: getInputBorder(decoration.disabledBorder),
      enabledBorder: getInputBorder(decoration.enabledBorder),
      border: getInputBorder(decoration.border),
      enabled: decoration.enabled,
      semanticCounterText: decoration.semanticCounterText,
      alignLabelWithHint: decoration.alignLabelWithHint,
      constraints: decoration.constraints.flutterConstraints,
    );
  }

  void onTap(BuildContext context, List<Reaction> reactions) => reactions
      .where((reaction) => reaction.trigger.type == TriggerType.click)
      .forEach((reaction) =>
          FunctionsRepository.performAction(context, reaction.action));

  void onChanged(BuildContext context, TextFieldNode node, String inputValue) {
    final CodelesslyContext payload = context.read<CodelesslyContext>();
    // Change local state of text field.
    if (payload.nodeValues.containsKey(node.id)) {
      final List<ValueModel> values = payload.nodeValues[node.id]!.value;
      final ValueModel? value =
          values.firstWhereOrNull((val) => val.name == 'inputValue');
      final List<ValueModel> updatedValues = [...values]
        ..remove(value)
        ..add(value?.copyWith(value: inputValue) ??
            StringValue(name: 'inputValue', value: inputValue));
      payload.nodeValues[node.id]!.value = updatedValues;
    } else {
      payload.nodeValues[node.id]!.value = [
        StringValue(name: 'inputValue', value: inputValue)
      ];
    }
    node.reactions
        .where((reaction) => reaction.trigger.type == TriggerType.changed)
        .forEach((reaction) => FunctionsRepository.performAction(
              context,
              reaction.action,
              internalValue: inputValue,
            ));
  }

  void onSubmitted(BuildContext context, List<Reaction> reactions) => reactions
      .where((reaction) => reaction.trigger.type == TriggerType.submitted)
      .forEach((reaction) =>
          FunctionsRepository.performAction(context, reaction.action));
}

class PassiveTextFieldWidget extends StatelessWidget {
  final TextFieldNode node;
  final WidgetBuildSettings settings;
  final VoidCallback? onTap;
  final Function(String)? onChanged;
  final VoidCallback? onSubmitted;
  final bool useIconFonts;

  const PassiveTextFieldWidget({
    super.key,
    required this.node,
    this.settings = const WidgetBuildSettings(),
    this.onTap,
    this.onChanged,
    this.onSubmitted,
    this.useIconFonts = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool enabled =
        context.getNodeValue(node.id, 'enabled') ?? node.properties.enabled;
    final bool obscureText = context.getNodeValue(node.id, 'obscureText') ??
        node.properties.obscureText;
    final bool readOnly =
        context.getNodeValue(node.id, 'readOnly') ?? node.properties.readOnly;
    final bool showCursor = context.getNodeValue(node.id, 'showCursor') ??
        node.properties.showCursor;
    final int? maxLength =
        context.getNodeValue(node.id, 'maxLength') ?? node.properties.maxLength;

    Widget widget;

    widget = TextField(
      autocorrect: node.properties.autoCorrect,
      autofocus: node.properties.autoFocus,
      enableInteractiveSelection: node.properties.enableInteractiveSelection,
      enabled: enabled,
      obscureText: obscureText,
      readOnly: readOnly,
      showCursor: showCursor,
      keyboardType: node.properties.keyboardType.toFlutter(),
      selectionHeightStyle: node.properties.selectionHeightStyle.toFlutter(),
      selectionWidthStyle: node.properties.selectionWidthStyle.toFlutter(),
      textAlign: node.properties.textAlign.toFlutter(),
      // textAlignVertical: node.textAlignVertical,
      cursorColor: node.properties.cursorColor.toFlutterColor(opacity: 1),
      cursorHeight: node.properties.cursorHeight,
      cursorWidth: node.properties.cursorWidth,
      cursorRadius: Radius.circular(node.properties.cursorRadius),
      maxLength: maxLength,
      maxLines: node.properties.maxLines,
      minLines: node.properties.minLines,
      obscuringCharacter: node.properties.obscuringCharacter,
      decoration: PassiveTextFieldTransformer.getDecoration(
        context,
        node,
        node.properties.decoration,
        useIconFonts,
        settings,
      ),
      style:
          PassiveTextFieldTransformer.getTextStyle(node.properties.inputStyle),
      onTap: onTap,
      onChanged: onChanged,
      onEditingComplete: () {},
      onSubmitted: (value) => onSubmitted?.call(),
    );

    if (!node.isHorizontalExpanded) {
      widget = SizedBox(width: node.basicBoxLocal.width, child: widget);
    }

    return widget;
  }
}
