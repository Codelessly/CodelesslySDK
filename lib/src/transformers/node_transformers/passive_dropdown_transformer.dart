import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../codelessly_sdk.dart';
import '../utils/node_state_provider.dart';

class PassiveDropdownTransformer extends NodeWidgetTransformer<DropdownNode> {
  PassiveDropdownTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    DropdownNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) {
    return buildDropdownFromNode(context, node, settings);
  }

  Widget buildDropdownFromNode(
    BuildContext context,
    DropdownNode node,
    WidgetBuildSettings settings,
  ) {
    return PassiveDropdownWidget(
      node: node,
      onTap: () => onTap(context, node),
      onChanged: (index, value) => onChanged(context, node, index, value),
      settings: settings,
    );
  }

  Widget buildFromProps(
    BuildContext context, {
    required DropdownProperties props,
    required double height,
    required double width,
    bool value = false,
    required WidgetBuildSettings settings,
  }) {
    final node = DropdownNode(
      id: '',
      name: 'Dropdown',
      basicBoxLocal: NodeBox(0, 0, width, height),
      retainedOuterBoxLocal: NodeBox(0, 0, width, height),
      properties: props,
    );
    return buildDropdownFromNode(context, node, settings);
  }

  void onTap(BuildContext context, DropdownNode node) =>
      FunctionsRepository.triggerAction(context, node: node, TriggerType.click);

  void onChanged(
    BuildContext context,
    DropdownNode node,
    int index,
    Object internalValue,
  ) {
    NodeStateProvider.setState(context, internalValue);
    FunctionsRepository.setPropertyValue(
      context,
      node: node,
      property: 'value',
      value: internalValue,
    );

    FunctionsRepository.triggerAction(
      context,
      node: node,
      TriggerType.changed,
      value: internalValue,
    );
  }
}

class PassiveDropdownWidget extends StatelessWidget {
  final DropdownNode node;
  final VoidCallback? onTap;
  final Function(int index, Object value)? onChanged;
  final int? initialValue;
  final WidgetBuildSettings settings;

  /// The values the items and selection bindings read instead of the build
  /// context's, such as the variable defaults a design canvas shows.
  final ScopedValues? scopedValues;

  const PassiveDropdownWidget({
    super.key,
    required this.node,
    this.onTap,
    this.onChanged,
    this.initialValue,
    required this.settings,
    this.scopedValues,
  });

  /// The label of the item provided at [context].
  String labelOf(BuildContext context, Object? value) {
    if (!node.properties.useDataSource) return '$value';
    final ScopedValues scopedValues = ScopedValues.of(context);
    final String labelText =
        PropertyValueDelegate.getPropertyValue<String>(
          node,
          'itemLabel',
          scopedValues: scopedValues,
        ) ??
        node.properties.itemLabel;
    return PropertyValueDelegate.substituteVariables(
      labelText,
      nullSubstitutionMode: settings.nullSubstitutionMode,
      scopedValues: scopedValues,
    );
  }

  /// The image before the label of the item provided at [context], if the
  /// dropdown has one.
  Widget? imageOf(BuildContext context) {
    final DropdownProperties props = node.properties;
    if (props.itemImage.trim().isEmpty) return null;
    final String url = PropertyValueDelegate.substituteVariables(
      props.itemImage,
      nullSubstitutionMode: NullSubstitutionMode.emptyString,
      scopedValues: ScopedValues.of(context),
    ).trim();
    final double size = props.itemImageSize;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 10),
      child: SizedBox.square(
        dimension: size,
        child: url.isEmpty
            ? null
            : ClipRRect(
                borderRadius: BorderRadius.circular(props.itemImageRadius),
                child: Image.network(
                  url,
                  key: const ValueKey('codelessly-dropdown-item-image'),
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      SizedBox.square(dimension: size),
                ),
              ),
      ),
    );
  }

  /// An item's row: its image, if any, and its label.
  Widget itemContent(BuildContext context, Object? value, TextStyle style) {
    final Widget? image = imageOf(context);
    final Widget label = Text(
      labelOf(context, value),
      style: style,
      overflow: TextOverflow.ellipsis,
    );
    if (image == null) return label;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        image,
        Flexible(child: label),
      ],
    );
  }

  List<DropdownMenuItem<Object>> buildItems(BuildContext context, List items) {
    return [
      for (final (index, value) in items.indexed)
        DropdownMenuItem<Object>(
          value: value,
          alignment:
              node.properties.itemAlignment.flutterAlignmentGeometry ??
              AlignmentDirectional.centerStart,
          child: ChangeNotifierProvider<CodelesslyContext>.value(
            value: context.read<CodelesslyContext>(),
            child: IndexedItemProvider(
              item: IndexedItem(index, value),
              child: Builder(
                builder: (context) => itemContent(
                  context,
                  value,
                  TextUtils.retrieveTextStyleFromProp(
                    node.properties.itemTextStyle,
                  ),
                ),
              ),
            ),
          ),
        ),
    ];
  }

  List<Widget> selectedItemBuilder(BuildContext context, List items) {
    return [
      for (final (index, value) in items.indexed)
        DropdownMenuItem<Object>(
          value: Object,
          alignment:
              node.properties.itemAlignment.flutterAlignmentGeometry ??
              AlignmentDirectional.centerStart,
          child: IndexedItemProvider(
            item: IndexedItem(index, value),
            child: Builder(
              builder: (context) => Container(
                // An expanded dropdown gives the value the field's width; the
                // design width only caps one that sizes to its value.
                constraints: node.properties.isExpanded
                    ? null
                    : BoxConstraints(
                        maxWidth:
                            node.basicBoxLocal.width - node.properties.iconSize,
                      ),
                child: itemContent(
                  context,
                  value,
                  TextUtils.retrieveTextStyleFromProp(
                    node.properties.selectedItemTextStyle,
                  ),
                ),
              ),
            ),
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final ScopedValues scopedValues =
        this.scopedValues ?? ScopedValues.of(context);
    final List items = node.properties.useDataSource
        ? PropertyValueDelegate.getPropertyValue<List>(
                node,
                'data',
                scopedValues: scopedValues,
              ) ??
              []
        : node.properties.items;

    Object? value =
        PropertyValueDelegate.getPropertyValue<Object>(
          node,
          'value',
          scopedValues: scopedValues,
        ) ??
        node.value;
    // Data source items are maps and lists read anew on each build: the
    // selected one is the item equal to the value by content.
    const DeepCollectionEquality equality = DeepCollectionEquality();
    final List matches = [
      for (final Object? item in items)
        if (equality.equals(item, value)) item,
    ];
    value = matches.length == 1 ? matches.single : null;

    return AdaptiveNodeBox(
      node: node,
      child: Theme(
        data: Theme.of(context).copyWith(
          hoverColor: node.properties.hoverColor?.toFlutterColor(),
          splashColor: node.properties.splashColor?.toFlutterColor(),
        ),
        child: Builder(
          builder: (context) {
            final child = DropdownButton<Object>(
              value: value,
              isDense: node.properties.isDense,
              isExpanded: node.properties.isExpanded,
              autofocus: node.properties.autofocus,
              enableFeedback: node.properties.enableFeedback,
              alignment:
                  node
                      .properties
                      .selectedItemAlignment
                      .flutterAlignmentGeometry ??
                  Alignment.centerLeft,
              hint: node.properties.hint.isNotEmpty
                  ? Text(
                      node.properties.hint,
                      style: TextUtils.retrieveTextStyleFromProp(
                        node.properties.hintStyle,
                      ),
                      overflow: TextOverflow.ellipsis,
                    )
                  : null,
              iconDisabledColor: node.properties.iconDisabledColor
                  .toFlutterColor(),
              iconEnabledColor: node.properties.iconEnabledColor
                  .toFlutterColor(),
              iconSize: node.properties.iconSize,
              icon: retrieveIconWidget(
                node.properties.icon,
                node.properties.iconSize,
              ),
              dropdownColor: node.properties.dropdownColor.toFlutterColor(),
              focusColor: node.properties.focusColor.toFlutterColor(),
              elevation: node.properties.elevation,
              borderRadius: node.properties.borderRadius.borderRadius,
              onTap: onTap,
              padding: node.padding.flutterEdgeInsets,
              onChanged: node.properties.enabled
                  ? (value) {
                      if (value == null) return;
                      final index = items.indexOf(value);
                      onChanged?.call(index, value);
                    }
                  : null,
              underline: node.properties.underline
                  ? null
                  : const SizedBox.shrink(),
              items: buildItems(context, items),
              selectedItemBuilder: (context) =>
                  selectedItemBuilder(context, items),
            );
            Widget field = child;
            final DropdownMenuStyleModel? menuStyle = node.properties.menuStyle;
            if (menuStyle != null) {
              // The field stays the dropdown button; the menu it opens is
              // a card anchored under it.
              field = _AnchoredDropdownMenu(
                widget: this,
                style: menuStyle,
                items: items,
                value: value,
                enabled: node.properties.enabled,
                child: child,
              );
            }
            if (node.horizontalFit.isWrap) {
              return IntrinsicWidth(child: field);
            }
            return field;
          },
        ),
      ),
    );
  }
}

/// Opens a [DropdownMenuStyleModel]-styled menu anchored under [child], the
/// dropdown's field, in place of the platform's dropdown menu.
class _AnchoredDropdownMenu extends StatefulWidget {
  const _AnchoredDropdownMenu({
    required this.widget,
    required this.style,
    required this.items,
    required this.value,
    required this.enabled,
    required this.child,
  });

  final PassiveDropdownWidget widget;
  final DropdownMenuStyleModel style;
  final List items;
  final Object? value;
  final bool enabled;
  final Widget child;

  @override
  State<_AnchoredDropdownMenu> createState() => _AnchoredDropdownMenuState();
}

class _AnchoredDropdownMenuState extends State<_AnchoredDropdownMenu> {
  final OverlayPortalController _portal = OverlayPortalController();
  final LayerLink _link = LayerLink();
  Size _fieldSize = Size.zero;
  bool _below = true;

  void _open() {
    if (!widget.enabled || _portal.isShowing) return;
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final double screenHeight = MediaQuery.sizeOf(context).height;
    final double bottom = box.localToGlobal(Offset.zero).dy + box.size.height;
    setState(() {
      _fieldSize = box.size;
      _below =
          bottom + widget.style.offset + widget.style.maxHeight <=
              screenHeight ||
          bottom < screenHeight / 2;
    });
    _portal.show();
    widget.widget.onTap?.call();
  }

  void _close() {
    if (_portal.isShowing) setState(_portal.hide);
  }

  void _pick(int index, Object value) {
    _close();
    widget.widget.onChanged?.call(index, value);
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: _buildMenu,
      child: CompositedTransformTarget(
        link: _link,
        child: FocusableActionDetector(
          enabled: widget.enabled,
          mouseCursor: widget.enabled
              ? SystemMouseCursors.click
              : MouseCursor.defer,
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) => _open(),
            ),
          },
          child: Semantics(
            button: true,
            enabled: widget.enabled,
            expanded: _portal.isShowing,
            onTap: widget.enabled ? _open : null,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _open,
              // The button only draws the field; the menu is this one.
              child: IgnorePointer(child: ExcludeFocus(child: widget.child)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenu(BuildContext context) {
    final DropdownMenuStyleModel style = widget.style;
    final DropdownProperties props = widget.widget.node.properties;
    final double radius =
        style.radius ?? props.borderRadius.borderRadius.topLeft.x;
    final BorderSide side = style.border == null
        ? BorderSide.none
        : borderSideOf(style.border!);
    final List<BoxShadow> shadows = style.shadows != null
        ? boxShadowsOf(style.shadows)
        : kElevationToShadow[props.elevation.clamp(0, 24)] ??
              kElevationToShadow[8]!;
    final TextStyle itemStyle = TextUtils.retrieveTextStyleFromProp(
      props.itemTextStyle,
    );
    final TextStyle selectedStyle = style.selectedTextStyle.applyTo(itemStyle);
    final Color? hover =
        style.hoverItemColor?.toFlutterColor() ??
        props.hoverColor?.toFlutterColor();
    final EdgeInsets itemPadding =
        style.itemPadding?.flutterEdgeInsets ??
        const EdgeInsets.symmetric(horizontal: 14);

    final Widget menu = Container(
      key: const ValueKey('codelessly-dropdown-menu'),
      width: _fieldSize.width < style.minWidth
          ? style.minWidth
          : _fieldSize.width,
      constraints: BoxConstraints(maxHeight: style.maxHeight),
      decoration: BoxDecoration(
        color:
            style.color?.toFlutterColor() ??
            props.dropdownColor.toFlutterColor(),
        borderRadius: BorderRadius.circular(radius),
        border: side == BorderSide.none ? null : Border.fromBorderSide(side),
        boxShadow: shadows,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          (radius - side.width).clamp(0, double.infinity),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: SingleChildScrollView(
            padding:
                style.padding?.flutterEdgeInsets ??
                const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (index, item) in widget.items.indexed)
                  IndexedItemProvider(
                    item: IndexedItem(index, item),
                    child: Builder(
                      builder: (context) {
                        final bool selected = item == widget.value;
                        final TextStyle textStyle = selected
                            ? selectedStyle
                            : itemStyle;
                        return Semantics(
                          selected: selected,
                          button: true,
                          child: Material(
                            color: selected
                                ? style.selectedItemColor?.toFlutterColor() ??
                                      Colors.transparent
                                : Colors.transparent,
                            child: InkWell(
                              key: ValueKey('codelessly-dropdown-item-$index'),
                              hoverColor: hover,
                              splashColor: props.splashColor?.toFlutterColor(),
                              onTap: () => _pick(index, item),
                              child: Container(
                                height: style.itemHeight,
                                padding: itemPadding,
                                alignment:
                                    props
                                        .itemAlignment
                                        .flutterAlignmentGeometry ??
                                    AlignmentDirectional.centerStart,
                                child: Row(
                                  children: [
                                    ?widget.widget.imageOf(context),
                                    Expanded(
                                      child: Text(
                                        widget.widget.labelOf(context, item),
                                        style: textStyle,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (selected && style.showCheck)
                                      Padding(
                                        padding:
                                            const EdgeInsetsDirectional.only(
                                              start: 8,
                                            ),
                                        child: Icon(
                                          Icons.check,
                                          key: const ValueKey(
                                            'codelessly-dropdown-check',
                                          ),
                                          size: style.checkSize,
                                          color:
                                              style.checkColor
                                                  ?.toFlutterColor() ??
                                              textStyle.color,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _close,
          ),
        ),
        CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          targetAnchor: _below ? Alignment.bottomLeft : Alignment.topLeft,
          followerAnchor: _below ? Alignment.topLeft : Alignment.bottomLeft,
          offset: Offset(0, _below ? style.offset : -style.offset),
          child: Align(
            alignment: _below ? Alignment.topLeft : Alignment.bottomLeft,
            child: menu,
          ),
        ),
      ],
    );
  }
}
