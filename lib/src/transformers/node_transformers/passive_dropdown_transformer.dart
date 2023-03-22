import 'package:codelessly_api/api.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../codelessly_sdk.dart';

class PassiveDropdownTransformer extends NodeWidgetTransformer<DropdownNode> {
  PassiveDropdownTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    DropdownNode node,
    BuildContext context, [
    WidgetBuildSettings settings = const WidgetBuildSettings(),
  ]) {
    return buildDropdownFromNode(node);
  }

  Widget buildDropdownFromNode(DropdownNode node) {
    return PassiveDropdownWidget(node: node);
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

  void onTap(List<Reaction> reactions) => reactions
      .where((reaction) => reaction.trigger.type == TriggerType.click)
      .forEach(onAction);

  // void onChanged(List<Reaction> reactions) => reactions
  //     .where((reaction) => reaction.trigger.type == TriggerType.changed)
  //     .forEach(onAction);

  void onAction(Reaction reaction) {
    switch (reaction.action.type) {
      case ActionType.link:
        launchUrl(Uri.parse((reaction.action as LinkAction).url));
        break;
      default:
        break;
    }
  }
}

class PassiveDropdownWidget extends StatelessWidget {
  final DropdownNode node;
  final VoidCallback? onTap;
  final bool useIconFonts;

  const PassiveDropdownWidget({
    super.key,
    required this.node,
    this.onTap,
    this.useIconFonts = false,
  });

  List<DropdownMenuItem<int>> get items {
    return node.properties.items
        .map(
          (item) => DropdownMenuItem<int>(
            value: node.properties.items.indexOf(item),
            alignment: node.properties.itemAlignment.flutterAlignmentGeometry ??
                AlignmentDirectional.centerStart,
            child: Text(
              item,
              style: PassiveDropdownTransformer.getTextStyle(
                  node.properties.itemTextStyle),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )
        .toList();
  }

  List<Widget> selectedItemBuilder(BuildContext context) {
    return node.properties.items
        .map(
          (item) => Container(
            constraints: BoxConstraints(
                maxWidth: node.basicBoxLocal.width - node.properties.iconSize),
            child: Text(
              item,
              style: PassiveDropdownTransformer.getTextStyle(
                  node.properties.selectedItemTextStyle),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveNodeBox(
      node: node,
      child: DropdownButton<int>(
        value: node.properties.value,
        isDense: node.properties.dense,
        isExpanded: node.properties.expanded,
        autofocus: node.properties.autoFocus,
        enableFeedback: node.properties.enableFeedback,
        alignment:
            node.properties.selectedItemAlignment.flutterAlignmentGeometry ??
                Alignment.centerLeft,
        hint: node.properties.hint.isNotEmpty
            ? Text(
                node.properties.hint,
                style: PassiveDropdownTransformer.getTextStyle(
                    node.properties.hintStyle),
                overflow: TextOverflow.ellipsis,
              )
            : null,
        iconDisabledColor: node.properties.iconDisabledColor.toFlutterColor(),
        iconEnabledColor: node.properties.iconEnabledColor.toFlutterColor(),
        iconSize: node.properties.iconSize,
        icon: node.properties.icon.show && node.properties.icon.icon != null
            ? retrieveIconWidget(
                node.properties.icon, node.properties.iconSize, useIconFonts)
            : null,
        dropdownColor: node.properties.dropdownColor.toFlutterColor(),
        focusColor: node.properties.focusColor.toFlutterColor(),
        elevation: node.properties.elevation,
        borderRadius: node.properties.borderRadius.borderRadius,
        onTap: onTap,
        onChanged: node.properties.enabled ? (value) {} : null,
        underline: node.properties.underline ? null : SizedBox.shrink(),
        items: items,
        selectedItemBuilder: selectedItemBuilder,
      ),
    );
  }
}
