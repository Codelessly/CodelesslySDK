import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';
import '../../functions/functions_repository.dart';
import '../utils/node_provider.dart';

class PassiveTextFieldTransformer extends NodeWidgetTransformer<TextFieldNode> {
  PassiveTextFieldTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    TextFieldNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) {
    return PassiveTextFieldWidget(
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
    NodeProvider.setState(context, inputValue);
    FunctionsRepository.triggerAction(context, node: node, TriggerType.changed);
  }

  void onChanged(BuildContext context, TextFieldNode node, String inputValue) {
    NodeProvider.setState(context, inputValue);
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
    NodeProvider.setState(context, inputValue);
    FunctionsRepository.triggerAction(
        context, node: node, TriggerType.submitted, value: inputValue);
  }

  void onIconTap(BuildContext context, TextFieldNode node,
      List<Reaction> reactions, String inputValue) {
    NodeProvider.setState(context, inputValue);
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
  final Function(BuildContext context, String value)? onTap;
  final Function(BuildContext context, String value)? onChanged;
  final Function(BuildContext context, String value)? onSubmitted;
  final Function(BuildContext context, List<Reaction> reactions, String value)?
      onIconTap;
  final bool useIconFonts;

  const PassiveTextFieldWidget({
    super.key,
    required this.node,
    required this.settings,
    this.onTap,
    this.onChanged,
    this.onSubmitted,
    this.useIconFonts = false,
    this.onIconTap,
  });

  @override
  State<PassiveTextFieldWidget> createState() => _PassiveTextFieldWidgetState();
}

class _PassiveTextFieldWidgetState extends State<PassiveTextFieldWidget> {
  late final TextEditingController _controller = TextEditingController(
    text: PropertyValueDelegate.substituteVariables(
      widget.node.initialText,
      nullSubstitutionMode: widget.settings.nullSubstitutionMode,
      scopedValues: ScopedValues.of(context),
    ),
  );

  late final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(onFocusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    NodeProvider.setState(context, _controller.text);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void onFocusChanged() {
    if (!_focusNode.hasFocus) {
      widget.onSubmitted?.call(context, _controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = context.getNodeValue(widget.node.id, 'enabled') ??
        widget.node.properties.enabled;
    final bool obscureText =
        context.getNodeValue(widget.node.id, 'obscureText') ??
            widget.node.properties.obscureText;
    final bool readOnly = context.getNodeValue(widget.node.id, 'readOnly') ??
        widget.node.properties.readOnly;
    final bool showCursor =
        context.getNodeValue(widget.node.id, 'showCursor') ??
            widget.node.properties.showCursor;
    final int? maxLength = context.getNodeValue(widget.node.id, 'maxLength') ??
        widget.node.properties.maxLength;

    final ScopedValues scopedValues = ScopedValues.of(context);

    Widget field;

    field = TextField(
      focusNode: _focusNode,
      autocorrect: widget.node.properties.autoCorrect,
      autofocus: !widget.settings.isPreview && widget.node.properties.autoFocus,
      enableInteractiveSelection:
          widget.node.properties.enableInteractiveSelection,
      enabled: enabled,
      controller: _controller,
      obscureText: obscureText,
      readOnly: readOnly,
      showCursor: showCursor,
      keyboardType: widget.node.properties.keyboardType.toFlutter(),
      selectionHeightStyle:
          widget.node.properties.selectionHeightStyle.toFlutter(),
      selectionWidthStyle:
          widget.node.properties.selectionWidthStyle.toFlutter(),
      textAlign: widget.node.properties.textAlign.toFlutter(),
      textAlignVertical:
          widget.node.properties.textAlignVertical.flutterTextAlignVertical,
      cursorColor:
          widget.node.properties.cursorColor.toFlutterColor(opacity: 1),
      cursorHeight: widget.node.properties.cursorHeight,
      cursorWidth: widget.node.properties.cursorWidth,
      cursorRadius: Radius.circular(widget.node.properties.cursorRadius),
      maxLength: maxLength,
      maxLines:
          widget.node.properties.maxLines.orNullIf(!widget.node.isVerticalWrap),
      minLines:
          widget.node.properties.minLines.orNullIf(!widget.node.isVerticalWrap),
      expands: !widget.node.isVerticalWrap,
      obscuringCharacter: widget.node.properties.obscuringCharacter,
      style: TextUtils.retrieveTextStyleFromProp(
          widget.node.properties.inputStyle),
      onTap: () => widget.onTap?.call(context, _controller.text),
      onChanged: (value) => widget.onChanged?.call(context, value),
      onEditingComplete: () {},
      onSubmitted: (value) {
        // handled by the focus listener!
      },
      decoration: getDecoration(
        context,
        widget.node,
        widget.node.properties.decoration,
        widget.useIconFonts,
        widget.settings,
        scopedValues,
      ),
    );

    final double? width =
        widget.node.isHorizontalWrap || widget.node.isHorizontalExpanded
            ? null
            : widget.node.basicBoxLocal.width;
    final double? height =
        widget.node.isVerticalWrap || widget.node.isVerticalExpanded
            ? null
            : widget.node.basicBoxLocal.height;

    if (widget.node.isHorizontalWrap) {
      field = IntrinsicWidth(
        child: field,
      );
    }

    field = SizedBox(
      width: width,
      height: height,
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
    final String? labelText = getText(
      context,
      node,
      property: 'labelText',
      defaultValue: decoration.labelText,
      scopedValues: scopedValues,
      settings: settings,
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
    final String? errorText = getText(
      context,
      node,
      property: 'errorText',
      defaultValue: decoration.errorText,
      scopedValues: scopedValues,
      settings: settings,
    );
    final String? prefixText = getText(
      context,
      node,
      property: 'prefixText',
      defaultValue: decoration.prefixText,
      scopedValues: scopedValues,
      settings: settings,
    );
    final String? suffixText = getText(
      context,
      node,
      property: 'suffixText',
      defaultValue: decoration.suffixText,
      scopedValues: scopedValues,
      settings: settings,
    );
    final String? counterText = getText(
      context,
      node,
      property: 'counterText',
      defaultValue: decoration.counterText,
      scopedValues: scopedValues,
      settings: settings,
    );

    return InputDecoration(
      icon: !decoration.icon.show || decoration.icon.isEmpty
          ? null
          : retrieveIconWidget(decoration.icon, null, useIconFonts),
      labelText: labelText?.isNotEmpty == true ? labelText : null,
      labelStyle: TextUtils.retrieveTextStyleFromProp(decoration.labelStyle),
      floatingLabelStyle:
          TextUtils.retrieveTextStyleFromProp(decoration.floatingLabelStyle),
      helperText: helperText,
      helperStyle: TextUtils.retrieveTextStyleFromProp(decoration.helperStyle),
      helperMaxLines: decoration.helperMaxLines,
      hintText: hintText,
      hintStyle: TextUtils.retrieveTextStyleFromProp(decoration.hintStyle),
      hintMaxLines: decoration.hintMaxLines,
      errorText: errorText,
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
                  context, decoration.prefixIcon.reactions, _controller.text),
              iconModel: decoration.prefixIcon,
              useIconFonts: useIconFonts,
            ),
      // prefixIconConstraints:
      //     decoration.prefixIconConstraints.flutterConstraints,
      prefixText: prefixText,
      prefixStyle: TextUtils.retrieveTextStyleFromProp(decoration.prefixStyle),
      suffixIcon: !decoration.suffixIcon.icon.show ||
              decoration.suffixIcon.icon.isEmpty
          ? null
          : _ReactiveIcon(
              onTap: () => widget.onIconTap?.call(
                  context, decoration.suffixIcon.reactions, _controller.text),
              iconModel: decoration.suffixIcon,
              useIconFonts: useIconFonts,
            ),
      suffixText: suffixText,
      suffixStyle: TextUtils.retrieveTextStyleFromProp(decoration.suffixStyle),
      // suffixIconConstraints:
      //     decoration.suffixIconConstraints.flutterConstraints,
      counterText: decoration.showCounter ? counterText : '',
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
    if (value == null) return null;
    return PropertyValueDelegate.substituteVariables(
      value,
      scopedValues: scopedValues,
      nullSubstitutionMode: settings.nullSubstitutionMode,
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
