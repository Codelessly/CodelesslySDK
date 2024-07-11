import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../codelessly_sdk.dart';
import '../../functions/functions_repository.dart';
import '../utils/node_state_provider.dart';

class PassiveTextFieldTransformer extends NodeWidgetTransformer<TextFieldNode> {
  PassiveTextFieldTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    TextFieldNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) {
    return PassiveTextFieldWidget(
      key: ValueKey(node.id),
      node: node,
      settings: settings,
      onTap: (context, value) => onTap(context, node, value),
      onIconTap: (context, reactions, value) =>
          onIconTap(context, node, reactions, value),
      onChanged: (context, value) => onChanged(context, node, value),
      onSubmitted: (context, value) => onSubmitted(context, node, value),
    );
  }

  Widget buildTextFieldWidgetFromProps({
    required TextFieldProperties props,
    required double height,
    required double width,
    required WidgetBuildSettings settings,
  }) {
    final node = TextFieldNode(
      id: '',
      name: 'TextField',
      basicBoxLocal: NodeBox(0, 0, width, height),
      properties: props,
      edgePins: EdgePinsModel.standard,
    );
    return PassiveTextFieldWidget(
      node: node,
      settings: settings,
    );
  }

  void onTap(BuildContext context, TextFieldNode node, String inputValue) {
    NodeStateProvider.setState(context, inputValue);
    FunctionsRepository.triggerAction(context, node: node, TriggerType.changed);
  }

  void onChanged(BuildContext context, TextFieldNode node, String inputValue) {
    NodeStateProvider.setState(context, inputValue);
    FunctionsRepository.setNodeValue(context,
        node: node, property: 'inputValue', value: inputValue);

    FunctionsRepository.setPropertyVariable(context,
        node: node, property: 'inputValue', value: inputValue);

    FunctionsRepository.triggerAction(
        context, node: node, TriggerType.changed, value: inputValue);
  }

  void onSubmitted(
    BuildContext context,
    TextFieldNode node,
    String inputValue,
  ) {
    NodeStateProvider.setState(context, inputValue);
    FunctionsRepository.triggerAction(
        context, node: node, TriggerType.submitted, value: inputValue);
  }

  void onIconTap(BuildContext context, TextFieldNode node,
      List<Reaction> reactions, String inputValue) {
    NodeStateProvider.setState(context, inputValue);
    FunctionsRepository.triggerAction(
      context,
      node: node,
      TriggerType.click,
      value: inputValue,
      reactions: reactions,
    );
  }
}

class PassiveTextFieldWidget extends StatefulWidget {
  final TextFieldNode node;
  final WidgetBuildSettings settings;
  final List<VariableData> variablesOverrides;
  final Function(BuildContext context, String value)? onTap;
  final Function(BuildContext context, String value)? onChanged;
  final Function(BuildContext context, String value)? onSubmitted;
  final Function(BuildContext context, List<Reaction> reactions, String value)?
      onIconTap;
  final bool useIconFonts;
  final bool withAutofill;
  final AutovalidateMode? autovalidateMode;
  final FormFieldValidator<String>? validator;

  PassiveTextFieldWidget({
    super.key,
    required this.node,
    required this.settings,
    this.onTap,
    this.onChanged,
    this.onSubmitted,
    this.useIconFonts = false,
    this.withAutofill = true,
    this.onIconTap,
    List<VariableData>? variables,
    this.autovalidateMode,
    this.validator,
  }) : variablesOverrides = variables ?? [];

  @override
  State<PassiveTextFieldWidget> createState() => _PassiveTextFieldWidgetState();
}

class _PassiveTextFieldWidgetState extends State<PassiveTextFieldWidget> {
  late final TextEditingController controller =
      TextEditingController(text: getInitialText(widget.node.initialText));

  final FocusNode focusNode = FocusNode();

  String getInitialText(String text) {
    return PropertyValueDelegate.substituteVariables(
      text,
      nullSubstitutionMode: widget.settings.nullSubstitutionMode,
      scopedValues: ScopedValues.of(context),
    );
  }

  @override
  void initState() {
    super.initState();
    focusNode.addListener(onFocusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    NodeStateProvider.setState(context, controller.text);
  }

  @override
  void didUpdateWidget(covariant PassiveTextFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update controller text if this text field is bound to a variable.
    final ScopedValues scopedValues = ScopedValues.of(context);

    // Get the value of bound variable and update the controller text if it's
    // different from the current controller text.
    // widget.node.variables['inputValue'] only works when a sync variable is specified. If it is not then
    // we rely on initial text to be able to see if controller text needs to be updated.
    String? currentPropertyValue = widget.node.variables['inputValue'] != null
        ? PropertyValueDelegate.getPropertyValue<String>(
            widget.node,
            'inputValue',
            scopedValues: scopedValues,
          )
        : findIndexedValueIfApplied(scopedValues) ??
            PropertyValueDelegate.getPropertyValueFromNodeValues<String>(
              widget.node,
              'inputValue',
              scopedValues: scopedValues,
            );
    if (currentPropertyValue != null) {
      currentPropertyValue = PropertyValueDelegate.substituteVariables(
        currentPropertyValue,
        scopedValues: scopedValues,
        nullSubstitutionMode: widget.settings.nullSubstitutionMode,
      );
    }

    if (currentPropertyValue != null &&
        controller.text != currentPropertyValue) {
      controller.text = currentPropertyValue;
    }
  }

  /// The purpose of this function is to find the indexed value of the variable
  /// 'item' if it is applied to the initial text. This is used to determine if
  /// the controller text needs to be updated when the variable 'inputValue' is
  /// not specified.
  String? findIndexedValueIfApplied(ScopedValues scopedValues) {
    if (scopedValues.indexedItem == null) return null;
    if (widget.node.initialText.isEmpty) return null;
    if (widget.node.variables['inputValue'] != null) return null;
    final match = VariableMatch.parseAll(widget.node.initialText);
    if (!match.any((match) => match.name == 'item')) return null;

    return widget.node.initialText;
  }

  @override
  void dispose() {
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  void onFocusChanged() {
    if (!focusNode.hasFocus) {
      widget.onSubmitted?.call(context, controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextFieldNode node = widget.node;
    final TextFieldProperties properties = node.properties;

    final bool enabled =
        context.getNodeValue(node.id, 'enabled') ?? properties.enabled;
    final bool obscureText =
        context.getNodeValue(node.id, 'obscureText') ?? properties.obscureText;
    final bool readOnly =
        context.getNodeValue(node.id, 'readOnly') ?? properties.readOnly;
    final bool showCursor =
        context.getNodeValue(node.id, 'showCursor') ?? properties.showCursor;
    final int? maxLength =
        context.getNodeValue(node.id, 'maxLength') ?? properties.maxLength;

    final ScopedValues scopedValues = ScopedValues.of(context);

    final TextInputType keyboardType =
        properties.keyboardType == TextInputTypeEnum.number
            ? TextInputType.numberWithOptions(
                decimal: properties.showDecimalKey,
                signed: properties.showSignKey)
            : properties.keyboardType.toFlutter();

    final TextInputValidatorModel validatorModel = properties.validator;
    final FormFieldValidator<String> validator =
        widget.validator ?? validatorModel.validate;

    Widget field = TextFormField(
      focusNode: focusNode,
      autocorrect: properties.autoCorrect,
      autofocus: !widget.settings.isPreview && properties.autoFocus,
      enableInteractiveSelection: properties.enableInteractiveSelection,
      enabled: enabled,
      controller: controller,
      obscureText: widget.node.properties.maxLines == 1 &&
          widget.node.isVerticalWrap &&
          obscureText,
      readOnly: readOnly,
      showCursor: showCursor,
      keyboardType: keyboardType,
      textInputAction:
          widget.node.properties.textInputAction.flutterTextInputAction,
      selectionHeightStyle: properties.selectionHeightStyle.toFlutter(),
      selectionWidthStyle: properties.selectionWidthStyle.toFlutter(),
      textAlign: properties.textAlign.toFlutter(),
      textAlignVertical: properties.textAlignVertical.flutterTextAlignVertical,
      cursorColor: properties.cursorColor.toFlutterColor(opacity: 1),
      cursorHeight: properties.cursorHeight,
      cursorWidth: properties.cursorWidth,
      cursorRadius: Radius.circular(properties.cursorRadius),
      maxLength: maxLength,
      validator: validator,
      autovalidateMode: widget.autovalidateMode ??
          widget.node.properties.autovalidateMode.flutterAutovalidateMode,
      autofillHints:
          AutofillGroup.maybeOf(context) != null && !widget.settings.isPreview
              ? widget.node.properties.autofillHints.map((hint) => hint.code)
              : null,
      inputFormatters: [
        if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
        if (properties.formatter.toFlutterFormatter() case var formatter?)
          formatter,
      ],
      maxLines:
          widget.node.properties.maxLines.orNullIf(!widget.node.isVerticalWrap),
      minLines:
          widget.node.properties.minLines.orNullIf(!widget.node.isVerticalWrap),
      expands: !widget.node.isVerticalWrap,
      obscuringCharacter: widget.node.properties.obscuringCharacter,
      style: TextUtils.retrieveTextStyleFromProp(
          widget.node.properties.inputStyle),
      onTap: () => widget.onTap?.call(context, controller.text),
      onChanged: (value) => widget.onChanged?.call(context, value),
      onEditingComplete: () {},
      onFieldSubmitted: (value) {
        // handled by the focus listener!
      },
      decoration: getDecoration(
        context,
        node,
        properties.decoration,
        widget.useIconFonts,
        widget.settings,
        scopedValues,
      ),
    );

    if (node.isHorizontalWrap) {
      field = IntrinsicWidth(child: field);
    }
    if (node.isVerticalWrap) {
      field = IntrinsicHeight(child: field);
    }

    field = AdaptiveNodeBox(
      node: node,
      child: field,
    );

    return field;
  }

  InputDecoration getDecoration(
    BuildContext context,
    TextFieldNode node,
    InputDecorationModel decoration,
    bool useIconFonts,
    WidgetBuildSettings settings,
    ScopedValues scopedValues,
  ) {
    final bool isCollapsed =
        context.getNodeValue(node.id, 'isCollapsed') ?? decoration.isCollapsed;
    final bool isDense =
        context.getNodeValue(node.id, 'isDense') ?? decoration.isDense;
    final Widget? labelText = buildText(
      context,
      node,
      property: 'labelText',
      defaultValue: decoration.labelText,
      scopedValues: scopedValues,
      settings: settings,
      variablesOverrides: widget.variablesOverrides,
      color: decoration.labelStyle.fills.first.toFlutterColor(),
      fontSize: decoration.labelStyle.fontSize,
      letterSpacing: decoration.labelStyle.letterSpacing,
      lineHeight: decoration.labelStyle.lineHeight,
      fontName: decoration.labelStyle.fontName,
      textDecoration: decoration.labelStyle.textDecoration,
    );
    final String? hintText = getText(
      context,
      node,
      property: 'hintText',
      defaultValue: decoration.hintText,
      scopedValues: scopedValues,
      settings: settings,
    );
    final String? helperText = getText(
      context,
      node,
      property: 'helperText',
      defaultValue: decoration.helperText,
      scopedValues: scopedValues,
      settings: settings,
    );
    final Widget? errorText = buildText(
      context,
      node,
      property: 'errorText',
      defaultValue: decoration.errorText,
      scopedValues: scopedValues,
      settings: settings,
      variablesOverrides: widget.variablesOverrides,
      color: decoration.errorStyle.fills.first.toFlutterColor(),
      fontSize: decoration.errorStyle.fontSize,
      letterSpacing: decoration.errorStyle.letterSpacing,
      lineHeight: decoration.errorStyle.lineHeight,
      fontName: decoration.errorStyle.fontName,
      textDecoration: decoration.errorStyle.textDecoration,
    );
    final Widget? prefixText = buildText(
      context,
      node,
      property: 'prefixText',
      defaultValue: decoration.prefixText,
      scopedValues: scopedValues,
      settings: settings,
      variablesOverrides: widget.variablesOverrides,
      color: decoration.prefixStyle.fills.first.toFlutterColor(),
      fontSize: decoration.prefixStyle.fontSize,
      letterSpacing: decoration.prefixStyle.letterSpacing,
      lineHeight: decoration.prefixStyle.lineHeight,
      fontName: decoration.prefixStyle.fontName,
      textDecoration: decoration.prefixStyle.textDecoration,
    );
    final Widget? suffixText = buildText(
      context,
      node,
      property: 'suffixText',
      defaultValue: decoration.suffixText,
      scopedValues: scopedValues,
      settings: settings,
      variablesOverrides: widget.variablesOverrides,
      color: decoration.suffixStyle.fills.first.toFlutterColor(),
      fontSize: decoration.suffixStyle.fontSize,
      letterSpacing: decoration.suffixStyle.letterSpacing,
      lineHeight: decoration.suffixStyle.lineHeight,
      fontName: decoration.suffixStyle.fontName,
      textDecoration: decoration.suffixStyle.textDecoration,
    );
    final Widget? counterText = buildText(
      context,
      node,
      property: 'counterText',
      defaultValue: decoration.counterText,
      scopedValues: scopedValues,
      settings: settings,
      variablesOverrides: widget.variablesOverrides,
      color: decoration.counterStyle.fills.first.toFlutterColor(),
      fontSize: decoration.counterStyle.fontSize,
      letterSpacing: decoration.counterStyle.letterSpacing,
      lineHeight: decoration.counterStyle.lineHeight,
      fontName: decoration.counterStyle.fontName,
      textDecoration: decoration.counterStyle.textDecoration,
    );

    return InputDecoration(
      icon: !decoration.icon.show || decoration.icon.isEmpty
          ? null
          : retrieveIconWidget(decoration.icon, null, useIconFonts),
      label: labelText,
      floatingLabelStyle:
          TextUtils.retrieveTextStyleFromProp(decoration.floatingLabelStyle),
      helperText: helperText,
      helperStyle: TextUtils.retrieveTextStyleFromProp(decoration.helperStyle),
      helperMaxLines: decoration.helperMaxLines,
      hintText: hintText,
      hintStyle: TextUtils.retrieveTextStyleFromProp(decoration.hintStyle),
      hintMaxLines: decoration.hintMaxLines,
      error: errorText,
      errorStyle: TextUtils.retrieveTextStyleFromProp(decoration.errorStyle),
      errorMaxLines: decoration.errorMaxLines,
      floatingLabelBehavior: decoration.floatingLabelBehavior.toFlutter(),
      isCollapsed: isCollapsed,
      isDense: isDense,
      contentPadding: node.padding.flutterEdgeInsets,
      prefixIcon: !decoration.prefixIcon.icon.show ||
              decoration.prefixIcon.icon.isEmpty
          ? null
          : _ReactiveIcon(
              onTap: () => widget.onIconTap?.call(
                  context, decoration.prefixIcon.reactions, controller.text),
              iconModel: decoration.prefixIcon,
              useIconFonts: useIconFonts,
            ),
      // prefixIconConstraints:
      //     decoration.prefixIconConstraints.flutterConstraints,
      prefix: prefixText,
      prefixStyle: TextUtils.retrieveTextStyleFromProp(decoration.prefixStyle),
      suffixIcon: !decoration.suffixIcon.icon.show ||
              decoration.suffixIcon.icon.isEmpty
          ? null
          : _ReactiveIcon(
              onTap: () => widget.onIconTap?.call(
                  context, decoration.suffixIcon.reactions, controller.text),
              iconModel: decoration.suffixIcon,
              useIconFonts: useIconFonts,
            ),
      suffix: suffixText,
      suffixStyle: TextUtils.retrieveTextStyleFromProp(decoration.suffixStyle),
      // suffixIconConstraints:
      //     decoration.suffixIconConstraints.flutterConstraints,
      counter: decoration.showCounter
          ? decoration.counterText?.isNotEmpty == true
              ? counterText
              : null
          : null,
      counterText: decoration.showCounter ? null : '',
      // counterText: decoration.showCounter
      //     ? decoration.counterText?.isNotEmpty == true
      //         ? decoration.counterText
      //         : null
      //     : '',
      counterStyle:
          TextUtils.retrieveTextStyleFromProp(decoration.counterStyle),
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

  InputBorder? getInputBorder(InputBorderModel? inputBorder) {
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

  String? getText(
    BuildContext context,
    BaseNode node, {
    required String property,
    required String? defaultValue,
    required ScopedValues scopedValues,
    required WidgetBuildSettings settings,
  }) {
    final String? value =
        context.getNodeValue(node.id, property) ?? defaultValue;
    if (value == null || value.isEmpty) return null;
    final newValue = PropertyValueDelegate.substituteVariables(
      value,
      scopedValues: scopedValues,
      nullSubstitutionMode: settings.nullSubstitutionMode,
    );
    if (newValue.isEmpty) return null;
    return newValue;
  }

  Widget? buildText(
    BuildContext context,
    BaseNode node, {
    required List<VariableData> variablesOverrides,
    required String property,
    required String? defaultValue,
    required ScopedValues scopedValues,
    required WidgetBuildSettings settings,
    Color? color,
    double? fontSize,
    LetterSpacing? letterSpacing,
    LineHeight? lineHeight,
    FontName? fontName,
    TextDecorationEnum? textDecoration,
    List<Effect>? effects,
    TextAlignHorizontalEnum? textAlignHorizontal,
    int? maxLines,
  }) {
    final String? value =
        context.getNodeValue(node.id, property) ?? defaultValue;
    if (value == null || value.isEmpty) return null;
    return TextUtils.buildText(
      context,
      value,
      node: node,
      variablesOverrides: variablesOverrides,
      nullSubstitutionMode: settings.nullSubstitutionMode,
      replaceVariablesWithSymbol: settings.replaceVariablesWithSymbols,
      color: color,
      fontSize: fontSize,
      letterSpacing: letterSpacing,
      lineHeight: lineHeight,
      fontName: fontName,
      textDecoration: textDecoration,
      effects: effects,
      textAlignHorizontal: textAlignHorizontal,
      maxLines: maxLines,
    );
  }
}

class _ReactiveIcon extends StatelessWidget {
  final VoidCallback onTap;
  final ReactiveIconModel iconModel;
  final bool useIconFonts;

  const _ReactiveIcon({
    required this.onTap,
    required this.iconModel,
    required this.useIconFonts,
  });

  @override
  Widget build(BuildContext context) {
    final icon = Align(
      widthFactor: 1,
      heightFactor: 1,
      child: retrieveIconWidget(iconModel.icon, null, useIconFonts)!,
    );

    if (iconModel.reactions.isEmpty) return icon;

    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: icon,
      ),
    );
  }
}
