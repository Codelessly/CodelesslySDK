import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';
import '../../functions/functions_repository.dart';
import '../utils/node_state_provider.dart';

class PassiveNavigationBarTransformer
    extends NodeWidgetTransformer<NavigationBarNode> {
  PassiveNavigationBarTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    NavigationBarNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) {
    return PassiveNavigationBarWidget(
      node: node,
      onChanged: (index) => onChanged(node, context, index),
    );
  }

  void onChanged(NavigationBarNode node, BuildContext context, int index) {
    NodeStateProvider.setState(context, index);
    final item = node.properties.items[index];
    FunctionsRepository.triggerAction(context, TriggerType.changed,
        reactions: item.reactions);
  }

  Widget buildNavigationBarWidgetFromProps({
    required NavigationBarProperties style,
  }) {
    final node = NavigationBarNode(
      id: '',
      name: 'NavigationBar',
      basicBoxLocal: NodeBox(0, 0, 100, kBottomNavigationBarHeight),
      properties: style,
    );
    return PassiveNavigationBarWidget(
      node: node,
      applyBottomPadding: false,
    );
  }

  Widget buildPreview({
    NavigationBarProperties? properties,
    NavigationBarNode? node,
    double? height,
    double? width,
    int currentIndex = 0,
    ValueChanged<int>? onChanged,
  }) {
    final previewNode = NavigationBarNode(
      properties: properties ?? node!.properties,
      id: '',
      name: 'NavigationBar',
      basicBoxLocal:
          NodeBox(0, 0, width ?? 300, height ?? kBottomNavigationBarHeight),
      retainedOuterBoxLocal:
          NodeBox(0, 0, width ?? 300, height ?? kBottomNavigationBarHeight),
      currentIndex: currentIndex,
      verticalFit: SizeFit.shrinkWrap,
    );
    return PassiveNavigationBarWidget(
      node: previewNode,
      applyBottomPadding: false,
      onChanged: onChanged,
    );
  }
}

class PassiveNavigationBarWidget extends StatefulWidget
    implements PreferredSizeWidget {
  final NavigationBarNode node;
  final ValueChanged<int>? onChanged;
  final bool useIconFonts;
  final bool applyBottomPadding;

  const PassiveNavigationBarWidget({
    super.key,
    required this.node,
    this.onChanged,
    this.useIconFonts = false,
    this.applyBottomPadding = true,
  });

  @override
  Size get preferredSize => node.basicBoxLocal.size.flutterSize;

  @override
  State<PassiveNavigationBarWidget> createState() =>
      _PassiveNavigationBarWidgetState();
}

class _PassiveNavigationBarWidgetState
    extends State<PassiveNavigationBarWidget> {
  int currentIndex = 0;

  @override
  void initState() {
    currentIndex = context.getNodeValue(widget.node.id, 'currentIndex') ??
        widget.node.currentIndex;
    super.initState();
  }

  void onChanged(int index) {
    currentIndex = index;
    widget.onChanged?.call(index);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    Widget navBar;
    switch (widget.node.properties.styleDefinition) {
      case StyleDefinition.material_2:
        navBar = buildM2NavigationBar(context, widget.node, onChanged);
      case StyleDefinition.material_3:
        navBar = buildM3NavigationBar(context, widget.node, onChanged);
    }

    if (widget.node.properties.makeNotched) {
      final double elevation;
      final Color? backgroundColor;
      switch (widget.node.properties.styleDefinition) {
        case StyleDefinition.material_2:
          final prop = widget.node.properties as M2NavigationBarProperties;
          elevation = prop.elevation;
          backgroundColor = prop.backgroundColor?.toFlutterColor();
        case StyleDefinition.material_3:
          final prop = widget.node.properties as M3NavigationBarProperties;
          elevation = prop.elevation;
          backgroundColor = prop.backgroundColor?.toFlutterColor();
      }
      navBar = BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: widget.node.properties.notchMargin,
        clipBehavior: Clip.antiAlias,
        elevation: elevation,
        color: backgroundColor,
        child: navBar,
      );
    }
    navBar = AdaptiveNodeBox(
      node: widget.node,
      child: navBar,
    );
    return navBar;
  }

  Widget buildM3NavigationBar(
    BuildContext context,
    NavigationBarNode node,
    ValueChanged<int>? onChanged,
  ) {
    final M3NavigationBarProperties style =
        node.properties as M3NavigationBarProperties;
    final Color? bgColor = style.makeNotched
        ? Colors.transparent
        : style.backgroundColor?.toFlutterColor();
    final double elevation = style.makeNotched ? 0 : style.elevation;
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: bgColor,
        indicatorColor: style.indicatorColor?.toFlutterColor(),
        iconTheme: MaterialStateProperty.resolveWith<IconThemeData>((states) {
          if (states.contains(MaterialState.selected)) {
            return IconThemeData(
              color: style.selectedIconColor?.toFlutterColor(),
              size: style.selectedIconSize,
            );
          }
          return IconThemeData(
            color: style.unselectedIconColor?.toFlutterColor(),
            size: style.unselectedIconSize,
          );
        }),
        labelBehavior: style.labelBehavior.flutterLabelBehavior,
        labelTextStyle: MaterialStateProperty.resolveWith<TextStyle?>((states) {
          if (states.contains(MaterialState.selected)) {
            return TextUtils.retrieveTextStyleFromProp(
                style.selectedLabelStyle);
          }
          return TextUtils.retrieveTextStyleFromProp(
              style.unselectedLabelStyle);
        }),
      ),
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: widget.applyBottomPadding ? null : EdgeInsets.zero,
        ),
        child: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: onChanged,
          backgroundColor: bgColor,
          elevation: elevation,
          height: node.basicBoxLocal.height,
          labelBehavior: style.labelBehavior.flutterLabelBehavior,
          destinations: [
            for (final itemModel in style.items) getM3Item(itemModel, style)
          ],
        ),
      ),
    );
  }

  Widget buildM2NavigationBar(
    BuildContext context,
    NavigationBarNode node,
    ValueChanged<int>? onChanged,
  ) {
    final M2NavigationBarProperties style =
        node.properties as M2NavigationBarProperties;

    final Color? selectedLabelColor =
        style.selectedLabelStyle.fills.firstOrNull?.toFlutterColor();
    final Color? unselectedLabelColor =
        style.unselectedLabelStyle.fills.firstOrNull?.toFlutterColor();

    final IconThemeData selectedIconTheme = IconThemeData(
      color: style.selectedIconColor?.toFlutterColor(),
      size: style.selectedIconSize,
    );

    final IconThemeData unselectedIconTheme = IconThemeData(
      color: style.unselectedIconColor?.toFlutterColor(),
      size: style.unselectedIconSize,
    );

    final TextStyle selectedLabelStyle = TextUtils.retrieveTextStyleFromProp(
        style.selectedLabelStyle.copyWith(fills: []));
    final unselectedLabelStyle = TextUtils.retrieveTextStyleFromProp(
        style.unselectedLabelStyle.copyWith(fills: []));

    final double elevation = style.makeNotched ? 0 : style.elevation;

    /// QUOTE FROM [BottomNavigationBar]
    ///
    ///     final double additionalBottomPadding = MediaQuery.of(context).padding.bottom;
    ///     <...>
    ///        child: ConstrainedBox(
    ///          constraints: BoxConstraints(minHeight: kBottomNavigationBarHeight + additionalBottomPadding),
    ///          <...>
    ///          Padding(
    ///               padding: EdgeInsets.only(bottom: additionalBottomPadding),
    ///          <...>
    ///     <...>
    ///
    /// END QUOTE
    ///
    ///  This is adaptive padding that changes depending on platform and device
    ///  to protect the navigation bar from being obscured. Manual SafeArea.
    ///
    ///  This only happens in [BottomNavigationBar] and NOT [NavigationBar].
    ///
    ///  We don't want that. We disable it here.
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        padding: widget.applyBottomPadding ? null : EdgeInsets.zero,
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onChanged,
        type: style.navigationBarType.flutterNavigationBarType,
        landscapeLayout: style.landscapeLayout.flutterLandscapeLayout,
        backgroundColor: style.backgroundColor?.toFlutterColor(),
        selectedItemColor: selectedLabelColor,
        unselectedItemColor: unselectedLabelColor,
        selectedLabelStyle: selectedLabelStyle,
        unselectedLabelStyle: unselectedLabelStyle,
        selectedIconTheme: selectedIconTheme,
        unselectedIconTheme: unselectedIconTheme,
        elevation: elevation,
        showSelectedLabels: style.labelBehavior.showForSelected(),
        showUnselectedLabels: style.labelBehavior.showForUnselected(),
        iconSize: style.unselectedIconSize,
        items: [
          for (final itemModel in style.items) getM2Item(itemModel, style)
        ],
      ),
    );
  }

  BottomNavigationBarItem getM2Item(
    M2NavigationBarItem itemModel,
    M2NavigationBarProperties style,
  ) {
    final Widget unselectedIconDj = retrieveNavBarItemIconWidget(
      itemModel.icon,
      null,
      // style.unselectedIconSize,
      widget.useIconFonts,
    );

    final Widget? selectedIconDj =
        itemModel.differSelectedIcon && itemModel.selectedIcon != null
            ? retrieveNavBarItemIconWidget(
                itemModel.selectedIcon!,
                null,
                // style.selectedIconSize,
                widget.useIconFonts,
              )
            : null;
    return BottomNavigationBarItem(
      icon: unselectedIconDj,
      activeIcon: selectedIconDj,
      // TODO: we are using [style.backgroundColor] because there's a bug in
      // flutter sdk where the top level background color is not applied to the
      // bottom navigation bar when it is shifting type and color per item
      // is not provided.
      // Detailed explanation: https://codelessly.slack.com/archives/C018XK7431R/p1659077643469429
      backgroundColor: itemModel.backgroundColor?.toFlutterColor() ??
          style.backgroundColor?.toFlutterColor().orNullIf(
              style.navigationBarType != M2NavigationBarType.shifting),
      label: itemModel.label,
      tooltip: itemModel.tooltip.orNullIf(itemModel.label == itemModel.tooltip),
    );
  }

  NavigationDestination getM3Item(
    M3NavigationBarItem itemModel,
    M3NavigationBarProperties style,
  ) {
    final Widget unselectedIcon = retrieveNavBarItemIconWidget(
      itemModel.icon,
      null,
      // style.unselectedIconSize,
      widget.useIconFonts,
    );

    final Widget? selectedIconDj =
        itemModel.differSelectedIcon && itemModel.selectedIcon != null
            ? retrieveNavBarItemIconWidget(
                itemModel.selectedIcon!,
                null,
                // style.selectedIconSize,
                widget.useIconFonts,
              )
            : null;
    return NavigationDestination(
      icon: unselectedIcon,
      selectedIcon: selectedIconDj,
      label: itemModel.label,
      tooltip: itemModel.tooltip.orNullIf(itemModel.label == itemModel.tooltip),
    );
  }
}
