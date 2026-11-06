import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../codelessly_sdk.dart';

/// Renders a [PaginationNode]: page controls for the pagination controller
/// it names.
class PassivePaginationTransformer
    extends NodeWidgetTransformer<PaginationNode> {
  /// Creates a [PassivePaginationTransformer].
  PassivePaginationTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    PaginationNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) => PassivePaginationWidget(node: node, settings: settings);
}

/// The page controls of a [PaginationNode], following its controller.
///
/// Until a list creates the controller (in the editor's canvas, or before
/// the list builds), it shows page 1 of 10 so the design has something to
/// show.
class PassivePaginationWidget extends StatelessWidget {
  /// The node.
  final PaginationNode node;

  /// The settings the node is built with.
  final WidgetBuildSettings settings;

  /// Creates a [PassivePaginationWidget].
  const PassivePaginationWidget({
    super.key,
    required this.node,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final PaginationRegistry? registry = context
        .read<CodelesslyContext?>()
        ?.pagination;
    if (registry == null) return _controls(context, null);
    return ListenableBuilder(
      listenable: registry,
      builder: (context, _) {
        final String name = PropertyValueDelegate.substituteVariables(
          node.controller,
          scopedValues: ScopedValues.of(context),
          nullSubstitutionMode: NullSubstitutionMode.emptyString,
        ).trim();
        final PaginationController? controller = registry[name];
        if (controller == null) return _controls(context, null);
        return ListenableBuilder(
          listenable: controller,
          builder: (context, _) => _controls(context, controller),
        );
      },
    );
  }

  Widget _controls(BuildContext context, PaginationController? controller) {
    final PaginationProperties p = node.properties;
    final int page = controller?.page ?? 1;
    final int? pageCount =
        controller?.pageCount ?? (controller == null ? 10 : null);
    final int? total =
        controller?.totalCount ?? (controller == null ? 200 : null);
    final int from = controller?.from ?? 1;
    final int to = controller?.to ?? 20;
    final bool hasMore = controller?.hasMore ?? true;
    final bool enabled = controller != null && node.enabled;

    Future<void> go(Future<void> Function() move) async {
      await move();
      if (!context.mounted || controller == null) return;
      FunctionsRepository.triggerAction(
        context,
        TriggerType.changed,
        node: node,
        value: controller.page,
      );
    }

    final TextStyle style = TextStyle(
      fontSize: p.fontSize,
      fontWeight: FontWeight.values[((p.fontWeight ~/ 100) - 1).clamp(0, 8)],
      color: p.textColor.toFlutterColor(),
    );

    Widget button({
      required String label,
      required bool canPress,
      required VoidCallback onPressed,
      bool active = false,
      String? semantics,
    }) => PaginationButton(
      label: label,
      style: style,
      properties: p,
      active: active,
      enabled: enabled && canPress,
      semanticsLabel: semantics,
      onPressed: onPressed,
    );

    final List<Widget> buttons = [
      if (p.showFirstLast)
        button(
          label: p.firstLabel,
          semantics: 'First page',
          canPress: page > 1,
          onPressed: () => go(controller!.first),
        ),
      if (p.showPrevNext)
        button(
          label: p.previousLabel,
          semantics: 'Previous page',
          canPress: page > 1,
          onPressed: () => go(controller!.previous),
        ),
      if (p.showPageNumbers)
        for (final int? number in PaginationProperties.pageItems(
          page: page,
          pageCount: pageCount ?? page + (hasMore ? 1 : 0),
          siblingCount: math.max(0, p.siblingCount),
          boundaryCount: math.max(0, p.boundaryCount),
        ))
          if (number == null)
            SizedBox(
              width: p.buttonSize * 0.75,
              child: Text('…', style: style, textAlign: TextAlign.center),
            )
          else
            button(
              label: '$number',
              semantics: 'Page $number',
              active: number == page,
              canPress: number != page,
              onPressed: () => go(() => controller!.goTo(number)),
            ),
      if (p.showPrevNext)
        button(
          label: p.nextLabel,
          semantics: 'Next page',
          canPress: hasMore,
          onPressed: () => go(controller!.next),
        ),
      if (p.showFirstLast)
        button(
          label: p.lastLabel,
          semantics: 'Last page',
          canPress: pageCount != null && page < pageCount,
          onPressed: () => go(controller!.last),
        ),
    ];

    final String summary = p.summaryText
        .replaceAll('{from}', '$from')
        .replaceAll('{to}', '$to')
        .replaceAll('{total}', total == null ? 'many' : '$total')
        .replaceAll('{page}', '$page')
        .replaceAll('{pageCount}', pageCount == null ? '?' : '$pageCount');

    final List<int> options = [
      ...(controller?.model.pageSizeOptions ?? const [10, 20, 50, 100]),
    ];
    final int pageSize = controller?.pageSize ?? 20;
    if (!options.contains(pageSize)) options.add(pageSize);
    options.sort();

    return Padding(
      padding: node.padding.flutterEdgeInsets,
      child: Wrap(
        alignment: p.alignment.flutterWrapAlignment,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: p.spacing * 3,
        runSpacing: p.spacing,
        children: [
          if (p.showSummary)
            Text(
              PropertyValueDelegate.substituteVariables(
                summary,
                scopedValues: ScopedValues.of(context),
                nullSubstitutionMode: NullSubstitutionMode.emptyString,
              ),
              style: style,
            ),
          Wrap(
            spacing: p.spacing,
            runSpacing: p.spacing,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: buttons,
          ),
          if (p.showPageSize)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(p.pageSizeLabel, style: style),
                SizedBox(width: p.spacing * 2),
                DropdownButton<int>(
                  value: pageSize,
                  style: style,
                  isDense: true,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final int option in options)
                      DropdownMenuItem(value: option, child: Text('$option')),
                  ],
                  onChanged: enabled
                      ? (value) {
                          if (value != null) {
                            go(() => controller!.setPageSize(value));
                          }
                        }
                      : null,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// One button of a [PaginationNode].
class PaginationButton extends StatelessWidget {
  /// The text.
  final String label;

  /// The text style.
  final TextStyle style;

  /// The node's style.
  final PaginationProperties properties;

  /// Whether this is the current page.
  final bool active;

  /// Whether it can be pressed.
  final bool enabled;

  /// What a screen reader says.
  final String? semanticsLabel;

  /// Called when pressed.
  final VoidCallback onPressed;

  /// Creates a [PaginationButton].
  const PaginationButton({
    super.key,
    required this.label,
    required this.style,
    required this.properties,
    required this.active,
    required this.enabled,
    required this.onPressed,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final PaginationProperties p = properties;
    final BorderRadius radius = BorderRadius.circular(p.cornerRadius);
    final Color? background = active
        ? p.activeColor.toFlutterColor()
        : p.buttonColor?.toFlutterColor();
    final Color? border = active ? null : p.borderColor?.toFlutterColor();
    return Semantics(
      button: true,
      selected: active,
      enabled: enabled,
      label: semanticsLabel ?? label,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled || active ? 1 : p.disabledOpacity,
        child: Material(
          color: background ?? Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: border == null || p.borderWidth <= 0
                ? BorderSide.none
                : BorderSide(color: border, width: p.borderWidth),
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: enabled ? onPressed : null,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: p.buttonSize,
                minHeight: p.buttonSize,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    label,
                    style: active
                        ? style.copyWith(
                            color: p.activeTextColor.toFlutterColor(),
                            fontWeight: FontWeight.w600,
                          )
                        : style,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
